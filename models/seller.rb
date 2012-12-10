# -*- encoding: utf-8 -*-

class Seller
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  # Referenced
  embeds_one  :timeline,  as: :timeable
  embeds_many :timelines, as: :timeable
  # 分类
  has_many :categories, foreign_key: 'seller_nick', dependent: :delete    
  # 大促
  has_many :campaigns,  foreign_key: 'seller_nick', dependent: :delete
  # 宝贝
  has_many :items, foreign_key: 'seller_nick', dependent: :delete do
    def new_arrivals
      where(timelines: nil)
    end
    def paids(range = Date.today)
      where(:'timelines.increment.month_num'.lt => 0, 'timelines.date' => range)
    end
  end

  attr_accessor :crawler

  # Fields
  field :seller_id,   type: Integer
  field :shop_id,     type: Integer
  field :items_count, type: Integer, default: 0

  field :uid,         type: String   # 用户字符串ID

  field :seller_nick, type: String
  field :store_url,   type: String
  field :company,     type: String
  field :label,       type: String
  
  field :timestamp,   type: Integer # 同步时间
  field :_id,         type: String,  default: -> { seller_nick }

  after_create :set_info

  def to_i
    seller_id
  end

  def set_info
    if uid
      unless defined?(@crawler)
        @crawler = {} 
      end
      @crawler[_id] = Crawler.new(rate_url)
      page_dom = @crawler[_id].get_dom
      return nil if page_dom.nil?
      info_list = page_dom.at('div.personal-info').at('ul').css('li')
      company   = info_list[0].at('div.fleft2').text.strip
      label     = info_list[1].at('a').text.strip
      # 更新
      update_attributes(company: company, label: label)
    end
  end

  def rate_url
    'http://rate.taobao.com/user-rate-' + uid + '.htm'
  end

  def category_parents
    categories.where(parent_id: nil)
  end

  def sync(error_count = 0)
    # 起始化
    unless defined?(@threading)
      timestamp = Time.now.to_i
      @threading = { timestamp: timestamp }
    end
    # 初始值
    unless @threading.has_key?(_id)
      @threading[_id] = { seller_id: seller_id, seller_nick: seller_nick, crawler: Crawler.new(store_url), pages: 1, page: 1, campaigns:  {}, categories: {}, items: {} }
      @threading[_id][:crawler].item_search_url
      logger.info "#{_id}，数据抓取准备就绪。"
    end
    page_dom = @threading[_id][:crawler].get_dom # 获取首页对象
    if page_dom.nil?
      @threading.delete(_id)
      logger.error "#{_id}，抓取错误，任务被清除。"
    else
      @threading[_id] = Item.sync(@threading, _id, page_dom) # 店铺宝贝
      # 下架或售罄同步
      item_onsales_count = @threading[_id][:items].keys.count
      if item_onsales_count > 0 && items_count > item_onsales_count
        unknown_ids = self.item_ids - @threading[_id][:items].keys
        unless unknown_ids.empty?
          @threading[_id] = Item.recycling(@threading, _id, unknown_ids) 
        end
      end
      if @threading[_id][:items].empty?
        if error_count < 3
          error_count += 1
          logger.error "数据丢失，将开始 第#{error_count}次 重试。"
          sleep error_count
          sync(error_count)
        else
          logger.error "三次失败，放弃吧~~"
          @threading.delete(_id)
        end
      else
        # 店铺分类
        @threading[_id] = Category.sync(@threading, _id, page_dom) # 分类及宝贝归类。
        @threading[_id][:items] = Item.each_items(@threading[_id][:items]) # 写入宝贝数据，获取数值变化。
        Category.each_categories( @threading[_id][:categories], @threading[_id][:items] )
        Campaign.each_campaigns(  @threading[_id][:campaigns],  @threading[_id][:items] )
        # 更新店铺
        timeline = Timeline.new( Seller.each_timelines( @threading[_id][:items] ) )
        update_attributes(timelines: (timelines << timeline), items_count: @threading[_id][:items].keys.count, timestamp: @threading[:timestamp])
        # 清场
        @threading[_id][:items].clear
        @threading.delete(_id)
        if @threading.count == 1
          logger.error "批次：#{@threading[:timestamp]}，同步结束。"
          remove_instance_variable(:@threading)
        end
      end
    end
  end

  class << self

    def sync(store_url)
      crawler = Crawler.new(store_url)
      crawler.item_search_url
      page_dom = crawler.get_dom # 获取页面对象
      return nil if page_dom.nil? # 非法地址

      seller_nick    = get_seller_nick(page_dom)
      current_seller = where(_id: seller_nick.to_s).first

      result = if current_seller.nil?
        seller     = { store_url: store_url, seller_nick: seller_nick, uid: get_uid(page_dom) }
        seller_ids = parse_seller_ids(page_dom)

        if seller_ids
          logger.info "通过#{store_url}，创建店铺 #{seller_nick}。"
          seller.merge!(seller_ids)
          { status: 'created', seller: create(seller) } # 创建店铺
        else
          logger.error "通过#{store_url}，创建店铺失败。"
          nil # 识别不出HTML内容
        end
      else
        { status: 'already', seller: current_seller } # 店铺已存在
      end
      return result
    end

    private
    include SellerParse
    include TimelineParse
  end
end
# -*- encoding: utf-8 -*-

class Seller
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  embeds_many :sales,     as: :saleable, class_name: 'Sale'
  embeds_one  :last_sale, as: :saleable, class_name: 'Sale'
  # Referenced
  # 分类
  has_many :categories, foreign_key: 'seller_nick', dependent: :delete    
  # 大促
  has_many :campaigns, foreign_key: 'seller_nick', dependent: :delete
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
  field :uid,         type: String   # 用户字符串ID

  field :seller_nick, type: String
  field :store_url,   type: String
  field :company,     type: String
  field :label,       type: String
  
  field :synced_at,   type: DateTime # 店铺同步时间
  field :_id,         type: String,  default: -> { seller_nick }

  after_create :set_info

  def synced_time
    if synced_at
      synced_at.in_time_zone.strftime("%m月%d日 %H时")
    else
      '期待数据中..'
    end
  end

  def set_info
    if uid
      @crawler = Crawler.new(rate_url)
      page_dom = @crawler.get_dom
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

  def sync
    @crawler = Crawler.new(store_url)
    @crawler.item_search_url
    page_dom = @crawler.get_dom # 获取页面对象
    return nil if page_dom.nil?
    logger.info "更新，#{seller_nick}店铺数据。"
    store_sync(page_dom) 
  end

  def store_sync(page_dom)
    syncing_at = Time.now
    timestamp  = syncing_at.to_i
    
    if Category.sync(self, page_dom)
      logger.info "店铺分类数：#{categories.count}。"
      Item.sync(self, timestamp)
    else
      logger.warn "没有找到店铺分类。"
      Item.sync(self, timestamp, page_dom)
    end
    # 下架或售罄同步
    Item.recycling(self, timestamp)
    # 销售统计
    Sale.sync(self, synced_at.to_i)
    # 更新店铺同步时间
    update_attributes(synced_at: syncing_at)
  end

  class << self

    def sync(store_url)
      @crawler = Crawler.new(store_url)
      @crawler.item_search_url
      page_dom = @crawler.get_dom # 获取页面对象
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

    def parse_seller_ids(page_dom)
      html = page_dom.xpath("//meta[@name='microscope-data']/@content").first.value
      { seller_id: parse_seller_id(html).to_i, shop_id: parse_shop_id(html).to_i } if html
    end

    def parse_shop_id(html)
      html.match(/shopId=(.*);\ userid/)[1]
    end

    def parse_seller_id(html)
      html.match(/userid=(.*);/)[1]
    end

    def get_seller_nick(page_dom)
      seller_nick = page_dom.at('div#shop-info').at('span.J_WangWang')['data-nick']
      URI.decode(seller_nick) if seller_nick
    end

    def get_uid(page_dom)
      uid = page_dom.at('p.shop-grade')
      uid.css('a').first['href'].match(/rate-(.*).htm/)[1] if uid
    end
  end

end
# -*- encoding: utf-8 -*-
require 'redis/hash_key'

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
  field :user_tag,    type: Integer
  
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
      info_list = page_dom.at('div.left-box').at('ul').css('li')
      company   = info_list[0].at('div.fleft2').text.strip
      label     = info_list[1].at('a').text.strip
      user_tag  = page_dom.at('input#userTag')[:value].to_i
      # 更新
      update_attributes(company: company, label: label, user_tag: user_tag)
    end
  end

  def rate_url
    'http://rate.taobao.com/user-rate-' + uid + '.htm'
  end

  def category_parents
    categories.where(parent_id: nil)
  end

  def sync(error_count = 0)
    crawler  = Crawler.new(store_url)
    crawler.item_search_url
    page_dom = crawler.get_dom # 获取首页对象

    unless page_dom.nil?
      threading = Item.sync(self, page_dom) # 店铺宝贝
      if threading[:items].empty?
        if error_count < 3
          error_count += 1
          logger.error "数据丢失，将开始 第#{error_count}次 重试。"
          sleep error_count
          sync(error_count)
        else
          logger.error "三次失败，放弃吧~~"
          return nil
        end
      else
        # 店铺分类
        threading = Category.sync(threading, page_dom) # 分类及宝贝归类。
        threading[:items] = Item.each_items(threading[:items]) # 写入宝贝数据，获取数值变化。
        Category.each_categories( threading[:categories], threading[:items], timestamp )
        Campaign.each_campaigns( threading[:campaigns],  threading[:items], timestamp )
        # 更新店铺
        data = { items_count: threading[:items].keys.count, timestamp: Time.now.to_i }
        timeline = Seller.each_timelines(threading[:items], timestamp)
        if timeline.is_a?(Hash) 
          if timeline.has_key?(:increment)
            timeline[:increment][:items_count] = timeline[:items_count] - items_count
          end
          timeline_arr = ActiveSupport::JSON.decode(timelines.to_json)
          timeline_arr << timeline
          data[:timelines] = timeline_arr.uniq
        end
        update_attributes(data)
      end
      Item.thread_reset(_id)
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

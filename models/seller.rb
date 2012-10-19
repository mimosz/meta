# -*- encoding: utf-8 -*-
require 'pp'

class Seller
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  # Referenced
  has_many :categories, foreign_key: 'seller_nick' # 分类
  has_many :items,      foreign_key: 'seller_nick'

  attr_accessor :crawler

  # Fields
  field :seller_id,   type: Integer
  field :shop_id,     type: Integer

  field :seller_nick, type: String
  field :store_url,   type: String
  field :_id,         type: String, default: -> { seller_nick }

  def category_parents
    categories.where(parent_id: nil)
  end

  def item_arrivals
    items.not_in(_id: Sale.where( seller_nick: _id).only(:num_iid).distinct(:num_iid))
  end

  def item_paids(range = Date.today)
    items.where(:_id.in => Sale.where( seller_nick: _id, :month_num.lt => 0, date: range).only(:num_iid).distinct(:num_iid))
  end

  def sync
    Seller.sync(store_url)
  end

  def store_sync(page_dom)
    if Category.sync(self, page_dom)
      puts "店铺分类数：#{categories.count}"
      Item.sync(self)
    else
      puts "没有找到店铺分类。"
      Item.sync(self, page_dom)
    end
  end

  class << self

    def sync(store_url)
      @crawler = Crawler.new(store_url)
      @crawler.item_search_url

      page_dom       = @crawler.get_dom # 获取页面对象
      seller_nick    = get_seller_nick(page_dom)
      current_seller = where(_id: seller_nick.to_s).last

      if current_seller.nil?
        seller     = { store_url: store_url, seller_nick: seller_nick }
        seller_ids = parse_seller_ids(page_dom)
        if seller_ids
          seller.merge!(seller_ids) 
          current_seller = create(seller) 
        end
      else
        puts "更新#{current_seller._id}店铺数据。"
      end
      if current_seller
        current_seller.store_sync(page_dom) 
      else
        puts "通过#{store_url} 创建店铺失败。"
      end
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

  end

end
# -*- encoding: utf-8 -*-

class Item
  include Mongoid::Document
  # Referenced
  has_and_belongs_to_many :categories, index: true do
    def cat_names
      only(:cat_name).distinct(:cat_name)
    end
  end
  has_and_belongs_to_many :campaigns, index: true  do # 大促
    def campaigning(date = Date.today )
      where(:end_at.gte => date)
    end
  end

  embeds_many :timelines
  belongs_to  :seller,  foreign_key: 'seller_nick', index: true

  # Fields
  field :num_iid,     type: Integer
  field :seller_nick, type: String

  field :outer_id,    type: String
  field :title,       type: String
  field :pic_url,     type: String

  field :prom_type,     type: String

  field :price,         type: Float,   default: 0
  field :tag_price,     type: Float,   default: -> { price }
  field :prom_price,    type: Float,   default: -> { price }
  field :prom_discount, type: Integer, default: 100

  field :total_num,   type: Integer,  default: 0
  field :month_num,   type: Integer,  default: 0
  field :quantity,    type: Integer,  default: 0

  field :favs_count,  type: Integer,  default: 0
  field :skus_count,  type: Integer,  default: 0
  field :post_fee,    type: Boolean,  default: false

  field :synced_at,   type: DateTime, default: -> { Time.now }

  field :_id,         type: Integer,  default: -> { num_iid }

  default_scope desc(:favs_count)

  def to_timeline
    {
      outer_id:      outer_id,
      title:         title,
      pic_url:       pic_url,
      prom_type:     prom_type,
      price:         price,
      prom_price:    prom_price,
      prom_discount: prom_discount,
      total_num:     total_num,
      month_num:     month_num,
      quantity:      quantity,
      favs_count:    favs_count,
      skus_count:    skus_count,
      post_fee:      post_fee,
      synced_at:     synced_at
    }
  end

  def item_url
    'http://detail.tmall.com/item.htm?id=' << num_iid.to_s
  end

  class << self

    def sync(seller, page_dom=nil)
      @pages    = 0
      @seller   = seller
      @crawler  = Crawler.new(seller.store_url)
      @category = nil # 分类
      @campaign = nil # 大促

      if page_dom
        puts "没有店铺类目。"
        items_dom = init_items(page_dom)
        if items_dom
          each_items(items_dom)
          each_pages
        end
      else
        unless seller.categories.empty?
          seller.categories.each do |category|
            @category = category
            page_dom  = get_page_dom
            if page_dom
              items_dom = init_items(page_dom)
              if items_dom
                each_items(items_dom)
                each_pages
              end
            else
              puts "店铺分类：#{category.cat_name}"
            end
          end
        end
      end
    end

    private

    def get_page_dom(page=1)
      params = { 'pageNum' => page }
      if @category
        params.merge!({'scid' => @category.cat_id}) 
        puts "店铺分类：#{@category.cat_name}。"
      end
      @crawler.params = params
      @crawler.item_search_url

      return @crawler.get_dom
    end

    def get_items_dom(page_dom)
      list = page_dom.at('div.shop-hesper-bd')
      list = list.at('ul.shop-list') if list
      list.css('li') if list
    end

    def get_total(page_dom)
      search_dom = page_dom.at('div.search-result')
      if search_dom
        return search_dom.at('span').text.to_i 
      else
        items_dom = get_items_dom(page_dom)
        if items_dom
          pages = page_dom.at('div.shop-filter').at('span.page-info')
          total = pages.split('/').last
          return total * items_dom.count
        end
      end
      0
    end

    def init_items(page_dom)
      total = get_total(page_dom)
      if total < 1
        puts "本页没有货品。"
      else
        items_dom = get_items_dom(page_dom)
        if items_dom
          items_count = items_dom.count
          puts "共有货品 #{total}件，每页 #{items_count}件。"
          @pages      = pages_count(total, items_count) if total > items_count
          return items_dom
        else
          puts "咦~，共有#{total}件货品呀？"
        end
      end
      nil
    end

    def each_pages
      # 分页执行
      if @pages > 1
        2.upto(@pages).each do |page|
          page_dom  = get_page_dom(page)
          items_dom = get_items_dom(page_dom) if page_dom
          each_items(items_dom) if items_dom
          puts "第 #{page}/#{@pages} 页。"
        end
      else
        puts "没有分页。"
      end
    end

    def each_items(items_dom)
      items_dom.each do |item_dom|
        item = parse_item(item_dom)
        if item
          # 取值完毕，开始操作数据库
          current_item = where(_id: item[:num_iid].to_i).last
          if current_item
            # 分类
            if @category && !current_item.category_ids.include?(@category.cat_id)
              current_item.categories << @category
              current_item.save
            end
            # 内容无变更的update操作，updated_at也不会变更，新增synced_at字段，解决此问题
            if current_item.synced_at < 45.minutes.ago # 6.hours.ago
              # 获取销售信息
              set_item_sales(item)
              # 创建历史版本
              timeline = Timeline.new(current_item.to_timeline)
              # 创建增量，差值
              timeline.increment_create(current_item)
              # 绑定属性
              current_item.timelines << timeline
              current_item.campaigns << @campaign if @campaign
              current_item.update_attributes(item)
            else
              puts "跳过，重复计算。"
            end
          else
            set_item_sales(item)
            item[:categories] = [@category] if @category
            item[:campaigns]  = [@campaign] if @campaign
            current_item      = @seller.items.create(item)
          end
        end
      end
    end

    def parse_item(item_dom)
      item_link = item_dom.at('div.pic').at('a')
      if item_link
        num_iid   = parse_num_iid(item_link)
        pic_url   = parse_pic_url(item_link)

        title     = item_dom.at('div.desc').at('a').text.strip
        price     = item_dom.at('div.price').at('strong').text[0..-3].to_f
        total_num = item_dom.at('div.sales-amount').at('em').text.to_i
        return { synced_at: Time.now, num_iid: num_iid, outer_id: parse_outer_id(title), total_num: total_num, title: title, pic_url: pic_url, price: price }
      end
      nil
    end

    def parse_num_iid(link_dom)
      return link_dom['href'][36..-2].to_i
    end

    def parse_pic_url(link_dom)
      img_dom = link_dom.at('img')
      pic_url = img_dom['data-ks-lazyload'] || img_dom['src']
      if pic_url
        pic_url.gsub!('_b.jpg', '')
        pic_url.gsub!('_160x160.jpg', '')
      end
      return pic_url
    end

    def parse_outer_id(title)
      title = title.gsub(/\p{Han}/, ',') # 剔汉字
      arr   = title.split(',').compact.reverse
      arr.each do |str|
        return str.strip unless str.size < 3
      end
      nil
    end

    def set_item_sales(node)
      # 宝贝销售数据
      sales_json = @crawler.tmall_item_json(@seller.seller_id, node[:num_iid]) # 地址被改变
      sales      = parse_sales(sales_json) if sales_json
      node.merge!(sales)
      # 宝贝收藏数
      favs_count = @crawler.get_favs_count(node[:num_iid])
      node[:favs_count] = favs_count if favs_count
    end

    def wenrentuan(pay_count, counts, prices) # 万人团，动态价格
      counts.each_with_index do |count, i|
        if pay_count > count
          return prices[i].to_i
        end
      end
      return prices[0].to_i
    end

    def to_date(timestamp) # 淘宝，时间戳转换
      timestamp = timestamp.to_s
      timestamp = timestamp.to_s[0..9] if timestamp.size > 10
      return Time.at(timestamp.to_i)
    end

    def set_campaign(campaign) # 大促
      start_at    = to_date(campaign['startTime'])
      end_at      = to_date(campaign['endTime'])
      seller_nick = @seller._id
      campaign_id = "#{seller_nick}-#{start_at.to_i}-#{end_at.to_i}"
      
      if !@campaign.nil? && @campaign._id == campaign_id
        return @campaign
      end

      @campaign = Campaign.where(_id: campaign_id ).last
      if @campaign.nil?
        @campaign = Campaign.create({
           seller_nick: seller_nick,
              start_at: start_at, 
                end_at: end_at, 
                  name: campaign['campaignName'], 
              discount: (campaign['shopUnderFiftyPOff'] ? 50 : 100),
                  plan: campaign['promotionPlan']
        })
      end
    end

    def parse_sales(json)
      sales  = {}
      if json['isSuccess']
        root = json['defaultModel']

        month_num  = root['sellCountDO']['sellCount']
        quantity   = root['inventoryDO']['icTotalQuantity']
        skus_count = root['inventoryDO']['skuQuantity'].count
        sales.merge!({ month_num: month_num, quantity: quantity, skus_count: skus_count })

        item_price = root['itemPriceResultDO']
        # 默认价格体系
        prices     = item_price['priceInfo']
        price_info = prices[prices.keys[0]]

        if price_info && price_info['price']
          price             = price_info['price'].to_f    # 原价
          tag_price         = price_info['tagPrice'].to_f # 吊牌价
          sales[:tag_price] = tag_price
          # 大促
          if item_price['campaignInfo']
            set_campaign(item_price['campaignInfo'])
          else
            @campaign = nil # 清除，大促信息
          end
          # 优惠
          if price_info['promPrice']
            prom = price_info['promPrice']
            prom_type  = prom['type']
            # 优惠价
            prom_price   = if prom_type == '万人团' && item_price['wanrentuanInfo']
              wanrentuan = item_price['wanrentuanInfo']
              pay_count  = wanrentuan['groupUC'].to_i                # 当前购买数
              counts     = wanrentuan['wrtLevelNeedCounts'].reverse  # 购买等级
              prices     = wanrentuan['wrtLevelFinalPrices'].reverse # 价格等级
              (wenrentuan(pay_count, counts, prices) / 100)
            else
              prom['price'].to_f  
            end

          sales[:prom_price]     = prom_price.round(2)
          sales[:prom_type]      = prom_type
          sales[:prom_discount]  = prom_price / price * 100
          end
        end
        if root['deliveryDO']['deliverySkuMap']['default'][0]['postage'] = '商家承担运费'
          sales[:post_fee] = true
        end
      else
        puts "模板变更需要调整：#{@crawler.request.url}"
      end
      return sales
    end

    def pages_count(total, size=20)
      page = (total / size.to_f).to_i
      page += 1 if (total % size) > 0
      return page
    end
  end
end
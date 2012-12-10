# -*- encoding: utf-8 -*-
module BaseParse # 分类、宝贝，需要调用。
  def get_items_dom(page_dom)
    list = page_dom.at('div.shop-hesper-bd')
    list = list.at('ul.shop-list') if list
    list.css('li') if list
  end

  def parse_num_iid(link_dom)
    return link_dom['href'][36..-2].to_i
  end

  def get_total(page_dom)
    search_dom = page_dom.at('div.search-result')
    if search_dom
      return search_dom.at('span').text.to_i 
    else
      items_dom = get_items_dom(page_dom) # 共享给分类
      if items_dom
        pages = page_dom.at('div.shop-filter').at('span.page-info')
        total = pages.split('/').last
        return total * items_dom.count
      end
    end
    0
  end
end

module ItemParse
  def parse_item(seller_id, item_dom, timestamp)
    item_link = item_dom.at('div.pic').at('a')
    if item_link
      num_iid   = parse_num_iid(item_link)
      pic_url   = parse_pic_url(item_link)

      title     = item_dom.at('div.desc').at('a').text.strip
      price     = item_dom.at('div.price').at('strong').text[0..-3].to_f
      total_num = item_dom.at('div.sales-amount').at('em').text.to_i
      return ActiveSupport::JSON.decode(
        Item.new(status: 'onsale', seller_nick: seller_id, timestamp: timestamp, num_iid: num_iid, outer_id: parse_outer_id(title), total_num: total_num, title: title, pic_url: pic_url, price: price).to_json
      ).symbolize_keys
    end
    nil
  rescue Nokogiri::XML::XPath::SyntaxError => error
    each_pages(seller_id, nil, @threading[seller_id][:page])
    logger.error "HTML解析错误，开始重试~"
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
    return ::Time.at(timestamp.to_i)
  end

  def parse_sales(seller_id, item_id, json)
    sales  = {}
    if json['isSuccess']
      root = json['defaultModel']

      sales[:month_num]  = root['sellCountDO']['sellCount']
      sales[:quantity]   = root['inventoryDO']['icTotalQuantity']
      sales[:skus_count] = root['inventoryDO']['skuQuantity'].count
      sales[:status]     = 'soldout' if sales[:quantity] == 0 # 售罄

      item_price = root['itemPriceResultDO']
      # 默认价格体系
      prices     = item_price['priceInfo']
      price_info = prices[prices.keys[0]]

      if price_info && price_info['price']
        price             = price_info['price'].to_f    # 原价
        tag_price         = price_info['tagPrice'].to_f # 吊牌价
        sales[:tag_price] = tag_price
        # 大促
        sales[:campaign_ids] << set_campaign(seller_id, item_id, item_price['campaignInfo']) if item_price['campaignInfo']
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
      logger.fatal "宝贝的JSON数据模板，需要调整。"
    end
    return sales
  end
end

module CategoryParse
  def get_cats_dom(page_dom) # 淘宝系统，树形分类
    page_dom.at('ul#J_Cats').css('li.cat') if page_dom.at('ul#J_Cats')
  end

  def parse_cat(cat_dom, priority, parent_id)
    ActiveSupport::JSON.decode(
      Category.new(
        cat_id: parse_id(cat_dom[:id]), 
        priority: priority, 
        cat_name: parse_name(cat_dom.at('a')), 
        parent_id: parent_id
      ).to_json
    ).symbolize_keys
  end

  def parse_name(link_dom)
    name = link_dom.text
    name = link_dom.at('img')[:alt] if name.blank?
    name.strip
  end

  def parse_id(html)
    html.gsub('J_Cat','')
  end

  def find_cat(link)
    href = link[:href]
    if href.nil?
      logger.info 'HTML解析，跳过，锚'
    else
      params = ::URI.parse(href.strip).query || nil
      if params.nil?
        logger.info 'HTML解析，跳过，无参数链接'
      else
        params = ::CGI.parse(params)
        if params.has_key?('scid') # 分类链接
          cat_id = params['scid'].first
          return nil if cat_id.blank?
          if params.has_key?('scname')
            cat_name = ::Base64.decode64(::URI.unescape(params['scname'].first )).force_encoding("GB18030").encode("UTF-8") # 淘宝分类链接，名称编码解析
          else # 链接参数中，不带名称
            cat_name = link.text
            if cat_name.blank? # 无文字，找图片文字
              img = link.at('img')
              if img
                cat_name = img['alt']
                cat_name = img['data-ks-lazyload'] || img['src'] if cat_name.blank?
              else
                cat_name = '未知分类'  
              end
            end
          end
          return ActiveSupport::JSON.decode(
            Category.new(cat_id: cat_id, cat_name: cat_name).to_json
          ).symbolize_keys
        else
          logger.info 'HTML解析，跳过，非分类链接'
        end
      end
    end
    nil
  rescue ::URI::InvalidURIError
    nil
  end
end

module SellerParse
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
    ::URI.decode(seller_nick) if seller_nick
  end

  def get_uid(page_dom)
    uid = page_dom.at('p.shop-grade')
    uid.css('a').first['href'].match(/rate-(.*).htm/)[1] if uid
  end
end

module TimelineParse
  def timeline_sum(timeline, item)
    # 售价
    price = if item.has_key?(:prom_price) && item[:prom_price] > 0
      item[:prom_price]
    else
      item[:price]
    end
    # 货值
    timeline[:price] += price * item[:quantity]
    # 
    timeline[:total_num] += item[:total_num]
    timeline[:month_num] += item[:month_num]
    timeline[:quantity]  += item[:quantity]

    timeline[:favs_count]  += item[:favs_count]
    timeline[:skus_count]  += item[:skus_count]

    timeline[:items_count]  += 1

    case item[:status]
    when 'onsale'
      timeline[:onsales] = ([item[:num_iid]] && timeline[:onsales])
    when 'soldout'
      timeline[:soldouts] = ([item[:num_iid]] && timeline[:soldouts])
    when 'inventory'
      timeline[:inventories] = ([item[:num_iid] ]&& timeline[:inventories])
    end
    timeline[:proms] = ([item[:prom_type] ]&&  timeline[:proms]) if item[:prom_type]

    if item.has_key?(:timeline)
      timeline[:increment][:total_num] += item[:timeline][:increment][:total_num]
      timeline[:increment][:month_num] += item[:timeline][:increment][:month_num]
      timeline[:increment][:quantity]  += item[:timeline][:increment][:quantity]

      timeline[:increment][:favs_count] += item[:timeline][:increment][:favs_count]
      timeline[:increment][:skus_count] += item[:timeline][:increment][:skus_count]

      timeline[:increment][:total_sales] += item[:timeline][:increment][:total_sales]
      timeline[:increment][:month_sales] += item[:timeline][:increment][:month_sales]
      timeline[:increment][:qty_sales]   += item[:timeline][:increment][:qty_sales]
    end
  end

  def each_timelines(items, item_ids=[])
    timeline = ActiveSupport::JSON.decode(Timeline.new(increment: Increment.new).to_json).symbolize_keys
    items.each do |id, item|
      if item_ids.empty?
        timeline_sum(timeline, item)
      elsif item_ids.include?(id)
        timeline_sum(timeline, item)
      end
    end
    return timeline
  end
end
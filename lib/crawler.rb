# -*- encoding: utf-8 -*-
require 'nestful'
require 'nokogiri'
require 'pp'

class Crawler
  def initialize(url)
    @url     = url
    @request = Nestful::Request.new(@url)
    @request.headers = { 'User-Agent' => switcher }
  end

  def request
    @request
  end

  def url=(value)
    request.url = value
  end

  def params=(value)
    request.params = value
  end

  def headers=(value)
    request.headers.merge!(value)
  end


  def get_html(opts={})
    path      = opts[:path]      || request.query_path
    try_count = opts[:try_count] || 0
    debug # 调试
    response = request.connection.get(path)
    return response.body.force_encoding('GB18030').encode('UTF-8')
  rescue Nestful::TimeoutError, Errno::ETIMEDOUT, Errno::ECONNRESET
    if opts[:try_count].to_i < 3 # 重试3次
      puts "========================开始重试========================"
      get_html({try_count: (try_count + 1)})
    else
      puts "========================很扯，三次都没搞定========================"
    end
  rescue Nestful::Redirection => error
    location = error.response['Location']
    if location.include?('deny.html') || location.include?('error.php')
      puts "========================宝宝醒了，换浏览器。========================"
      self.headers = { 'User-Agent' => switcher, 'Referer' => request.url }
      get_html({try_count: (try_count + 1)})
    else
      url = location
      get_html({path: fixed_path, try_count: try_count})
    end
  rescue Nestful::ServerError => error
    return nil
  end

  def get_json(try_count=0)
    request.execute
  rescue Nestful::TimeoutError, Errno::ETIMEDOUT
    if try_count < 3 # 重试3次
      puts "========================开始重试========================"
      get_json(try_count + 1)
    else
      puts "========================很扯，三次都没搞定========================"
    end
  end

  def debug
    puts request.url
    puts request.params
    puts request.headers
  end

  def get_dom
    html = get_html
    dom = if html.nil?
      nil
    else
      Nokogiri::HTML(html)
    end
    return dom
  end

  def taobao_item_json(seller_id, num_iid)
    self.url     = item_taobao_url
    self.params  = { 
      ump: false, 
      itemId: num_iid, 
      sellerId: seller_id, 
      templateId: 0,
      isWrtTag: false,
      isAreaSell: false,
      isSellerPay: true,
      isSpu: true,
      tgTag: false,
      isSecKill: false,
      itemWeight: 0,
      tmallBuySupport: true,
      campaignType: 0,
      callback: 'item' 
    }
    self.headers = { 'Referer' => item_url(num_iid) }

    html = get_json
    if html
      html = html.force_encoding("GBK").encode("UTF-8")
      json = html.match(/item\((.*)\)/)[1]
      if json
        pp json
        return ActiveSupport::JSON.decode(json)
      end
    else
      puts "模板变更需要调整：#{request.url}"
    end
    nil
  end

  def tmall_item_json(seller_id, num_iid)
    self.url     = item_tmall_url
    self.params  = { 
      ump: false, 
      itemId: num_iid, 
      sellerId: seller_id, 
      templateId: 0,
      isWrtTag: false,
      isAreaSell: false,
      isSellerPay: true,
      isSpu: true,
      tgTag: false,
      isSecKill: false,
      itemWeight: 0,
      tmallBuySupport: true,
      campaignType: 0,
      callback: 'item' 
    }
    self.headers = { 'Referer' => item_url(num_iid) }

    html = get_json
    if html
      html = html.force_encoding("GBK").encode("UTF-8")
      json = html.match(/item\((.*)\)/)
      if json
        json     = json[1]
        int_keys = json.scan(/([0-9]+):/)
        unless int_keys.empty? # 检测非法的数字键
          int_keys.flatten.each do |key|
            json.gsub!("#{key}:", "\"#{key}\":")
          end
        end
        return ActiveSupport::JSON.decode(json)
      end
    else
      puts html
      puts "模板变更需要调整：#{request.url}"
    end
    nil
  end

  def get_favs_count(num_iid)
    keys = "ICCP_1_#{num_iid}"

    self.url    = item_favs_url
    self.params = { keys: keys, callback:'favs_count'}

    html = get_json
    if html
      json = html.match(/favs_count\((.*)\);/)[1]
      return ActiveSupport::JSON.decode(json)[keys].to_i if json
    else
      puts "模板变更需要调整：#{request.url}"
    end
    nil
  end

  def item_search_url
    request.url = @url + '/search.htm'
  end

  private

  def fixed_path
    request.query_path.gsub('%25','%')
  end

  def item_url(num_iid)
    'http://item.taobao.com/item.htm?id=' + num_iid.to_s
  end

  def item_taobao_url
    'http://ajax.tbcdn.cn/json/ifq.htm'
  end

  def item_tmall_url
    'http://mdskip.taobao.com/core/initItemDetail.htm'
  end

  def item_favs_url
    'http://count.tbcdn.cn/counter3'
  end

  def switcher
    user_agents = [
      'Mozilla/5.0 (compatible; MSIE 6.0; Windows NT 5.1; 360se)',
      'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
      'Mozilla/5.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; TencentTraveler 4.0; .NET CLR 2.0.50727)',
      'Mozilla/5.0 (compatible; EtaoSpider/1.0; +http://open.etao.com/dev/EtaoSpider)',
      'Mozilla/5.0 (compatible; MSIE 6.0; Windows NT 5.1; 360se)',
      'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Maxthon 2.0)',
      'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C)',
      'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C)',
      'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; SE 2.X MetaSr 1.0)',
      'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/14.0.802.30 Safari/535.1 SE 2.X MetaSr 1.0',
      'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.3 (KHTML, like Gecko) Maxthon/3.3.2.1000 Chrome/16.0.883.0 Safari/535.3',
    ]
    user_agents.sample
  end
end
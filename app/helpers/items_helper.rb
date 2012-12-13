# -*- encoding: utf-8 -*-
require 'csv'

Meta.helpers do
  def export_items(seller_nick, items)
    file_tag = "/tmp/#{seller_nick}-#{Date.today.to_s}-items.csv"
    file_csv = File.join(file_tag)
    return file_csv if File.exist?(file_csv)
    unless items.empty?
      header_row = ['淘宝ID', '商家编码', '促销活动', '促销价格', '价格', '月销量', '总销量', '库存', '收藏数', 'SKU数', '销售状态', '标题', '图片地址']
      CSV.open(file_tag, "wb:GB18030", col_sep: ',') do |csv|
      csv << header_row
        items.each do |item|
          row = [ 
          item.num_iid,     
          item.outer_id,
          item.prom_type,      
          item.prom_price,   
          item.price, 
          item.month_num, 
          item.total_num,  
          item.quantity,    
          item.favs_count, 
          item.skus_count, 
          item.show_status,
          item.title,      
          item.pic_url, 
          ]
          csv << row
        end
      end
    end
    return file_csv
  end

  def status_tag(content, status, label='label')
    css = case status
    when 'onsale'
      'label-success'
    when 'soldout'
      'label-inverse'
    when 'inventory'
      'label-warning'
    end
    content_tag(:span, content, class: "#{label} #{css}")
  end
end
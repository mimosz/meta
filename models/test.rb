# -*- encoding: utf-8 -*-
require 'csv'

def sales_import
  Dir.glob('*.csv').each do |csv_file|
    sales = CSV.read(csv_file, 'rb:GB18030:UTF-8', headers: true, col_sep: ',')
  end
end

def method_name
  seller = Seller.find('newbalance旗舰店')
  seller_sales = { total_num: 0, month_num: 0, total_price: 0, month_price: 0, total_prom_price: 0, month_prom_price: 0, quantity: 0, favs_count: 0,  skus_count: 0}
  item_paids = seller.items.paids
  item_paids.each do |item|

    sale = item.sales.last
    seller_sales[:total_num]   += sale.total_num
    seller_sales[:month_num]   += sale.month_num

    seller_sales[:total_price] += item.price * sale.total_num
    seller_sales[:month_price] += item.price * sale.month_num

    seller_sales[:total_prom_price] += item.prom_price * sale.total_num
    seller_sales[:month_prom_price] += item.prom_price * sale.month_num

    seller_sales[:quantity]   += item.quantity

    seller_sales[:favs_count] += item.favs_count
    seller_sales[:skus_count] += item.skus_count
  end
  pp seller_sales
end

def sales_export
 header_row = ['淘宝ID', '卖家昵称', '商家编码', '标题', '图片地址', '促销活动', '价格', '促销价格', '总销量', '月销量', '库存', '收藏数', 'SKU数', '抓取日期']
 Seller.all.each do |seller|
  CSV.open("#{seller._id}-sales.csv", "wb:GB18030", col_sep: ',') do |csv|
    csv << header_row
    seller.items.includes(:sales).each do |item|
      item.sales.each do |sale|
        csv << [ 
          sale.num_iid,     
          sale.seller_nick, 
          sale.outer_id,   
          sale.title,      
          sale.pic_url,     

          sale.prom_type,  

          sale.price,       
          sale.prom_price, 

          sale.total_num,  
          sale.month_num,  
          sale.quantity,    

          sale.favs_count, 
          sale.skus_count, 

          sale.date
        ]
      end
    end
  end
 end
end
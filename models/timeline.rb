
# -*- encoding: utf-8 -*-

class Timeline
  include Mongoid::Document
  embedded_in :item
  embeds_one  :increment # 增量
  

  # Fields
  field :outer_id,      type: String
  field :title,         type: String
  field :pic_url,       type: String

  field :prom_type,     type: String

  field :price,         type: Float
  field :prom_price,    type: Float,   default: -> { price }
  field :prom_discount, type: Integer, default: 100

  field :total_num,     type: Integer, default: 0
  field :month_num,     type: Integer, default: 0
  field :quantity,      type: Integer, default: 0

  field :favs_count,    type: Integer, default: 0
  field :skus_count,    type: Integer, default: 0
  field :post_fee,      type: Boolean, default: false

  field :date,          type: Date
  field :_id,           type: Date, default: -> { date }

  after_create do |document| # 创建增量
    increment = {
            date: document.date,
      # 价格
           price: ( document.price    - document.item.price ).round(2),
      # 销售
       total_num: document.total_num  - document.item.total_num,
       month_num: document.month_num  - document.item.month_num,
      # 库存
        quantity: document.quantity   - document.item.quantity,
      skus_count: document.skus_count - document.item.skus_count,
      # 收藏
      favs_count: document.favs_count - document.item.favs_count
    }
    # 优惠活动
    if document.prom_type
      prom = { 
           prom_price: (document.prom_price - document.item.prom_price).round(2), 
        prom_discount: document.prom_discount - document.item.prom_discount
      }
      increment.merge!(prom) 
    end
    document.increment = Increment.new(increment)
    document.save
  end

end
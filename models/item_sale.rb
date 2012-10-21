# -*- encoding: utf-8 -*-

class ItemSale
  include Mongoid::Document
  embedded_in :item

  # Fields
  field :num_iid,     type: Integer
  field :seller_nick, type: String

  field :outer_id,    type: String
  field :title,       type: String
  field :pic_url,     type: String 

  field :price,       type: Float,   default: 0
  
  field :prom_type,   type: String
  field :prom_price,  type: Float

  field :total_num,   type: Integer, default: 0
  field :month_num,   type: Integer, default: 0
  field :quantity,    type: Integer, default: 0

  field :favs_count,  type: Integer, default: 0
  field :skus_count,  type: Integer, default: 0

  field :date,        type: Date
  field :_id,         type: Date, default: -> { date }

  # default_scope desc(:date)
end
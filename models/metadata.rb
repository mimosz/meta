# -*- encoding: utf-8 -*-

class Metadata # 元数据
  include Mongoid::Document

  # Fields
  field :price,      type: Float,   default: 0
  field :prom_price, type: Float,   default: -> { price }

  field :prom_discount, type: Integer

  field :total_num,  type: Integer, default: 0
  field :month_num,  type: Integer, default: 0
  field :quantity,   type: Integer, default: 0

  field :favs_count, type: Integer, default: 0
  field :skus_count, type: Integer, default: 0

  field :timestamp,  type: Integer, default: -> { Time.now.to_i }
  field :_id,        type: Integer, default: -> { timestamp }

  default_scope desc(:timestamp)
end
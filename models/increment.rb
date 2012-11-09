# -*- encoding: utf-8 -*-

class Increment
  include Mongoid::Document
  embedded_in :timeline

  # Fields
  field :price,         type: Float
  field :prom_price,    type: Float
  field :prom_discount, type: Integer

  field :total_num,     type: Integer
  field :month_num,     type: Integer
  field :quantity,      type: Integer

  field :favs_count,    type: Integer
  field :skus_count,    type: Integer

  field :date,          type: Date
  field :_id,           type: Date, default: -> { date }
end
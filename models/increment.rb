# -*- encoding: utf-8 -*-

class ItemIncrement < Metadata
  embedded_in :timeline, class_name: 'ItemTimeline' # 增量

  # Fields
  field :total_sales, type: Float, default: 0
  field :month_sales, type: Float, default: 0
  field :qty_sales,   type: Float, default: 0
  field :duration,    type: Float, default: 0 # 数据间隔，小时数
  
end

class Increment < Metadata
  embedded_in :timeline

  # Fields
  field :total_sales, type: Float, default: 0
  field :month_sales, type: Float, default: 0
  field :qty_sales,   type: Float, default: 0
  field :items_count, type: Integer, default: 0
  field :duration,    type: Float, default: 0 # 数据间隔，小时数
  
end
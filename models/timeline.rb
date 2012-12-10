# -*- encoding: utf-8 -*-

class Timeline < Metadata # 店铺、分类、促销，历史数据
  embedded_in :timeable, polymorphic: true
  embeds_one  :increment, class_name: 'Increment' # 增量

  # Fields
  field :onsales,     type: Array,   default: [] # 在售
  field :soldouts ,   type: Array,   default: [] # 售罄
  field :inventories, type: Array,   default: [] # 下架
  field :proms,       type: Array,   default: [] # 活动

  field :items_count, type: Integer, default: 0 # 宝贝数
  
end

class ItemTimeline < Metadata # 宝贝，历史数据
  embedded_in :item
  embeds_one  :increment, class_name: 'ItemIncrement' # 增量

  # Fields
  field :outer_id,      type: String
  field :title,         type: String
  field :pic_url,       type: String

  field :prom_type,     type: String

  field :post_fee,      type: Boolean, default: false
  field :status,        type: String

  def show_status
    case status
    when 'onsale'
      '在售'
    when 'soldout'
      '售罄'
    when 'inventory'
      '下架'
    else
      '未知'
    end
  end

end
# -*- encoding: utf-8 -*-

class Sale
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  has_and_belongs_to_many :props
  belongs_to :item,   foreign_key: 'num_iid'


  # Fields
  field :num_iid,     type: Integer
  field :seller_nick, type: String

  field :outer_id,    type: String
  field :title,       type: String
  field :pic_url,     type: String

  field :prom_type,   type: String

  field :price,       type: Float,   default: 0
  field :prom_price,  type: Float

  field :total_num,   type: Integer, default: 0
  field :month_num,   type: Integer, default: 0
  field :quantity,    type: Integer, default: 0

  field :favs_count,  type: Integer, default: 0
  field :skus_count,  type: Integer, default: 0

  field :date,      type: Date

  class << self
    def sync(item)
      last_sale = where(num_iid: item[:num_iid].to_i, date: item[:date]).last
      if last_sale
        return false
      else
        create(item)
        return true
      end
    end
  end
end

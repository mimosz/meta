# -*- encoding: utf-8 -*-

class Prop
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  # Referenced
  has_and_belongs_to_many :sales do
    def find_by_item(num_iid, date)
      where(num_iid: num_iid, date: date)
    end
    def find_by_seller(seller_nick, date)
      where(seller_nick: seller_nick, date: date)
    end
  end

  field :label, type: String
  field :value, type: String

  field :_id,   type: String, default: -> { "#{label}:#{value};" }
end

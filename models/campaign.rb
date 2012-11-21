# -*- encoding: utf-8 -*-

class Campaign
  include Mongoid::Document
  embeds_many :sales,     as: :saleable, class_name: 'Sale'
  embeds_one  :last_sale, as: :saleable, class_name: 'Sale'
  
  has_and_belongs_to_many :items, index: true
  belongs_to :seller,   foreign_key: 'seller_nick', index: true

  # Fields
  field :seller_nick, type: String
  field :name,        type: String

  field :discount, type: Integer, default: 100
  field :start_at, type: DateTime
  field :end_at,   type: DateTime
  field :plan,     type: Array

  field :_id,      type: String, default: -> { "#{seller_nick}-#{start_at.to_i}-#{end_at.to_i}" }

  scope :pre, ->(time = Time.now){ where(:end_at.gte => time) }
  scope :ing, ->(time = Time.now){ where(:start_at.lte => time, :end_at.gte => time) }

end
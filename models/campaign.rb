# -*- encoding: utf-8 -*-

class Campaign
  include Mongoid::Document
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
end
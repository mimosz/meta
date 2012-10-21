# -*- encoding: utf-8 -*-

class Prop
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  # Referenced

  field :label, type: String
  field :value, type: String

  field :_id,   type: String, default: -> { "#{label}:#{value};" }
end

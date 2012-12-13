# -*- encoding: utf-8 -*-

class Campaign
  include Mongoid::Document
  embeds_one  :timeline,  as: :timeable
  embeds_many :timelines, as: :timeable
  # Referenced
  belongs_to :seller,   foreign_key: 'seller_nick', index: true

  # Fields
  field :seller_nick, type: String
  field :name,        type: String

  field :discount, type: Integer, default: 100
  field :start_at, type: DateTime
  field :end_at,   type: DateTime
  field :timestamp,type: Integer # 同步时间
  field :plan,     type: Array
  field :item_ids, type: Array,  default: []

  field :_id,      type: String, default: -> { "#{seller_nick}-#{start_at.to_i}-#{end_at.to_i}" }

  scope :pre, ->(time = Time.now){ where(:end_at.gte => time) }
  scope :ing, ->(time = Time.now){ where(:start_at.lte => time, :end_at.gte => time, :item_ids.ne => []) }

  def to_s
    name
  end

  def items
    Item.where(seller_nick: seller_nick).in(_id: item_ids)
  end

  def items_count
    item_ids.count
  end

  class << self
    def each_campaigns(campaigns, items)
      logger.info "批量处理，促销信息。"
      campaigns.each do |id, campaign|
        campaign[:item_ids] = campaign[:item_ids].uniq.compact # 去重、去空
        timeline = Timeline.new(each_timelines(items, campaign[:item_ids]))
        current_campaign = Campaign.where(seller_nick: campaign[:seller_nick], _id: id).first
        if current_campaign
          if current_campaign.item_ids == campaign[:item_ids]
            campaign.delete(:item_ids)
          else
            campaign[:item_ids] = (current_campaign.item_ids << campaign[:item_ids]).uniq
          end
          campaign[:timelines] = (current_campaign.timelines << timeline).uniq
          current_campaign.update_attributes(campaign)
        else
          create(campaign.merge!(timelines: [timeline]))
        end
      end
    end
    include TimelineParse
  end

end
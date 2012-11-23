# -*- encoding: utf-8 -*-

class Sale
  include Mongoid::Document
  belongs_to :saleable, polymorphic: true


  # Fields
  field :seller_nick, type: String

  field :onsales,     type: Array,   default: [] # 在售
  field :soldouts ,   type: Array,   default: [] # 售罄
  field :inventories, type: Array,   default: [] # 下架
  field :proms,       type: Array,   default: [] # 活动

  field :sales,       type: Float,   default: 0
  field :volume,      type: Integer, default: 0

  field :quantity,    type: Integer, default: 0
  field :favs_count,  type: Integer, default: 0
  field :skus_count,  type: Integer, default: 0

  field :duration,    type: Integer, default: 0
  field :synced_at,   type: DateTime

  field :_id,         type: Integer, default: -> { synced_at.to_i }

  default_scope desc(:synced_at)

  class << self

    def sync(seller, timestamp)
      synced_at   = Time.at(timestamp)
      seller_nick = seller._id
      # 默认值
      default     = nil
      # 销售
      seller_sales   = nil
      campaign_sales = {}
      category_sales = {}

      items     = seller.items.where('timelines._id' => timestamp)
      unless items.empty?
        # 宝贝
        items.each do |item|
          timeline = item.timelines.where(_id: timestamp).first
          if timeline
            # 
            if default.nil?
              #
              default      = { seller_nick: seller_nick, synced_at: synced_at, duration: timeline.duration }
              #
              seller_sales = seller.sales.new(default)
              #
              sales_new(campaign_sales, seller.campaigns.ing(synced_at), default)
              sales_new(category_sales, seller.categories, default)
            end
            # 累加，店铺销售
            sales_sum(seller_sales, timeline)
            # 累加，店内类目销售
            sales_set(category_sales, item.category_ids, timeline) 
            # 累加，促销活动销售
            sales_set(campaign_sales, item.campaign_ids, timeline) 
          end
        end
        # 
        unless default.nil?
          seller_sales.save
          # 
          sales_save(category_sales)
          # 
          sales_save(campaign_sales)
        end
      end
    end

    private

    def sales_sum(sales, sale)
      # 
      case sale.status
      when 'onsale'
        sales.onsales     << sale._id
      when 'soldout'
        sales.soldouts    << sale._id
      when 'inventory'
        sales.inventories << sale._id
      end
      # 
      unless sale.prom_type.nil?
        sales.proms << sale.prom_type unless sales.proms.include?(sale.prom_type)
      end
      # 
      sales.sales  += sale.sales
      sales.volume += sale.increment.total_num
      # 
      sales.quantity   += sale.quantity
      sales.favs_count += sale.favs_count
      sales.skus_count += sale.skus_count
      # return sales
    end

    def sales_new(node, objs, vals)
      unless objs.empty?
        objs.each do |obj|
          node[obj._id] = obj.sales.new(vals)
        end
      end
    end

    def sales_set(node, objs, vals)
      unless objs.empty?
        objs.each do |obj|
          sales_sum(node[obj], vals) if node.has_key?(obj)
        end
      end
    end

    def sales_save(node)
      unless node.empty?
        node.each do |id, sale|
          sale.save
        end
      end
    end
  end
end
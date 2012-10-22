# -*- encoding: utf-8 -*-
require 'digest/md5'

class Category
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  # Referenced
  has_and_belongs_to_many :items
  has_many   :children, foreign_key: 'parent_id', class_name: 'Category'
  belongs_to :seller,   foreign_key: 'seller_nick'

  # Fields
  field :cat_id,      type: Integer
  field :parent_id,   type: Integer
  field :priority,    type: Integer
  field :cat_name,    type: String
  field :seller_nick, type: String

  field :synced_at,   type: Date # 类目下，商品同步时间

  field :_id,         type: Integer, default: -> { cat_id }

  default_scope asc(:priority)

  def check?(cat)
    new_str = cat.values.join('')
    token = Digest::MD5.hexdigest("#{cat_id}#{priority}#{cat_name}#{parent_id}")
    return token == Digest::MD5.hexdigest(new_str)
  end

  class << self
    
    def sync(seller, page_dom)
      cats_dom = get_cats_dom(page_dom)
      if cats_dom
        cats = each_cats(cats_dom)
        unless cats.empty?
          cat_ids = []
          cats.each do |cat|
            current_cat = where(_id: cat[:cat_id].to_i).last
            if current_cat
              current_cat.update_attributes(cat) if current_cat.check?(cat)
            else
              current_cat = seller.categories.create(cat)
            end
          end
          return true
        end
      end
      false
    end

    private

    def get_cats_dom(page_dom)
      page_dom.at('ul#J_Cats').css('li.cat') if page_dom.at('ul#J_Cats')
    end

    def parse_cat(cat_dom, priority, parent_id)
      { cat_id: parse_id(cat_dom[:id]), priority: priority, cat_name: parse_name(cat_dom.at('a')), parent_id: parent_id }
    end

    def parse_name(link_dom)
      name = link_dom.text
      name = link_dom.at('img')[:alt] if name.blank?
      name.strip
    end

    def parse_id(html)
      html.gsub('J_Cat','')
    end

    def each_cats(cats_dom, priority=0, parent_id=nil)
      cats = []
      cats_dom.each do |cat_dom|
        case cat_dom[:class]
        when 'cat J_CatHeader' # 淘宝系统分类
          next # 跳过
        end

        cat = parse_cat(cat_dom, priority, parent_id)
        cats << cat
        priority += 1
        children_dom = cat_dom.css('li')
        if children_dom # 是否含子类
          children  = each_cats(children_dom, priority, cat[:cat_id])
              cats += children
          priority += children.count
        end
      end
      return cats
    end 
  end
end
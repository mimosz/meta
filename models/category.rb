# -*- encoding: utf-8 -*-
require 'digest/md5'

class Category
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  embeds_many :sales, as: :saleable
  # Referenced
  has_and_belongs_to_many :items, index: true
  has_many   :children, foreign_key: 'parent_id', class_name: 'Category'
  belongs_to :seller,   foreign_key: 'seller_nick', index: true
  belongs_to :parent,   foreign_key: 'parent_id', class_name: 'Category', index: true

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
    def each_create(seller, cats)
      cats.each do |cat|
        current_cat = where(_id: cat[:cat_id].to_i).last
        if current_cat
          current_cat.update_attributes(cat) if current_cat.check?(cat)
        else
          current_cat = seller.categories.create(cat)
        end
      end
    end
    
    def sync(seller, page_dom)
      cats_dom = get_cats_dom(page_dom)

      cats = if cats_dom # 淘宝系统，树形分类
        each_cats(cats_dom)              
      else # 自定义分类
        logger.warn "店铺，自定义分类"
        get_cats(page_dom)
      end

      if cats.nil? || cats.empty?
        logger.error "什么店铺呀？！居然不错店内分类。"
        return false
      else
        each_create(seller, cats)
        return true
      end
    end

    private

    def find_cat(link)
      href = link[:href]
      if href.nil?
        logger.info 'HTML解析，跳过，锚'
      else
        params = URI.parse(href.strip).query || nil
        if params.nil?
          logger.info 'HTML解析，跳过，无参数链接'
        else
          params = CGI.parse(params)
          if params.has_key?('scid') # 分类链接
            cat_id = params['scid'].first
            if params.has_key?('scname')
              cat_name = Base64.decode64(URI.unescape(params['scname'].first )).force_encoding("GB18030").encode("UTF-8") # 淘宝分类链接，名称编码解析
            else # 链接参数中，不带名称
              cat_name = link.text
              if cat_name.blank? # 无文字，找图片文字
                img = link.at('img')
                if img
                  cat_name = img['alt']
                  cat_name = img['data-ks-lazyload'] || img['src'] if cat_name.blank?
                else
                  cat_name = '未知分类'  
                end
              end
            end
            return { cat_id: cat_id, cat_name: cat_name,  }
          else
            logger.info 'HTML解析，跳过，非分类链接'
          end
        end
      end
      nil
    rescue URI::InvalidURIError
      nil
    end

    def get_cats(page_dom) # 自定义分类
      links = page_dom.css('a')
      cats = []
      links.each do |link|
        cat = find_cat(link)
        cats << cat if cat
      end
      return cats
    end

    def get_cats_dom(page_dom) # 淘宝系统，树形分类
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
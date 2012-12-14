# -*- encoding: utf-8 -*-
require 'digest/md5'

class Category
  include Mongoid::Document
  include Mongoid::Timestamps # adds created_at and updated_at fields
  embeds_one  :timeline,  as: :timeable
  embeds_many :timelines, as: :timeable
  # Referenced
  has_many   :children, foreign_key: 'parent_id', class_name: 'Category'
  belongs_to :seller,   foreign_key: 'seller_nick', index: true
  belongs_to :parent,   foreign_key: 'parent_id', class_name: 'Category', index: true

  # Fields
  field :cat_id,      type: Integer
  field :parent_id,   type: Integer
  field :priority,    type: Integer
  field :timestamp,   type: Integer # 同步时间

  field :cat_name,    type: String
  field :seller_nick, type: String

  field :item_ids,    type: Array,  default: []

  field :_id,         type: Integer, default: -> { cat_id }

  default_scope asc(:priority)

  def to_s
    cat_name
  end

  def check?(cat)
    new_str = cat.values.join('')
    token = Digest::MD5.hexdigest("#{cat_id}#{priority}#{cat_name}#{parent_id}")
    return token == Digest::MD5.hexdigest(new_str)
  end

  def items
    Item.where(seller_nick: seller_nick).in(_id: item_ids)
  end

  def items_count
    item_ids.count
  end

  class << self
    def sync(threading, page_dom)
      # 起始化
      nick = threading[:seller_nick]
      init_category(nick, threading)
      # 解析分类
      cats_dom = get_cats_dom(page_dom)

      cats     = if cats_dom # 淘宝系统，树形分类
        each_cats(nick, cats_dom)              
      else # 自定义分类
        logger.warn "店铺，自定义分类"
        get_cats(nick, page_dom)
      end
      # 收集宝贝
      if cats.empty?
        logger.warn "店铺，没有分类。"
        return threading
      else
        @threading[nick][:categories] = cats
        category_ids = @threading[nick][:categories].keys
        category_ids.each do |category_id|
          each_pages(nick, category_id)
        end
        return @threading[nick]
      end
    end

    def each_categories(categories, items)
      logger.info "批量处理，店内分类。"
      categories.each do |id, category|
        if category[:item_ids].empty?
          logger.warn "#{category[:cat_id]} #{category[:cat_name]}，分类中没有宝贝。"
        else
          category[:item_ids] = category[:item_ids].uniq.compact # 去重、去空
          timeline = Timeline.new(each_timelines(items, category[:item_ids]))
          current_category = Category.where(seller_nick: category[:seller_nick], _id: category[:cat_id]).first
          if current_category
            if current_category.item_ids == category[:item_ids]
              category.delete(:item_ids)
            else
              category[:item_ids] = (current_category.item_ids << category[:item_ids]).uniq
            end
            category[:timelines] = (current_category.timelines << timeline).uniq
            current_category.update_attributes( category )
          else
            category[:timelines] = [timeline]
            create( category )
          end
        end
      end
    end

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

    private

    def get_page_dom(seller_id, category_id, page=1)
      crawler = @threading[seller_id][:crawler]
      crawler.item_search_url
      crawler.params = { 'scid' => category_id, 'pageNum' => page }
      logger.info "店铺分类：#{@threading[seller_id][:categories][category_id][:cat_name]}。"
      return crawler.get_dom
    end

    def each_pages(seller_id, category_id)
      # 分页执行
      if @threading[seller_id][:pages] > 1
        pages = @threading[seller_id][:pages]
        2.upto(pages).each do |page|
          page_dom  = get_page_dom(seller_id, category_id, page)
          items_dom = get_items_dom(page_dom) if page_dom
          each_items(seller_id, items_dom, category_id) if items_dom
          logger.warn "第 #{page}/#{pages} 页。"
        end
        @threading[seller_id][:pages] = 1 # 用后清零
      else
        page_dom = get_page_dom(seller_id, category_id)
        if page_dom
          total    = get_total(page_dom)
          if total < 1
            logger.error "本页没有货品。"
          else
            items_dom = get_items_dom(page_dom)
            if items_dom
              each_items(seller_id, items_dom, category_id)
              items_count = items_dom.count
              if total > items_count
                @threading[seller_id][:pages] = @threading[seller_id][:crawler].pages_count(total, items_count)
                pages = @threading[seller_id][:pages]
                logger.warn "货品共有 #{total}件，每页 #{items_count}件，分为 #{pages}页。"
                each_pages(seller_id, category_id) if pages > 1 # 内循环，执行分页
              end
            else
              logger.error "咦~，共有#{total}件货品呀？"
            end
          end
        end
      end
    end

    def each_items(seller_id, items_dom, category_id)
      items_dom.each do |item_dom|
        item_link = item_dom.at('div.pic').at('a')
        num_iid   = parse_num_iid(item_link) if item_link
        if num_iid 
          if @threading[seller_id][:items].has_key?(num_iid)
            set_threading(seller_id, num_iid, category_id)
          else
            item_id = set_item(seller_id, item_dom)
            if item_id
              set_threading(seller_id, item_id, category_id)
            else
              logger.error "出现错误，宝贝ID：#{num_iid}，分类ID：#{category_id}"
            end
          end
        end
      end
    end
    # 收集，分类中的宝贝
    def set_threading(seller_id, item_id, category_id)
      @threading[seller_id][:categories][category_id][:item_ids] << item_id
      @threading[seller_id][:items][item_id][:category_ids] << category_id
    end

    def get_cats(seller_id, page_dom) # 自定义分类
      links = page_dom.css('a')
      cats  = {}
      links.each do |link|
        cat = find_cat(link)
        if cat && !cats.has_key?(cat[:cat_id])
          cat[:seller_nick]  = seller_id
          cat[:timestamp]    = @threading[seller_id][:timestamp]
          cats[cat[:cat_id]] = cat 
        end
      end
      return cats
    end

    def each_cats(seller_id, cats_dom, priority=0, parent_id=nil)
      cats = {}
      cats_dom.each do |cat_dom|
        case cat_dom[:class]
        when 'cat J_CatHeader' # 淘宝系统分类
          next # 跳过
        end
        cat = parse_cat(cat_dom, priority, parent_id)
        if cat && !cats.has_key?(cat[:cat_id])
          cat[:seller_nick]  = seller_id
          cat[:timestamp]    = @threading[seller_id][:timestamp]
          cats[cat[:cat_id]] = cat     
        end
        children_dom = cat_dom.css('li')
        if children_dom # 是否含子类
          children = each_cats(seller_id, children_dom, priority, cat[:cat_id])
          cats.merge!(children)
        end
        priority += 1
      end
      return cats
    end

    include InitSync
    include BaseParse
    include CategoryParse 
    include TimelineParse
  end
end
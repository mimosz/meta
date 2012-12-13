# -*- encoding: utf-8 -*-

Meta.controllers :items, parent: :sellers do
  before do
    if current_seller
      @page      = params[:page].blank? ? 1 : params[:page].to_i
      @page_size = params[:page_size].blank? ? 20 : params[:page_size].to_i
    end
  end

  get :index do
    if params[:category_id].blank?
      @items = @seller.items.page(@page).per(@page_size)
    else
      @category = Category.where(_id: params[:category_id]).only(:cat_name, :item_ids).first
      if @category
        @items = Item.in(_id: @category.item_ids).page(@page).per(@page_size)
      else
        flash[:error] = "#{@seller._id} 里，没有这个分类，不要乱来哦~"
        redirect url(:categories, :index, seller_id: @seller._id)
      end
    end
    render 'items/index'
  end
end
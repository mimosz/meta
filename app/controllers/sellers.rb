# -*- encoding: utf-8 -*-

Meta.controllers :sellers do

  get :index do
    @sellers = Seller.all
    render 'sellers/index'
  end
  
  get :show, :with => :seller_id do
    @seller = Seller.where(_id: params[:seller_id].force_encoding('utf-8')).last
    if params[:category_id].blank?
      @items    = @seller.items
    else
      @category = @seller.categories.where(_id: params[:category_id].force_encoding('utf-8')).last
      @items    = @category.items
    end
    render 'sellers/show'
  end

  get :new do
    
  end

  get :create do

  end
end
# -*- encoding: utf-8 -*-

Meta.controllers :sellers do

  get :index do
    @sellers = Seller.all
    render 'sellers/index'
  end
  
  get :show, :with => :seller_id do
    @seller = Seller.where(_id: params[:seller_id].force_encoding('utf-8')).last
    case
    when !params[:category_id].blank?
      @category = @seller.categories.where(_id: params[:category_id]).last
      @items    = @category.items.includes(:campaigns, :categories)
    when !params[:campaign_id].blank?
      @campaign = @seller.campaigns.where(_id: params[:campaign_id].force_encoding('utf-8')).last
      @items    = @campaign.items.includes(:campaigns, :categories)
    else
      @items    = @seller.items.includes(:campaigns, :categories)
    end
    render 'sellers/show'
  end

  get :new do
    
  end

  get :create do

  end
end
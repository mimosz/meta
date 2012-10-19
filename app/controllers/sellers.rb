# -*- encoding: utf-8 -*-

Meta.controllers :sellers do

  get :index do
    @sellers = Seller.all
    render 'sellers/index'
  end
  
  get :show, :with => :seller_id do
    @seller = Seller.where(_id: params[:seller_id].force_encoding('utf-8')).last
    render 'sellers/show'
  end

  get :new do
    
  end

  get :create do

  end
end
# -*- encoding: utf-8 -*-

Meta.controllers :categories, parent: :sellers do
  before do
    current_seller
  end

  get :index do
    @categories = @seller.categories.where(parent_id: nil).includes(:children)
    render 'categories/index'
  end
end
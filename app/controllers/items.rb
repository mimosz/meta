# -*- encoding: utf-8 -*-

Meta.controllers :items, parent: :sellers do
  before do
    current_seller
  end

  get :index do
    render 'items/index'
  end
end
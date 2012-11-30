# -*- encoding: utf-8 -*-

class SyncWorker
  
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(seller_nick)
    seller  = find_by_nick(seller_nick)
    seller.sync if seller # 店铺
  end

  # 卖家
  def find_by_nick(seller_nick)
    Seller.where(_id: seller_nick).first
  end
end
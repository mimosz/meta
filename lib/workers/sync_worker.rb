# -*- encoding: utf-8 -*-

class SyncWorker
  
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(seller_nick)
    seller = Seller.find(seller_nick) rescue nil
    seller.sync if seller # 店铺
  end
end
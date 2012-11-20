# -*- encoding: utf-8 -*-
require 'resque/errors'

module ResqueJobs
  
  class ResqueJob
    # 卖家
    def self.find_by_nick(seller_nick)
      Seller.where(_id: seller_nick).first
    end
  end
  
  class SyncStore < ResqueJob
    @queue = :crawler

    def self.perform(seller_nick)
      seller  = find_by_nick(seller_nick)
      if seller
        seller.sync  # 店铺
      end
    rescue Resque::TermException
      puts "=================同步错误：店铺 #{seller_nick}=================="
    end
  end
end
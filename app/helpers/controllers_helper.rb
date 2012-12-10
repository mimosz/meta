# -*- encoding: utf-8 -*-

Meta.helpers do
  
  def current_seller
    back_to('您要看那家店铺？') if params[:seller_id].blank?
    return @seller if defined?(@seller)
    seller_id = params[:seller_id].force_encoding('utf-8')
    seller    = Seller.where(_id: seller_id).first
    back_to('没有您要找的店铺。') if seller.nil?
    @seller = seller 
  end

  def back_to(msg = nil)
    flash[:warning] = msg unless msg.nil?
    redirect url(:sellers, :index)
  end

end
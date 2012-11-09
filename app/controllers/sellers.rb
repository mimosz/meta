# -*- encoding: utf-8 -*-

Meta.controllers :sellers do
  before do
    @page      = 1 
    @page_size = 20
    @page      = params[:page].to_i unless params[:page].blank?
    @page_size = params[:page_size].to_i unless params[:page_size].blank?
  end

  get :index do
    @sellers = Seller.all.includes(:campaigns).page(@page).per(@page_size)
    render 'sellers/index'
  end
  
  get :show, with: :seller_id, provides: [:html, :csv] do
    @seller = Seller.where(_id: params[:seller_id].force_encoding('utf-8')).last
    
    case content_type
    when :html
      case
      when !params[:category_id].blank?
        @category = @seller.categories.where(_id: params[:category_id]).last
        @items    = @category.items.includes(:categories).page(@page).per(@page_size)
      when !params[:campaign_id].blank?
        @campaign = @seller.campaigns.where(_id: params[:campaign_id].force_encoding('utf-8')).last
        @items    = @campaign.items.includes(:categories).page(@page).per(@page_size)
      else
        @items    = @seller.items.includes(:categories).page(@page).per(@page_size)
      end
      render 'sellers/show'
    when :csv
      @items    = @seller.items.includes(:categories)
      if @items.empty?
          flash[:error] = '哦，人品大爆发，没宝贝~'
          redirect url(:sellers, :index)
      else
        file_csv = export_items(@seller._id, @items)
        send_file file_csv, type: 'text/csv', filename: File.basename(file_csv)
      end
    end
  end
end
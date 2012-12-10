# -*- encoding: utf-8 -*-

Meta.controllers :sellers do
  before do
    @page      = params[:page].blank? ? 1 : params[:page].to_i
    @page_size = params[:page_size].blank? ? 20 : params[:page_size].to_i
  end

  get :index do
    @sellers = Seller.all.includes(:campaigns).page(@page).per(@page_size)
    render 'sellers/index'
  end

  post :create do
    result = Seller.sync(params[:seller][:store_url])
    if result.nil?
      flash[:error] = '非常抱歉，您提供的店铺地址，系统未能识别~'
      redirect url(:sellers, :index)
    else
      case result[:status].to_sym
      when :created
        flash[:notice] = "欢迎光临，#{result[:seller]._id}，请开启数据抓取任务。"
        redirect url(:resque, :index, seller_id: result[:seller]._id)
      when :already
        flash[:notice] = "欢迎光临，#{result[:seller]._id}。"
        redirect url(:sellers, :show, seller_id: result[:seller]._id)  
      end
    end
  end
  
  get :show, with: :seller_id, provides: [:html, :csv] do
    if current_seller
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
end
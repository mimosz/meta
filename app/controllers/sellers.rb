# -*- encoding: utf-8 -*-

Meta.controllers :sellers do

  before do
    @page      = params[:page].blank? ? 1 : params[:page].to_i
    @page_size = params[:page_size].blank? ? 20 : params[:page_size].to_i
  end

  get :index do
    @conditions = {}
    unless params[:label].blank?
      @conditions[:label] = params[:label].force_encoding('utf-8')
    end
    @sellers = Seller.where(@conditions).page(@page).per(@page_size)
    render 'sellers/index'
  end

  post :create do
    if params[:seller][:store_url].blank? || params[:seller][:store_url].match(/http:\/\/(.*)\.tmall\.com/).nil?
      flash[:error] = "铁公鸡，你倒是给个天猫店铺网址呀？！"
      redirect url(:sellers, :index)
    end
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
  
  get :show, with: :seller_id do
    if current_seller
      render 'sellers/show'
    end
  end
end

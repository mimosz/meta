# -*- encoding: utf-8 -*-

Meta.controllers :resque, parent: :sellers do
  before do
    seller_id = params[:seller_id].force_encoding('utf-8')
    @seller = Seller.where(_id: seller_id).first
    if @seller
      resque.reload_schedule! if resque::Scheduler.dynamic
      @queues = {}
      @queues["Store-#{@seller.shop_id}"] = { cron: '0 0 * * *', class: 'SyncWorker', args: @seller._id, description: "#{@seller._id} 的数据抓取。"}
    else
      flash[:error] = '哦，人品大爆发，无此店铺~'
      redirect url(:sellers, :index)
    end
  end

  get :index do
    render 'resque/index'
  end

  get :play, with: :resque_id, provides: [:html, :js] do
    @resque_id = params[:resque_id].force_encoding('utf-8')
    @queue     = @queues[@resque_id]
    resque.set_schedule(@resque_id, @queue)
    if request.xhr?
      render 'resque/play', nil, layout: false
    else
      flash[:success] = '数据同步，已开始排期～'
      redirect url(:resque, :index, seller_id: @seller._id)
    end
  end

  get :pause, with: :resque_id, provides: [:html, :js] do
    @resque_id = params[:resque_id].force_encoding('utf-8')
    resque.remove_schedule(@resque_id)
    if request.xhr?
      @queue = @queues[@resque_id]
      render 'resque/pause', nil, layout: false
    else
      flash[:success] = '数据同步，已停止～'
      redirect url(:resque, :index, seller_id: @seller._id)
    end
  end
end

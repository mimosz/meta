# -*- encoding: utf-8 -*-

Meta.controllers :resque, parent: :sellers do
  before do
    resque.reload_schedule! if resque::Scheduler.dynamic
    @seller = Seller.where(_id: params[:seller_id].force_encoding('utf-8')).last
    @queues = {}
    @queues["Store-#{@seller.shop_id}"] = { cron: '0 0 * * *', queue: :crawler, class: 'ResqueJobs::SyncStore', args: @seller._id, description: '同步店铺' }
  end

  get :index do
    render 'resque/index'
  end

  get :play, :with => :resque_id, provides: [:html, :js] do
    @resque_id = params[:resque_id].force_encoding('utf-8')
    @queue     = @queues[@resque_id]
    resque.set_schedule(@resque_id, @queue)
    if request.xhr?
      render 'resque/play', nil, layout: false
    else
      flash[:success] = '数据同步，已开始排期～'
      redirect url(:resque, :index, user_id: user_id)
    end
  end

  get :pause, :with => :resque_id, provides: [:html, :js] do
    @resque_id = params[:resque_id].force_encoding('utf-8')
    resque.remove_schedule(@resque_id)
    if request.xhr?
      @queue = @queues[@resque_id]
      render 'resque/pause', nil, layout: false
    else
      flash[:success] = '数据同步，已停止～'
      redirect url(:resque, :index, user_id: user_id)
    end
  end
end
# -*- encoding: utf-8 -*-

Meta.controllers :codebuilder do

  get :index do
    render 'codebuilder/index'
  end
  
  post :show do
    styles = {
      fav: "text-align: left; line-height: 18px; display: block; background: url(http://img01.taobaocdn.com/tps/i1/T1RI6VXeBlXXXNDv_j-210-51.png) no-repeat; height: 68px; color: #666; overflow: hidden; text-decoration: none",
      pay: "text-align: left; line-height: 18px; display: block; background-image: url(http://img02.taobaocdn.com/tps/i2/T1P26WXjtcXXXNDv_j-210-51.png); height: 68px; color: rgb(102, 102, 102); overflow: hidden; text-decoration: none; background-position: initial initial; background-repeat: no-repeat no-repeat;"
    }
    # 导入数据
    rows = CSV.read(params[:csv_file][:tempfile], 'rb:GB18030:UTF-8', headers: true, col_sep: ',')
    if rows.headers.include?('淘宝ID')
      @items = rows
      @css = styles[params[:type].to_sym]
      render 'codebuilder/show', layout: false
    else
      flash[:error] = '模板错误，必须包含：淘宝ID、标题、图片、价格、专柜价。'
      redirect url(:codebuilder, :index)
    end
  end

end
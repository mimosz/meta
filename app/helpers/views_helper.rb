# -*- encoding: utf-8 -*-

Meta.helpers do
  
  def current_path?(uri)
    path_info = URI.parse(uri).path
    request.path_info =~ /^#{Regexp.escape(path_info)}/
  end
  
  def render_list(list=[], options={})
    if list.is_a? Hash
      options = list
      list = []
    end
    yield(list) if block_given?
    list_type ||= :ul
    if options[:type] 
      if ["ul", "dl", "ol"].include?(options[:type])
        list_type = options[:type].to_sym
      end
    end
    contents = ''
    list.each_with_index do |content, i|
      item_class = []
      item_content = content
      item_options = {}
      if content.is_a? Array
        item_content = content[0]
        item_options = content[1]
      end
      if item_options[:class]
        item_class << item_options[:class]
      end
      link = item_content.match(/href=(["'])(.*?)(\1)/)[2] rescue nil
      if link  && current_path?(link)
        item_class << "active" unless link == '#'
      end
      item_class = (item_class.empty?)? nil : item_class.join(" ")
      contents << content_tag(:li, item_content, class: item_class )
    end
    content_tag(list_type, contents, {class: options[:class], id: options[:id]})
  end

  def nest_name(name)
    if name.include?('http://' && ('.jpg'||'.png'))
      image_tag( name, class: '' )
    else
      name
    end
  end

  def local_time(time)
    if time
      time.in_time_zone.strftime("%m月%d日 %H时")
    else
      '期待数据中..'
    end
  end

  def percent(num, total, divide='%')
    pct = if total == 0
      0
    else
      (num / total.to_f * 100).round(2)
    end

    if divide.nil?
      pct
    else
      "#{pct}#{divide}" 
    end
  end
  
end
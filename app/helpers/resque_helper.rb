# -*- encoding: utf-8 -*-

Meta.helpers do

  def queue_status(queue_id)
    :success if schedule.has_key?(queue_id)
  end

  def interval(queue)
    case
    when queue.has_key?(:every)
      '每' + queue[:every].gsub('w','周').gsub('d','天').gsub('h','小时').gsub('m','分钟').gsub('s','秒')
    when queue.has_key?(:cron)
      cron_str(queue[:cron])
    end
  end

  def worker_status
    workers_count = resque.workers.size
    busy_rate = if workers_count > 0 
      (resque.working.size/workers_count.to_f*100).round
    else
      0
    end
    idle_rate = 100 - busy_rate
    busy_css = if busy_rate > 80
      'bar-danger'
    else
      'bar-warning'
    end
    busy = content_tag(:div, '', class: 'bar ' + busy_css, rel: 'tooltip', title: '已用', style: "width: #{busy_rate}%;")
    idle = content_tag(:div, '', class: 'bar bar-success', rel: 'tooltip', title: '可用', style: "width: #{idle_rate}%;")
    content_tag(:div, busy.to_s + idle.to_s, class: 'progress')
  end

  def schedule # 计划
    resque.schedule
  end

  private

  def resque
    return @resque if defined?(@resque)
    @resque = Resque
  end

  def cron_str(cron)
    cron_sections = cron.split(' ').reverse
    str = '每'
    if cron_sections.count == 5
      cron_sections.each_with_index do |section, i|
        case i
          when 0 # 星期
            str += '周' + cron_week(section) + '，' if section != '*'
          when 1 # 月份
            if section != '*'
              str += '年' if str.size == 1
              str += section + '月' 
            end
          when 2 # 日期
             if section != '*'
              str += '月' if str.size == 1
              str += section + '号'
            end
          when 3 # 小時
            if section != '*'
              str += '天' if str.size == 1 
              str += section + '点'
            end
          when 4 # 分钟
             if section != '*'
              str += '小时' if str.size == 1 
              str += section + '分'
            end
        end
      end
    end
    str
  end

  def cron_week(week)
    case week.to_i
      when 0 # 星期天
        '天'
      when 1 
        '一'
      when 2 
        '二'
      when 3 
        '三'
      when 4 
        '四'
      when 5 
        '五'
      when 6 
        '六'
    end
  end

end
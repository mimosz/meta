source :rubygems
source 'http://ruby.taobao.org/'

platforms :jruby do
  gem 'jruby-openssl'
  gem 'jruby-rack'
  gem 'json', '~> 1.7.5'
  gem 'dm-active_model'
  gem 'origin'
  gem 'warbler'
  gem 'mizuno'
end

platforms :ruby do
  # Server requirements
  gem 'thin'
  # Project requirements
  gem 'yajl-ruby', require: 'yajl'
end

# Project requirements
gem 'rake'
gem 'sinatra-flash', require: 'sinatra/flash'
gem 'nestful'
gem 'nokogiri' # 解析HTML
gem 'mini_magick'


# Component requirements
gem 'erubis',  '~> 2.7.0'
gem 'mongoid', '~> 3.0.0'
gem 'mongoid_auto_increment_id', '~> 0.5.0'
gem 'kaminari', git: 'git://github.com/mimosa/kaminari.git', require: 'kaminari/sinatra'

# Jobs requirements
gem 'slim'
gem 'sidekiq'
gem 'sidekiq-scheduler'
gem 'redis-objects', require: nil

gem 'grape' # API接口
gem 'padrino', git: 'git://github.com/padrino/padrino-framework.git'
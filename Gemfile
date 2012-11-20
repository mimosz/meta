source :rubygems
source 'http://ruby.taobao.org/'

platforms :ruby do
  # Server requirements
  gem 'thin'
  # Project requirements
  gem 'yajl-ruby', require: 'yajl'
  gem 'rtesseract'
end

platforms :jruby do
  gem 'jruby-openssl'
  gem 'jruby-rack'
  gem 'warbler'
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
gem 'resque', require: 'resque/server'
gem 'redis-namespace',  '~> 1.2.1' # Redis 命名空间
gem 'resque-scheduler', '~> 2.0.0.e', require: 'resque_scheduler'

# Padrino Stable Gem
gem 'padrino', '0.10.7'
gem 'grape' # API接口
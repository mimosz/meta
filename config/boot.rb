# -*- encoding: utf-8 -*-

# Defines our constants
PADRINO_ENV  = ENV['PADRINO_ENV'] ||= ENV['RACK_ENV'] ||= 'development'  unless defined?(PADRINO_ENV)
PADRINO_ROOT = File.expand_path('../..', __FILE__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
Bundler.require(:default, PADRINO_ENV)
# 兼容 Rails
module Rails
    def self.root
      PADRINO_ROOT
    end
    def self.logger
      Padrino.logger
    end
end
##
# ## Enable devel logging
#
Rails.logger.colorize!
# ## Configure your I18n
#
I18n.default_locale = :zh_cn
#
# ## Configure your HTML5 data helpers
#
# Padrino::Helpers::TagHelpers::DATA_ATTRIBUTES.push(:dialog)
# text_field :foo, :dialog => true
# Generates: <input type="text" data-dialog="true" name="foo" />
#
# ## Add helpers to mailer
#
# Mail::Message.class_eval do
#   include Padrino::Helpers::NumberHelpers
#   include Padrino::Helpers::TranslationHelpers
# end

##
# Add your before (RE)load hooks here
#
Padrino.before_load do
  Mongoid.load!(Padrino.root('config/mongoid.yml'), Padrino.env)
end

##
# Add your after (RE)load hooks here
#
Padrino.after_load do
  # 编码处理
  unless RUBY_VERSION < '1.9'
    Encoding.default_internal = nil
  end
  Time.zone = 'Beijing'
end

Padrino.load!
#!/usr/bin/env rackup
# encoding: utf-8

# This file can be used to start Padrino,
# just execute it from the command line.

require File.expand_path("../config/boot.rb", __FILE__)
require 'resque_scheduler'
require 'resque_scheduler/server'

run Rack::URLMap.new \
  '/'       => Padrino.application,
  '/resque' => Resque::Server.new

memory_usage = (`ps -o rss= -p #{$$}`.to_i / 1024.00).round(2)
logger.warn "使用内存: #{memory_usage} M"
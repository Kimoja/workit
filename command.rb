#!/usr/bin/env ruby

require_relative 'deps'

begin
  func = ARGV.shift
  require_relative "commands/#{func}"
  eval(func)
rescue => e
  log_error "#{e.message}"
  e.backtrace[0..20].each { |line| log "#{line}" }

  exit 1
end
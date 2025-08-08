#!/usr/bin/env ruby

require_relative 'deps'

begin
  eval(ARGV.shift)
rescue => e
  log_error "#{e.message}"
  e.backtrace[0..20].each { |line| log "#{line}" }

  exit 1
end
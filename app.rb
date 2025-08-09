require "bundler/setup"

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'

Bundler.require

loader = Zeitwerk::Loader.new
loader.push_dir("app")
loader.collapse("app/clients")
loader.collapse("app/features")
loader.collapse("app/lib")
loader.setup   

# binding.pry
# $cli_path = __dir__

begin
  #func = ARGV.shift
  binding.pry
  pp "ok"
  ##require_relative "commands/#{func}"
  #eval(func)
rescue => e
  log_error "#{e.message}" if e.message
  e.backtrace[0..20].each { |line| log "#{line}" }

  exit 1
end
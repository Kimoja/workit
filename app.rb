require "bundler/setup"

Bundler.require

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'

require_relative 'app/utils/config'
require_relative 'app/utils/cache'
require_relative 'app/utils/git'
require_relative 'app/utils/github'
require_relative 'app/utils/log'
require_relative 'app/utils/open'
require_relative 'app/utils/prompt'
require_relative 'app/utils/sound'

loader = Zeitwerk::Loader.new
loader.push_dir("app")
loader.collapse("app/clients")
loader.collapse("app/features")
loader.collapse("app/lib")
loader.setup   

APP_PATH = Dir.pwd
PWD_PATH = ARGV.shift
func = ARGV.shift

Dir.chdir(PWD_PATH)

begin
  require_relative "app/commands/#{func}"
  eval(func)
rescue => e
  log_error "#{e.message}" if e.message
  e.backtrace[0..20].each { |line| log "#{line}" }

  exit 1
end
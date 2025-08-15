require 'bundler/setup'

Bundler.require

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'
require 'pathname'
require 'active_support/all'

loader = Zeitwerk::Loader.new
loader.push_dir('app')
loader.collapse('app/base')
loader.setup

APP_PATH = Dir.pwd
PWD_PATH = ARGV.shift
cmd = ARGV.shift

Dir.chdir(PWD_PATH)

begin
  # rubocop:disable Style/EvalWithLocation
  # rubocop:disable Security/Eval
  # rubocop:disable Style/DocumentDynamicEvalDefinition
  eval("Commands::#{cmd}.call")
  # rubocop:enable Style/EvalWithLocation
  # rubocop:enable Security/Eval
  # rubocop:enable Style/DocumentDynamicEvalDefinition
rescue StandardError => e
  Utils::Log.error(e.message || e)
  e.backtrace[0..20].each { |line| Utils::Log.log line }
ensure
  Utils::Cache.save
end

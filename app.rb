s = Time.now
require_relative "boot"
  pp "#{Time.now - s} seconds to load boot"

APP_PATH = Dir.pwd
PWD_PATH = ARGV.shift
cmd = ARGV.shift

Dir.chdir(PWD_PATH)

begin
  command_class = Object.const_get(cmd)
  pp "#{Time.now - s} seconds to load #{cmd} command"
  # raise
  command_class.call
rescue StandardError => e
  Utils::Log.error(e.message || e)
  e.backtrace[0..20].each { |line| Utils::Log.log line }
ensure
  Utils::Cache.save
end

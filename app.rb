require_relative "boot"

APP_PATH = Dir.pwd
PWD_PATH = ARGV.shift
cmd = ARGV.shift

Dir.chdir(PWD_PATH)

begin
  command_class = Object.const_get(cmd)
  command_class.call
rescue StandardError => e
  Utils::Log.error(e.message || e)
  e.backtrace[0..20].each { |line| Utils::Log.log line }
end

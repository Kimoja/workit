require_relative 'deps'

$cli_path = __dir__

begin
  func = ARGV.shift
  require_relative "commands/#{func}"
  eval(func)
rescue => e
  log_error "#{e.message}" if e.message
  e.backtrace[0..20].each { |line| log "#{line}" }

  exit 1
end
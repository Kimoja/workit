### BOOTSNAP ###

require 'bootsnap'

cache_dir = File.expand_path('tmp/cache', __dir__)
FileUtils.mkdir_p(cache_dir)

Bootsnap.setup(
  cache_dir: cache_dir,
  development_mode: true,
  load_path_cache: true,
  compile_cache_iseq: true,
  compile_cache_yaml: true
)

### BUNDLER & MISC ###

require_relative 'bundle/bundler/setup'

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'
require 'pathname'
require 'zeitwerk'
require 'uinit/memoizable'
require 'pry'
require 'tty-prompt'

require_relative 'app/utils/core_extensions'

### ZEITWERK ###

loader = Zeitwerk::Loader.new
loader.push_dir('app')
loader.collapse('app/base')
loader.setup

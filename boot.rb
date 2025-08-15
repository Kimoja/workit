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

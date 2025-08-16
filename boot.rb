s = Time.now
require 'bundler/setup'
  pp "#{Time.now - s} seconds to bundler/setup"

Bundler.require
  pp "#{Time.now - s} seconds to bundler/require"

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'
require 'pathname'
  pp "#{Time.now - s} seconds to less support"
require 'active_support/all'

  pp "#{Time.now - s} seconds to manual"

loader = Zeitwerk::Loader.new
loader.push_dir('app')
loader.collapse('app/base')
loader.setup
  pp "#{Time.now - s} seconds to Zeitwerk"

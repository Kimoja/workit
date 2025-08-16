s = Time.now
require_relative 'bundle/bundler/setup'
  pp "#{Time.now - s} seconds to bundler/require"

require 'optparse'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'date'
require 'ostruct'
require 'pathname'
require 'zeitwerk'

  pp "#{Time.now - s} seconds to manual"

loader = Zeitwerk::Loader.new
loader.push_dir('app')
loader.collapse('app/base')
loader.setup
  pp "#{Time.now - s} seconds to Zeitwerk"

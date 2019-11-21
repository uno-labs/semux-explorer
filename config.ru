$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

if ENV['RACK_ENV'] == 'development'
  puts 'Loading as Development'

  require 'logger'
  logger = Logger.new($stdout)

  require 'semux_explorer'
  run SemuxExplorer
else
  require 'semux_explorer'
  run SemuxExplorer.freeze
end

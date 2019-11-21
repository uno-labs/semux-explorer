environment ENV['RACK_ENV'] || 'development'

workers Integer(ENV['WEB_WORKERS'] || 1)
threads_count = Integer(ENV['WEB_THREADS'] || 1)
threads threads_count, threads_count

bind "tcp://#{ENV['HOST'] || '0.0.0.0'}:#{ENV['PORT'] || 33601}"
bind "unix://#{ENV['SOCKET']}" if ENV['SOCKET']

preload_app!

rackup DefaultRackup

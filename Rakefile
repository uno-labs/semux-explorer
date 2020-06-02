irb = proc do |env|
  ENV['RACK_ENV'] = env
  trap('INT', "IGNORE")
  dir, base = File.split(FileUtils::RUBY)
  cmd = if base.sub!(/\Aruby/, 'irb')
    File.join(dir, base)
  else
    "#{FileUtils::RUBY} -S irb"
  end
  File.read('config/.env').each_line do |line|
    name, value = line.strip.split('=')
    ENV[name.strip] = value.strip.sub(/^["'](.*)["']$/, '\1')
  end
  sh "#{cmd} -r ./lib/cli.rb"
end

desc "Open irb shell in development mode"
task :default, :dev_irb do 
  irb.call('development')
end

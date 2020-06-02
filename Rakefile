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

desc "Download light wallet releases"
task :getwasm do
  REPO_RELEASES = 'https://api.github.com/repos/uno-labs/semux-light-core-wasm/releases'
  ASSETS_LOCATION = 'public/js/semux-light-core'

  require 'fileutils'
  require 'open-uri'
  require 'json'
  require 'tempfile'
  require 'rubygems/package'
  require 'zlib'

  data = open(REPO_RELEASES) { |file| file.read }
  releases = JSON.parse(data)
  releases.each do |release|
    tag, tgz = release["tag_name"]
    release["assets"].each do |asset|
      url = asset["browser_download_url"]
      if url.end_with?('.tar.gz')
        tgz = url
      end
    end

    files = Dir.glob(ASSETS_LOCATION + "/#{tag}/*.{js,wasm}")
    if files.count == 2
      puts "assets tagged `#{tag}` already in place"
    else
      do_download = true
    end

    if tgz && do_download
      data = open(tgz) { |source| source.read }
      Tempfile.create do |file|
        file.write data
        Gem::Package::TarReader.new(Zlib::GzipReader.open(file)) do |reader|
          reader.rewind
          reader.each do |entry|
            if entry.file? && entry.full_name =~ /(.js|.wasm)$/
              destination_name = File.join(ASSETS_LOCATION, tag, File.basename(entry.full_name))
              FileUtils.mkdir_p(File.dirname(destination_name))
              open(destination_name, 'w') { |destination| destination.write entry.read }
              puts "#{tgz} => #{destination_name}"
            end
          end
        end
      end
    end
  end
end

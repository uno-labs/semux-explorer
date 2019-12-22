class Cache
  def initialize
    @backend_request_cache = {}
  end

  def get(hash)
    if item = @backend_request_cache[hash]
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) - item[:time] < ENV['CACHE_TIMEOUT'].to_f
        item[:data]
      else
        delete(hash)
        nil
      end
    end
  end

  def set(hash, data)
    @backend_request_cache[hash] = {
      :time => Process.clock_gettime(Process::CLOCK_MONOTONIC),
      :data => data,
    }
    data
  end

  def delete(hash)
    @backend_request_cache.delete(hash)
  end
end

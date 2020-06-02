require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'awesome_print'
require 'ostruct'
require 'digest/sha1'
require 'semux_explorer_api/extender'
require 'semux_explorer_api/native'

module SemuxExplorerAPI
  module API
    extend self

    def delegates_get
      Extender.delegates_get
    end

    def address_get(address_hash)
      Extender.address_get(address_hash)
    end

    def block_get(block_id, page: 0)
      Extender.block_get(block_id)
    end

    def transaction_get(transaction_hash)
      Extender.transaction_get(transaction_hash)
    end

    def block_transactions(*args)
      Extender.block_transactions(*args)
    end

    def address_transactions(*args)
      Extender.address_transactions(*args)
    end

    def init
      @last_block = nil
      Extender.init
    end

    def address_name(address, renew: false)
      Extender.address_names[address.to_s]
    end

    def name_address(name, renew: false)
      Extender.address_names.key(name.to_s)
    end

    def validators_count
      Extender.validators_count
    end

    def last_block
      @last_block ||= Extender.block_get_last
    end

    PERFECT_BLOCK_DURATION = 30.0

    def next_block_wait_time
      last_block_time = DateTime.strptime(last_block.timestamp.to_s, "%Q").to_time
      host_to_block_delay = Time.now - last_block_time
      $last_host_to_block_delay ||= host_to_block_delay
      $last_host_to_block_delay = host_to_block_delay if host_to_block_delay > $last_host_to_block_delay
      expected_wait_time = last_block_time + $last_host_to_block_delay - Time.now
      $last_host_to_block_delay -= (expected_wait_time - PERFECT_BLOCK_DURATION) if expected_wait_time > PERFECT_BLOCK_DURATION
      expected_wait_time
    end

    def backend_time
      Extender.response_times.inject(0.0) { |all, time| all + time[1] }
    end
  end
end

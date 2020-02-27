require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'awesome_print'
require 'ostruct'
require 'digest/sha1'
require 'cache'

module SemuxExplorerAPI
  class BackendError < StandardError; def backtrace; []; end; end
  class InvalidCredentials < StandardError; def backtrace; []; end; end
  class InvalidAddress < StandardError; def backtrace; []; end; end

  module MethodsV2
    def delegates_get
      delegates = request("semux.blockchain.delegates.get", nil)
      save_address_names(delegates)
      delegates
    end

    def address_get(address_hash)
      fail InvalidAddress unless address_hash.match /^0x[\da-fA-F]{40}$/
      Array(request("semux.blockchain.address.get", [address_hash]))[0]
    end

    def block_get(block_id, page: 0)
      request("semux.blockchain.block.get_by_id", block_id)
    end

    def block_get_last
      request("semux.blockchain.block.get_last", nil)
    end

    def transaction_get(transaction_hash)
      request("semux.blockchain.transactions.get_by_id", transaction_hash)
    end

    def block_transactions(block_id, offset: nil, limit: nil)
      offset = offset.to_i
      offset = 0 if offset < 0
      limit = limit.to_i
      limit = 200 if limit <= 0 || limit > 1000
      request("semux.blockchain.transactions.get_by_block_id", :block_id => block_id, :limit => limit, :offset => offset) || []
    end

    def address_transactions(address_hash, offset: nil, limit: nil)
      offset = offset.to_i
      offset = 0 if offset < 0
      limit = limit.to_i
      limit = 20 if limit <= 0 || limit > 100
      request("semux.blockchain.transactions.get_by_address", :address => address_hash, :limit => limit, :offset => offset) || []
    end
  end

  module API
    include MethodsV2
    extend self

    attr_reader :backend_times

    def init
      @cache ||= Cache.new
      @last_block = nil
      @backend_times = {}
      @address_names ||= {}
      @debug_output = $stdout if ENV['RACK_ENV'] == 'development'
      @base_uri = ENV['BACKEND_BASE']
    end

    def address_name(address, renew: false)
      delegates_get if @address_names.empty?
      @address_names[address.to_s]
    end

    def name_address(name, renew: false)
      delegates_get if @address_names.empty?
      @address_names.key(name.to_s)
    end

    def last_block
      @last_block ||= block_get_last
    end

    def backend_time
      backend_times.inject(0.0) { |all, time| all + time[1] }
    end

    private

    def save_address_names(delegates)
      @address_names = Hash[delegates.map{ |delegate| [delegate.addr, delegate.name] }]
    end

    def http
      @http ||= begin
        uri = URI.parse(@base_uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if @base_uri.start_with?('https')
        http
      end
    end

    def post(body)
      uri = URI.parse(@base_uri)
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = body.to_json

      @backend_times ||= {}
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = http.request(request)
      @backend_times[body[:method]] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      response.body
    end

    def cached_post(body, key_hash)
      if false && ENV['RACK_ENV'] == 'development'
        post(body)
      else
        if data = @cache.get(key_hash)
          data
        else
          @cache.set(key_hash, post(body))
        end
      end
    end

    CREDENTIALS_FILE = 'config/credentials.json'

    def credentials
      JSON.parse(File.read CREDENTIALS_FILE)
    rescue Errno::ENOENT => e
      fail InvalidCredentials, { :error => 'credentials not found' }.ai
    rescue JSON::ParserError => e
      fail InvalidCredentials, { :error => 'error parsing credentials' }.ai
    end

    def auth
      body = {
        :method => "base.user.auth.new_session",
        :data => credentials,
        :ts => Time.now.to_i,
      }

      response_body = post(body)
      response = JSON.parse(response_body, object_class: OpenStruct)

      case response.result["res"]
      when "SUCCESS"
        @session_id = response.data["sid"]
      else
        fail InvalidCredentials, { :method => body[:method], :response => response }.ai
      end
    rescue JSON::ParserError => e
      fail BackendError, { :error => "#{e}: #{e.message}", :method => body[:method], :response => response }.ai
    end

    def request(method, data)
      key_hash = Digest::SHA1.hexdigest([method, data].to_json)
      body = { 
        :method => method,
        :data => data,
        :ts => Time.now.to_i,
        :sid => @session_id || auth,
      }

      response_body = cached_post(body, key_hash)
      response = JSON.parse(response_body, object_class: OpenStruct)

      case response.result["res"]
      when "SUCCESS"
        response.data
      when "INVALID_SID"
        @cache.delete(key_hash)
        auth
        request(method, data)
      when "BLOCK_NOT_FOUND", "ADDRESS_NOT_FOUND", "TRANSACTION_NOT_FOUND"
        nil
      else
        @cache.delete(key_hash)
        fail BackendError, { :method => method, :params => data, :response => response }.ai
      end
    rescue JSON::ParserError => e
      @cache.delete(key_hash)
      fail BackendError, { :error => "#{e}: #{e.message}", :method => method, :params => data, :response => response }.ai
    end
  end
end

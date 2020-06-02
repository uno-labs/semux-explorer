require 'cache'

module SemuxExplorerAPI
  module Extender
    extend self

    class BackendError < StandardError; def backtrace; []; end; end
    class InvalidCredentials < StandardError; def backtrace; []; end; end
    class InvalidAddress < StandardError; def backtrace; []; end; end

    def init
      response_times.clear
    end

    def cache
      @cache ||= Cache.new
    end

    def address_names
      delegates_get if @address_names.nil?
      @address_names
    end

    def validators_count
      delegates_get if @validators_count.nil?
      @validators_count
    end

    def base_uri
      @base_uri ||= ENV['BACKEND_BASE']
    end

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

    def response_times
      @response_times ||= {}
    end

    private

    def save_address_names(delegates)
      @address_names = Hash[delegates.map{ |delegate| [delegate.addr, delegate.name] }]
      @validators_count = delegates.count{ |delegate| delegate.state == 'VALIDATOR' }
    end

    def http
      @http ||= begin
        uri = URI.parse(base_uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if base_uri.start_with?('https')
        http
      end
    end

    def post(body)
      uri = URI.parse(base_uri)
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = body.to_json

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = http.request(request)
      response_times[body[:method]] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      response.body
    end

    def cached_post(body, key_hash)
      if ENV['RACK_ENV'] == 'development'
        post(body)
      else
        if data = cache.get(key_hash)
          data
        else
          cache.set(key_hash, post(body))
        end
      end
    end

    CREDENTIALS_FILE = 'config/extender_credentials.json'

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
        cache.delete(key_hash)
        auth
        request(method, data)
      when "BLOCK_NOT_FOUND", "ADDRESS_NOT_FOUND", "TRANSACTION_NOT_FOUND"
        nil
      else
        cache.delete(key_hash)
        fail BackendError, { :method => method, :params => data, :response => response }.ai
      end
    rescue JSON::ParserError => e
      cache.delete(key_hash)
      fail BackendError, { :error => "#{e}: #{e.message}", :method => method, :params => data, :response => response }.ai
    end
  end
end

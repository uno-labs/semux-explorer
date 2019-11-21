require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'awesome_print'
require 'ostruct'
require 'digest/sha1'

module SemuxExplorerAPI
  class BackendError < StandardError; def backtrace; []; end; end

  module Methods
    def address_names
      $address_names
    end

    def address_name(address, renew: false)
      if renew || $address_names.nil? || $address_names.empty?
        delegates_get
      end
      $address_names[address.to_s]
    end

    def name_address(name, renew: false)
      if renew || $address_names.nil? || $address_names.empty?
        delegates_get
      end
      $address_names.invert[name.to_s]
    end

    def delegates_get
      delegates = request("semux.blockchain.delegates.get", {})
      $address_names = Hash[delegates.map{ |delegate| [delegate.addr, delegate.name] }]
      delegates
    end

    def address_get(addr)
      if addr.match /0x[\da-fA-F]{40}/
        Array(request("semux.blockchain.address.get", [addr]))[0]
      else
        nil
      end
    end

    def block_get(block_id, page: 0)
      request("semux.blockchain.block.get_by_id", block_id)
    end

    def block_transactions(block_id, offset: nil, limit: nil)
      offset = offset.to_i
      offset = 0 if offset < 0
      limit = limit.to_i
      limit = 200 if limit <= 0 || limit > 1000
      request("semux.blockchain.transactions.get_by_block_id", :block_id => block_id, :limit => limit, :offset => offset)
    end

    def address_transactions(address, offset: nil, limit: nil)
      offset = offset.to_i
      offset = 0 if offset < 0
      limit = limit.to_i
      limit = 20 if limit <= 0 || limit > 100
      request("semux.blockchain.transactions.get_by_address", :address => address, :limit => limit, :offset => offset)
    end
  end

  module API
    include Methods
    extend self

    attr_reader :user, :session_id, :last_request_time

    @debug_output = $stdout if ENV['RACK_ENV'] == 'development'
    @base_uri = ENV['BACKEND_BASE']

    private

    def http
      @http ||= begin
        uri = URI.parse(@base_uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if @base_uri.start_with?('https')
        http
      end
    end

    def post(pathname='', body: {})
      uri = URI.parse(@base_uri + pathname)
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = body.to_json
      response = http.request(request)
      response.body
    end

    def auth
      credentials = JSON.parse File.read('config/credentials.json')
      data = request("base.user.auth.new_session", credentials, cache: false)

      @session_id = data["sid"]
      @user = data["user"]

      data
    end

    MAX_RETRY_COUNT = 2

    def request(name, data, cache: true)
      fail if @retry_count.to_i > MAX_RETRY_COUNT

      body = { :data => data, :method => name, :ts => Time.now.to_i }
      body["sid"] = @session_id if @session_id

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if ENV['RACK_ENV'] == 'development' || !cache
        response_body = post(body: body)
        @last_request_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      else
        $cache ||= {}
        response_body = begin
          hash = Digest::SHA1.hexdigest([name, data].to_json)
          stored_data = $cache[hash]
          if stored_data && (start - stored_data[0] < ENV['CACHE_TIMEOUT'].to_i)
            @last_request_time = nil
            stored_data[1]
          else
            post_response = post(body: body)
            finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            @last_request_time = finish - start
            $cache[hash] = [finish, post_response]
            post_response
          end
        end
      end

      response = JSON.parse(response_body, :object_class => OpenStruct)

      case response["result"]["res"]
      when "SUCCESS"
        @retry_count = 0
        response["data"]
      when "INVALID_SID"
        $cache.delete(hash) if $cache
        @session_id = nil
        auth
        @retry_count ||= 0
        @retry_count += 1
        request(name, data)
      when "BLOCK_NOT_FOUND", "ADDRESS_NOT_FOUND", "TRANSACTION_NOT_FOUND"
        nil
      else
        $cache.delete(hash) if $cache
        fail BackendError, { :method => name, :params => data, :response => response }.ai
      end
    rescue JSON::ParserError => e
      $cache.delete(hash) if $cache
      fail BackendError, { :error => "#{e}: #{e.message}", :method => name, :params => data, :response => response }.ai
    end
  end
end

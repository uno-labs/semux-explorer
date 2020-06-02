require 'open-uri'

module SemuxExplorerAPI
  module Native
    extend self

    class BackendError < StandardError; def backtrace; []; end; end

    def base_uri
      @base_uri ||= nil + ENV['BACKEND_SEMUX_API_BASE'] || fail(BackendError.new 'BACKEND_SEMUX_API_BASE not defined in env')
    end

    def account(address)
      uri = base_uri + 'account?' + URI.encode_www_form(:address => address)
      JSON.parse(open(uri) { |io| io.read })
    rescue OpenURI::HTTPError => e
      JSON.parse(e.io.string)
    end

    def broadcast_raw_transaction(raw)
      uri = base_uri + 'broadcast-raw-transaction?' + URI.encode_www_form(:raw => raw)
      JSON.parse(open(uri) { |io| io.read })
    rescue OpenURI::HTTPError => e
      JSON.parse(e.io.string)
    end

    def account_pending_transactions(address)
      chunk_size = 10
      offset = 0
      results = []
      chunk_response = nil
      loop do
        uri = base_uri + 'account/pending-transactions?' + URI.encode_www_form(:address => address, :from => offset, :to => offset + chunk_size)
        offset += chunk_size
        chunk_response = JSON.parse(open(uri) { |io| io.read })
        if chunk_response["success"]
          read_count = chunk_response["result"].count
          results.concat chunk_response["result"]
        else
          read_count = 0
        end
        break if read_count < chunk_size
      end
      chunk_response["result"] = results
      chunk_response
    rescue OpenURI::HTTPError => e
      JSON.parse(e.io.string)
    end

    def latest_block
      uri = base_uri + 'latest-block'
      JSON.parse(open(uri) { |io| io.read })
    rescue OpenURI::HTTPError => e
      JSON.parse(e.io.string)
    end
  end
end

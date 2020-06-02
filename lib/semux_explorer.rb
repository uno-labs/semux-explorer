require 'roda'
require 'semux_explorer_api'
require 'helpers'
require 'reverse_paginator'

class SemuxExplorer < Roda
  API = SemuxExplorerAPI::API

  include Helpers

  plugin :slash_path_empty
  plugin :render, :engine => 'slim'
  plugin :static, ['/img', '/css', '/js', '/favicon.ico', '/robots.txt']
  plugin :error_handler do |error|
    response.status = error_http_status(error)
    case @_error_content_type
    when 'text/plain'
      error.message
    when 'application/json'
      { :success => false, :message => error.message }
    else
      view :error, :locals => { :error => error }
    end
  end
  plugin :not_found do
    show_not_found
  end

  FRAGMENTS = ['last_block']

  route do |r|
    start_timer
    @path_parts = r.path.split('/').reject(&:empty?)

    r.on 'address', String do |address|
      @address = API.address_get(address) || show_not_found
      @transactions = paginate_transactions(address: @address, page: r.params['page'])
      view :'address/view'
    end

    r.on 'delegate', String do |name|
      address_hash = API.name_address(name) || show_not_found
      @address = API.address_get(address_hash) || show_not_found
      @transactions = paginate_transactions(address: @address, page: r.params['page'])
      view :'delegate/view'
    end

    r.on 'block', String do |block_id|
      @block = API.block_get(block_id) || show_not_found
      @transactions = paginate_transactions(block: @block, page: r.params['page'])
      view :'block/view'
    end

    r.on 'transaction', String do |transaction_hash|
      @transaction = API.transaction_get(transaction_hash) || show_not_found
      view :'transaction/view'
    end

    r.on 'fragment', String, String do |_, fragment|
      show_not_found unless FRAGMENTS.include?(fragment)
      render "part/#{fragment}"
    end

    r.root do
      @delegates = API.delegates_get
      @delegates.sort_by! do |delegate|
        "#{(10**19 - (delegate.delegate_state ? delegate.delegate_state.votes_sum : 0)).to_s.rjust(20, '0')} #{delegate.name}"
      end
      view :index
    end
  end
end

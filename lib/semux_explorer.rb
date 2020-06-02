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
    message = error.message
    if ENV['RACK_ENV'] == 'developmecnt'
      error.backtrace.each{ |source| message << "\n" << source }
    end
    case @_error_content_type
    when 'text/plain'
      message
    when 'application/json'
      { :success => false, :message => message }
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

    r.on 'wallet' do
      response['Access-Control-Allow-Origin'] = '*'

      tag = r.params["tag"]
      tag = light_core_tags.last unless light_core_tags.include?(tag)

      r.get 'nonce', String do |address|
        response['Content-Type'] = @_error_content_type = 'text/plain'
        API.get_nonce(address)
      end

      r.post 'broadcast' do
        response['Content-Type'] = @_error_content_type = 'application/json'
        JSON.pretty_generate(API.broadcast(r.params['raw']))
      end

      r.is do
        view :'wallet/view', :locals => { :semux_light_core_js => "/js/semux-light-core/#{tag}/UnoSemuxLightCoreWasm.js" }
      end
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

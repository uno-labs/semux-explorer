require 'roda'
require 'slim'

require 'semux_explorer_api'
require 'helpers'

class SemuxExplorer < Roda
  plugin :render, :engine => 'slim', :pretty => true
  plugin :static, ['/css', '/favicon.ico', '/robots.txt']
  plugin :error_handler
  plugin :not_found

  API = SemuxExplorerAPI::API
  include Helpers

  ERROR_STATUS_MAP = {
    SemuxExplorerAPI::BackendError => 502,
    NotFoundError => 404,
  }

  error do |error|
    response.status = ERROR_STATUS_MAP[error.class] || 500

    view :error, :locals => { :error => error }
  end

  not_found do
    show_not_found
  end

  route do |r|
    @request_start_time = Time.now
    @active_chapter = r.path.sub(/^\//, '')
    @page_title = @active_chapter.split('/').join(' :: ')

    r.is 'theme' do
      view :theme
    end

    r.on ['address', 'delegate'] do
      view_as_delegate = r.matched_path == '/delegate'

      r.on String do |address|
        @address = API.address_get(API.name_address(address) || address)
        show_not_found unless @address
        @transactions_offset = (r.params['transactions_offset'] || 0).to_i
        @transactions_limit = (r.params['transactions_limit'] || 50).to_i
        @transactions_count = @address.transactions_count.to_i
        #@transactions = API.address_transactions(@address.addr, offset: @transactions_offset, limit: @transactions_limit)
        view view_as_delegate ? :delegate : :address
      end
    end

    r.on 'block' do
      r.on String do |block_id|
        @block = API.block_get(block_id)
        show_not_found unless @block
        @transactions_offset = (r.params['transactions_offset'] || 0).to_i
        @transactions_limit = (r.params['transactions_limit'] || 200).to_i
        @transactions_count = @block.transactions_count.to_i
        #@transactions = API.block_transactions(@block.id, offset: @transactions_offset, limit: @transactions_limit)
        view :block
      end
    end

    r.root do
      @delegates = API.delegates_get
      @delegates.sort_by!{ |delegate| "#{(10**19 - (delegate.delegate_state ? delegate.delegate_state.votes_sum : 0)).to_s.rjust(20, '0')}#{delegate.name}" }
      view :index
    end
  end
end

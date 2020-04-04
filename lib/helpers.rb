module Helpers
  class NotFoundError < StandardError; def backtrace; []; end; end

  TAGS_FILE = 'config/tags.json'

  def tags(reset: false)
    return @tags if @tags && !@tags.empty? && !reset
    json = JSON.parse(File.read TAGS_FILE)
    @tags = {}
    json.each_pair do |label, data|
      if data.kind_of? Hash
        @tags.update(data)
        json.delete(label)
      end
    end
    @tags.update(json)
    @tags
  rescue Errno::ENOENT => e
    {}
  rescue JSON::ParserError => e
    {}
  end

  def show_not_found
    fail NotFoundError.new('404')
  end

  def details(var_name)
    return nil unless ENV['RACK_ENV'] == 'development'
    if var_value = instance_variable_get("@#{var_name}")
      "<details><summary>debug on <code>#{var_name}</code></summary>#{var_value.ai(:html => true)}</details>"
    end
  end

  def page_description
    @page_description
  end

  def site_title
    ENV['SITE_TITLE'] || 'Semux.Top Explorer'
  end

  def page_title
    [site_title, @path_parts].flatten.compact.join(' :: ')
  end

  def int_as_sem(number, decimals: 9)
    sprintf("%.#{decimals}f", number.to_f / 10**9).sub(/(\.\d*?)0+$/, '\1').chomp('.')
  end

  def timestamp_time(unix_ms, local: false)
    iso8601 = DateTime.strptime(unix_ms.to_s, "%Q").iso8601(3);
    klass = local ? 'local' : 'utc'
    "<time class=\"#{klass}\" datetime=\"#{iso8601}\">#{iso8601[0..18].tr('T',' ')}</time>"
  end
                    
  def decimal_align_class(string, decimals: 9)
    decimals = 9 if decimals > 9
    decimal_count = string.partition('.').last.length
    decimal_count = decimals if decimal_count > decimals
    decimal_count = -1 if decimal_count == 0
    decimal_count -= 1 if decimals < 9
    "align-#{decimals - decimal_count}"
  end

  def sem_td(nsem, decimals: 9)
    sem = int_as_sem(nsem, decimals: decimals)
    "<td class=\"text-right text-monospace #{decimal_align_class(sem, decimals: decimals)}\">#{sem}</td>"
  end

  def sem_span(nsem)
    sem = int_as_sem(nsem)
    "<div class=\"align-sem text-right text-monospace #{decimal_align_class(sem)}\">#{sem}</div>"
  end

  def address_link(address, name: true, hex: false, shorten: false, tag: true)
    return 'nil' if address.nil?
    address = address.to_s
    delegate_link = address_link = ''

    if name && delegate_name = SemuxExplorer::API.address_name(address)
      if main_resource?(delegate_name: delegate_name)
        delegate_link = "<span class=\"text-warning\">#{delegate_name}</a> "
      else
        delegate_link = "<a class=\"text-warning\" href=\"/delegate/#{delegate_name}\">#{delegate_name}</a> "
      end
    else
      hex = true
    end

    if hex
      label = tag && tags[address] || (shorten ? address[0..9] + ':' : address)
      klass = "text-monospace"
      klass += " text-info" if tag && tags[address]
      if label == 'block reward' || main_resource?(address: address)
        address_link = "<span class=\"#{klass}\">#{label}</span>"
      else
        address_link = "<a class=\"#{klass}\" href=\"/address/#{address}\">#{label}</a>"
      end
    end

    delegate_link + address_link
  end

  def transaction_link(transaction, shorten: false)
    return 'nil' if transaction.nil?
    transaction = transaction.to_s
    label = shorten ? transaction[0..9] + ':' : transaction
    "<a class=\"text-monospace\" href=\"/transaction/#{transaction}\">#{label}</a>"
  end

  def block_link(block_id, label: nil)
    if block_id == -1
      'genesis'
    else
      "<a href=\"/block/#{block_id}\">#{label||("block/"+block_id.to_s)}</a>"
    end
  end

  def external_link(target, object, data)
    case target
    when :'semux.info'
      base = "https://semux.info/explorer"
      case object
      when :address
        "<a href=\"#{base}/account/#{data}\" target=\"_blank\">🔗 at semux.info</a>"
      when :block
        "<a href=\"#{base}/block/#{data}\" target=\"_blank\">🔗 at semux.info</a>"
      when :address_transactions
        "<a href=\"#{base}/account/#{data}#transfers\" target=\"_blank\">🔗 at semux.info</a>"
      when :transaction
        "<a href=\"#{base}/transaction/#{data}\" target=\"_blank\">🔗 at semux.info</a>"
      end
    else
      ''
    end
  end

  def hex_to_text(data)
    [data.sub(/^0x/, '').gsub('00', '95')].pack('H*').encode('UTF-8')
  rescue
    nil
  end

  DELEGATE_STYLE_MAP = {
    'DELEGATE' => 'warning',
    'VALIDATOR' => 'success',
    'SMART_CONTRACT' => 'info',
    'ALIVE' => 'success',
    'WARNING' => 'warning',
    'DEAD' => 'danger',
  }

  def delegate_state_badge(state, label:nil)
    style = DELEGATE_STYLE_MAP[state] || 'dark'
    "<span class=\"badge badge-pill badge-#{style}\">#{label || state.downcase.sub('warning', 'warn')}</span>"
  end

  TRANSACTION_STYLE_MAP = {
    'VOTE' => 'warning',
    'UNVOTE' => 'warning',
    'TRANSFER' => 'success',
    'COINBASE' => 'dark',
    'DELEGATE' => 'info',
    'CALL' => 'danger',
    'SUCCESS' => 'success',
    'FAILURE' => 'danger',
  }

  def transaction_type_badge(transaction)
    type = transaction.type || transaction.code
    style = TRANSACTION_STYLE_MAP[type] || 'dark'
    result = "<span class=\"badge badge-pill badge-#{style}\">#{type.downcase}</span>"
    if transaction.type == 'CALL' && transaction.transactions_result
      result += transaction_type_badge(transaction.transactions_result)
    end
    result
  end

  def paginate_transactions(address:nil, block:nil, page:)
    case
    when address
      ReversePaginator.new(total: address.transactions_count.to_i, limit: 20, page: page.to_i) do |offset, limit|
        SemuxExplorerAPI::API.address_transactions(address.addr, offset: offset, limit: limit)
      end
    when block
      ReversePaginator.new(total: block.transactions_count.to_i, limit: 20, page: page.to_i) do |offset, limit|
        SemuxExplorerAPI::API.block_transactions(block.id, offset: offset, limit: limit)
      end
    end
  end

  def start_timer
    SemuxExplorerAPI::API.init
    @start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def stop_timer
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start
  end

  def main_resource?(address:nil, delegate_name:nil)
    case
    when address
      @path_parts[0] == 'address' && @path_parts[1] == address
    when delegate_name
      @path_parts[0] == 'delegate' && @path_parts[1] == delegate_name
    end
  end

  ERROR_STATUS_MAP = {
    SemuxExplorerAPI::InvalidCredentials => 500,
    SemuxExplorerAPI::InvalidAddress => 400,
    SemuxExplorerAPI::BackendError => 502,
    NotFoundError => 404,
  }

  def error_http_status(error)
    ERROR_STATUS_MAP[error.class] || 500
  end
end

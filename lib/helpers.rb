module Helpers
  class NotFoundError < StandardError; def backtrace; []; end; end

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
    [site_title, @page_title].reject(&:empty?).compact.join(' :: ')
  end

  def chapters
    []
  end

  def active_chapter
    @active_chapter
  end

  def int_as_sem(number)
    sprintf('%.9f', number.to_f / 10**9).sub(/(\.\d*?)0+$/, '\1').chomp('.')
  end

  def timestamp_time(unix_ms)
    DateTime.strptime(unix_ms.to_s, "%Q").iso8601(3)
  end
                    
  MAX_DECIMAL = 9

  def decimal_align_class(string)
    decimal_count = string.partition('.').last.length
    decimal_count = MAX_DECIMAL if decimal_count > MAX_DECIMAL
    decimal_count = -1 if decimal_count == 0
    "align-#{MAX_DECIMAL - decimal_count}"
  end

  def sem_td(nsem)
    sem = int_as_sem(nsem)
    "<td class=\"text-right text-monospace #{decimal_align_class(sem)}\">#{sem}</td>"
  end

  def sem_span(nsem)
    sem = int_as_sem(nsem)
    "<div class=\"align-sem text-right text-monospace #{decimal_align_class(sem)}\">#{sem}</div>"
  end

  def address_link(address, name: true, hex: false, shorten: false)
    return 'nil' if address.nil?
    address = address.to_s
    delegate_link = address_link = ''
    if name && delegate_name = SemuxExplorer::API.address_name(address)
      delegate_link = "<a class=\"text-warning\" href=\"/delegate/#{delegate_name}\">#{delegate_name}</a> "
    else
      hex = true
    end
    if hex
      label = shorten ? address[0..9] + ':' : address
      address_link = "<a class=\"text-monospace\" href=\"/address/#{address}\">#{label}</a>"
    end
    delegate_link + address_link
  end

  def block_link(block_id, label: nil)
    label ||= 'genesis' if block_id == -1
    "<a href=\"/block/#{block_id}\">#{label||("block/"+block_id.to_s)}</a>"
  end

  def external_link(target, object, data)
    case target
    when :'semux.info'
      base = "https://semux.info/explorer"
      case object
      when :address
        "<a href=\"#{base}/account/#{data}\" target=\"_blank\">🔗 at semux.info</a>"
      when :block
        "<a href=\"#{base}/block/#{data}\" target=\"_blank\">🔗 at semux.info</a>"
      when :address_transactions
        "<a href=\"#{base}/account/#{data}#transfers\" target=\"_blank\">🔗 at semux.info</a>"
      end
    else
      ''
    end
  end

  DELEGATE_STYLE_MAP = {
    'delegate' => 'warning',
    'validator' => 'success'
  }

  def delegate_state_badge(state)
    style = DELEGATE_STYLE_MAP[state.downcase] || 'dark'
    "<span class=\"badge badge-pill badge-#{style}\">#{state.downcase}</span>"
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
end

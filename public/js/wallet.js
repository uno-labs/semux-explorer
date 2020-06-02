'use strict';

var BACKEND_ORIGIN = ''; // empty string for your own backend, 'https://semux.top/wallet' for our backend

var TRANSACTION_EXPLORER = '/transaction/'; // prefix for transaction explorer

window.prepare_wallet = function(body) {
  if (!body.querySelector('section.wallet')) return;
  body.querySelector('#prepare-transaction').onclick = window.prepare_transaction;
  body.querySelector('#commit-transaction').onclick = window.commit_transaction;
  var last_block_element = body.querySelector('[data-fragment="part/last_block"]');
  if (last_block_element) {
    last_block_element.parentNode.addEventListener('auto-refresh-done', window.refresh_pending_transaction);
  }
};

window.refresh_pending_transaction = function(event) {
  var transaction_hashes = document.querySelector('.last-block').dataset.transactions.split(',');

  for (var i = 0; i < transaction_hashes.length; i++) {
    var pending_transaction_link = document.querySelector('a.transaction-pending[data-hash="' + transaction_hashes[i] + '"]');

    if (pending_transaction_link) {
      pending_transaction_link.href = TRANSACTION_EXPLORER + transaction_hashes[i];
      var transaction_status = pending_transaction_link.parentNode.querySelector('.badge-warning');

      if (transaction_status) {
        transaction_status.classList.remove('badge-warning');
        transaction_status.classList.add('badge-info');
        transaction_status.innerHTML = 'complete';
      }
    }
  }
};

window.commit_transaction = function(event) {
  var xhr = new XMLHttpRequest();

  xhr.onload = function() {
    var local_time = (new Date()).toLocaleString(navigator.languages);

    var response = JSON.parse(xhr.response);
    if (response.success) {
      var message = '<p class="text-muted mb-1"><span class="badge badge-success">success</span> <span class="badge badge-warning mr-1">pending</span> <small><time class="text-muted mr-1">' + local_time + '</time></small> <a class="transaction-pending text-monospace" target="_blank" data-hash="' + response.result + '"><small>' + response.result + '</small></a></p>';
    }else{
      var message = '<p class="text-break mb-1"><span class="badge badge-danger">error</span> <small><time class="text-muted mr-1">' + local_time + '</time></small> <small>' + response.message + '</small></p>';
    }

    document.querySelector('#transactions-result').innerHTML += message;
    document.querySelector('fieldset.commit').classList.add('d-none');
    document.querySelector('fieldset.result').classList.remove('d-none');
  };

  var data = new FormData();
  data.set('raw', window.latest_transaction_data);
  xhr.open('POST', BACKEND_ORIGIN + '/wallet/broadcast');
  xhr.send(data);
};

window.display_error = function(error_message, input=null) {
  var lines = error_message.split(/\r\n|\r|\n/);
  if (lines.length > 1) {
    console.log(error_message);
    console.trace();
  }
  var message_element = document.createElement('DIV');
  message_element.innerHTML = lines[0].replace(/.*?'(.*)'.*/, '$1');

  if (input) {
    message_element.className = "invalid-feedback";
    input.parentNode.insertBefore(message_element, input.nextSibling);
    input.classList.add('is-invalid');
  }else{
    message_element.className = "text-danger";
    document.querySelector('fieldset.result').classList.remove('d-none');
    document.querySelector('#transactions-result').insertBefore(message_element, null);
  }
};

window.clear_errors = function() {
  var invalid_inputs = document.querySelectorAll('input.is-invalid');
  for (var i = 0; i < invalid_inputs.length; i++) {
    invalid_inputs[i].classList.remove('is-invalid');
    invalid_inputs[i].parentNode.removeChild(invalid_inputs[i].nextSibling);
  }
};

window.prepare_transaction = function(event) {
  window.clear_errors();

  var mnemonic_phrase_input = document.querySelector('#mnemonic-phrase');
  var mnemonic_phrase = mnemonic_phrase_input.value;
  if (!mnemonic_phrase.match(/.+$/)) {
    return window.display_error(mnemonic_phrase_input.dataset.invalid_format, mnemonic_phrase_input);
  }

  var mnemonic_password_protected_checkbox = document.querySelector('#mnemonic-password-protected');
  if (mnemonic_password_protected_checkbox.checked) {
    var mnemonic_phrase_password = window.prompt(mnemonic_password_protected_checkbox.dataset.prompt);
    if (mnemonic_phrase_password === null) return;
  }else{
    var mnemonic_phrase_password = "";
  }

  var {error, res: hd_wallet} = Module.UnoSemuxAccountHD.sImportFromMnemonic(mnemonic_phrase, mnemonic_phrase_password);
  if (error) return window.display_error(error, mnemonic_phrase_input);

  var {error, res: account} = hd_wallet.addrAddNextHD();
  if (error) return window.display_error(error, mnemonic_phrase_input);

  var {error, res: from_address} = account.addrStrHex();
  if (error) return window.display_error(error, mnemonic_phrase_input);

  var NETWORK_TYPES = {
    "MAINNET": Module.UnoSemuxNetworkType.MAINNET,
    "TESTNET": Module.UnoSemuxNetworkType.TESTNET,
    "DEVNET": Module.UnoSemuxNetworkType.DEVNET,
  };
  var network_type = NETWORK_TYPES[document.querySelector('#network-type').value];

  var TRANSACTION_TYPES = {
    "TRANSFER": Module.UnoSemuxTransactionType.TRANSFER,
    "DELEGATE": Module.UnoSemuxTransactionType.DELEGATE,
    "VOTE": Module.UnoSemuxTransactionType.VOTE,
    "UNVOTE": Module.UnoSemuxTransactionType.UNVOTE,
    "CREATE": Module.UnoSemuxTransactionType.CREATE,
    "CALL": Module.UnoSemuxTransactionType.CALL,
  };
  var transaction_type = TRANSACTION_TYPES[document.querySelector('#transaction-type').value];

  var to_address_input = document.querySelector('#to-address');
  var to_address = to_address_input.value.trim() || "";
  if (to_address.match(/^[\da-fA-F]{40}$/)) to_address = '0x' + to_address;
  if (!to_address.match(/^0x[\da-fA-F]{40}$|^$/)) {
    return window.display_error(to_address_input.dataset.invalid_format, to_address_input);
  }

  var sem_amount_input = document.querySelector('#sem-amount');
  var sem_amount = (sem_amount_input.value.trim() || "0").replace(/\,/g, '.');
  if (!sem_amount.match(/^([1-9]\d*|0)?(\.\d+)?$/)) {
    return window.display_error(sem_amount_input.dataset.invalid_format, sem_amount_input);
  }

  var xhr = new XMLHttpRequest();
  xhr.onload = function() {
    if (xhr.status != 200) {
      return window.display_error('' + xhr.status + ' ' + xhr.statusText + ': ' + xhr.response);
    }
    var nonce = parseInt(xhr.response);
    var {error, res: transaction} = new Module.UnoSemuxTransaction.sNew(
      network_type,
      transaction_type,
      String(to_address),
      String(parseFloat(sem_amount) * 1000000000),
      String("5000000"),
      String(nonce),
      String(new Date().getTime()),
      String("0x756E6F2D6C616273206C696768742077616C6C65742064656D6F"), // uno-labs light wallet demo
      String("0"),
      String("0")
    );
    if (error) return window.display_error(error);

    var {error, res: signed_transaction} = account.sign1(transaction);
    if (error) return window.display_error(error);

    var {error, res: signed_transaction_hash} = signed_transaction.txHash();
    if (error) return window.display_error(error);

    var {error, res: signed_transaction_data} = signed_transaction.encode();
    if (error) return window.display_error(error);

    window.latest_transaction_data = signed_transaction_data;

    document.querySelector('fieldset.commit').classList.remove('d-none');
    document.querySelector('#review-from-address').innerHTML = '<a class="text-monospace" href="/address/0x' + from_address + '">0x' + from_address + '</a>';
    document.querySelector('#review-to-address').innerHTML = '<a class="text-monospace" href="/address/' + to_address + '">' + to_address + '</a>';
    document.querySelector('#review-sem-amount').innerHTML = String(sem_amount) + ' SEM';
  };
  xhr.open('GET', BACKEND_ORIGIN + '/wallet/nonce/0x' + from_address);
  xhr.send();
};

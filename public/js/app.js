window.prepare = function(body) {
  window.translate_dates(body);

  var delegates_table = body.querySelector('table#delegates');
  if (delegates_table) {
    window.render_favorites(delegates_table);
    window.sort_favorites(delegates_table);
    for (var i = 1, row; row = delegates_table.rows[i]; i += 1) {
      row.cells[0].addEventListener('click', window.toggle_favorite_event);
    }
    delegates_table.rows[0].cells[0].addEventListener('click', window.sort_favorites_event);
    var delegates_search = body.querySelector('input#search-delegate');
    if (delegates_search) {
      delegates_search.addEventListener('input', window.filter_delegates_event);
      delegates_search.form.addEventListener('reset', window.filter_delegates_event);
      delegates_search.form.addEventListener('submit', function(event) { event.preventDefault() });
      delegates_search.value = (localStorage.getItem('filter_delegates')||'');
      window.filter_delegates(body, delegates_search.value);
    }
  }

  if (!window.refresh_timers) window.refresh_timers = {};
  for (var i in window.refresh_timers) clearTimeout(window.refresh_timers[i]);
  window.auto_refresh_done_event = new Event('auto-refresh-done');
  var fragments = body.querySelectorAll('.auto-refresh').forEach(window.add_refresh_timer);
};

window.add_refresh_timer = function(element) {
  var timeout = parseFloat(element.getAttribute('data-refresh')) || 1.0;
  var fragment = element.getAttribute('data-fragment');
  clearTimeout(window.refresh_timers[fragment]);
  window.refresh_timers[fragment] = setTimeout(function() {
    window.refresh_fragment(fragment);
  }, timeout * 1000.0);
};

window.refresh_fragment = function(fragment) {
  clearTimeout(window.refresh_timers[fragment]);
  window.refresh_timers[fragment] = null;

  var xhr = new XMLHttpRequest();
  xhr.open('GET', '/fragment/'+fragment);
  xhr.onload = function() {
    if (xhr.status === 200) {
      var element = document.querySelector('[data-fragment="'+fragment+'"]');
      var parent = element.parentNode;
      element.outerHTML = xhr.responseText;
      window.add_refresh_timer(parent.lastChild);
      window.translate_dates(parent.lastChild);
      if (!xhr.responseText.match(/data-refresh="1.0"/)) {
        parent.dispatchEvent(window.auto_refresh_done_event);
      }
    }else{
      clearTimeout(window.refresh_timers[fragment]);
      window.refresh_timers[fragment] = setTimeout(function() {
        window.refresh_fragment(fragment);
      }, 1000.0);
    }
  };
  xhr.send();
};

window.translate_dates = function(body) {
  var times = body.getElementsByTagName('time');
  for (var i=0; i < times.length; i++) {
    if (times[i].className.split(/\s+/).indexOf('local') !== -1 && times[i].dateTime) {
      times[i].innerHTML = (new Date(times[i].dateTime)).toLocaleString(navigator.languages);
    }
  }
};

window.render_favorites = function(delegates_table) {
  var favorite_delegates = (localStorage.getItem('favorite_delegates')||'').split(',');
  var rows = delegates_table.getElementsByTagName('tr');
  for (var i = 1, row; row = rows[i]; i += 1) {
    row.className = row.className.replace(/\bfavorite\b/g, "");
    for (var j in favorite_delegates) {
      if (row.cells[2].innerText.trim() == favorite_delegates[j]) {
        row.className += ' favorite';
      }
    }
  }
}

window.toggle_favorite_event = function(event) {
  var favorite_delegates = (localStorage.getItem('favorite_delegates')||'').split(',');
  var delegate_name = event.target.parentElement.cells[2].innerText;
  var index = favorite_delegates.indexOf(delegate_name);
  if (index == -1) favorite_delegates.push(delegate_name);
  else favorite_delegates.splice(index, 1);
  localStorage.setItem('favorite_delegates', favorite_delegates.join(','));
  window.render_favorites(document.body);
  window.sort_favorites(document.body.querySelector('table#delegates'));
};

window.filter_delegates_event = function(event) {
  window.filter_delegates(document.body, event.type == 'reset' ? '' : event.target.value.trim());
};

window.filter_delegates = function(body, search) {
  var delegates_table = body.querySelector('table#delegates');
  var rows = delegates_table.getElementsByTagName('tr');
  localStorage.setItem('filter_delegates', search);
  for (var i = 1, row; row = rows[i]; i += 1) {
    row.className = row.className.replace(/\bd-none\b/g, "");
    if (event.type == 'reset') continue;
    var data_index = row.getAttribute('data-index');
    if (!data_index) {
      data_index = row.cells[2].innerText.trim() + ' ' + row.cells[6].innerText.trim();
      row.setAttribute('data-index', data_index);
    }
    if (!data_index.match(new RegExp(search.replace(/^\|+|\|+$/g,'').replace(/\|+/g, '|'), 'i'))) {
      row.className += ' d-none';
    }
  }
};

window.sort_favorites_event = function(event) {
  var sort_favorites = localStorage.getItem('sort_favorites') || 'off';
  sort_favorites = (sort_favorites == 'off' ? 'on' : 'off');
  localStorage.setItem('sort_favorites', sort_favorites);
  window.sort_favorites(document.body.querySelector('table#delegates'));
};

window.sort_favorites = function(delegates_table) {
  var rows = delegates_table.rows
  if (localStorage.getItem('sort_favorites') == 'on') {
    rows[0].className += ' favorite';
    for (var i = rows.length - 1, limit = 1; i >= limit;) {
      if (rows[i].className.match(/\bfavorite\b/)) {
        rows[i].parentNode.insertBefore(rows[i], rows[1]);
        limit += 1;
      }else{
        var rank = parseInt(rows[i].cells[1].innerText.trim());
        if (rank > i) {
          var place = rows[rows.length-1];
          while (place && parseInt(place.cells[1].innerText.trim()) > rank) place = place.previousSibling;
          rows[i].parentNode.insertBefore(rows[i], place.nextSibling);
        }
        i -= 1;
      }
    }
  }else{
    rows[0].className = rows[0].className.replace(/\bfavorite\b/g, '');
    for (var i = 1; i < rows.length; i += 1) {
      var rank = parseInt(rows[i].cells[1].innerText.trim());
      if (rank > i) {
        var place = rows[rows.length-1];
        while (place && parseInt(place.cells[1].innerText.trim()) > rank) place = place.previousSibling;
        rows[i].parentNode.insertBefore(rows[i], place.nextSibling);
        i -= 1;
      }
    }
  }
};

document.addEventListener("DOMContentLoaded", function() {
  window.prepare(document.body);
});

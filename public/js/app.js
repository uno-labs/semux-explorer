window.prepare = function(body) {
  var times = body.getElementsByTagName('time');
  for (var i=0; i < times.length; i++) {
    if (times[i].className.split(/\s+/).indexOf('local') !== -1 && times[i].dateTime) {
      times[i].innerHTML = (new Date(times[i].dateTime)).toLocaleString(navigator.languages);
    }
  }
  window.prepare_favorites(body);
};

window.render_favorites = function(delegates_table) {
  var favorite_delegates = (localStorage.getItem('favorite_delegates')||'').split(',');
  var rows = delegates_table.getElementsByTagName('tr');
  for (var i = 0, row; row = rows[i]; i += 1) {
    row.className = row.className.replace(/\bfavorite\b/g, "");
    for (var j in favorite_delegates) {
      if (row.cells[2].innerText.trim() == favorite_delegates[j]) {
        row.className += ' favorite';
      }
    }
  }
}

window.toggle_favorite = function(event) {
  var favorite_delegates = (localStorage.getItem('favorite_delegates')||'').split(',');
  var delegate_name = event.target.parentElement.cells[2].innerText;
  var index = favorite_delegates.indexOf(delegate_name);
  if (index == -1) favorite_delegates.push(delegate_name);
  else favorite_delegates.splice(index, 1);
  localStorage.setItem('favorite_delegates', favorite_delegates.join(','));
  window.render_favorites(document.body);
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
    if (!data_index.match(search.replace(/^\|+|\|+$/g,'').replace(/\|+/g, '|'))) {
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
  var rows = delegates_table.getElementsByTagName('tr');
  if (localStorage.getItem('sort_favorites') == 'on') {
    rows[0].cells[1].innerHTML = '♥';
    for (var i = rows.length - 1, limit = 1; i >= limit;) {
      if (rows[i].className.match(/\bfavorite\b/)) {
        rows[i].parentNode.insertBefore(rows[i], rows[1]);
        limit += 1;
      }else{
        i -= 1;
      }
    }
  }else{
    rows[0].cells[1].innerHTML = '▼';
    for (var i = 1; i < rows.length; i += 1) {
      var rank = parseInt(rows[i].cells[0].innerText.trim());
      if (rank > i) {
        var place = rows[rows.length-1];
        while (place && parseInt(place.cells[0].innerText.trim()) > rank) place = place.previousSibling;
        rows[i].parentNode.insertBefore(rows[i], place.nextSibling);
        i -= 1;
      }
    }
  }
};

window.prepare_favorites = function(body) {
  var delegates_table = body.querySelector('table#delegates');
  if (delegates_table) {
    window.render_favorites(delegates_table);
    window.sort_favorites(delegates_table);
    for (var i = 1, row; row = delegates_table.rows[i]; i += 1) {
      row.cells[0].addEventListener('click', window.toggle_favorite);
      row.cells[1].addEventListener('click', window.toggle_favorite);
    }
    delegates_table.rows[0].cells[0].addEventListener('click', window.sort_favorites_event);
    delegates_table.rows[0].cells[1].addEventListener('click', window.sort_favorites_event);
    var delegates_search = body.querySelector('input#search-delegate');
    if (delegates_search) {
      delegates_search.addEventListener('input', window.filter_delegates_event);
      delegates_search.form.addEventListener('reset', window.filter_delegates_event);
      delegates_search.form.addEventListener('submit', function(event) { event.preventDefault() });
      window.filter_delegates(body, delegates_search.value = (localStorage.getItem('filter_delegates')||''));
    }
  }
};

document.addEventListener("DOMContentLoaded", function() {
  window.prepare(document.body);
});

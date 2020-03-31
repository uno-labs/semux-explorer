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
  var favorite_delegates = (Cookies.get('favorite_delegates')||'').split(',');
  var rows = delegates_table.getElementsByTagName('tr');
  for (var i = 0, row; row = rows[i]; i += 1) {
    row.className = row.className.replace(/\bfavorite\b/g, "");
    for (var j in favorite_delegates) {
      if (row.cells[2].innerText.replace(/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g, '') == favorite_delegates[j]) {
        row.className += ' favorite';
      }
    }
  }
}

window.toggle_favorite = function(event) {
  var favorite_delegates = (Cookies.get('favorite_delegates')||'').split(',');
  var delegate_name = this.parentElement.cells[2].innerText;
  var index = favorite_delegates.indexOf(delegate_name);
  if (index == -1) favorite_delegates.push(delegate_name);
  else favorite_delegates.splice(index, 1);
  Cookies.set('favorite_delegates', favorite_delegates.join(','));
  window.render_favorites(document.body);
};

window.prepare_favorites = function(body) {
  var tables = body.getElementsByTagName('table');
  var delegates_table = false;
  for (var i=0; i < tables.length; i += 1) {
    if (tables[i].id == 'delegates') {
      delegates_table = tables[i];
      break;
    }
  }

  if (delegates_table) {
    window.render_favorites(delegates_table);
    for (var i = 0, row; row = delegates_table.rows[i]; i += 1) {
      row.cells[0].addEventListener('click', window.toggle_favorite, false);
      row.cells[1].addEventListener('click', window.toggle_favorite, false);
    }
  }
};

document.addEventListener("DOMContentLoaded", function() {
  window.prepare(document.body);
});

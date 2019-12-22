window.prepare = function(body) {
  var times = body.getElementsByTagName('time');
  for (var i=0; i < times.length; i++) {
    if (times[i].className.split(/\s+/).indexOf('local') !== -1 && times[i].dateTime) {
      times[i].innerHTML = (new Date(times[i].dateTime)).toLocaleString(navigator.languages);
    }
  }
};

document.addEventListener("DOMContentLoaded", function() {
  window.prepare(document.body);
});

// SPDX-License-Identifier: GPL-3.0-or-later
// The comparison table is written in HTML. On a phone it is shown as a stack of cards; this script
// writes each column's name on its cells for that layout. Without JS, the table scrolls in its box.
(function () {
  var table = document.querySelector("#matrix table");
  if (!table) return;
  var heads = Array.prototype.map.call(table.querySelectorAll("thead th"), function (th) {
    return th.textContent.trim();
  });
  Array.prototype.forEach.call(table.querySelectorAll("tbody tr:not(.group)"), function (r) {
    Array.prototype.forEach.call(r.children, function (td, i) {
      if (i > 0 && heads[i]) td.setAttribute("data-col", heads[i]);
    });
  });
  table.classList.add("stacked");
})();

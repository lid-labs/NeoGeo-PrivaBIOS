// SPDX-License-Identifier: GPL-3.0-or-later
// The comparison table is written in HTML; this script only adds what is computed from it: the
// tally per column, the two lists of differences, and the column names the phone layout shows on
// each cell. Computed from the table so that no hand-written figure drifts when a row changes.
// Without JS, the table stays whole and readable.
(function () {
  "use strict";

  var VERDICTS = ["yes", "part", "no", "unk"];
  var LABEL = { yes: "yes", part: "partly", no: "no or issue", unk: "not documented" };
  var GLYPH = { yes: "✓", part: "◐", no: "✕", unk: "?" };
  var COLUMNS = [["UniBIOS 4.0", 1], ["Sprixe BIOS", 2]];

  // Both directions: what one has and the other has not, or not entirely.
  var DIFF_RULES = [
    {
      title: "Sprixe BIOS yes, UniBIOS 4.0 not found or known issue",
      mark: "yes",
      test: function (u, s) { return s === "yes" && (u === "unk" || u === "no"); }
    },
    {
      title: "UniBIOS 4.0 yes, Sprixe BIOS partly or no",
      mark: "part",
      test: function (u, s) { return u === "yes" && (s === "part" || s === "no"); }
    }
  ];

  function rowSlug(topic) {
    return "row-" + topic.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  }

  // The verdict carried by a cell's `.v` badge, or null (the licence row has none).
  function cellVerdict(row, idx) {
    var td = row.children[idx];
    var v = td ? td.querySelector(".v") : null;
    if (!v) return null;
    for (var i = 0; i < VERDICTS.length; i++) if (v.classList.contains(VERDICTS[i])) return VERDICTS[i];
    return null;
  }

  function badge(v) {
    var span = document.createElement("span");
    span.className = "v " + v;
    var i = document.createElement("i");
    i.setAttribute("aria-hidden", "true");
    i.textContent = GLYPH[v];
    span.appendChild(i);
    return span;
  }

  function init() {
    var table = document.querySelector("#matrix table");
    var tallyBox = document.getElementById("tally");
    var diffsBox = document.getElementById("diffs");
    if (!table || !tallyBox || !diffsBox) return;

    var rows = Array.prototype.slice.call(table.querySelectorAll("tbody tr:not(.group)"));

    COLUMNS.forEach(function (col) {
      var n = { yes: 0, part: 0, no: 0, unk: 0 };
      rows.forEach(function (r) {
        var v = cellVerdict(r, col[1]);
        if (v !== null) n[v]++;
      });
      var box = document.createElement("div");
      var h = document.createElement("h3");
      h.textContent = col[0];
      var ul = document.createElement("ul");
      VERDICTS.forEach(function (v) {
        var li = document.createElement("li");
        var b = document.createElement("b");
        b.textContent = String(n[v]);
        li.appendChild(badge(v));
        li.appendChild(b);
        li.appendChild(document.createTextNode(LABEL[v]));
        ul.appendChild(li);
      });
      box.appendChild(h);
      box.appendChild(ul);
      tallyBox.appendChild(box);
    });

    DIFF_RULES.forEach(function (rule) {
      var box = document.createElement("div");
      var h = document.createElement("h3");
      var title = document.createElement("span");
      title.textContent = rule.title;
      h.appendChild(badge(rule.mark));
      h.appendChild(title);
      var ul = document.createElement("ul");
      rows.forEach(function (r) {
        if (!rule.test(cellVerdict(r, 1), cellVerdict(r, 2))) return;
        var topic = (r.children[0] && r.children[0].textContent || "").trim();
        r.id = rowSlug(topic);
        var li = document.createElement("li");
        var a = document.createElement("a");
        a.href = "#" + r.id;
        a.textContent = topic;
        li.appendChild(a);
        ul.appendChild(li);
      });
      box.appendChild(h);
      box.appendChild(ul);
      diffsBox.appendChild(box);
    });

    // The column name on each cell, for the stacked phone layout.
    var heads = Array.prototype.map.call(table.querySelectorAll("thead th"), function (th) {
      return th.textContent.trim();
    });
    rows.forEach(function (r) {
      Array.prototype.forEach.call(r.children, function (td, i) {
        if (i > 0 && heads[i]) td.setAttribute("data-col", heads[i]);
      });
    });
    table.classList.add("stacked");

    // The rows got their ids just now: follow a link that pointed at one of them.
    if (location.hash) {
      var target = document.getElementById(location.hash.slice(1));
      if (target) target.scrollIntoView();
    }
  }

  init();
})();

---
layout: default
title: search
permalink: /search/
lang: en
---

<style>
  .search-input {
    width: 100%; padding: 0.6rem 0.9rem;
    background: var(--bg-alt); border: 1px solid var(--border);
    border-radius: var(--radius); color: var(--fg);
    font-family: var(--font-mono); font-size: 0.9rem; margin-bottom: 1.5rem;
  }
  .search-input:focus { outline: none; border-color: var(--accent); }
  .search-input::placeholder { color: var(--fg-muted); }
  #search-results { list-style: none; margin: 0; }
  #search-results .post-entry { padding: 0.7rem 1rem; }
  #search-results .search-snippet {
    color: var(--fg-dim); font-size: 0.8rem; margin-top: 0.2rem;
  }
  #search-results mark {
    background: rgba(210, 153, 29, 0.35);
    color: var(--fg); padding: 0.05em 0.2em; border-radius: 2px;
  }
  .search-empty { color: var(--fg-muted); font-family: var(--font-mono); font-size: 0.85rem; }
</style>

<section class="post-list">
  <h2>search</h2>
  <input type="search" class="search-input" id="search-input" placeholder="search posts and projects..." autofocus>
  <ul id="search-results"></ul>
  <p id="search-empty" class="search-empty"></p>
</section>

<script src="https://cdn.jsdelivr.net/npm/lunr@2.3.9/lunr.min.js"></script>
<script>
(function() {
  var input = document.getElementById('search-input');
  var results = document.getElementById('search-results');
  var empty = document.getElementById('search-empty');
  var idx = null;
  var docs = {};

  fetch('{{ "/search.json" | relative_url }}')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      idx = lunr(function() {
        this.ref('url');
        this.field('title', { boost: 10 });
        this.field('tags', { boost: 5 });
        this.field('excerpt');
        this.field('content');
        data.forEach(function(doc) {
          docs[doc.url] = doc;
          this.add(doc);
        }, this);
      });
      // Search from URL param once index is ready
      var params = new URLSearchParams(window.location.search);
      var q = params.get('q');
      if (q) { input.value = q; doSearch(q); }
    });

  function doSearch(q) {
    results.innerHTML = '';
    if (!idx) { empty.textContent = 'index loading...'; return; }
    if (!q || q.length < 2) { empty.textContent = ''; return; }
    var matches = idx.search(q);
    if (matches.length === 0) { empty.textContent = 'no results for "' + q + '"'; return; }
    empty.textContent = '';
    matches.slice(0, 15).forEach(function(m) {
      var doc = docs[m.ref];
      var li = document.createElement('li');
      li.className = 'post-entry';
      li.style.cssText = 'flex-direction:column;align-items:flex-start;gap:0.2rem;';
      li.innerHTML = '<div><span style="color:var(--fg-muted);font-size:0.75rem;font-family:var(--font-mono);">'
        + doc.date + '</span> <a href="' + doc.url + '">' + doc.title + '</a></div>'
        + (doc.excerpt ? '<span class="search-snippet">' + doc.excerpt.substring(0, 200) + '</span>' : '');
      results.appendChild(li);
    });
  }

  input.addEventListener('input', function() { doSearch(this.value.trim()); });
})();
</script>

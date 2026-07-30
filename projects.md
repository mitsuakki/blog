---
layout: default
title: projects
permalink: /projects/
lang: en
---

<style>
  /* Filter rows */
  .filter-row {
    display: flex; gap: 0.35rem; margin-bottom: 0.5rem;
    align-items: baseline; flex-wrap: wrap;
  }
  .filter-row .filter-label {
    font-family: var(--font-mono); font-size: 0.7rem;
    color: var(--fg-muted); text-transform: uppercase;
    letter-spacing: 0.05em; margin-right: 0.3rem; min-width: 3.5rem;
  }
  .filter-row input { display: none; }
  .filter-row label {
    font-family: var(--font-mono); font-size: 0.72rem;
    padding: 0.15em 0.6em; border-radius: var(--radius);
    border: 1px solid var(--border); color: var(--fg-dim);
    cursor: pointer; user-select: none; white-space: nowrap;
    transition: background var(--ease), color var(--ease), border-color var(--ease);
  }
  .filter-row label:hover { color: var(--accent); border-color: var(--accent); }

  /* Active filter state */
  #org-all:checked    ~ .filter-row .for-org-all,
  #org-mitsuakki:checked ~ .filter-row .for-org-mitsuakki,
  #org-sarumc:checked ~ .filter-row .for-org-sarumc,
  #org-bedrock:checked ~ .filter-row .for-org-bedrock,
  #lang-all:checked    ~ .filter-row .for-lang-all,
  #lang-c-cpp:checked  ~ .filter-row .for-lang-c-cpp,
  #lang-go:checked     ~ .filter-row .for-lang-go,
  #lang-java:checked   ~ .filter-row .for-lang-java,
  #lang-php:checked    ~ .filter-row .for-lang-php,
  #lang-ts:checked     ~ .filter-row .for-lang-ts,
  #lang-shell:checked  ~ .filter-row .for-lang-shell,
  #lang-v:checked      ~ .filter-row .for-lang-v,
  #lang-other:checked  ~ .filter-row .for-lang-other,
  #stars-all:checked  ~ .filter-row .for-stars-all,
  #stars-0:checked    ~ .filter-row .for-stars-0,
  #stars-1-5:checked  ~ .filter-row .for-stars-1-5,
  #stars-5-20:checked ~ .filter-row .for-stars-5-20,
  #stars-20:checked   ~ .filter-row .for-stars-20,
  #page-1:checked     ~ .pager .for-page-1,
  #page-2:checked     ~ .pager .for-page-2,
  #page-3:checked     ~ .pager .for-page-3,
  #page-4:checked     ~ .pager .for-page-4 {
    background: var(--accent); color: #fff; border-color: var(--accent);
  }

  /* Filter logic with :has() */
  .project-item { display: flex; }

  section:has(#org-mitsuakki:checked) .project-item:not([data-org="mitsuakki"]) { display: none; }
  section:has(#org-sarumc:checked)    .project-item:not([data-org="sarumc"])    { display: none; }
  section:has(#org-bedrock:checked)   .project-item:not([data-org="bedrock-v"]) { display: none; }

  section:has(#lang-c-cpp:checked)   .project-item:not([data-lang="C/C++"])    { display: none; }
  section:has(#lang-go:checked)      .project-item:not([data-lang="Go"])         { display: none; }
  section:has(#lang-java:checked)    .project-item:not([data-lang="Java"])       { display: none; }
  section:has(#lang-php:checked)     .project-item:not([data-lang="PHP"])        { display: none; }
  section:has(#lang-ts:checked)      .project-item:not([data-lang="TypeScript"]) { display: none; }
  section:has(#lang-shell:checked)   .project-item:not([data-lang="Shell"])      { display: none; }
  section:has(#lang-v:checked)       .project-item:not([data-lang="V"])          { display: none; }
  section:has(#lang-other:checked)   .project-item:not([data-lang="other"])      { display: none; }

  section:has(#stars-0:checked)    .project-item:not([data-stars="0"])       { display: none; }
  section:has(#stars-1-5:checked)  .project-item:not([data-stars="1-5"])     { display: none; }
  section:has(#stars-5-20:checked) .project-item:not([data-stars="5-20"])    { display: none; }
  section:has(#stars-20:checked)   .project-item:not([data-stars="20+"])     { display: none; }

  /* Pagination: show only current page group */
  section:has(#page-1:checked) .page-group:not([data-page="1"]) { display: none; }
  section:has(#page-2:checked) .page-group:not([data-page="2"]) { display: none; }
  section:has(#page-3:checked) .page-group:not([data-page="3"]) { display: none; }
  section:has(#page-4:checked) .page-group:not([data-page="4"]) { display: none; }

  /* Hide pager + show all items when filtering */
  section:has(#org-mitsuakki:checked) .pager,
  section:has(#org-sarumc:checked) .pager,
  section:has(#org-bedrock:checked) .pager,
  section:has(#lang-c-cpp:checked) .pager,
  section:has(#lang-go:checked) .pager,
  section:has(#lang-java:checked) .pager,
  section:has(#lang-php:checked) .pager,
  section:has(#lang-ts:checked) .pager,
  section:has(#lang-shell:checked) .pager,
  section:has(#lang-v:checked) .pager,
  section:has(#lang-other:checked) .pager,
  section:has(#stars-0:checked) .pager,
  section:has(#stars-1-5:checked) .pager,
  section:has(#stars-5-20:checked) .pager,
  section:has(#stars-20:checked) .pager { display: none; }

  section:has(#org-mitsuakki:checked) .page-group,
  section:has(#org-sarumc:checked) .page-group,
  section:has(#org-bedrock:checked) .page-group,
  section:has(#lang-c-cpp:checked) .page-group,
  section:has(#lang-go:checked) .page-group,
  section:has(#lang-java:checked) .page-group,
  section:has(#lang-php:checked) .page-group,
  section:has(#lang-ts:checked) .page-group,
  section:has(#lang-shell:checked) .page-group,
  section:has(#lang-v:checked) .page-group,
  section:has(#lang-other:checked) .page-group,
  section:has(#stars-0:checked) .page-group,
  section:has(#stars-1-5:checked) .page-group,
  section:has(#stars-5-20:checked) .page-group,
  section:has(#stars-20:checked) .page-group { display: block !important; }

  /* Pager */
  .pager {
    display: flex; gap: 0.35rem; justify-content: center;
    margin-top: 1.5rem; font-family: var(--font-mono);
  }
  .pager input { display: none; }
  .pager label {
    padding: 0.25em 0.7em; border-radius: var(--radius);
    border: 1px solid var(--border); color: var(--fg-dim);
    cursor: pointer; user-select: none; font-size: 0.8rem;
    transition: background var(--ease), color var(--ease);
  }
  .pager label:hover { color: var(--accent); border-color: var(--accent); }

  #projects-root ul { list-style: none; }
  #projects-root .page-group { margin: 0; }
  .project-search {
    width: 100%; padding: 0.4rem 0.7rem;
    background: var(--bg-alt); border: 1px solid var(--border);
    border-radius: var(--radius); color: var(--fg);
    font-family: var(--font-mono); font-size: 0.8rem;
    margin-bottom: 0.75rem;
  }
  .project-search:focus { outline: none; border-color: var(--accent); }
  .project-search::placeholder { color: var(--fg-muted); }
</style>

<section class="post-list" id="projects-root">
  <h2>projects</h2>

  {% assign project_list = site.projects | sort: "stars" | reverse %}
  {% if project_list.size == 0 %}
  <p style="color: var(--fg-muted); font-family: var(--font-mono); font-size: 0.85rem;">
    No projects synced yet. Run the sync script to pull READMEs from GitHub.
  </p>
  {% else %}

  {% assign per_page = 5 %}
  {% assign total_pages = project_list.size | minus: 1 | divided_by: per_page | plus: 1 %}

  <!-- Search -->
  <input type="search" class="project-search" id="project-search" placeholder="search projects...">

<!-- Filter radios: must be direct siblings of .filter-row for ~ to work -->
  <input type="radio" name="org"   id="org-all"   checked style="display:none">
  <input type="radio" name="org"   id="org-mitsuakki" style="display:none">
  <input type="radio" name="org"   id="org-sarumc" style="display:none">
  <input type="radio" name="org"   id="org-bedrock" style="display:none">

  <input type="radio" name="lang"  id="lang-all"  checked style="display:none">
  <input type="radio" name="lang"  id="lang-c-cpp" style="display:none">
  <input type="radio" name="lang"  id="lang-go" style="display:none">
  <input type="radio" name="lang"  id="lang-java" style="display:none">
  <input type="radio" name="lang"  id="lang-php" style="display:none">
  <input type="radio" name="lang"  id="lang-ts" style="display:none">
  <input type="radio" name="lang"  id="lang-shell" style="display:none">
  <input type="radio" name="lang"  id="lang-v" style="display:none">
  <input type="radio" name="lang"  id="lang-other" style="display:none">

  <input type="radio" name="stars" id="stars-all" checked style="display:none">
  <input type="radio" name="stars" id="stars-0" style="display:none">
  <input type="radio" name="stars" id="stars-1-5" style="display:none">
  <input type="radio" name="stars" id="stars-5-20" style="display:none">
  <input type="radio" name="stars" id="stars-20" style="display:none">

  <input type="radio" name="page"  id="page-1" checked style="display:none">
  {% for p in (2..total_pages) %}
  <input type="radio" name="page"  id="page-{{ p }}" style="display:none">
  {% endfor %}

  <div class="filter-row">
    <span class="filter-label">source</span>
    <label class="for-org-all" for="org-all">all</label>
    <label class="for-org-mitsuakki" for="org-mitsuakki">mitsuakki</label>
    <label class="for-org-sarumc" for="org-sarumc">sarumc</label>
    <label class="for-org-bedrock" for="org-bedrock">bedrock-v</label>
  </div>

  <div class="filter-row">
    <span class="filter-label">language</span>
    <label class="for-lang-all" for="lang-all">all</label>
    <label class="for-lang-c-cpp" for="lang-c-cpp">C/C++</label>
    <label class="for-lang-go" for="lang-go">Go</label>
    <label class="for-lang-java" for="lang-java">Java</label>
    <label class="for-lang-php" for="lang-php">PHP</label>
    <label class="for-lang-ts" for="lang-ts">TS</label>
    <label class="for-lang-shell" for="lang-shell">Shell</label>
    <label class="for-lang-v" for="lang-v">V</label>
    <label class="for-lang-other" for="lang-other">other</label>
  </div>

  <div class="filter-row" style="margin-bottom: 1.25rem;">
    <span class="filter-label">stars</span>
    <label class="for-stars-all" for="stars-all">all</label>
    <label class="for-stars-0" for="stars-0">0</label>
    <label class="for-stars-1-5" for="stars-1-5">1-5</label>
    <label class="for-stars-5-20" for="stars-5-20">5-20</label>
    <label class="for-stars-20" for="stars-20">20+</label>
  </div>

  <!-- Project list with page groups -->
  {% for page_num in (1..total_pages) %}
  <ul class="page-group" data-page="{{ page_num }}">
  {% for proj in project_list %}
    {% assign item_page = forloop.index0 | divided_by: per_page | plus: 1 %}
    {% if item_page != page_num %}{% continue %}{% endif %}

    {% assign org = proj.repo | split: "/" | first %}
    {% assign stars = proj.stars | plus: 0 %}
    {% if stars == 0 %}
      {% assign star_range = "0" %}
    {% elsif stars <= 5 %}
      {% assign star_range = "1-5" %}
    {% elsif stars <= 20 %}
      {% assign star_range = "5-20" %}
    {% else %}
      {% assign star_range = "20+" %}
    {% endif %}

    {% comment %} Map language to filter key {% endcomment %}
    {% assign lang_key = "other" %}
    {% if proj.language == "C" or proj.language == "C++" %}{% assign lang_key = "C/C++" %}
    {% elsif proj.language == "Go" %}{% assign lang_key = "Go" %}
    {% elsif proj.language == "Java" %}{% assign lang_key = "Java" %}
    {% elsif proj.language == "PHP" %}{% assign lang_key = "PHP" %}
    {% elsif proj.language == "TypeScript" %}{% assign lang_key = "TypeScript" %}
    {% elsif proj.language == "Shell" %}{% assign lang_key = "Shell" %}
    {% elsif proj.language == "V" %}{% assign lang_key = "V" %}
    {% endif %}

    <li class="project-item post-entry"
        data-org="{{ org }}"
        data-lang="{{ lang_key }}"
        data-stars="{{ star_range }}"
        style="flex-direction: column; align-items: flex-start; gap: 0.3rem;">
      <div style="display: flex; align-items: baseline; gap: 0.75rem; width: 100%;">
        <a href="{{ proj.url | relative_url }}" style="font-weight: 600;">{{ proj.title }}</a>
        {% unless proj.archived %}
        {% if proj.sync_status == "new" %}
        <span class="badge badge-green">NEW</span>
        {% elsif proj.sync_status == "updated" %}
        <span class="badge badge-yellow">UPDATED</span>
        {% endif %}
        {% endunless %}
        {% if proj.archived %}
        <span class="badge badge-yellow">ARCHIVED</span>
        {% endif %}
        <span style="color: var(--fg-muted); font-size: 0.75rem; margin-left: auto;">
          &#9733; {{ proj.stars }}
        </span>
      </div>
      {% if proj.description %}
      <p style="color: var(--fg-dim); font-size: 0.82rem; margin: 0; line-height: 1.4;">
        {{ proj.description | truncate: 140 }}
      </p>
      {% endif %}
      <div style="display: flex; gap: 0.3rem; flex-wrap: wrap;">
        {% if proj.language %}
        <code class="post-tag">{{ proj.language }}</code>
        {% endif %}
        {% for topic in proj.topics limit: 3 %}
        <code class="post-tag" style="background: var(--bg-overlay); color: var(--fg-dim);">{{ topic }}</code>
        {% endfor %}
      </div>
    </li>
  {% endfor %}
  </ul>
  {% endfor %}

  {% if total_pages > 1 %}
  <div class="pager">
    {% for p in (1..total_pages) %}
    <label class="for-page-{{ p }}" for="page-{{ p }}">{{ p }}</label>
    {% endfor %}
  </div>
  {% endif %}

  {% endif %}
</section>

<script>
(function() {
  var search = document.getElementById('project-search');
  if (!search) return;

  search.addEventListener('input', function() {
    var q = this.value.toLowerCase();
    var items = document.querySelectorAll('#projects-root .project-item');
    var groups = document.querySelectorAll('#projects-root .page-group');

    if (q) {
      // Show all page groups so search can find items on any page
      groups.forEach(function(g) { g.style.display = ''; });
      // Filter items by text
      items.forEach(function(el) {
        el.style.display = el.textContent.toLowerCase().indexOf(q) !== -1 ? 'flex' : 'none';
      });
    } else {
      // Reset: remove inline styles, let CSS rules handle filtering
      items.forEach(function(el) { el.style.display = ''; });
      groups.forEach(function(g) { g.style.display = ''; });
    }
  });
})();
</script>

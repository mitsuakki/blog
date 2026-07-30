---
layout: project
title: "blog"
repo: "mitsuakki/blog"
repo_url: "https://github.com/mitsuakki/blog"
description: "My personal blog where i write reverse and software engineering posts"
language: "Ruby"
stars: 1
updated: "2026-07-20T08:06:08Z"
topics: [blog, gh-pages, reverse-engineering, ruby-gem]
readme_sha: "ed640cd07339f8a661eba5478af4a49ef3bfbec5"
sync_status: "new"
archived: false
lang: en
---



Reverse engineering blog. Malware analysis, binary RE, exploit dev. No fluff.

## Run locally

```bash
bundle install
bundle exec jekyll serve
```

## Structure

```
.
├── _config.yml          # Jekyll config
├── _layouts/            # Page layouts
├── _posts/              # Blog posts (YYYY-MM-DD-slug.md)
├── _includes/           # Reusable partials
├── assets/css/          # Styles
├── index.html           # Home
├── about.md             # About page
└── 404.html             # Segfault page
```

## Deploy

Push to `main` or `gh-pages` branch. GitHub Pages builds it automatically.

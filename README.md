# bits & bytes

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

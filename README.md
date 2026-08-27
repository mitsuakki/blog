# mitsuakki's blog

Reverse engineering blog. Malware analysis, binary RE, exploit dev. No fluff.
Static site built with Jekyll, hosted on GitHub Pages.

## Run locally

```bash
bundle install
bundle exec jekyll serve
```

Site is served at `http://localhost:4000/blog/`.

## Theme

The front end is a single stylesheet (`assets/css/style.scss`) driven by CSS
custom properties defined in `:root`. To restyle, tweak the variables there
rather than hunting through selectors:

- `--bg`, `--fg`, `--accent`, ... — color palette
- `--font-display`, `--font-hand`, `--font-serif`, `--font-mono` — typography
- `--sketch-radius`, `--sketch-radius-sm` — hand-drawn border wobble
- `--sidebar-width`, `--content-width` — layout sizing

The left sidebar (avatar, nav, social links) lives in `_includes/sidebar.html`
and is pulled into every page via `_layouts/default.html`. Below 860px it
collapses into a horizontal bar.

## Deploy

Push to `main` or `gh-pages` branch. GitHub Pages builds it automatically.

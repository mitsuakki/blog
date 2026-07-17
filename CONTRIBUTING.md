# Contributing to bits & bytes

Thanks for wanting to contribute. This is a personal reverse engineering blog,
but I welcome corrections, translations, and guest posts if you know the
subject.

## Ways to contribute

### 1. Fix a mistake

Found a technical error? Wrong instruction, broken link, outdated info?
Open a bug report issue or a PR. These get merged fast.

### 2. Propose a guest post

You have RE knowledge and want to share. Use the "New post proposal"
issue template. I'll review and we'll iterate.

Read a few existing posts first to match the tone: first person, technical,
code heavy, no fluff. French and English both welcome.

### 3. Improve French translations

I write both languages but translations are never perfect. If you spot
awkward phrasing or anglicisms in the French versions, PR welcome.

### 4. Report a security issue

**Do not open a public issue.** See [SECURITY.md](SECURITY.md).

## Pull request process

1. Fork the repo, create a branch.
2. Make your changes. Keep scope tight. One thing per PR.
3. If adding a post, include both `_posts/<slug>-en.md` and `_posts/<slug>-fr.md`,
   or at least one with `lang:` frontmatter set.
4. Run locally if you can: `bundle exec jekyll serve --future`.
5. Open a PR against `main`. Fill the template.
6. CI must pass: build, link check, spell check, lint.

## Post conventions

- File: `YYYY-MM-DD-slug.md`
- Frontmatter: `layout: post`, `title`, `tags`, `lang: en` or `lang: fr`
- French posts add `permalink: /fr/<slug>/`
- No em dashes anywhere in visible content
- First person. Real opinions. Show mistakes, not just success.
- Code blocks use `{% highlight lang %}` with a real language tag
- Test every code snippet in a post before publishing

## Code of conduct

Don't be a jerk. If you're here to argue about tools, find somewhere else.
Technical debate is fine. Gatekeeping is not.

## License

By contributing you agree your content goes under the same license as the
blog (see repo license file). I credit all contributors on the post itself.

# Security policy

## Reporting a vulnerability

If you find a security issue in this blog's tooling, CI/CD, or infrastructure,
do **not** open a public issue.

Email: **alexis.dauge@ensc.fr**
PGP key: [github.com/mitsuakki.gpg](https://github.com/mitsuakki.gpg)

Expect a response within 48 hours. Please give me reasonable time to fix before
disclosing anything publicly.

## Scope

This policy covers:

- CI/CD pipeline weaknesses (workflow injection, secret leaks)
- Dependabot alerts on outdated gems with known CVEs
- Cross-site scripting (XSS) via Jekyll templates or user content
- Supply chain issues in Ruby gems or GitHub Actions

## Out of scope

- Issues already caught by `github/codeql-action` or Dependabot
- Missing HTTP security headers (GitHub Pages controls the server, we can't
  set `Content-Security-Policy` or `X-Frame-Options` ourselves)
- Typos, broken links, or content errors (open a normal issue)

## Static site note

This is a static Jekyll blog hosted on GitHub Pages. No server-side code.
No database. No authentication. Attack surface is basically zero.

What matters:

1. **CI/CD integrity.** Review workflow changes in PRs. Never merge a PR
   that modifies `.github/workflows/` without reading the diff.
2. **Gem supply chain.** Dependabot watches `Gemfile.lock`. Review its PRs.
3. **PR content.** Anyone can propose a post via PR. Review before merge
   so no malicious content lands on the site.

## Supported versions

Only the `main` branch is supported. The deployed site always reflects the
latest commit on `main`.

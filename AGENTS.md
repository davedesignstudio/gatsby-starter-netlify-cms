# AGENTS.md

## Cursor Cloud specific instructions

### What this repo actually is
Despite the `README.md`, `package.json`, `package-lock.json`, `yarn.lock`, and the misplaced
`js/gatsby-config.js`/`js/gatsby-node.js` (all Gatsby/Netlify-CMS leftovers), the buildable product
is a **Jekyll static site** (the "Devoll" theme). The Jekyll signals are authoritative:
`_config.yml`, `_layouts/`, `_includes/`, `_posts/`, `_data/`, `_sass/`, and `*.html` pages with
Liquid front matter. There is no root `gatsby-config.js` and no `src/` dir, so `npm run build`
(`gatsby build`) does not work — ignore the Node/Gatsby tooling.

### Toolchain
- Ruby 3.2 + Jekyll 4.x (installed globally via `gem`, no Gemfile in this repo).
- Node is present but not needed for the Jekyll build.

### Run / build (standard commands)
- Dev server (use this): `jekyll serve --host 0.0.0.0 --port 4000 --livereload`
  - Serves at `http://localhost:4000`, auto-regenerates on file changes, livereload triggers a
    browser refresh. Editing `_config.yml` is the exception — it requires restarting the server.
- One-off build: `jekyll build` (outputs to `_site/`).

### Non-obvious caveats
- `jekyll build`/`serve` print hundreds of Sass **deprecation warnings** from the old
  `_sass/foundation/**` files under modern `sass-embedded`. These are harmless — the build still
  succeeds (exit 0) and pages render.
- Pagination is half-configured: `_config.yml` sets `paginate`, but `jekyll-paginate` is not listed
  under `plugins:`. Jekyll 4 prints "you appear to have pagination turned on, but you haven't
  included the `jekyll-paginate` gem" and the `blog/` page renders without a post list. This is a
  pre-existing repo issue (not an environment problem); fix it in `_config.yml` if blog pagination
  is needed.
- `_site/` is generated build output (git-ignored); never commit it.

### Lint / test
There is no meaningful lint or test suite for the Jekyll site. The `package.json` `test` script is a
Gatsby-leftover stub (`exit 1`) and `format`/prettier target Gatsby `src/**` files that don't exist —
do not rely on them.

---
name: dphilhower-studio-site
description: Build and maintain the D Philhower Studio Jekyll site with zoom-format layout, brand colors, and service sections. Use when working on dphilhowerstudio.com, the zoom homepage, graphic design studio layout, Jekyll preview, or site smoke tests.
---

# D Philhower Studio Site

## Project

Graphic design business site for **dphilhowerstudio.com** using a full-viewport **zoom-format layout** (snap-scroll sections, scale-in transitions, tile-grid services).

## Brand colors

Apply exactly:

| Token | Value | Use |
|-------|-------|-----|
| `--bg-deep` | `#000000` | Page background |
| `--text-primary` | `#ffffff` | Interior/body text |
| `--accent` | `#1a4d8f` | Blue headings, links, buttons, highlights |
| `--accent-bright` | `#2a6cb8` | Lighter blue emphasis |
| `--stroke` / `--border` | `rgba(114, 47, 55, 0.2)` | Maroon strokes at 0.2 opacity |
| `--sub-color` | `#722f37` | Maroon sub-color reference |

Rules:
- Black background, white inside text
- Blue for accent text and primary buttons (white text on blue buttons)
- Maroon at 0.2 opacity for borders/strokes

## Services (always include)

1. Logo Design
2. Poster Design
3. Print Media
4. Website Design

## Key files

```
_layouts/zoom.html          # Minimal layout (nav + content + JS)
index.html                  # Homepage (layout: zoom)
css/dphilhower-zoom.css     # All zoom layout styles
javascripts/dphilhower-zoom.js
_config.yml                 # Site title, url, description
_data/nav.yml               # Section nav anchors
scripts/test.js             # npm test smoke checks
Gemfile                     # Jekyll dependencies
```

Do not revert `index.html` to the old Devoll slider template unless explicitly asked.

## Layout sections

Homepage sections in order:

1. `#home` — Hero (D Philhower Studio, dphilhowerstudio.com)
2. `#services` — 2×2 zoom tile grid
3. `#about` — Studio copy + stat cards
4. `#work` — Portfolio grid (use `images/@stock/work-*.jpg`)
5. `#contact` — CTA + `hello@dphilhowerstudio.com`

## Commands

```bash
# Smoke tests (layout files, colors, services, images)
npm test

# Local Jekyll preview
bundle install
bundle exec jekyll serve
# → http://localhost:4000
```

Ruby: use project `Gemfile` (Jekyll ~> 4.3). If Ruby is missing, install via mise (`ruby@3.2`) before `bundle install`.

## Editing checklist

- [ ] Color tokens in `css/dphilhower-zoom.css` match brand table above
- [ ] All four services present in `index.html`
- [ ] `index.html` front matter uses `layout: zoom`
- [ ] Portfolio image paths exist under `images/@stock/`
- [ ] `npm test` passes
- [ ] Jekyll builds without layout errors (`bundle exec jekyll build`)

## Scope discipline

- Change only zoom-layout files unless the user asks for broader refactors
- Match existing naming: `zoom-*` classes, BEM-style modifiers
- Keep `_layouts/zoom.html` free of legacy Foundation header/footer

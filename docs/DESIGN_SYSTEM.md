# Design system

Pure CSS, custom properties, BEM. No Tailwind, no Bootstrap, no bundler.

## Tokens (`app/assets/stylesheets/base/variables.css`)

`:root` is the dark theme; `[data-theme="light"]` overrides the same names. The theme is set on `<html data-theme="dark">` by the layouts and toggled by `theme_controller.js` (persisted in localStorage); `prefers-color-scheme` is used only for the `theme-color` metas.

- Surfaces `--color-bg-{primary,secondary,tertiary,hover,active}`; text `--color-text-{primary,secondary,tertiary,inverse}`; borders `--color-border-{default,subtle,strong}`
- Accent `--color-accent{,-hover,-muted,-text}` (calm blue), secondary `--color-secondary{,-hover,-muted}` (warm amber)
- Status `--color-{success,warning,danger,info}{,-bg}`
- Shadows `--shadow-{sm,md,lg,glow}`; radius `--radius-{sm,md,lg,xl,full}`; transitions `--transition-{fast 120ms,base 200ms,slow 350ms}`
- Spacing `--space-{1,2,3,4,5,6,8,10,12,16,20}` (4 px steps on an 8 px base)
- Type `--font-{sans,serif,mono}`, scale `--text-{xs..5xl}`, `--leading-*`, `--tracking-*`
- Z-index `--z-{dropdown 100,sticky 200,modal-backdrop 300,modal 400,toast 500}`; containers `--container-{sm 640,md 768,lg 1024,xl 1200}`

Fonts (placeholders, swap in one place): Inter (UI, `--font-sans`), Fraunces (display, `--font-serif`, landing headlines only), JetBrains Mono (numbers, `--font-mono`). Loaded from Google Fonts with two `preconnect` links and one `css2` stylesheet per layout; CSP allows `fonts.googleapis.com` and `fonts.gstatic.com` only.

## Files and load order

```
base/        variables, reset, typography, global (focus ring, forced-colors, the one global reduced-motion rule, print)
components/  button, card, badge, input, nav, modal, toast, dropdown, avatar, skeleton, language-toggle, tab-bar, public-footer
layouts/     container, grid, stack (.stack, .cluster)
pages/       landing, auth, app
utilities/   spacing (mt-*, mb-*, p-*), visibility (.sr-only, .hidden, .hidden-mobile, .hidden-desktop)
native.css   loaded only when hotwire_native_app?: hides web chrome the shells replace
application.css  empty on purpose
```

Each layout links its files with one `stylesheet_link_tag "<path>", "data-turbo-track": "reload"` per file in this order: base, components, layouts, page, utilities, native, then `javascript_importmap_tags`. `public.html.erb` is the informational site and the auth pages; `application.html.erb` is the authenticated area.

## Rules

- BEM: `.block__element--modifier`; layout primitives `.stack`, `.cluster`, `.grid`, `.container`.
- Mobile first: base styles for phones, `@media (min-width: 641px | 769px | 1025px)` upward. Never `max-width` queries.
- Tokens only: no raw colours, sizes or fonts in components or pages.
- Animate `transform` and `opacity` only; enter animations with `@starting-style`; respect `prefers-reduced-motion` (the global rule in `base/global.css` neutralises animations; pages add content fallbacks, e.g. the hero copy is visible without the scene).
- Focus: `:focus-visible` ring from `base/global.css`, with a `forced-colors: active` fallback.
- Touch targets 48 px; icon-only buttons carry `aria-label`.
- Every string through `t()`; `spec/i18n/core_copy_rules_spec.rb` fails on visible text outside `t()`, hardcoded brand names and em dashes.

## Components

`.btn` (`--primary --secondary --ghost --accent --danger --sm --lg --full`), `.card` (`__header __body __footer --interactive --nested`), `.badge` (`--info --success --warning --danger --accent --secondary`), `.input`, `.input-group` (`__label __hint __error`), `.select`, `dialog.dialog` (`__header __body __footer`, native `<dialog>`), `.toast` (`--success --error --info --warning`, `toast_controller.js`), `.dropdown` (`--open`, `dropdown_controller.js`), `.avatar` (`--sm --md --lg --xl`), `.skeleton`, `.language-toggle`, `.tab-bar`, `.public-footer`, `.nav`.

## The hero scene (`hero_scene_controller.js`)

The landing hero mounts `data-controller="hero-scene"` with a `canvas` target (`.landing__hero-bg`: fixed, inset 0, `z-index: -1`, `pointer-events: none`) and a `heroContent` target whose hidden/visible classes the view passes as `data-hero-scene-hidden-class` / `-visible-class`. Lifecycle: reduced motion reveals the copy and never imports Three; otherwise `await import("three")` (vendored r169, `preload: false`), bail if disconnected meanwhile; `initScene` in try/catch (no WebGL: warn and reveal); renderer capped at 2560x1440 with CSS at 100%, pixel ratio 1.5 on mobile, 1.75 on coarse pointers, 2 otherwise; resize and orientation debounced through rAF; clock paused on `visibilitychange`; palette follows `html[data-theme]` through a `MutationObserver`; `disconnect()` removes every listener, disposes every geometry and material, disposes the renderer and removes the canvas. The geometry (a point sphere and three orbit rings) is the site's one signature; every visual element has a purpose, no glow for its own sake.

## Stimulus controllers

`theme`, `dialog`, `toast`, `dropdown`, `clipboard`, `web_share`, `scroll_reveal`, `landing_nav`, `hero_scene`, `passkey`, `web_push`, `bridge/{share,notification_token,push_permission}`. Rules and templates: `.claude/commands/stimulus.md`.

## PWA

`PwaController` serves `pwa/manifest.json.erb` (`application/manifest+json`) and `pwa/service-worker.js` (push and notificationclick only, no offline cache). Icons: `public/icon.svg` (source) and `public/icon.png` (512, any + maskable, rendered from the SVG with `qlmanage -t -s 512`).

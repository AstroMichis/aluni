# Design system

Pure CSS, custom properties, BEM. No Tailwind, no Bootstrap, no bundler.

## Tokens (`app/assets/stylesheets/base/variables.css`)

`:root` is the dark theme; `[data-theme="light"]` overrides the same names. Brand palette: deep green `#173D2D` (main), gold `#B69A5B` (secondary), slate `#26364A` (accessories), cream `#F1EBDD` (subtle accent), olive `#6B7650` (decoration). The same values live in the `theme-color` metas, `pwa/manifest.json.erb`, `config/native_app.yml` and the native shells' theme files. The theme is set on `<html data-theme="dark">` by the layouts and toggled by `theme_controller.js` (persisted in localStorage); `prefers-color-scheme` is used only for the `theme-color` metas.

- Surfaces `--color-bg-{primary,secondary,tertiary,hover,active}`; text `--color-text-{primary,secondary,tertiary,inverse}`; borders `--color-border-{default,subtle,strong}`
- Accent `--color-accent{,-hover,-muted,-text}` (brand gold in dark, deep green in light; gold on `bg-secondary` is 4.46:1, so text on cards uses `-text`), secondary `--color-secondary{,-hover,-muted}` (olive, decorative fills only, never text), chrome `--color-chrome` (slate, device bezels and rails)
- Status `--color-{success,warning,danger,info}{,-bg}`
- Shadows `--shadow-{sm,md,lg,glow}`; radius `--radius-{sm,md,lg,xl,full}`; transitions `--transition-{fast 120ms,base 200ms,slow 350ms}`
- Spacing `--space-{1,2,3,4,5,6,8,10,12,16,20}` (4 px steps on an 8 px base)
- Type `--font-{sans,serif,mono}`, scale `--text-{xs..5xl}`, `--leading-*`, `--tracking-*`
- Z-index `--z-{dropdown 100,sticky 200,modal-backdrop 300,modal 400,toast 500}`; containers `--container-{sm 640,md 768,lg 1024,xl 1200}`

Fonts (placeholders, swap in one place): Inter (UI, `--font-sans`), Fraunces (display, `--font-serif`, landing headlines only), JetBrains Mono (numbers, `--font-mono`). Loaded from Google Fonts with two `preconnect` links and one `css2` stylesheet per layout; CSP allows `fonts.googleapis.com` and `fonts.gstatic.com` only.

## Files and load order

```
base/        variables, reset, typography, global (focus ring, forced-colors, the one global reduced-motion rule, print)
components/  button, card, badge, input, nav, modal, toast, dropdown, avatar, skeleton, language-toggle, tab-bar, public-footer, phone-frame, store-button
layouts/     container, grid, stack (.stack, .cluster)
pages/       landing, auth, menu, app
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

`.btn` (`--primary --secondary --ghost --accent --danger --sm --lg --full`), `.card` (`__header __body __footer --interactive --nested`), `.badge` (`--info --success --warning --danger --accent --secondary`), `.input`, `.input-group` (`__label __hint __error`), `.select`, `dialog.dialog` (`__header __body __footer`, native `<dialog>`), `.toast` (`--success --error --info --warning`, `toast_controller.js`), `.dropdown` (`--open`, `dropdown_controller.js`), `.avatar` (`--sm --md --lg --xl`), `.skeleton`, `.language-toggle`, `.tab-bar`, `.public-footer`, `.nav`, `.store-button` (`--soon`, `__glyph __text __hint __name __badge`; `shared/_store_buttons`), `.phone-frame` (`__bar __pill __content __map __pin __row __meter __chip __option __alert`; a simulated phone for the landing tour that animates from `--reveal-opacity`, `--reveal-shift` and `--reveal-scale`), `.tour-step` (`--idle --active`, `__copy __device __next`) and `.tour-nav` (`__dot`).

## The hero scene (`hero_scene_controller.js`)

The landing hero mounts `data-controller="hero-scene"` with a `canvas` target (`.landing__hero-bg`: fixed, inset 0, `z-index: -1`, `pointer-events: none`, a CSS vignette in `::after`) and a `heroContent` target whose hidden/visible classes the view passes as `data-hero-scene-hidden-class` / `-visible-class`; `-fallback-class` (`.landing__hero-bg--static`) is a CSS-only field backdrop the controller applies when the scene cannot run. The scene is rolling crop fields: a `PlaneGeometry` (120 or 60 segments) displaced by deterministic value noise with one vertex colour per 5x5 field patch and hedgerows between, one `InstancedMesh` of cone plants (about 6000 on desktop, 2000 on phones) coloured per crop, and a pin (sphere, needle, pulsing ring) on the centre field. Budget: about 60k triangles and 5 draw calls on desktop, 18k on phones; Lambert materials, no shadows, no textures, no addons.

The tour drives it. `scroll_story_controller` dispatches `window` `landing:progress` events (`{ step, progress, heroProgress, scroll }`, step 0 hero, 1..5 tour steps, 6 past the last step); the controller asks for the current state with `landing:sync` once Three is ready. Per step: the camera eases between keyframes; step 1 drops the pin; step 2 highlights the centre field and bares its neighbours; step 3 regrows the neighbours in their crop colours; step 4 cycles three rotation layouts over the 3x3 centre block from thirds of the progress; step 5 warms and dims the light and frosts the outer fields; past the tour the canvas fades to 0.35.

Lifecycle: reduced motion shows the backdrop and reveals the copy, never importing Three; a 1.5 s safety timer reveals the copy even if the 1.3 MB import is slow; otherwise `await import("three")` (vendored r169, `preload: false`), bail if disconnected meanwhile; `initScene` and every animation frame run in try/catch (no WebGL or a crash: warn, tear down, backdrop); renderer capped at 2560x1440 with CSS at 100%, pixel ratio 1.5 on mobile, 1.75 on coarse pointers, 2 otherwise; resize and orientation debounced through rAF; clock paused on `visibilitychange`; palette follows `html[data-theme]` through a `MutationObserver` and recolours fog, lights, ground and plants; `disconnect()` removes every listener, disposes every geometry and material, disposes the renderer and removes the canvas. The fields are the site's one signature; every visual element has a purpose, no glow for its own sake.

## The menu dial (`/menu`, `radial_menu_controller.js`)

The main menu: a web preview now, the app's first screen later. `MenuHelper::SECTIONS` maps each section key (fields, crops, weather, staff, reports) to its panel options; copy lives in `pages.menu.*` and panels follow the sectors' order. The SVG (`viewBox -102..102`, centre 0,0) is drawn on the server: one wedge path in `<defs>`, reused through `<use>` at 12 o'clock and rotated into place, with a `<pattern>` texture in its tint, an icon and a short label. The key doubles as `data-tone`, which sets `--tint` from a status token: fields `--color-warning`, crops `--color-success`, weather `--color-info`, staff `--color-secondary-hover`, reports `--color-accent`.

The controller turns the rotor with a pointer drag (touch first: `touch-action: none`, capture after 6 px so taps still click, flick momentum, a spring that snaps to the nearest section), the wheel or trackpad (one section per 60 px), and the arrow keys on the `role="slider"` SVG. The section under the gold marker is the selection; the hub button in the centre swaps its kicker, title and description while the wheel moves, and labels counter-rotate to stay upright. Tapping the selected wedge, the hub or Enter opens a modal `<dialog>`: a circle placed over the hub scales past the screen's diagonal (Web Animations, transform and opacity only), the stage zooms out behind it and the panel's cards rise in a stagger. Close (button or Escape) plays it backwards and returns focus to the hub. Reduced motion snaps and cuts with zero durations.

## Stimulus controllers

`theme`, `dialog`, `toast`, `dropdown`, `clipboard`, `web_share`, `scroll_reveal`, `scroll_story` (the landing tour: one passive scroll listener, an IntersectionObserver on the viewport centre, `--active`/`--idle` step classes, `aria-current` on the dots, the `landing:progress` event), `landing_nav`, `hero_scene`, `radial_menu` (the menu dial), `passkey`, `web_push`, `bridge/{share,notification_token,push_permission}`. Rules and templates: `.claude/commands/stimulus.md`.

## PWA

`PwaController` serves `pwa/manifest.json.erb` (`application/manifest+json`) and `pwa/service-worker.js` (push and notificationclick only, no offline cache). Icons: `public/icon.svg` (source: three field bands and a gold pin on deep green) and `public/icon.png` (512, any + maskable, rendered from the SVG with `qlmanage -t -s 512`; re-render it after changing the SVG).

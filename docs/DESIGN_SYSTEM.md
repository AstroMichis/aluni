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
pages/       landing, auth, app
utilities/   spacing (mt-*, mb-*, p-*), visibility (.sr-only, .hidden, .hidden-mobile, .hidden-desktop)
native.css   loaded only when hotwire_native_app?: hides web chrome the shells replace
application.css  empty on purpose
```

Each layout links its files with one `stylesheet_link_tag "<path>", "data-turbo-track": "reload"` per file in this order: base, components, layouts, page, utilities, native, then `javascript_importmap_tags`. `public.html.erb` is the landing page and the auth pages; `application.html.erb` is the authenticated area.

## Rules

- BEM: `.block__element--modifier`; layout primitives `.stack`, `.cluster`, `.grid`, `.container`.
- Mobile first: base styles for phones, `@media (min-width: 641px | 769px | 1025px)` upward. Never `max-width` queries.
- Tokens only: no raw colours, sizes or fonts in components or pages.
- Animate `transform` and `opacity` only; enter animations with `@starting-style`; respect `prefers-reduced-motion` (the global rule in `base/global.css` neutralises animations; pages add content fallbacks, e.g. the hero copy is visible without the scene).
- Focus: `:focus-visible` ring from `base/global.css`, with a `forced-colors: active` fallback.
- Touch targets 48 px; icon-only buttons carry `aria-label`.
- Every string through `t()`; `spec/i18n/core_copy_rules_spec.rb` fails on visible text outside `t()`, hardcoded brand names and em dashes.

## Components

`.btn` (`--primary --secondary --ghost --accent --danger --sm --lg --full`), `.card` (`__header __body __footer --interactive --nested`), `.badge` (`--info --success --warning --danger --accent --secondary`), `.input`, `.input-group` (`__label __hint __error`), `.select`, `dialog.dialog` (`__header __body __footer`, native `<dialog>`), `.toast` (`--success --error --info --warning`, `toast_controller.js`), `.dropdown` (`--open`, `dropdown_controller.js`), `.avatar` (`--sm --md --lg --xl`), `.skeleton`, `.language-toggle`, `.tab-bar`, `.public-footer`, `.nav`, `.store-button` (`--soon`, `__glyph __text __hint __name __badge`; `shared/_store_buttons`), `.phone-frame` (`__bar __pill __content __map __pin __row __meter __chip __option __alert`; a simulated phone for the landing tour that animates from `--reveal-opacity`, `--reveal-shift` and `--reveal-scale`), `.tour-step` (`--idle --active`, `__copy __device __next`) and `.tour-nav` (`__dot`). The onboarding chat (`docs/ONBOARDING.md`): `.chat` (`__header __companion __log __message--user --assistant __avatar __bubble __typing __composer __send __notice`; `content-visibility: auto` on the log), `.chat-panel` (the landing's scripted chat: a bottom sheet on phones, a 420 px side panel from 1025 px, `__companion`), `.confirm-card` (one 48 px checkbox per proposed change, plain Turbo forms), `.progress` (`__dots __dot--done --current __step`), `.onboarding` (`__companion` sticky from 1025 px, `__preview`), `.mascot` (`__canvas __shadow __fallback __bubble`, state modifiers `--offstage --onstage --arrived --away --docked --hidden --static --fallback --companion`) and `.mascot-avatar` (`--sm --md --lg --xl`, the inline SVG twin).

## The hero scene (`hero_scene_controller.js`)

The landing hero mounts `data-controller="hero-scene"` with a `canvas` target (`.landing__hero-bg`: fixed, inset 0, `z-index: -1`, `pointer-events: none`, a CSS vignette in `::after`) and a `heroContent` target whose hidden/visible classes the view passes as `data-hero-scene-hidden-class` / `-visible-class`; `-fallback-class` (`.landing__hero-bg--static`) is a CSS-only field backdrop the controller applies when the scene cannot run. The scene is rolling crop fields: a `PlaneGeometry` (120 or 60 segments) displaced by deterministic value noise with one vertex colour per 5x5 field patch and hedgerows between, one `InstancedMesh` of cone plants (about 6000 on desktop, 2000 on phones) coloured per crop, and a pin (sphere, needle, pulsing ring) on the centre field. Budget: about 60k triangles and 5 draw calls on desktop, 18k on phones; Lambert materials, no shadows, no textures, no addons.

The tour drives it. `scroll_story_controller` dispatches `window` `landing:progress` events (`{ step, progress, heroProgress, scroll }`, step 0 hero, 1..5 tour steps, 6 past the last step); the controller asks for the current state with `landing:sync` once Three is ready. Per step: the camera eases between keyframes; step 1 drops the pin; step 2 highlights the centre field and bares its neighbours; step 3 regrows the neighbours in their crop colours; step 4 cycles three rotation layouts over the 3x3 centre block from thirds of the progress; step 5 warms and dims the light and frosts the outer fields; past the tour the canvas fades to 0.35.

Lifecycle: reduced motion shows the backdrop and reveals the copy, never importing Three; a 1.5 s safety timer reveals the copy even if the 1.3 MB import is slow; otherwise `await import("three")` (vendored r169, `preload: false`), bail if disconnected meanwhile; `initScene` and every animation frame run in try/catch (no WebGL or a crash: warn, tear down, backdrop); renderer capped at 2560x1440 with CSS at 100%, pixel ratio 1.5 on mobile, 1.75 on coarse pointers, 2 otherwise; resize and orientation debounced through rAF; clock paused on `visibilitychange`; palette follows `html[data-theme]` through a `MutationObserver` and recolours fog, lights, ground and plants; `disconnect()` removes every listener, disposes every geometry and material, disposes the renderer and removes the canvas. The fields and Aluni are the site's two signatures; every visual element has a purpose, no glow for its own sake.

## Aluni, the mascot (`mascot_controller.js`)

A seedling that has just pushed out of the soil, built procedurally from core Three.js in `app/javascript/mascot/` (`character.js`, `animator.js`, `palette.js`; pinned under `mascot/`, `preload: false`, imported lazily next to Three). A slightly egg-shaped seed body (`SphereGeometry` scaled 1 / 1.12 / 1) carries the face low on its front: two big dark eyes (two spheres, one material with a lighter emissive) that blink, two gold cheek ovals and a curved mouth drawn as one `ShapeGeometry` with a vertex colour attribute and one `MeshBasicMaterial({ vertexColors: true })`, every vertex pushed onto the egg's surface; the mouth opens by moving its own vertices. A short stem (`CapsuleGeometry`) rises from the crown into two broad cotyledon leaves (`ExtrudeGeometry` from a `Shape` of quadratic curves, a small bevel) in pivot groups that lean apart and sway independently; two smaller blades grow from the sides as arms, pivoting at the shoulders so the right one can wave; two root-ball feet (`LatheGeometry`, a squashed bulb with ridges) alternate in a bouncy gait. `MeshStandardMaterial` roughness 0.75, one `HemisphereLight` plus one `DirectionalLight` from the upper left, no shadows, no textures, no addons. Budget: about 4.4k triangles and 11 draw calls (seed, two eyes, face, stem, two leaves, two arms, two feet); the ground shadow is CSS (`.mascot__shadow`). Colours are the `--color-mascot-*` tokens (seed, seed-shade, leaf, leaf-shade, eye, cheek, mouth), mirrored as hex ints in `palette.js`: dark uses the cover-crop and olive greens of the hero palette, light the deeper greens so it reads on cream; the palette follows `html[data-theme]` live.

The stage (`pages/home/_mascot`) is a small fixed box bottom-left (`.mascot`, 260x320 on desktop, 170x210 on phones, `z-index: var(--z-dropdown)`, `pointer-events: none`), not a fullscreen canvas: the walk-in, the slide away and the dock are CSS transforms of this box. States are modifiers the view passes to the controller: `--offstage` (translated below the viewport on phones, left of it from 769 px), `--onstage` (`transition: transform 1.6s`), `--arrived`, `--away` (the tour has the reader), `--docked` (FLIP into the chat panel's slot through `--mascot-dock-x/y/scale`), `--hidden`, `--static` and `--fallback` (the SVG twin is showing). `.mascot--companion` (`shared/_mascot_companion`) is the same stage positioned relative inside a chat column for `mode: "docked"`: no entrance, idle from the start, no bubble. The speech bubble (`.mascot__bubble`, `pointer-events: auto`, a card with a tail, `@starting-style` pop-in, `--visible`) is HTML inside the stage: the controller projects a non-bobbing head anchor into `--mascot-bubble-x/y` on arrive, resize and dock; its controls are real buttons and links from the view (48 px, every string through `t("mascot.*")`).

Animator states: `offstage -> entering -> waving -> idle <-> talking -> docking -> docked`, plus `static`. Layers: breathing (body scale 2% at 0.25 Hz), leaf sway (0.08 rad at 0.5 Hz with phase offsets), blink every 3-6 s (140 ms), glance every 4-9 s toward a random point or the pointer on desktop, the gait while entering (feet 0.45 rad at 2.2 Hz, body bob and roll), the wave (right arm up 2.2 rad, three swings, 1.6 s, head tilt), the talk (mouth at 7 Hz with decaying amplitude, nod at 1.5 Hz, for `clamp(chars * 28, 900, 5000)` ms) and a 400 ms dock settle.

Controller contract (Stimulus `mascot`): targets `canvas bubble fallback`; values `mode` ("landing" | "docked"), `dockSelector`, `entranceDelay` (700 ms), `progressEvent` ("landing:progress"); classes `offstage onstage arrived docked away hidden static fallback bubbleVisible`. Events dispatched on `window`: `mascot:ready`, `mascot:arrived`, `mascot:docked` with `{ handoff: "canvas" | "svg" }` ("svg" means the stage hid itself: phones, or no WebGL to keep, so the panel shows its own avatar), `mascot:fallback` with `{ reason }`, `mascot:lets-go`. Listened on `window`: `mascot:speak { chars }`, `mascot:dock { selector }`, `mascot:hide`, `mascot:show`, and the landing progress event (step >= 1 adds `--away`, step 0 removes it). Actions from the bubble: `letsGo()` and `dismiss()`. Lifecycle as the hero scene: reduced motion never imports Three and shows the SVG twin at once (then `mascot:arrived` so the bubble shows); `await import("three")` then the `mascot/*` modules in try/catch; any failure warns, tears down and shows the twin; renderer `alpha`, `antialias`, `low-power`, pixel ratio capped at 2 (1.5 on phones); resize debounced through rAF; clock paused when the tab is hidden, the stage is away or hidden; `disconnect()` removes every listener and timer and disposes every geometry, material and the renderer, safely twice.

The SVG twin (`shared/_mascot_avatar`, `.mascot-avatar` with `--sm` 32, `--md` 40, `--lg` 56, `--xl` 120 px) is the same seedling drawn flat with the mascot tokens, `role="img"` and an `aria-label` from `t()`, no text nodes. It stands in the stage when the scene cannot run and is the avatar beside assistant messages in the chat.

## Stimulus controllers

`theme`, `dialog`, `toast`, `dropdown`, `clipboard`, `web_share`, `scroll_reveal`, `scroll_story` (the landing tour: one passive scroll listener, an IntersectionObserver on the viewport centre, `--active`/`--idle` step classes, `aria-current` on the dots, the `landing:progress` event), `landing_nav`, `hero_scene`, `mascot` (above), `passkey` (dispatches `passkey:start` and `passkey:error`), `web_push`, the onboarding chat's `chat`, `chat_message`, `geolocate` and `landing_chat` (`docs/ONBOARDING.md`), `bridge/{share,notification_token,push_permission}`. Rules and templates: `.claude/commands/stimulus.md`.

## PWA

`PwaController` serves `pwa/manifest.json.erb` (`application/manifest+json`) and `pwa/service-worker.js` (push and notificationclick only, no offline cache). Icons: `public/icon.svg` (source: three field bands and a gold pin on deep green) and `public/icon.png` (512, any + maskable, rendered from the SVG with `qlmanage -t -s 512`; re-render it after changing the SVG).

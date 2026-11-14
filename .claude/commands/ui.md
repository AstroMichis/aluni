# /ui -- UI Component Builder

You are creating a UI component or view for Aluni. The request is: $ARGUMENTS

## Before writing ANY code:

1. Read `docs/DESIGN_SYSTEM.md` completely
2. Read `app/assets/stylesheets/base/variables.css` (every token)
3. Read the most similar component in `app/assets/stylesheets/components/` and page in `pages/`
4. Read the most similar view: `app/views/pages/home.html.erb` (site), `app/views/passkeys/index.html.erb` (app)
5. Check `app/javascript/controllers/` for a controller you can reuse

## Design tokens (use ONLY these, never raw values)

- Surfaces `--color-bg-{primary,secondary,tertiary,hover,active}`; text `--color-text-{primary,secondary,tertiary,inverse}`; borders `--color-border-{default,subtle,strong}`
- Accent `--color-accent{,-hover,-muted,-text}`; secondary `--color-secondary{,-hover,-muted}`; status `--color-{success,warning,danger,info}{,-bg}`
- Spacing `--space-{1,2,3,4,5,6,8,10,12,16,20}`; radius `--radius-{sm,md,lg,xl,full}`; transitions `--transition-{fast,base,slow}`; shadows `--shadow-{sm,md,lg,glow}`
- Type: `--font-sans` for all UI, `--font-serif` for display headings on the landing only, `--font-mono` for numbers and references; scale `--text-{xs,sm,base,lg,xl,2xl,3xl,4xl,5xl}`; utilities `.text-display`, `.text-heading`, `.text-label`, `.text-mono`, `.text-muted`
- Z-index `--z-{dropdown,sticky,modal-backdrop,modal,toast}`; containers `--container-{sm,md,lg,xl}`

## Existing components (reuse, do not recreate)

`.btn` (`--primary --secondary --ghost --accent --danger --sm --lg --full`), `.card` (`__header __body __footer --interactive --nested`), `.badge` (`--info --success --warning --danger --accent --secondary`), `.input`, `.input-group` (`__label __hint __error`), `.select`, `dialog.dialog` (`__header __body __footer`), `.toast`, `.dropdown`, `.avatar` (`--sm --md --lg --xl`), `.skeleton`, `.language-toggle`, `.tab-bar`, `.public-footer`, `.nav`. Layout: `.stack` (`--sm --md --lg --xl`), `.cluster` (`--sm --md --lg --between --end --center`), `.grid` (`--2 --3 --4`), `.container` (`--sm --md --lg`).

## Native `<dialog>` for every modal

```erb
<div data-controller="dialog">
  <button type="button" class="btn btn--secondary" data-action="dialog#open"><%= t(".open") %></button>
  <dialog class="dialog" data-dialog-target="dialog" data-action="click->dialog#backdropClick" aria-labelledby="thing-title">
    <div class="dialog__header"><h2 class="text-heading" id="thing-title"><%= t(".title") %></h2></div>
    <div class="dialog__body">...</div>
    <div class="dialog__footer">
      <button type="button" class="btn btn--ghost" data-action="dialog#close"><%= t("shared.cancel") %></button>
    </div>
  </dialog>
</div>
```

## CSS rules

- BEM: `.block`, `.block__element`, `.block--modifier`, state `.block--open`
- Mobile first: base styles for phones; `@media (min-width: 641px)`, `(min-width: 769px)`, `(min-width: 1025px)` upward; never `max-width`
- Dark is the default; light works through the tokens (`[data-theme="light"] .x { }` only when a token swap is not enough)
- Enter animations with `@starting-style`; animate `transform` and `opacity` only
- `:focus-visible` ring (global in `base/global.css`) with the `forced-colors: active` fallback; hover states on every interactive element
- Touch targets 48 px (expand small controls with a `::before` pseudo-element)
- `contain: layout style` on repeated elements; `content-visibility: auto` on long scrollable lists
- `prefers-reduced-motion`: the global rule neutralises animations; add a content fallback when something is hidden until it animates in
- One `stylesheet_link_tag` per file in the layout that needs it; `application.css` stays empty

## View rules

- Every string through `t()`; add the key to `en` and `es` in the same change (`spec/i18n` fails otherwise)
- No brand name in views (`t("app_name")`), no em dashes
- Semantic HTML (`<main id="main">`, `<nav aria-label>`, `<button type="button">`), `aria-label` on icon-only buttons, `.sr-only` for screen-reader text
- `turbo_frame_tag` for sections that update independently; `data-controller` for behaviour
- Inside the native shells `native.css` hides the web chrome; check the page both ways (`NATIVE_WEB_ACCESS=1` in development, or a native user agent)

## Aesthetic direction

Calm, legible, built for people who are not comfortable with technology: large targets, one action per screen, short sentences, generous spacing. The hero scene is the one signature; nothing glows for its own sake.

## Quality checklist

- [ ] Tokens only (colours, spacing, type, radius, shadows)
- [ ] Correct font family per role
- [ ] Phone layout first, then wider breakpoints
- [ ] Dark and light checked
- [ ] Focus, hover, 48 px targets
- [ ] `@starting-style`, `transform`/`opacity` only, reduced motion respected
- [ ] `t()` everywhere, both locales, no em dashes
- [ ] BEM consistent, no inline styles, no utility frameworks
- [ ] Semantic HTML with aria labels
- [ ] Works inside the native shell (no duplicated chrome)

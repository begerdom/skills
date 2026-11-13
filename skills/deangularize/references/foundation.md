# Phase 1: Foundation and coexistence

The SPA keeps serving everything that is not migrated. Hash routes (`/admin#/tags`) and path
routes (`/admin/tags`) do not collide, so both worlds run side by side. The names below
(`admin_next`, `.admin-content`) are placeholders; pick names that fit the project.

## Contents

1. Bundle and layout
2. Base controller
3. Unpoly configuration
4. Shell parity
5. Coexistence switches
6. Test foundation
7. Reference area

## 1. Bundle and layout

- **Separate entrypoint** (e.g. `admin_next.js`): Unpoly and its CSS, a glob import of the
  compilers (`javascripts/admin_next/**/*.js`), the stylesheets the new views need (including
  shared blocks such as icon and flag sprites, which are easy to miss), later the island registry.
  The legacy bundle stays untouched until the removal wave; that gives one clean deletion point.
- jQuery and its plugins only for a kept library that needs them, imported into the new bundle
  explicitly.
- Glob imports are usually resolved when the watcher starts: after adding a compiler or SASS
  file, restart the dev asset watcher. Check how test runs build assets.
- No DOM access at module top level in compiler files. The bundle loads in `<head>`; one
  exception at top level aborts every module imported after it (globs import alphabetically).
- **Layout**: reproduce the legacy chrome region by region (header, spacer, menu, navigation,
  content) with the same classes. Legacy CSS positions these regions (often `fixed`); a partial
  layout collapses. Give the content region a class that becomes Unpoly's main target, and the
  body a class (`admin-next`) so shared spec helpers can tell the stacks apart.
- Carry over what the legacy layout or bundle did implicitly: CSRF meta, error reporting (Sentry)
  init, environment bar, test-only freezing of the browser clock when Timecop runs (MockDate),
  meta tags the SPA read (reload info, allowed HTML tags for the editor).
- Every response renders the full layout. Chrome that must follow every fragment update
  (flashes, active navigation item, badges, header widgets, a review state in the title) gets
  `up-hungry` and a stable id instead of event wiring.

## 2. Base controller

Move what applies from the API base controller: authentication (Devise scope), host check,
authorization (Consul `power`, Pundit, ...), content locale from params, `layout 'admin_next'`,
unauthorized → flash + redirect to the landing page. Helpers in the admin helper folder may need
explicit inclusion if `include_all_helpers = false`.

## 3. Unpoly configuration (one file)

| Setting | Why |
|---|---|
| Main target = content region | Navigation swaps only the content; chrome stays |
| Follow all links, submit all forms; opt out with `up-follow=false` / `up-submit=false` | SPA feel without annotating every link |
| Exclude `a[download]`, `a[href=""]`, `a[href="#"]`, `[target]`, `a[data-method]` from following | Downloads and editor tooltips would navigate |
| Instant links (follow on mousedown) only if wanted; exclude `.btn` | Compiler-managed openers then need `up-follow=false`, or the click handler comes too late |
| CSRF from the meta tag or the legacy cookie | Same token as the SPA |
| `Accept: text/html` on Unpoly requests (`up:request:load`) | Devise answers `*/*` on sign-out with 204 and nothing happens |
| Responses that are full documents without the main target (sign-in, 2FA setup, the legacy SPA) load as a new page (`up:fragment:loaded` → `location.assign(response.url)`) | Otherwise Unpoly stops after a redirect there |
| Overlay container at the start of `body` | Legacy modals came before the content; Capybara with `prefer_exact` takes the first match, so "Title" would hit the page field instead of the dialog field |
| Modal box styled like the legacy `.modal-content` (no padding, 600/900 px, no Unpoly ×, `dismissable: ['key', 'outside']` or `['key']` for static backdrops) | Dialog parity |
| Disable submit buttons during `up:form:submit` (via `event.renderOptions` or the button) | Legacy save bars did; specs check it |
| `up.motion.config.enabled = false` in tests | Deterministic specs |
| Load Unpoly's progress bar | Replaces the legacy global spinner for navigation |

## 4. Shell parity (do early, each a small task with its own scenarios)

- Navigation entries gated by authorization exactly like the legacy navigation. Active entry
  matched up to a path segment boundary (`/admin/media` must not light up on
  `/admin/media_creators`).
- Unload alert for changed main forms (`form.form[name]`): `beforeunload`, plus a `confirm()` on
  `up:link:follow` only when the navigation replaces the changed form (overlays and fragment
  updates beside it do not ask), plus back navigation inside Unpoly (`up:location:restore`;
  cancel with `preventDefault()` and push the previous location back). A form re-rendered with
  errors still counts as changed.
- Collapsible panels and navigation with the **same storage keys** as the legacy services, so
  state survives switching between old and new pages.
- Reload notification / version ping, session timeout, header widgets (e.g. a picker that inserts
  text into the focused field), content locale switcher (per tab in sessionStorage if the SPA kept
  it in memory across navigations; reset rules as in legacy).
- Flashes: server flashes in a hungry partial; a small `addFlash` for client-side flashes with
  the same markup (dismiss button).
- Global loading feedback: Unpoly progress bar and `.up-active`; island requests need their own
  counter (see `react_islands.md`).

## 5. Coexistence switches (flipped per area at cutover)

- **Both navigations**: the legacy Angular navigation template and the new navigation partial get
  the new path for a migrated area. Forgetting the legacy one sends users from the SPA back into
  the old screen.
- **Migrated-states redirect inside the SPA** (e.g. `migrated_states.js`): on a transition to a
  migrated state (`$transitions.onBefore` in ui-router 1.x, `$stateChangeStart` in 0.x),
  `location.assign(newPath)`. Covers `ui-sref`, `$state.go` from not-yet-migrated screens,
  bookmarks and `otherwise`. Before leaving, ask the legacy unload alert; hand over flashes and
  the content locale via sessionStorage. Guard Jasmine runs that boot the router.
- **State name → path on the server**: stored state names (review lists, notifications, mails,
  `ui_route_name` style model methods) need a helper that maps `{ state, params }` to a path. Use a
  table for migrated states and the router convention for the rest; after the removal, make
  unknown states raise.
- **Links from new views into unmigrated areas**: hash URL with `up-follow=false` (full load).
- **Spec addressing**: one switch per area. Cucumber: the `paths.rb` phrases. RSpec with inline
  hash URLs: `scripts/rewrite_hash_urls.rb` with a mapping table.
- **Stack-neutral spec helpers**: while legacy specs still exist, extend selectors with the new
  counterpart instead of replacing them (`[uib-tooltip], [tooltip]`), branch on the body class
  where behavior differs, and run the legacy specs that use the helper.
- **Large areas built inert over several commits**: keep the cutover switches as a local patch
  (`git diff <files> > $SCRATCH/cutover.patch`, `git checkout -- <files>` before each commit,
  `git apply` after) so specs run locally against the new screen without pushing a half-switched
  area.

## 6. Test foundation

- Feature specs reach new pages via route helpers on the admin host.
- Request specs per controller assert HTML and fragments (`response.body.squish`, redirect paths
  via `URI(response.location).path` when a default `locale` param gets appended). For POST/PATCH/
  DELETE, switch off forgery protection in an `around` block if the test env enforces it.
- Keep the JSON API specs as long as their endpoint has consumers.
- Verify the JS console error check of feature specs really reports errors (a broken regex can
  silence it for years); otherwise errors pile up until the final wave.
- Freeze the browser clock with the server clock in the new layout too, or relative dates flip.

## 7. Reference area

Pick the smallest complete CRUD area that touches the cross-cutting concerns: search with
debounce, pagination, authorization, content locks, content locale, rich text, an embedded list.
Have the user review it closely; their corrections become rules for all areas (record them in the
gotchas doc). Typical corrections from a finished migration: reproduce the complete legacy layout,
render the save bar as a panel like legacy (spacing), per-locale error flash, attributes instead
of classes as JS hooks, Ruby logic of a Haml view in one `:ruby` block, lock-specific markup in its
own partial, no comments that narrate the code.

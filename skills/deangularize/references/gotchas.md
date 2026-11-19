# Gotchas

Distilled from a four-week migration of a large AngularJS admin. Each bullet: the trap, then what
to do. Bootstrap traps are in `bootstrap_upgrade.md`, island traps in `react_islands.md`.

## Contents

1. Unpoly
2. Server-rendered forms vs. the old JSON forms
3. Rails, Haml, helpers
4. Feature specs and Capybara
5. capybara-lockstep and the test server
6. Docker, parallel runs, sandbox
7. Process

## 1. Unpoly

- **Check the project's Unpoly version.** Docs (and the `unpoly-docs` skill) describe the latest
  release; features like `up-defer` or `up-switch` + `up-show-for` need recent 3.x, and behavior
  changed between minors. Read the release notes in between.
- `up.layer.accept()` from a plain DOM handler targets `up.layer.current`, which can be the root
  layer. Resolve the overlay with `up.layer.get(element)`, or open programmatically with
  `up.layer.open({ onAccepted })`.
- Instant links follow on `mousedown`, before any `click` handler can `preventDefault`. Openers
  managed by compilers need `up-follow="false"`.
- `[up-href]` buttons do nothing (not even `up-confirm`) without `up-follow`.
- Unpoly sends `Accept: */*` unless told otherwise; Devise answers sign-out with 204.
- **Check that Unpoly's cache works at all.** Rails answers with `Vary: Accept`, and the cache only
  matches a request with the same headers. Setting Accept in `up:request:load` comes after the
  cache lookup, so nothing is ever served from the cache (and preloads are wasted). Set it in
  `up:link:follow` / `up:link:preload`, always as a new object
  (`event.renderOptions.headers = { Accept: 'text/html', ...event.renderOptions.headers }`); a
  default in `up.fragment.config.renderOptions.headers` is shared by reference and collects the
  X-Up and CSRF headers of other requests. Consider an opt-in cache (`autoCache` off,
  `up-cache="true"` + `up-preload` on navigation links, short `cacheEvictAge`, evict on every
  unsafe request) when GET requests have side effects such as taking a content lock.
- **Perceived speed:** the SPA showed the new screen at once and loaded data afterwards; a
  server-rendered navigation keeps the old page until the response. Measure from `mousedown`
  (instant links follow then), preload navigation links, skip layout parts (navigation, badge
  counts) for overlay and validation responses, avoid redirects on hot paths. Fade the main target
  while `.up-loading` after a ~100 ms `transition-delay` (cache hits never get the class, a
  click waiting for a pending preload does).
- Unpoly's progress bar fills up and is then removed at once, which reads as a hiccup. To fade it
  out, follow the documented custom indicator: `up.network.config.progressBar = false`, an element
  in the layout and a compiler on `up:network:late` / `up:network:recover` (grow with a long
  decelerating width transition, then fill up, fade out, reset on the opacity `transitionend`).
  Do not patch the internal `up.ProgressBar`.
- Client-side previews built after a pick (picker fields, placeholders taken from the picked
  record) must carry both content locales like the server-rendered ones; otherwise switching the
  locale before the form is rendered again shows the old locale. Specs: pick, then switch the
  locale before saving or reopening.
- **Client state that outlives navigations (on `body`, in `sessionStorage`) is unknown to the
  markup the server renders.** The SPA's content locale switcher sat in the shell; now every page
  renders its own, marked for the default locale. A compiler that only acts when the stored value
  differs from `body` works after a full page load (the server resets `body`) but leaves the new
  switcher wrong after a fragment update, where `body` already holds the stored value: the list
  shows English, the German flag is marked. Mark new elements from the current client state on
  every compile, the same for active tabs or toggles kept on the client. Spec: switch, follow a
  navigation link, check the marks.
- Dialogs hide the page scrollbar; Unpoly pads the body, but elements fixed to the right edge jump
  unless listed in `up.viewport.config.anchoredRightSelectors` (or marked `[up-fixed]`).
- Actions whose response leaves the app and carries a flash (sign-out) must not go through
  Unpoly: the full-document rule would load the page a second time and the flash is gone. Use a
  plain form POST (a tiny `a[data-method]` compiler, `up-follow=false`).
- `up-validate`: targets need ids and must exist in the DOM; never target the field being typed
  in; validations discard other pending validations of the same form; validation requests fire
  `up:form:validate`, not `up:form:submit`; validation responses do not render hungry elements, so
  results outside the targets do not update.
- `up-watch-event="input"` internally becomes `input` + `change`; a blur then fires a second
  autosubmit with stale hidden values. Pass an explicit string like `'input search'`.
- `up-switch` belongs on the container of a radio group (it aborts on the radios); all values in
  the container count as switch values.
- `up-keep` needs a unique target (give kept elements ids, or Unpoly derives `a[href="#"]` and
  keeps the wrong element). No `[up-keep]` inside a kept `[up-keep]` (the clone duplicates ids and
  rendering aborts halfway). `up:fragment:keep` bubbles: check `event.target === element`.
- Rendering errors surface only as a rejected promise of `up.render`; wrap it when debugging.
- Unpoly overlays append to the end of `body` by default; move the container to the start if specs
  rely on dialog fields coming first in document order.
- Back navigation into an Unpoly page fires no `beforeunload`; handle `up:location:restore`.
- Fetch keeps custom request headers across redirects: a header describing the current editor
  state reaches the redirect target too. Make the server ignore state that is not its own.
- `up.element.createFromHTML` needs trimmed HTML (else a text node); `<tr>` outside a table and a
  `<form>` inside a form are dropped by the parser: parse via a detached `<template>`.
- `up-defer` placeholders are requested again when a cached page revalidates; use
  `up-cache="false"` for content the user edits.
- Autofocus: `up.fragment.config.autoFocus` accepts functions that return an element; they get
  `origin` but no status, so detect submits by the origin being a form or its field. Overlays
  focus after their opening animation (`up:layer:opened`). The first page load is not a render
  pass; use `up:framework:booted`.
- Cross-host setups: expose Unpoly's response headers in CORS (`X-Up-*`), or Chrome logs "Refused
  to get unsafe header".
- Navigating to the same form again sends the request before the old page released its lock; the
  server reports the own lock as foreign. Re-claim it with `up.navigate`, not a full reload.
- A double click on a link to a form: the first request takes the lock, Unpoly aborts its response
  for the second, and the tab never learns the new lock code. A silent re-claim with an older
  remembered code then fails with every response and reloads until the lock expires. Let the
  server tell the form whether its request already sent codes and show the claim dialog instead
  of trying again; a guard that looks at the URL misses re-claims that keep it.

## 2. Server-rendered forms vs. the old JSON forms

The Angular client sent JSON shaped by its model; forms send strings for every field. Models
and controllers were written against the JSON.

- **Blank is `''`, not `nil`.** Model logic checking `nil?` flips. Normalize with `presence`.
- **Untouched fields were not sent.** Now every field arrives: do not assign blank password
  fields; keep a typed new password after a failed save so the user does not lose it.
- **Booleans arrive as `"0"`, `"1"` or `""`.** `""` is truthy in Ruby: a hidden "remove" flag
  with an empty value deleted files on every save. Cast with `ActiveModel::Type::Boolean`.
- **IDs arrive as strings.** Key-array associations save nothing silently, validations comparing
  integers let `"5"` pass. Code that diffs them against the stored integer IDs sees every ID as
  removed: a setter destroyed and recreated all links on each save, and a link whose `belongs_to`
  had `dependent: :destroy` took the linked record with it (a page's sub pages). Cast to integers
  in the model setter, not per controller: preview endpoints and other forms reach the model
  without the controller's cast. Drop the blank value that signals "remove all".
- **Untyped JSON stores** (`store_accessor`) would save `"1"` instead of `true`: serialize typed on
  the client or cast on the server.
- **Missing vs. null**: the JSON omitted keys; code using `fetch(:key, default)` now gets `nil`.
- **`params.expect`** silently drops index-keyed nested attributes unless written with double
  brackets: `docs_attributes: [[:id, :file_cache]]`.
- **`has_many :through` `_ids=` writes immediately** on persisted records: never assign them in a
  validation request.
- **STI forms**: one param key for all subclasses; `becomes!` (not `becomes`) with the chosen
  type before saving, and render the form from the original record.
- **Defaults** set by the Angular form controller move to `build_<record>`. Values legacy
  computed only on load must be remembered before assigning params, or a validation shows the
  unsaved state.
- **After a failed save** other page parts showing the same record should read
  `<attr>_in_database`.
- **Slug `to_param`**: admin routes take `record.id`.
- **Flash on validation errors** only where legacy showed one (often only for localized models).
- **Multiple error messages** of a field were comma-joined in legacy helpers; match it.

## 3. Rails, Haml, helpers

- All helpers share one namespace in views: a new helper can shadow an existing one in another
  module. `grep -rn "def <name>" app/helpers` before naming. Do not name helpers like route helpers.
- Check that a file does not exist before writing it; overwriting a legacy helper with the same
  name breaks only the legacy screens, and only browser specs notice.
- `rescue_from` handlers run after authorization wrappers (e.g. Consul's `with_current_power`)
  reset their context; re-establish it when rendering from a handler.
- The `locale` param may be taken by `default_url_options` and route defaults; use other names.
- Routes that differ only in `defaults:` (one resource per page type) confuse `url_for(params)`;
  pass explicit URLs.
- Haml 6: no `capture_haml`/`haml_tag`; `data: { locale: }` shorthand breaks the static attribute
  compiler (`locale: locale`); `nil` values in a passed-through attribute hash still render the
  attribute (`.compact`); classes are not sorted; buttons in `- if` blocks lose the separating
  space (`safe_join(buttons, ' ')`); `white-space: pre-line` shows Haml line breaks (`%td<`).
- `text_area_tag` does not escape a `SafeBuffer`: pass `String.new(...)` for code shown as text.
- Previews: sanitize with the same sanitizer as the save path; Rails' `sanitize` strips links with
  custom protocols.
- Date before 1582: `l(date)` converts to the Julian calendar; use `strftime`.
- A JSON request rendering a Haml partial needs `formats: [:html]`.
- `.except(:limit, :offset)` on a paginated relation keeps its loaded records; fetch IDs without
  limit and includes, then `where(id:)`.

## 4. Feature specs and Capybara

- Nokogiri-based steps (tables, mails, `page.html`) ignore CSS visibility: render only the active
  locale as text and swap it in JS; hidden rows count unless removed or kept in a `<template>`
  outside the table; `<br>` reads as empty, keep a space before it.
- Capybara's table matchers see only visible rows; an empty table has zero height and is
  invisible to Selenium (give it a 1 px row if a spec scopes into it).
- `Capybara.match = :prefer_exact` picks the first match in document order (see overlays).
- Spec helpers often find buttons with `visible: false`: render both state variants and hide one.
- `click_button` needs real `<button>`s.
- A hover step's synthetic `mouseleave` must close popovers; popovers must not intercept clicks
  (`pointer-events: none`).
- Long CSS tooltips (`white-space: nowrap`) can widen containers on hover and make Selenium miss
  the click target; long texts belong in help text.
- Browser time: freeze it with the server time (Timecop + MockDate) in the new layout too.
- Unload dialogs: the native `beforeunload` dialog appears only with the BiDi driver and only after
  real user activation (synthetic drags do not count); it has no custom text. Check the app's own
  `confirm()` text by leaving through an app link, the native dialog by reload/back. Put
  scenarios that leave the page at the end of a file (a later "new tab" step may crash).
- Opening a second tab can hang Chrome after several examples in one process; after a crash every
  later example fails. Broad runs: one spec file per container.
- A focused field outside the viewport makes ChromeDriver scroll it back before a click; the click
  then hits another element. Blur before synthetic drags.
- SortableJS fallback mode and synthetic drags: it samples the pointer every 50 ms (move in steps
  with pauses), finds targets with `elementFromPoint` (scroll the item to the middle first), and
  swallows the next click unless the drag helper dispatches a `click` after `mouseup` like a
  browser does. An aborted drag leaves its ghost in the DOM.
- Specs stubbing constants of API controllers (page sizes) must point to the new owner.
- Hash-route visits did not reload the SPA (stubs needed a full reload); path routes do. Specs
  written around that quirk may change meaning: check with the user.
- Specs of the public frontend may open admin forms; grep them at every cutover.
- Prove each new spec: run it against the state without the fix (`git stash push -- app/`, build,
  run) and see it fail for the expected reason.
- Layout bugs reported only by some users may come from fractional display scaling: Chrome rounds
  border widths down to whole device pixels, so a "2px border, 1px less padding" selected state
  ends up a fraction taller and the floats of the next row catch on it. Keep the box size constant
  (1px border plus `box-shadow: inset 0 0 0 1px`). Measure the user's screenshot before fixing a
  visual report. Specs need Chrome started with `--force-device-scale-factor` (CDP emulation does
  not round borders), and that Chrome must not take a fixed debug port another Chrome already
  holds, or chromedriver silently attaches to the unscaled one.
- Port the legacy filters with all their semantics: a `localize` filter may fall back to a
  `fallback_locale` key of the localized hash; a server helper that only picks `value[locale]`
  shows blank images or texts in the second locale. Grep the legacy filter's source, not its name.
- Image directives (`cropped-image` and similar) cut thumbnails to an aspect ratio; a plain `<img>`
  in the port looks fine in specs but not to editors. Check every directive used inside a preview.
- The JS console error check can be silently broken (a wrong host regex). Capybara's compound
  matchers and retrying helpers swallow `StandardError`s, so raise console errors as an RSpec
  expectation failure; reading the browser log clears it, so keep read errors for the example.
  Details in `final_waves.md` §6.

## 5. capybara-lockstep and the test server

- Lockstep waits for every open request, including `up-defer` placeholders; to observe a
  spinner, stop waiting temporarily, block the action with a queue (with a timeout, or the single
  server thread hangs), assert, release, resume waiting.
- Lockstep waits for newly inserted `<img>` but not for a changed `src`.
- **Puma with one thread and keep-alive reorders requests**: it waits up to ~200 ms for the next
  request on the same connection and serves it first. A fresh upload preview then arrived after
  the save that cleared the cache, hit a catch-all route and caused a CSP error. Start the
  Capybara server with keep-alives disabled (`enable_keep_alives: false`).
- Probes that "hold" a request must be verified to actually hold (log `up:request:load`,
  `up:network:late`); a counter installed after the first save counts from zero.

## 6. Docker, parallel runs, sandbox

- Find the non-interactive form of the project's Docker wrapper (TTY flags, env passthrough).
  Wrappers that join arguments into one shell string break Ruby one-liners and `bash -c`: quote
  the whole command or write a script under `tmp/` and run that; write output to a file and read
  it.
- Never run two spec runs on the same test DB/search index at once (also not from other sessions
  or worktrees: check `docker ps`); parallel runners separate DBs via `TEST_ENV_NUMBER`.
- Parallel browser specs: load the schema into every test DB first, build test assets with one
  single run first (other processes wait only briefly), give each Chrome its own debug port (a
  fixed `--remote-debugging-port` lets only one Chrome start).
- While a run is in progress, only add files: views compile on first render and meet helpers
  loaded at boot; JS/SASS were built at the start.
- `db:migrate` may dump the schema from a drifted dev DB; sync test DBs with
  `db:test:prepare`/`db:schema:load` and review schema diffs.
- After a rebase the test DB lags behind upstream migrations: reload the schema.
- Sandboxes may make `.claude/skills` read-only (write skill files with Write/Edit; run rebases or
  worktree removals that touch them unsandboxed with permission), and `$TMPDIR` differs inside and
  outside; keep logs in the scratchpad.
- Worktrees: tools search config upward (ESLint finds the main checkout's config:
  `--no-eslintrc -c .eslintrc.js`); git inside containers may not see the worktree; copy or build
  test assets; give the worktree its own `TEST_ENV_NUMBER`.
- Some auto modes refuse `docker stop`; stop the task and wait for the container to finish.

## 7. Process

- After a rebase, grep for calls to methods upstream deleted; textual merges hide them.
- When a change moves data between server and client (an `up-data` attribute, query params),
  grep the request specs for the old shape. Before pushing, run every CI job locally (Brakeman
  too), not only the specs of the area.
- New spec files shift CI's file distribution (Knapsack); order-dependent leaks in unrelated specs
  surface on other nodes. A common leak: records created in a group-level `around` hook survive
  when DatabaseCleaner starts in a `before` hook. Investigate them separately from the migration.
- Parallel subagents for many similar files work if each only creates new files and reports shared
  changes; check afterwards for duplicates and overwritten files.
- Do not "fix" things that differ only in tests (spec labels visible, translucent file inputs).
- A user report that cannot be reproduced against old and new with the user's real input (e.g.
  their document converted to clipboard HTML, the same browser version in a throwaway container)
  is often a stale bundle in the dev browser: dev servers serve unfingerprinted assets. Ask for a
  hard reload before digging deeper.
- Test editor pasting through the real clipboard (a copy event filling `text/html` +
  `text/plain`, then Ctrl+V), not through the editor's insert API, which skips its paste path.

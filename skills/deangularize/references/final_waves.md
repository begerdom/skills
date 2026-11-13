# Phase 4: Final waves

Start only after every area is migrated, and agree scope and order with the user (see
`decisions.md`). Each step ends with the full browser suite green and is its own commit (or a few
focused commits). Proven order: widget test pages → remove AngularJS and dead API → direct links,
packages, JSON helpers → Bootstrap → console check → parity rounds → renames and dead CSS →
coexistence names.

Commit titles from a finished migration, for the shape: "Port the widget specs to
server-rendered test pages", "Replace the AngularJS app under /admin by a redirect for legacy
links", "Remove the AngularJS backend", "Remove the JSON endpoints only the AngularJS backend
used", "Upgrade the backend to Bootstrap 5", "Fix the JavaScript errors the console check
reports", one commit per parity finding ("Frame the dialogs like the legacy ones"), and a
"Document ..." commit per wave for the plan and gotchas doc.

## 1. Widget specs on server-rendered test pages

Specs that mounted widgets on Angular test pages move to a test pages controller (routes only in
development and test, segment name not colliding with pagination params). See
`angular_mapping.md`, "Widget test pages". Drop scenarios that test pure Angular internals only
with the user's consent.

## 2. Remove AngularJS

- **Old entry → redirect page for legacy hash links**: the controller that served the SPA renders
  a tiny layout-free page with its own small script. The script maps hash routes of the old router
  to the new paths (keep query params such as `version_id`), unknown routes go to the landing page.
  It needs no authentication (the target asks). Redirects that carry a flash go straight to the
  landing page, or the redirect page consumes the flash.
- Delete: the Angular bundle entrypoint, `app.js`/router, controllers, directives, services,
  filters, models, the templates directory and the controller serving templates, Angular template
  helpers, the second (legacy) navigation, the migrated-states map, coexistence branches in new
  code (legacy lock codes, hash fallbacks, cutover tables), Angular Jasmine specs (keep specs of
  utilities the new code still uses, and the runner config for them).
- Move files the new bundle still imports from the legacy directory (editor customizations,
  shared utilities) to a shared directory; check that ESLint ignore rules still match.
- Packages: remove via the package manager so the lockfile follows; delete vendored libraries by
  hand. A package manager may auto-install peers of a new package (Popper for Bootstrap); make
  them optional (e.g. `packageExtensions` in pnpm) if unused.
- Error reporting: if the Angular bundle initialized Sentry (or similar) and the new bundle does
  not, add it now.
- Sign-in, password and 2FA layouts may still link the old stylesheet: point them to the new one.
- Specs: the sign-in helper should land on the new landing page. Side effects of the vanished SPA
  boot: the content locale in sessionStorage survives a user switch in the same tab; a lock
  release (`keepalive`) after leaving can arrive after the next `login_as` and eat it (wait until
  no lock is active before switching users).

### Dead JSON endpoints

Consumers are: island and compiler `fetch`/XHR calls, URLs in `up-data` and data attributes of
views, the layout (ping), other apps or projects (ask if unsure), the public frontend (previews
posting JSON), mails and exports. Delete the controller actions, JSON views, routes and their
specs that nobody consumes. Before deleting a controller, move what others still use from it:
page-size constants (spec stubs reference them), param sanitizers, confirmation-message partials.
Remove matching security-scanner ignore entries and i18n keys that only deleted templates named
(dynamic keys go to the i18n tool's ignore list).

## 3. Direct links instead of hash links

Mails, notifications, exports, an admin panel inside the public frontend and scripts may still
build `/admin#/...`. They keep working through the redirect page, but direct links are better. A
small `AdminUrl.to(:helper, ...)` that computes the path with the admin's route/path helpers and
prefixes the admin host. Traps: helper modules of a controller may not know route helpers
(`include_all_helpers = false`), and in mailers path helpers may return full URLs on the frontend
host; compute the path outside such full-URL contexts.

## 4. Unused packages and model JSON helpers

- An npm package is unused when no entrypoint, stylesheet, Jasmine suite or spec imports it (and
  no gem calls its binary). Remove, then prove: `CI=true pnpm install --frozen-lockfile --offline`
  (or the project's equivalent) and a test build; compare the build output with a copy taken
  before (`diff -rq`; content-hashed file names make this a strong check). Remove matching license
  approvals.
- Model methods that only fed the SPA (`to_hash`, `to_media_hash`, `as_json_for_select`) go when
  no picker, preview, usage list, builder item or lock still reads them. `to_hash` is special:
  ActiveSupport's `as_json` calls it on POROs, so check serialization paths before deleting.
- Dead JS from other bundles found on the way: report it, remove only with the user's consent.

## 5. Bootstrap upgrade

See `bootstrap_upgrade.md`. Take before-screenshots of every screen first.

## 6. Console error check

Feature specs should fail on JS errors of the app's hosts. Verify the check works (provoke an
error in a temporary spec). When it was broken, expect many real errors; typical causes:
`a && b()` used as "maybe an object" (`false.destroy()`), compilers not prepared for empty lists,
island unmounts during render, CORS headers Unpoly reads (`X-Up-*`) not exposed, CSP errors from
requests that arrived late (see the Puma keep-alive gotcha). Make the error class an RSpec
expectation failure so retrying matchers (`patiently`, compound matchers) do not swallow it, and
keep read errors until the next example (reading clears the browser log).

## 7. UI parity rounds

Compare with the real old UI, not with an intermediate state of the new one. Technique in
`parity_and_verification.md`. Expect findings in: dialog frames and backdrops, picker layouts,
tooltips (placement, clipping), collapsed navigation width, date picker look and views (months,
years), form details (locale flags, required stars, error placement), cursors, spacing of tables
in panels, review/status badges next to titles, transitions, loading indicators, slow pages.
After your round, the user clicks through and reports; handle each finding as analyse → propose →
build the chosen fix, each fix with a spec proven against the unfixed state.

Slow pages: measure before splitting (realistic data volume, server timings, browser long tasks).
Move expensive parts behind `up-defer` with a loading placeholder and `up-cache="false"`, build
collapsed tree levels lazily, avoid computing a URL per node.

## 8. Remove every Angular mention and dead CSS

- Grep for `angular`, `ng-`, `ng_`, `uib`, `$scope`, `ui-router`, `ui-sref`, `Restangular` in app,
  lib, spec, config, docs. Rename specs, helpers and comments after what they test now
  (`directives/` → `widgets/`, `UiSelectSteps` → `SearchableDropdownSteps`). Keep license
  attributions of code ported from Angular libraries.
- Decide with the user about names that encode router states (e.g. a `ui_route_name` model method,
  `{ 'state' => 'albums.edit', 'params' => … }` hashes, state names selected in SQL). First check
  whether any of it is persisted (DB columns, serialized JSON, sent mails, search documents, the
  hash-link redirect page). If not, replace it with one edit-path helper that builds Rails paths
  from a record (`record_edit_path(record)`) or from class name and id for SQL results (select the
  class name instead of the state), and keep the generated links identical (helper/request specs).
- Editor-facing options that render nothing since long (e.g. a flex mode whose JS was removed):
  ask whether to drop them; convert existing content with a data migration only where the new
  value renders the same, leave the rest and log it, and tell the user what changes visibly.
- Dead CSS: search every selector in views, helpers, JS and specs, including dynamically built
  names (`"is-#{...}"`, template literals, string concatenation); `git log -S` shows the last user.
- Prove that bundles outside the admin did not change (byte comparison, see
  `parity_and_verification.md`).

## 9. Drop the coexistence names

The new admin was built next to the old one under a second name (entrypoint `backend_next.js`,
script folder, layout, a `BackendNextHelper`, nav helpers, a body class, stylesheets and CSS blocks
with a `_next`/`-next` suffix). Once the old bundle is gone, ask the user whether to give
everything the plain name back; they will expect it.

- Inventory first: `git grep -n "<suffix>"` (snake, kebab and Camel case) plus `git ls-files |
  grep -i <suffix>`. Filter out unrelated hits (`nextSibling`, pagination "next", slider arrows).
- Move with `git mv` so history follows. The old folder name may still exist locally as an
  untracked leftover; move the folder's entries into it instead of the folder itself (otherwise
  `git mv` nests it), and leave foreign untracked content alone.
- Rewrite identifiers in one scripted pass (module, helpers, layout name, `stylesheet_link_tag` /
  `javascript_include_tag`, bundler entry list, body class, path comments), then reword the
  comments that mention the suffix as prose. Grep again until nothing is left.
- Check every path a comment or spec mentions (`javascripts/<admin>/…`): after the rename the
  folder name is the legacy one again, so stale references to deleted legacy files now point at
  plausible but wrong places.
- Suffixed stylesheets usually have an unsuffixed sibling: a legacy block whose class names the
  new markup kept on purpose, plus the `_next` file with additions. Merge each pair into one file
  instead of renaming over it, and delete rules no markup uses any more (search each class as fixed
  text, `git grep -F`: Haml writes `.class= content`, which a regex expecting quotes or spaces around
  the name misses). Bundlers that import a
  glob load files alphabetically: when the pair is adjacent in that order, appending the `_next`
  rules to the legacy file keeps the cascade; check the neighbours of every renamed file.
- A suffixed CSS block without sibling may have been suffixed to dodge a framework class (e.g.
  Bootstrap's `.tooltip`). Check whether that framework component is still imported before taking
  the plain name.
- Folders the old and new bundle shared (`backend_shared/`) can stay separate when the new folder
  is loaded through a glob: merging them in would change their load order (error reporting first,
  jQuery before the editor).
- Restart the dev asset watcher afterwards; it still builds the old entrypoint name.
- Run the whole suite: every layout, helper and asset name changed.
- Update README, CLAUDE.md and the project skill to describe the new admin; mark history in the
  plan and gotchas doc as history.

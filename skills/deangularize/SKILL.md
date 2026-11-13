---
name: deangularize
description: >-
  Migrate the AngularJS 1.x admin/backend SPA of a Rails project to server-rendered Rails views
  with Unpoly, React islands only for heavyweight widgets, and a Bootstrap 5 upgrade at the end,
  area by area with the feature specs as the specification: discovery and plan, coexistence of old
  and new UI, per-area loop (controller, views, up-validate forms, Unpoly dialogs, pickers,
  uploads, specs, parity check, cutover), removing AngularJS and its JSON API, final parity rounds.
  Use whenever the user says "deangularize", "/deangularize", "migrate the AngularJS backend to
  Unpoly", "remove AngularJS from the admin", "replace the Angular SPA with server-rendered
  views", wants to continue or resume such a migration or port the next admin screen off Angular,
  also in German ("Angular aus dem Backend entfernen", "AngularJS ablösen", "Admin auf Unpoly
  umstellen", "mach mit der Angular-Migration weiter"). Not for Angular 2+ or for feature work
  that stays inside the AngularJS app.
---

# Deangularize: AngularJS admin SPA → Rails views + Unpoly

The goal is an admin without AngularJS that still feels like an SPA: server-rendered views,
Unpoly for fragment updates, forms and overlays, a few React islands where real client state is
needed, and Bootstrap 5 at the very end. Behavior and look stay as they were. The existing
browser specs (RSpec/Capybara feature specs or Cucumber) are the specification. Old and new UI
coexist, one area is cut over at a time, and every commit is green.

This skill is the method. Everything project-specific (paths, commands, building blocks,
decisions, progress, gotchas) lives in a knowledge base inside the target project, created in
Phase 0 and read at the start of every later session. If the project already has its own
migration skill or docs, read those first; they override the generic defaults here.

## Reference files

| File | Read when |
|---|---|
| `references/discovery_and_plan.md` | Phase 0: inventory, plan doc, gotchas doc, per-project skill |
| `references/decisions.md` | before talking to the user about scope; whenever a decision comes up |
| `references/foundation.md` | Phase 1: new bundle/layout, Unpoly config, shell, coexistence switches |
| `references/area_loop.md` | every area: skeletons, cutover, parity checklist, closing checklist |
| `references/angular_mapping.md` | matching each Angular construct/widget to its replacement |
| `references/react_islands.md` | Phase 3, or any widget that needs client state |
| `references/final_waves.md` | Phase 4: removing AngularJS, dead API, packages, console check, coexistence names |
| `references/bootstrap_upgrade.md` | Bootstrap 3 → 5 while keeping the old look |
| `references/gotchas.md` | before building (skim), and when something behaves oddly |
| `references/parity_and_verification.md` | parity screenshots, DOM probes, full-suite runs, flakies |
| `references/upstream_sync.md` | after rebasing onto a main branch that still changes the SPA |

Scripts in `~/.claude/skills/deangularize/scripts/` (run with `bash`/`ruby` from the target
repo root; all read-only except the rewriter):

- `scripts/angular_inventory.sh [<area>]` – overview of the AngularJS app, or one area's states,
  templates, controllers, directives, API calls and specs. Heuristic; verify by reading.
- `scripts/rewrite_hash_urls.rb <config.yml> <files…>` – rewrites legacy hash URLs in specs
  (`admin_path(anchor: '/tags/1/edit')`) to route helpers from a mapping table.
- `scripts/legacy_drift.sh` – after a rebase: upstream commits touching the legacy side of
  migrated areas, plus methods deleted upstream that the branch still calls.

Other skills that help if installed: `unpoly-docs` (API details; check the project's Unpoly
version against the release notes), `effective-rails-testing`, `work-in-branch`,
`pass-all-checks`, `self-review`.

## Ground rules

- **Specs are the specification.** Scenario semantics never change silently. Rewiring stack
  coupling (URLs, selectors, stubbed constants of deleted controllers) is fine; new scenarios for
  new or newly fixed behavior are welcome. A scenario that would have to change its meaning goes
  to the user, unless a precedent the user already decided covers it (record precedents in the
  plan doc).
- **Green specs are not parity.** Specs check behavior, not looks. Every area gets a parity check
  against the real old UI (help texts, required stars, columns, badges, spacing, error display).
- **Server first.** Logic of Angular controllers moves into Rails controllers and helpers. Prefer
  Unpoly features (`up-validate`, `up-switch`, layers, `up-poll`, `up-defer`) over custom JS,
  custom compilers over React.
- **Generic building blocks.** Widgets become attribute-based compilers plus a helper or partial,
  registered in the project's building-block catalog. Behavior hangs on attributes, never on
  classes (and never on utility classes).
- **Reuse the legacy CSS** by rendering the same DOM structure and classes as the legacy
  templates; add scoped overrides only where needed.
- **Small green commits**, English imperative messages in the style of the branch. Stage files
  individually (`git add -A` picks up sandbox placeholder files), then check
  `git status --short | grep '^ M'` for a forgotten file.
- **Specs for every change**: a request spec per new controller, scenarios for new behavior, and
  each new spec proven to fail without the fix.
- **Keep the knowledge base current**: append each gotcha to the project's gotchas doc when it is
  learned, progress and decisions to the plan doc, new blocks to the catalog.
- Follow the user's style preferences from memory/CLAUDE.md (comments, dashes, blank lines).

Stop and ask (with no user present: mark the area blocked in the plan, continue with the next
one, report at the end) before you would:

- add any dependency (npm, gem, vendored lib), including Unpoly or React if not yet present,
- push, force-push, rebase or rewrite branch history, unless the agreed policy allows it,
- delete a JSON endpoint that still has a consumer,
- change or delete a scenario to make it pass (outside recorded precedents),
- deviate from legacy behavior beyond fixing obvious data loss (report such fixes),
- touch production data or remote infrastructure.

When the user reports a finding that touches an earlier decision: analyse, present options, and
build only the one they choose.

## Phase 0: Discovery and plan (with the user, no code changes)

1. Run `scripts/angular_inventory.sh` and verify its numbers by reading: Angular module and its
   dependencies, router config (states/routes), navigation template, how templates reach the SPA,
   API controllers, package.json and vendored jQuery plugins, CoffeeScript (if any), and the test
   setup (driver, capybara-lockstep, how specs address the SPA, Angular-coupled helpers).
2. Look at the project's public frontend: if it already uses Unpoly, its conventions (config,
   compilers, main target) are the house style to copy.
3. List the areas along the navigation with scenario counts, widgets, API endpoints and risk.
4. Write the plan doc and the gotchas doc (templates in `references/discovery_and_plan.md`)
   where the user wants them; default: local and untracked, e.g. under the project's `.claude/`.
5. Settle the up-front decisions in one batch question with recommendations
   (`references/decisions.md`).
6. Get the plan agreed and work on a feature branch. The branch carries code and specs only,
   no migration docs and no `.claude/` files, unless the user decides otherwise.

## Phase 1: Foundation and coexistence

Details: `references/foundation.md`.

- New bundle entrypoint and new layout next to the legacy ones (legacy untouched until the
  removal wave). The layout reproduces the legacy chrome DOM so the old CSS applies.
- Base controller (authentication, host, authorization, content locale, layout).
- One Unpoly config file: main target, follow all links/forms, `Accept: text/html`, full
  documents load as new pages, overlays before the content, legacy-looking modal frame, disabled
  submit buttons while saving.
- Shell parity: hungry flashes and navigation (power-gated), pagination, search bar, unload
  alert, collapsible panels/navigation sharing the legacy storage keys, reload notification.
- Coexistence switches flipped per area at cutover: `path:` in BOTH navigations, a
  migrated-states redirect inside the Angular app, a server-side state-name → path helper,
  spec URLs, stack-neutral test helpers.
- A reference area: the smallest complete CRUD area that exercises the cross-cutting concerns.

## Phase 2: Area by area

Details and skeletons: `references/area_loop.md`. Each step ends green.

1. **Inventory**: `scripts/angular_inventory.sh <area>`, then read fully: every spec of the area
   and specs elsewhere that reach it, the legacy templates, the Angular controllers (defaults,
   debounce, conditions no spec checks), the API controller and its JSON views. Note scope and
   open questions in the plan.
2. **Widget matching**: map every directive, filter and service to a building block
   (`references/angular_mapping.md` plus the project catalog). Missing ones are built generically
   and registered. A missing one that needs a new dependency: ask.
3. **Build inert**: route, controller, views, request spec. The SPA still serves the area.
   Commit ("…, not yet switched").
4. **Parity screenshots** of old and new before the cutover (temporary spec, never committed).
5. **Cutover** (all or nothing): spec URLs, both navigations, migrated-states map, link tables.
   Run the area's specs and every spec that reaches the area; iterate until green.
6. **Parity review**: legacy template line by line against the new view (checklist).
7. **Close**: lint, request and feature specs, docs (progress with scenario counts, gotchas,
   catalog, area status), commit, push and read CI if the policy allows.

After two or three areas the pattern has settled: generate a per-project skill with the
building-block catalog, recipe and area list (`references/discovery_and_plan.md` §6) so later
sessions can continue autonomously.

## Phase 3: Heavyweights as React islands

Details: `references/react_islands.md`. First ask whether an Unpoly layer plus fragment updates
suffice. Islands are for real client state: nested drag & drop builders, multi-selection bulk
editors, uploads with progress, a date/time picker if no library is approved. They mount through
one compiler, embed existing compilers instead of rebuilding them, and keep using JSON endpoints.
Approval of React (and any drag & drop or crop library) is a user decision.

## Phase 4: Final waves (agree scope and order with the user first)

Details: `references/final_waves.md`, `references/bootstrap_upgrade.md`.

1. Port widget specs from Angular test pages to server-rendered test pages.
2. Remove AngularJS: the old entry becomes a redirect page for legacy hash links; delete bundle,
   templates, template controller, Angular helpers, Angular Jasmine specs, packages, vendored
   libs, coexistence switches, and JSON endpoints without consumers.
3. Direct links instead of hash links in mails, exports and other apps.
4. Unused npm packages and model JSON helpers only the SPA read (prove with build diffs).
5. Bootstrap 5 with the old look (variables tuned to the BS3 theme, compat partials).
6. Make the JS console error check of feature specs work and fix everything it finds.
7. UI parity rounds against the real old UI (old tree via `git archive`), then user rounds.
8. Remove every Angular mention and dead SASS; update README/CLAUDE.md.
9. Drop the coexistence names (`backend_next` → `backend`, `_next` stylesheets merged into their
   legacy siblings); ask the user first.

## Phase 5: Verification

Details: `references/parity_and_verification.md`. Full browser suite in parallel plus all
non-browser specs; rerun parallel-only failures serially; check serial failures on the unchanged
HEAD before calling them pre-existing; flaky is not the same as racy. Linters and security
scanner clean (rubocop, brakeman, eslint, i18n checks). Read CI read-only after each push.

## Session start (resuming)

1. Branch: the migration branch or one derived from it, never main. Clean working tree; leave
   foreign changes alone.
2. Read the plan doc (progress, decisions), the gotchas doc (at least what concerns the next
   area), the project catalog/skill.
3. Check upstream: `git fetch && git log --oneline HEAD..origin/<main> | head`. Rebase only on
   instruction, then `references/upstream_sync.md` before building anything.
4. Pick the next unblocked area from the area list unless the user names one.

## Commands

Find out in Phase 0 and record in the plan doc: single spec, area specs, full browser suite in
parallel, non-browser specs, asset build for tests, dev server restart, linters. Typical traps:
Docker wrappers that need a TTY flag, wrappers that join arguments into one shell string (quote
the whole command or use a script file under `tmp/`), test assets built from sources only at the
start of a run, two runs sharing one test DB. See `references/gotchas.md` (Docker and runs).

## Report

At the end of a session, or when stopping, report briefly in the user's language: areas
migrated (scenario counts, commits), new building blocks, deliberate deviations from legacy,
scenarios changed and why, blockers and open questions with a recommendation, what comes next.

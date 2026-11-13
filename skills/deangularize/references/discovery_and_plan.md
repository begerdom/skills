# Phase 0: Discovery, plan, knowledge base

Nothing is changed in code during this phase. The output is an agreed plan, a gotchas doc and a
list of settled decisions, all committed on the migration branch.

## Contents

1. Inventory
2. What to read by hand
3. Area list
4. Plan doc template
5. Gotchas doc template
6. Per-project skill (after two or three areas)

## 1. Inventory

Run from the repo root:

```bash
bash ~/.claude/skills/deangularize/scripts/angular_inventory.sh                 # overview
bash ~/.claude/skills/deangularize/scripts/angular_inventory.sh --js app/assets/javascripts/admin \
  --templates app/views/templates/admin                                          # if auto-detection is off
```

Record the verified numbers in the plan ("Baseline"): Angular version, module dependencies,
states/routes, controllers, directives, services, filters, templates, API controllers, browser
spec files (and how many need JS), Bootstrap and angular-ui-bootstrap versions, Unpoly and React
presence, CoffeeScript files (none = "not applicable", say so), vendored jQuery plugins. Numbers
age fast; note the commit they were taken from.

## 2. What to read by hand

- **Bootstrapping**: the admin layout (`ng-app`), the controller serving it, the Angular module
  file (dependencies tell you which widget libraries exist: ui-router, Restangular, ui.bootstrap,
  ui.select, ui.tree, ui.sortable, ng-file-upload, ngAnimate, ...).
- **Routing**: the state/route definitions. Dynamic states (generated from a service) do not show
  up in a grep. Abstract states, `otherwise`, nested states with params.
- **Templates**: where they live and how the SPA gets them (`templateUrl` served by a Rails
  controller, `$templateCache`, embedded at boot). Templates rendered server-side at boot run for
  every user: a model change used there can break the whole SPA, and they may need an
  authorization context (e.g. a current power) to render.
- **Template helpers**: Ruby helpers that emit Angular markup (`ng_text_field`, `panel`,
  `save_cancel_bar`, ...). They are the contract the new helpers must reproduce (labels, required
  stars, error placement, hidden attributes such as `panel_title` that specs select on).
- **Services with state**: content locks, unload alerts, collapse state, flash, request tracker,
  "spec label" numbering. Their storage keys and DOM output are often relied on by specs.
- **API**: `Api::*` controllers, JSON views, base controller (auth, locale handling, flash meta),
  which endpoints other consumers use (mobile apps, other projects, the public frontend).
- **Tests**: driver setup (Selenium/Cuprite, BiDi for unload dialogs), capybara-lockstep or
  Angular waits, how specs address SPA pages (hash anchors, `paths.rb`), Angular-coupled helpers
  (`ng-*`, `.scope()`, `uib-*`, `.angular-ui-tree-*`, jQuery plugin calls), Angular test pages
  (`/admin#/test/...`), Jasmine specs, the JS console error check (does it actually report?).
- **Frontend**: if the public frontend already uses Unpoly, copy its config, compiler layout and
  helpers. That is the house style the team knows.
- **Assets**: bundler (esbuild/webpack/jsbundling), glob-import plugin, test asset outdir, lint
  config (which globs ESLint covers).
- **Run commands**: how to run one spec, a directory, the full suite in parallel, lint, the dev
  server, the asset watcher. Note TTY and quoting quirks of the Docker wrapper.

## 3. Area list

Walk the navigation top to bottom. For each top-level area:

| Area | States | Templates | Spec files (scenarios) | Widgets | API endpoints | Other consumers | Risk |
|---|---|---|---|---|---|---|---|

Ordering heuristic (the user decides the final order):

1. Foundation, then one small reference CRUD area that touches the cross-cutting concerns
   (search with debounce, pagination, authorization, locks, locale, rich text).
2. Plain CRUD areas with few widgets.
3. Cross-cutting shell tasks as soon as a migrated area needs them (navigation gating, unload
   alert, panels, header widgets).
4. Lists and dialogs with more interaction (media, pickers, uploads).
5. Workflows that embed heavyweights (page editors with builders) after the heavyweight exists.
6. Heavyweights as islands (tree editor, template builder).
7. The landing page (dashboard) only together with a full-suite run, since every login lands there.

Refine the order after each inventory: an area embedding a later widget moves after it.

## 4. Plan doc template (`<docs dir>/<topic>_plan.md`)

`<docs dir>` is where the user wants the knowledge base (default: local and untracked, e.g.
`.claude/skills/<project>-migration/docs/`; `docs/` only if the team commits it).

Write it in the team's language. Sections:

```markdown
# Migration plan: remove AngularJS from the admin

> Status line (current wave, last update). Created <date>, verified against <commit>.

## 0. Progress
Per area, newest last: scope, scenario counts (green), new building blocks, deliberate
deviations from legacy, scenario changes and who approved them, open follow-ups.

## 1. Goal and definition of done
## 2. Baseline (verified numbers with source commands)
## 3. Target architecture (house style: bundle, layout, base controller, Unpoly config, compilers,
##    islands, where views live)
## 4. Endpoint strategy: per API action (a) HTML route, (b) Unpoly fragment, (c) JSON for an island.
##    Delete JSON only when no consumer is left.
## 5. Order (waves) and risk table
## 6. Reference implementation (first area, as the template for all others)
## 7. React islands (which, why, prop/endpoint contracts)
## 8. Bootstrap upgrade (strategy, class renames with counts, vendored libs to replace)
## 9. Coexistence strategy (switches per area)
## 10. Test strategy (specs as specification, request specs, helpers to rewire)
## 11. Commands
## 12. Definition of done checklist
## 13. Decisions and open questions (dated; mark "user" vs "autonomous")
```

## 5. Gotchas doc template (`<docs dir>/<topic>_prompt.md`)

This is the hand-off prompt for fresh sessions and the place where every learned pitfall goes.
Write it in the team's language and keep appending.

```markdown
# Prompt: remove AngularJS from the admin

> Meant as the first prompt of a fresh session. Paths verified on <date>.

## Assignment (goal, end state, constraints)
## Starting point (verified facts about the SPA, API, tests, Bootstrap)
## Way of working (area by area, specs as specification, plan first, commit green)
## Definition of done
## Important starting files
## Learned pitfalls
### <area or topic> (<date>)
- **Short rule in bold.** Why it happened and how to do it right, with file names.
```

Rules for entries: one bold rule per bullet, the cause, the fix, where the reference
implementation lives. Prefer rules that transfer to the next area over narration of what was
done.

Two small data files complete the knowledge base, both extended at every cutover:

- `<docs dir>/<topic>_hash_urls.yml`: the mapping for `scripts/rewrite_hash_urls.rb` (legacy hash
  route → route helper). Specs written later on main with hash URLs get rewritten with it, and it
  is the source for the redirect page's route table in the removal wave.
- `<docs dir>/<topic>_legacy_paths.txt`: the legacy files of every migrated area (templates, Angular
  controllers, API controller, JSON views, specs) plus shared pieces, read by
  `scripts/legacy_drift.sh` after a rebase.

## 6. Per-project skill (after two or three areas)

Once the pattern has settled, generate a project skill so later sessions can run autonomously
("continue the migration"). Write it with the Write/Edit tools: a sandboxed shell often cannot
write into `.claude/skills`. Layout:

```
.claude/skills/<project>-admin-migration/
  SKILL.md                     # session start, per-area loop with project paths, autonomy rules, commands
  references/building_blocks.md  # catalog: helpers, partials, compilers (attribute APIs), islands,
                                 # concerns, CSS conventions, spec helpers and DOM contracts,
                                 # and the Angular → replacement table with status ✓ ◐ ✗ ⛔
  references/area_recipe.md      # skeletons copied from the reference area, cutover switches,
                                 # project parity checklist
  references/areas.md            # remaining areas in order, blockers, status, cross-cutting tasks
  references/upstream_sync.md    # drift porting with project paths
  scripts/                       # inventory/drift/url-rewrite configured for the project
```

The project skill points to the plan and gotchas docs as the knowledge base and says: read the
plan (progress, decisions) and the gotchas at every session start; register every new building
block in the catalog. Keep the project skill up to date when the migration moves into later
waves; mark parts that became history (e.g. coexistence switches after the removal of AngularJS).

# Parity checks and verification

Specs prove behavior; parity checks prove looks; byte comparisons prove that nothing else
changed. Never use the user's own browser; drive a separate headless Chrome through temporary
specs.

## 1. Parity screenshots while the SPA still exists

Per area, before the cutover (see `area_loop.md` §4). After the cutover, compare by temporarily
taking the area out of the migrated-states map for the run (back it up and restore it). Visit the
new form first, then the legacy one: the other way round the legacy form holds the lock and the
new one shows the takeover dialog, and a changed legacy form's unload alert blocks the next visit.

## 2. Parity against the real old UI after AngularJS is gone

1. Create a worktree (or use a scratch dir) and export the old state:
   `git archive <main-commit> | tar -x -C tmp/old` (include symlink targets: `git archive` does
   not follow symlinks).
2. Give it its own test DB (`TEST_ENV_NUMBER=<n>`), install packages offline from the lockfile,
   build test assets there.
3. Run the same temporary spec in both trees. Visit old pages via their hash URLs; in the new tree
   the same hash URLs go through the redirect page to the new paths.
4. Sort by pixel difference, then inspect:

```python
from PIL import Image, ImageChops
diff = ImageChops.difference(Image.open(a).convert('RGB'), Image.open(b).convert('RGB'))
print(diff.getbbox())  # None = identical
```

   Names and clocks always differ; look at pairs side by side and at crops at double size. The
   height of full-page screenshots reveals spacing drift.
5. For exact numbers use a DOM probe in the spec (`getBoundingClientRect`, computed margins,
   `clientWidth` vs. border box for scrollbars) instead of eyeballing pixels.
6. Special probes:
   - **Cursor probe**: collect elements with `cursor: pointer|move` whose parent lacks it (old
     tree) and click targets without it (new tree: React handlers via `__reactProps$*` keys, links
     without `href`, compiler hook selectors); match by tag and classes.
   - **Transition probe**: sample `opacity` per `requestAnimationFrame` in both trees.
   - **Performance probe**: realistic volume (factories plus `insert_all!`), server timings via
     `ActiveSupport::Notifications.subscribe('process_action.action_controller')`, browser long
     tasks via a `PerformanceObserver` injected with CDP `Page.addScriptToEvaluateOnNewDocument`,
     time to heading/spinner/content via a rAF loop. Measure the Unpoly click and the direct visit
     separately.
7. Write each finding down with old/new numbers before fixing; fix with a spec that fails on the
   unfixed state.

Keep temporary specs and screenshots out of the suite glob and out of commits; delete the old
tree and extra test DBs afterwards (or tell the user what is left).

## 3. Proving that other bundles did not change

For changes that should only affect the admin (package removal, Bootstrap, CSS cleanup):

1. Build before: `RAILS_ENV=test pnpm build` (or the project's build), copy the output dir.
2. Build after, compare manifests and files byte for byte (`diff -rq`, Python `filecmp`).
3. To build an older state: `git archive <commit> app/assets config vendor <js test dirs> ...` into
   `tmp/`, install offline with the frozen lockfile, build there.

Bundlers strip top-level JS comments; comments inside functions and JSX stay. Source-map or
postcss comments may contain build paths; differences there are fine.

## 4. Full-suite runs

- Browser specs in parallel (e.g. `parallel_rspec -n 6..8 spec/features`) in the background, with
  output to a file; prepare all test DBs and build assets once first. Non-browser specs separately
  (some may need serial runs, e.g. specs that depend on the server port).
- Parallel runner exclude patterns are often regexes, not globs.
- Broad serial reruns: one spec file per container, rerun crashed files alone.

## 5. Flaky failures

1. Failure only in the parallel run: rerun the file serially. Green → note it as parallel-only
   (shared ports, Redis, search index, cache, timing under load).
2. Failure also serially: run it on the unchanged HEAD (worktree or stash) before calling it
   pre-existing.
3. **Flaky is not the same as racy.** A test failing two of three times may be deterministically
   wrong with false-positive greens. Copy the scenario to `tmp/`, print the DB state after each
   step, find the first step that diverges. (Example: an empty hidden "remove" flag deleted files
   on the first save; the green runs never checked them.)
4. "Looks flaky, passes alone sometimes" after an early return in a controller: check that the
   input is assigned before re-rendering; `up-switch` then hides a panel and the next click misses.

## 6. Linters and security

Rubocop (explicit file list in worktrees), ESLint (check which globs it covers; `.jsx` may be
outside), Brakeman (justify ignores for free-form JSON with a note), i18n checks (dynamic keys to
the ignore list), license checks after package changes. Run linters over all Ruby files changed
since the last push right before committing; auto-correct can create new offenses.

## 7. CI

After each push read the pipeline read-only (e.g. `glab ci list`, job traces via the API). CI runs
the whole suite across nodes and finds breaks in areas you did not touch. A red job may be a
runner timeout during setup; read the trace before retrying or fixing.

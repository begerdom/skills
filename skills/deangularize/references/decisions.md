# Decisions to settle with the user

Put the up-front decisions in one batch question at the end of Phase 0, each with a
recommendation and the reason. Record every answer, dated, in the plan doc (§ decisions), marked
"user". Decisions you take yourself go there too, marked "autonomous", so a reviewer can find them.

## Up front

| Decision | Recommendation | Why |
|---|---|---|
| End state | No `ng-app`, no angular packages, no Restangular, no Angular directories; templates replaced by real controllers and views; models and controllers shaped like the rest of the app | A clear definition of done keeps the final waves honest |
| Look | Identical to the old UI; a Bootstrap upgrade keeps the old look | Editors notice every shift; a redesign is a separate project |
| Bootstrap target and timing | BS5, CSS only, at the very end | Per-area renames double the parity work; one wave with a before/after comparison is cheaper |
| jQuery | Remove from the admin, except for a kept library that needs it (e.g. a rich-text editor) | Replacing the editor would mean a content migration |
| Unpoly | Use the version the frontend already has; if absent, adding it is the first dependency decision | |
| React islands | Allowed, only for named heavyweights (builder, tree editor, bulk editor, uploader, date/time picker) | Everything else is cheaper and closer to Rails with Unpoly |
| New dependencies | Each one needs approval (name, version, license, why existing ones do not suffice) | Org policy; keeps the bundle small |
| Area order | Small CRUD first along the navigation, heavyweights last (see `discovery_and_plan.md`) | The pattern settles on cheap areas |
| Spec scenarios | Semantics unchanged; stack coupling may be rewired; changes that alter meaning go to the user; precedents get recorded | Specs are the only full description of behavior |
| Legacy bugs found on the way | Keep parity; fix data loss and report it; propose other fixes | The migration should not hide behavior changes |
| Old hash links (`/admin#/…` in mails, bookmarks) | Keep working via a redirect page after the removal | Sent mails cannot be changed |
| Branch and history | One long-lived branch with one commit per area (inert + cutover) and focused commits for the cleanup waves while working; at the end ask whether to rebase onto main and squash into a single commit (one user wanted exactly that) | Per-area commits keep the work reviewable and bisectable; the final shape is the team's call |
| Push policy | Ask before each push, or agree "push after each green area"; force-push only on explicit approval | Org policy; CI runs the full suite and finds breaks outside the area |
| Upstream changes | Rebase onto main only on instruction; port drift after each rebase | main keeps changing the legacy SPA |
| Docs and agent files: place | Ask. Default: plan doc, gotchas doc, URL mapping and the per-project skill stay local and untracked (e.g. under the project's `.claude/`), never in the branch; commit them only if the team wants them | Users often want the branch to carry code only; the docs are hand-off material for future sessions |
| CoffeeScript | Convert only if found | |

## Along the way

Ask when it comes up, with options and a recommendation:

- **Each new dependency** (drag & drop, cropping, tour, date picker, select library).
- **Editors with several open versions or tabs**: one version per request (simple, loses unsaved
  tabs, scenarios change) vs. all versions in one document (close to legacy, more client code).
  Present the scenario impact in numbers.
- **Island vs. Unpoly** for a borderline widget (media picker, upload, crop) if the answer is
  not obvious.
- **Deleting a JSON endpoint** whose consumers are unclear (external apps, other projects).
- **Deviations found in parity checks**: keep the legacy quirk or fix it. Fixes of real bugs
  (data loss) can go in, but get flagged in the report.
- **Product decisions hidden in scenarios**: e.g. whether an own content lock shows in lists, or
  whether leaving a form releases its lock at once. Once decided, it is a precedent for all areas.
- **Final-wave scope and order**: widget test pages, AngularJS removal, direct links in mails,
  package cleanup, model JSON helpers, Bootstrap, console check, parity rounds, renames.
- **Stricter authorization than legacy** (when the new controller would refuse what the SPA
  silently allowed).
- **History rewrite** (regrouping into one commit per area) and the force-push it needs.

## Examples of decisions from a finished migration of a large Rails CMS (for orientation only)

- Separate entrypoint `backend_next.js` next to the Angular `backend.js` until the removal.
- Keep the Redactor editor, rewire it from a directive to an Unpoly compiler.
- SortableJS approved for sorting (Tom Select's drag plugin would have needed jQuery UI), also for
  nested drag & drop in the page tree; Cropper.js for cropping; driver.js for the guided tour.
- Dependent form fields re-rendered by the server with `up-validate`; pure visibility via
  `up-switch`.
- Bulk edit and upload of images as React islands that embed the existing Tom Select compilers.
- Page editor keeps all open versions in one document like the SPA did.
- Unload alerts checked as exactly as possible (text checked when leaving via an app link).
- Final wave order: widget specs to server-rendered test pages → remove AngularJS and dead API →
  Bootstrap 5 (CSS only, BS3 look) and driver.js → direct links, package cleanup, parity rounds.

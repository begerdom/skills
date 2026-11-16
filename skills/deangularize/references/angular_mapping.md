# AngularJS construct → replacement

The table gives the default replacement. The pattern sections below explain the ones that need
more than a sentence. Before building anything, check the project's own catalog; register every
new block there.

## Contents

1. Mapping table
2. Dialogs
3. Pickers
4. Dependent fields and visibility
5. Uploads
6. Lists: add rows, sort, nested trees
7. Content locks, unload alerts, client state
8. Rich text editor, date picker, selects
9. Hidden DOM contracts specs rely on
10. Widget test pages

## 1. Mapping table

| AngularJS | Replacement |
|---|---|
| ui-router state / ngRoute route | Rails route + controller action rendering HTML; nested states → nested routes; abstract states disappear |
| `resolve:` | loading in the controller action |
| `ui-sref`, `$state.go`, `$state.href` | `link_to path` (Unpoly follows it); stored state names → server helper mapping state to path |
| `$stateParams` | `params` |
| Restangular / `$http` against `Api::*` JSON | the controller renders HTML; per action: (a) HTML route, (b) Unpoly fragment, (c) JSON only for an island |
| `ng-model` form + `$scope.save()` | `form_with` with `up-target`; server validation re-renders the form with 422 |
| `remote-validations`-style live errors | `up-validate` targeting the label/error element only, never the field being typed in |
| `ng-if` / `ng-show` on server data | condition in the view |
| `ng-show` on another field's value | `up-switch` + `up-show-for` (on the container of a radio group), or a small toggle compiler |
| `ng-change` driving previews, hints, computed text | `up-validate="<targets>"`; server renders from params |
| `$watch` computing on load | compute in the controller/view; client-side only if it must react without a request |
| `ng-repeat` | view loop; client-added rows → `<template>` + compiler |
| search with `$timeout` debounce | GET form with `up-autosubmit`, `up-watch-delay`, `up-target` on the results |
| client pagination of a fully loaded list | server pagination as a fragment, or "show more" from a `<template>` if legacy loaded everything once |
| filters (`date`, `currency`, `localize`, custom) | view helpers with the same output format |
| directive (widget) | attribute-based Unpoly compiler + helper/partial that renders its DOM |
| `$uibModal`, dialog service | Unpoly overlay (see Dialogs) |
| `confirm()` before an action | `up-confirm`; two-step confirmations → small compiler |
| `uib-tooltip` | `tooltip` attribute + CSS or a tiny compiler that renders into `body` (not clipped) |
| `uib-dropdown` | small dropdown compiler (no Popper needed) |
| `uib-tabset` with a state per tab | links to separate actions styled as tabs |
| `uib-tabset` holding unsaved state across tabs | all panes in one document + tab compiler |
| `uib-popover` | CSS/compiler popover, `pointer-events: none`, closable by the spec helper |
| `uib-progressbar` | `.progress` markup, updated by the owning compiler |
| `ui-select` | Tom Select compiler (often already in the project) |
| `ui-sortable` / jQuery UI sortable | SortableJS (dependency decision), fallback mode so synthetic drags in specs work |
| `angular-ui-tree` | compiler + SortableJS with own drop rules, or an island |
| ng-file-upload | file input + XHR upload to the existing upload endpoint, cache name in a hidden field |
| `msd-elastic` | autosize compiler (CSS `field-sizing: content` ignores `rows`) |
| ngAnimate transitions | CSS transitions or Unpoly motion; check the timing against legacy |
| `$rootScope.$broadcast` / `$emit` | DOM custom events |
| services holding state (locks, unload alert, collapse, flash) | compilers + sessionStorage/localStorage with the legacy keys |
| `$http` interceptor with global spinner (RequestTracker) | Unpoly progress bar and `.up-active`; a request counter for island `fetch`es |
| interceptor showing flashes from JSON meta | hungry flash partial; `addFlash` for client flashes |
| `$interval` polling | `up-poll`; a ping compiler for version checks |
| `ng-bind-html` | sanitized helper with the same sanitizer the save path uses |
| `ng-include` | partial |
| `form` directive focusing the first field | `up.fragment.config.autoFocus` function (see gotchas, Unpoly) |
| `[ng-click]` getting `cursor: pointer` from CSS | an explicit `.clickable` class on script-driven click targets |
| bootstrap-tour | driver.js or similar (dependency decision) |
| jQuery datepicker/clockpicker | an approved library or a small island reproducing the typing behavior |
| Jcrop | Cropper.js (dependency decision) |
| Jasmine specs of Angular code | delete with the code; keep specs of non-Angular utilities |

## 2. Dialogs

Three variants cover almost everything:

1. **Server decides, opener reloads**: opener with `up-layer="new" up-mode="modal"
   up-size="medium" up-target="<dialog root>"`. On success the server closes the layer
   (`up.layer.accept` in unpoly-rails + `head :no_content`); the opener reloads its fragment via
   `up-on-accepted="up.reload('<target>')"` (the target needs `up-source`, or reload the main
   target to get fresh flashes).
2. **Value goes back to the opener** (pickers, "create album" from inside another form): open
   programmatically in the opener's compiler with `up.layer.open({ url, mode: 'modal', target,
   onAccepted })`. Inside the overlay resolve the layer with `up.layer.get(element)`;
   `up.layer.accept()` from a plain DOM handler targets the current layer, which may be the root.
   A form of another area can render a dialog variant (`dialog: 1`) whose success response
   accepts the layer with `{ id, flash }` instead of setting a flash. Pass the opener's current
   choice (chosen and locked IDs) as `data` of `up.layer.open`, not as query params: the SPA kept
   it in memory, and a few hundred IDs exceed nginx's 8 KB request line (414). Unpoly sets `data`
   on the root of the layer's content, so the dialog's compiler belongs on that root.
3. **Dialog only when needed** (conflict, replacement choice): link with `up-method`,
   `up-confirm`, `up-fail-layer="new" up-fail-mode="modal" up-fail-target="<dialog>"`; the server
   answers 409 with the dialog. The dialog's form carries `up-layer="root"
   up-target=".admin-content"`, so its response replaces the page and Unpoly closes the overlay.

Dialog DOM: if specs scope "within the modal dialog", render the legacy `.modal >
.modal-header/-body/-footer` structure inside the overlay (with BS3 `.modal` needs
`display: block; position: static`; BS5 `.modal` also defines the `--bs-modal-*` variables).
Size from the legacy opener (`size: 'lg'` → large, none → medium, full-size pickers → a full
overlay size). A close × only where legacy had one. Request specs that hit `up.layer.accept` need
the header `X-Up-Mode: modal`.

When specs click "Cancel" without scoping and the form also has "Cancel": render the dialog into
a container inside the form (with `up.render`) instead of an overlay at the end of `body`, and
`up.destroy` its children on close.

## 3. Pickers

- A picker controller per record type renders a dialog (`layout: false`) with search, optional
  type filter, paginated items, a details sidebar if legacy had one. Items carry
  `data-picker-id/-caption/-thumb/-type`, so one generic compiler serves every type.
- The field partial renders a preview or a placeholder button; both open the picker (never an
  `<a>` inside an `<a>`). `onAccepted` sets the hidden ID field and dispatches `change`, which lets
  `up-validate` render the preview server-side.
- Reproduce legacy selection semantics exactly (second click does not deselect, multi-select
  highlight rules, initial selection, ordering of newly picked records, page sizes from the
  legacy constant so "paginates after N" specs still hold).
- Openers inside an overlay find owner parameters (e.g. a microsite id) through
  `up.layer.get(el).origin`; pass `origin:` when opening.

## 4. Dependent fields and visibility

- **Visibility only**: `up-switch` on the select or on the container of a radio group (the
  container should hold only the radios) and `up-show-for` on the targets. Disabled fields send no
  value.
- **Server-computed content** (previews, hints per combination, embed codes, totals):
  `up-validate="<targets>"` on the field or a container. Targets need ids and must always be in
  the DOM (hide instead of omitting). Never make the field being typed in a target. Validations
  discard pending validations of the same form, so keep validating fields few and independent,
  and compute pure client-side feedback in JS.
- Buttons that re-render a part with extra params ("add file to package"): a compiler calling
  `up.validate(target, { params })`; the controller reads the params in its `up.validate?` branch.
  Any early return must still assign the input to the model before rendering.

## 5. Uploads

- Keep the existing upload endpoint (often async with a poll). The field uploads immediately and
  puts the cache name into a hidden field (`<attr>_cache`); a remove button sets `remove_<attr>`.
- Progress needs `XMLHttpRequest` (`fetch` has no upload progress).
- Mark running uploads (`[uploading]`) and let submits ask first. File info (name, size, date,
  thumbnail) follows the upload event on the client; a server re-render reads the old file's info.
- After a failed save the form must send the cache name again, or the file is lost.
- Nested multi-file uploads: rows become `<name>[<index>][<cache_field>]`, deletion marks
  `_destroy`; `params.expect` needs double brackets for index-keyed rows.

## 6. Lists: add rows, sort, nested trees

- Client-added rows: `<template>` with a `NEW_ROW` placeholder index + compiler; the list holds
  only rows so `:nth-child` specs work. Parse rows through a `<template>` (a `<tr>` outside a
  table is dropped by the parser).
- Sorting: each item carries its hidden ID field, DOM order is the saved order; SortableJS in
  fallback mode, dispatch `change` after a drop (unload alert, save bars).
- Nested trees: SortableJS only drags direct children of the list it was created on and decides
  drops poorly in nested lists; implement `onMove` yourself (drop on half of the heading under the
  pointer, indent by horizontal movement like angular-ui-tree) and return `false`. Build collapsed
  children lazily from a `<template>` for big trees; load the tree with `up-defer`.
- Unsaved sub-records edited in a dialog: keep each as JSON in a hidden field, render the dialog
  from that JSON on the server, write back on "apply", re-render the list with `up.validate`.

## 7. Content locks, unload alerts, client state

- Locks: acquire on edit; release when leaving through the app (compiler destructor, `DELETE` with
  `keepalive`); do not release on tab close if specs rely on expiry; remember owned lock codes per
  tab (sessionStorage) so lists can hide the own lock and a reload re-claims it; refresh on the
  lock's interval; show the "lock was taken over" dialog and make the form read-only on loss.
- Unload alert: see `foundation.md` (Shell parity). Changes outside fields (a saved note, a sort)
  dispatch `change` on an ancestor so the alert sees them.
- State that must survive re-renders (expanded groups) lives in module scope of the compiler, not
  on the element; hungry elements lose classes set by JS, so keep such state on a container that
  is not replaced or re-apply it when compiling.

## 8. Rich text editor, date picker, selects

- Rich text: keep the library, wrap it in a compiler with the exact legacy options (paste
  cleanup, allowed tags, sync callbacks). Plugins that expected `$uibModal` get an object with
  `open()` that opens an Unpoly layer. Read the value from the synced textarea, not from a
  pretty-printing getter.
- Date/time: whatever replaces the jQuery picker must reproduce the typing behavior the specs and
  editors use (two-digit years, "1337" → "13:37", time without date sets today, formatting on
  blur, start date limits). Popups must not cover the next field.
- Selects with search: Tom Select compilers. Options render only when opened
  (`refreshOptions(false)` after load if specs read options); server order needs a neutral score
  function; `label[for]` links to its input, so `fill_in '<label>'` works.

## 9. Hidden DOM contracts specs rely on

Find these early by reading the spec helpers:

- attributes specs select on (`panel_title`, `heading` on tabs, legacy element names like
  `<publication-state-indicator>`, `.field_with_errors`),
- numbering services ("Delete", "Delete (2)") that spec labels depend on, counted in document
  order and per scope,
- legacy field names/ids that checkbox steps look up,
- test-only visibility (`.spec-label` visible only in tests, translucent file inputs) that looks
  odd in screenshots but is not a parity bug.

## 10. Widget test pages

Angular test pages (`/admin#/test/...`) that mount a widget alone become a server-rendered test
pages controller (routes only in dev/test): one view per widget, configured by params, showing
below what the form would submit. Porting them finds real gaps (labels without `for`, missing
filters, wrong page sizes). Scenarios about pure Angular internals (two widgets bound to one
model) are dropped with the user's consent.

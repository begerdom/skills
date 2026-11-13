# Bootstrap 3 → 5, keeping the old look

Do it once, at the end, after AngularJS is gone (angular-ui-bootstrap disappears with it). The
goal is the old look on a current Bootstrap, not a redesign. Deliberate visual deviations are
agreed with the user and recorded.

## Strategy

1. **Screenshots before the first change**: a temporary spec (outside the suite's glob) visits
   every screen and state; the same spec runs after the upgrade. Sort pairs by pixel diff, look at
   the suspicious ones (`parity_and_verification.md`).
2. **CSS only**: import only the Bootstrap partials in use; no Bootstrap JS, no Popper. Dropdowns,
   collapsible panels, tooltips and modals are already compilers/Unpoly.
3. **Variables mimic the BS3 theme**: font size (14 px), line height (~1.43), greys, border radius,
   input height (34 px), breakpoints of BS3 (sm 768, md 992, lg 1200) so `col-sm-*` keep their
   meaning, gutter 30 px, `$spacer` 15 px with spacers 5/10/15/20/30 px, `$enable-caret: false` if
   toggles draw their own arrows.
4. **Compat partials** (e.g. `bootstrap_ext/`) for what variables cannot do: heading margins, bold
   labels, BS3 clearfix, floating tabs, button colors of `.btn-default`, `.btn-xs`, errors on the
   group, checkbox spacing.
5. **Class renames** across views, helpers, JS templates and specs (count them first):

| BS3 | BS5 |
|---|---|
| `.panel`, `.panel-heading/-body/-footer` | `.card`, `.card-header/-body/-footer` |
| `.form-group`, `.control-label`, `.help-block` | `.mb-3` (`.mb-0` for "no bottom margin"), `.form-label`, `.form-text` |
| `.has-error` on the group, `.help-block` messages | `.is-invalid` on the group (keep group-level, pickers and islands show errors too), `.invalid-feedback` always visible |
| `.btn-default` | `.btn-secondary` styled like the old default |
| `.label-*` | `.badge.bg-*` (not `text-bg-*`); a `.badge` without `bg-*` is transparent |
| `.input-group-addon`, `.input-group-btn` | `.input-group-text`; buttons directly in the group |
| `.pull-left/-right`, `.text-right` | `.float-start/-end`, `.text-end` |
| `.hidden`, `.visible-*/.hidden-*`, `.sr-only` | `.d-none`, `.d-*`, `.visually-hidden` |
| `.col-xs-*`, `.img-responsive`, `.table-condensed` | `.col-*`, `.img-fluid`, `.table-sm` |
| `.checkbox(-inline)`, `.radio` | `.form-check(-inline)` + `.form-check-input` (label around input: `label.form-check.form-check-inline`) |
| `select.form-control` | `.form-select` (also in multi-line `select_tag` calls and JS templates) |
| `.nav > li.active > a` | `li.nav-item > a.nav-link.active` |
| dropdown `li > a` | `.dropdown-item` |
| pagination `li > a` | `.page-item > .page-link` |
| `.close` | `.btn-close` |
| `.fade.in`, `.modal-backdrop.in` | `.fade.show`, `.modal-backdrop.show` (also in specs waiting for dialogs) |
| `.well` | `.card` or utilities |
| `.caret` | gone |

6. Tom Select and other themed third-party CSS: switch to their BS5 theme and re-check sizes.

## Traps (all seen in a real upgrade)

- **`!default` also replaces `null`**: setting a variable to `null` before Bootstrap's defaults
  gives you the default (`$form-text-font-size: null` → 85 %). Set explicit values (`1em`).
- Values defined before importing Bootstrap's variables cannot use Bootstrap variables (`$blue`
  is undefined there). Bootstrap computes some sizes without `calc`: do not mix px and rem there.
- **Spacing utilities are `!important`**: `.mb-3` beats project rules; resets such as "last child
  of a card body has no margin" need `!important` themselves.
- **Root font size**: BS3 set `html { font-size: 10px }`, BS5 keeps the browser's 16 px. Third-party
  CSS in `rem` grows by 60 % (Tom Select inputs wrap, dropdown offsets grow); set those in px.
- **Reboot**: headings lose their top margin (BS3 20/10 px); restore it, but keep 0 for
  `.modal-title`, `.popover-header`, `.card-title`. `h1 small` and bold labels need compat rules.
- **`.page-header` no longer exists**; if the header is also a `.row`, a margin shorthand
  overrides the row's negative margins (titles shift by 15 px): set only vertical margins.
- **Clearfix**: BS5's has no `::before` and uses `display: block`; first-child margins collapse
  through, and content centered by BS3's table pseudo-elements moves left. Restore the BS3 mixin.
- **Flex next to floats**: a flex container beside a float gets narrowed and ignores negative
  margins (tabs indented, lines ending early). Let `.nav-tabs` float like in BS3 where needed.
- **`.nav` wraps** (`flex-wrap: wrap`): in a narrow column the longest entry widens all.
- **Tables**: BS5 draws borders under rows, BS3 above; the first row inside panels looks different.
- **`.col-md-*` without `.row`** stacks in BS5 (BS3 floated).
- **Component variables live on the component root**: `.modal-content` reads `--bs-modal-*` that
  `.modal` defines; markup without the root has no background or padding.
- **`.modal-header` is flex**: the close button goes after the title.
- **Popovers**: `.popover` is `display: block` and not absolutely positioned without Popper. Hide
  and position hover popovers explicitly, or they sit in the flow and push buttons away exactly
  when the mouse leaves (clicks then miss).
- **Dropdowns without Popper**: toggle `.show` on menu and toggle, set `data-bs-popper="static"`;
  menus inherit odd `line-height` from headers.
- **`a.btn[disabled]`** is not styled (`:disabled` only matches form controls): compat rule.
- **Input groups** are flex with wrap and overlap borders (`margin-left: -1px`): set
  `flex-wrap: nowrap` where needed, do not zero the second field's border (BS3 habit), give
  embedded widgets `flex: 1 1 auto`. BS3 input groups were tables: a button cell spanning a label
  and a field cannot be reproduced exactly.
- **Checkboxes**: without `.form-check-input` the native box sits beside the indent; inline checks
  sit on the baseline (BS3 middle), each row 1 px lower; BS5 drops `cursor: pointer` on labels.
- **Labels around buttons** (`label.btn` for file selects) get the compat label margin; reset it.
- **`code`** has no box any more.
- **`hidden` attribute vs. classes**: in BS3 `[hidden]` loses against classes with `display`
  (`.btn`, `.help-block`); in BS5 `.d-none` and `[hidden]` are both `!important`.
- **JS hooks on Bootstrap classes break**: `closest('.form-group')` finds nothing after the
  rename. Use dedicated attributes (`[file-upload-group]`); every user of a compiler needs the
  attribute.
- **Specs outside the admin directory** may select admin markup (`.nav li.active`): grep all specs.
- Focus styles: BS5 shows focus only via `:focus-visible`; libraries that focus their first
  button (tours) look different but correct.
- **Scrolling side navigation**: a classic scrollbar (15 px) covers the end of long labels and
  clips the icons of a collapsed 40 px nav. Widen the expanded nav by the scrollbar width (labels
  keep their old width) and hide the scrollbar of the collapsed one (`scrollbar-width: none`,
  wheel and touchpad still scroll). Check with a geometry spec: label right edge < `clientWidth`.

## Verification

- Pixel-diff the before/after screenshots, then inspect pairs; full-page heights reveal spacing
  drift (1 px per checkbox row adds up).
- DOM probes for exact numbers (`getBoundingClientRect`, computed margins).
- Prove that bundles outside the admin are byte-identical (`parity_and_verification.md`).
- Full browser suite; record deliberate deviations (BS5 checkboxes, select arrows, close button)
  in the plan's decisions.

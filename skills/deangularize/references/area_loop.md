# Phase 2: The per-area loop

Placeholders: `<area>` (plural, snake case), `<record>` (singular), `<Record>` (class),
`admin_next` (layout/bundle name), `.admin-content` (main target). Adapt names, authorization and
lock concerns to the project. Once the reference area exists, copy from it instead of from here.

## Contents

1. Inventory
2. Widget matching
3. Build inert: route, controller, views, request spec
4. Parity screenshots before the cutover
5. Cutover
6. Parity checklist
7. Closing checklist

## 1. Inventory

```bash
bash ~/.claude/skills/deangularize/scripts/angular_inventory.sh <area>
```

Then read **completely** (the list from the script is heuristic):

- every spec of the area and every spec elsewhere that reaches it (grep for the nav label, the
  hash route, the API path, the factory name: other areas use records of this one as examples or
  open its list in a second tab; specs of the public frontend may open admin forms too),
- the legacy templates and the Angular controllers/services behind them (defaults for new
  records, debounce, conditions, help texts, computed values on load, which fields are sent),
- the API controller and its JSON views (scopes, includes, authorization, change tracking, flash
  texts, confirmation requests before delete, timeouts of external systems shown as flashes,
  constants that specs stub, e.g. page sizes).

Write a short note into the plan's progress section: scope, widgets needed, open questions.

## 2. Widget matching

Map each directive, template helper, filter and service from the inventory to a building block
(`angular_mapping.md`, then the project catalog). For a missing one: build it generically (an
attribute API, a helper or partial, a request spec), register it in the catalog. If it needs a
new dependency, stop and ask; without the user, mark the area blocked and take the next.

## 3. Build inert

### Route

```ruby
# inside the admin scope, e.g. scope path: 'admin', module: 'admin', as: 'admin'
resources :<area> do
  member { get :<fragment> }   # only for lazily loaded parts (usage lists etc.)
end
```

Use numeric IDs everywhere (`record.id`): some models have a slug `to_param` for the frontend.
Singleton screens: `resource :<thing>, only: %i[show update], controller: '<things>'`.

### Controller

```ruby
class Admin::<Area>Controller < Admin::BaseController
  # authorization as in the API controller, e.g. Consul: power :<area>, as: :<area>_scope

  def index
    load_<area>
  end

  def new
    build_<record>
    render_form
  end

  def create
    build_<record>
    @<record>.attributes = <record>_params
    up.validate? ? render_form : save
  end

  def edit
    load_<record>
    render_form
  end

  def update
    load_<record>
    @<record>.attributes = <record>_params
    up.validate? ? render_form : save
  end

  def destroy
    load_<record>
    if @<record>.destroy
      flash[:success] = '<legacy text>'
    else
      flash[:danger] = '<legacy text>'
    end
    redirect_to admin_<area>_path(query: params[:query])
  end

  private

  def save
    if @<record>.save
      flash[:success] = '<legacy text>'
      redirect_to edit_admin_<record>_path(@<record>.id)
    else
      render_form(status: :unprocessable_entity)
    end
  end

  def render_form(status: :ok)
    render :form, status:
  end

  def load_<area>
    @<area> = <area>_scope.ordered.search(params[:query].to_s).paginate(page: params[:page])
  end

  def build_<record>
    @<record> ||= <area>_scope.new   # defaults the Angular form controller set go here
  end

  def <record>_params
    params.expect(<record>: %i[...])
  end
end
```

Notes:

- `up.validate?` requests never save, never track changes, never check locks; they render the
  form from the params so Unpoly can pick the targets.
- Normalize params the way the JSON client sent them: `presence` for blanks that mean nil,
  `ActiveModel::Type::Boolean` for flags, `to_i` for ID lists, skip untouched secret fields
  (passwords). See `gotchas.md`, "Server-rendered forms".
- With content locks: acquire on edit, validate on update, release after success, and after a
  failed save of a persisted record **re-claim** the just-validated lock so the re-rendered form
  carries a token (a fresh acquire reloads the record and drops the input).
- With change tracking or review workflows: call the same tracking the API controller called.

### Views

`index.html.haml`:

```haml
.page-header
  %h1
    <legacy title>
    = link_to new_admin_<record>_path, class: 'btn btn-primary' do
      <legacy button text>

= form_with url: admin_<area>_path, method: :get, html: { 'up-autosubmit': '', 'up-watch-delay': 300, 'up-target': '.<area>-results' } do
  = search_field_tag :query, params[:query], placeholder: '<legacy placeholder>'

= render 'results'
```

`_results.html.haml`:

```haml
.<area>-results
  - if @<area>.empty?
    %p.text-muted <legacy empty text>
  - else
    %table.table
      %tbody
        - @<area>.each do |<record>|
          %tr
            %td= link_to <record>.name, edit_admin_<record>_path(<record>.id)
            %td
              %button.btn.btn-link{ type: 'button', 'up-follow': '', 'up-href': admin_<record>_path(<record>.id, query: params[:query]), 'up-method': 'delete', 'up-confirm': '<legacy confirm text>', 'up-target': '.admin-content' }
                <legacy label>
    = render 'admin/shared/pagination', collection: @<area>, target: '.<area>-results'
```

`form.html.haml`:

```haml
:ruby
  persisted = @<record>.persisted?
  url = persisted ? admin_<record>_path(@<record>.id) : admin_<area>_path

= form_with url:, method: (persisted ? :patch : :post), html: { class: 'form', name: '<record>Form', novalidate: true, 'up-target': '.admin-content' } do
  .panel{ panel_title: 'Data' }          -# same DOM as the legacy panel helper
    .panel-body
      = admin_form_field @<record>, :name   -# label, required star, errors like legacy
  .panel.save-cancel-bar
    .panel-body
      %button.btn.btn-primary{ type: 'submit' } <legacy text>
      = link_to '<legacy cancel>', admin_<area>_path, class: 'btn btn-link'
```

Haml style: bundle Ruby logic in one `:ruby` block, partials for lock- or widget-specific markup,
no comments that narrate the code. Controls that specs press render as `<button>` (Capybara's
`click_button`); Unpoly-driven buttons need `up-follow` next to `up-href`.

### Request spec

```ruby
describe 'Admin::<Area>Controller' do
  it 'sends signed-out users to the sign-in page' do
    get admin_<area>_path
    expect(response).to redirect_to(new_admin_user_session_path)
  end

  context 'as an authorized user' do
    before { sign_in create(:<authorized_user>) }

    it 'lists and searches' do ... end
    it 'renders the form for a new record' do ... end
    it 'renders the form again with errors and status 422' do ... end
    it 'answers validation requests without saving' do
      patch admin_<record>_path(record.id), params: { ... }, headers: { 'X-Up-Validate' => 'name', 'X-Up-Target' => '#name' }
      expect(record.reload.name).to eq('old')
    end
  end

  context 'as an unauthorized user' do ... end
end
```

Run the request specs, commit: "Build <area> server-rendered, not yet switched".

## 4. Parity screenshots before the cutover

After the cutover the SPA redirects the area, and the comparison is gone. Write a temporary spec
outside the suite's glob (never commit it):

```ruby
describe 'Parity (temporary)', js: true do
  before { create(:<record>, ...); sign_in_as_admin }

  it 'legacy' do
    visit admin_spa_url(anchor: '/<area>/new')
    click_button '<save>'
    sleep 2
    page.save_screenshot('<area>_form_legacy.png')
  end

  it 'new' do
    visit new_admin_<record>_url
    click_button '<save>'
    sleep 2
    page.save_screenshot('<area>_form_new.png')
  end
end
```

Separate examples for old and new (inside the SPA a hash change does not reload). Wait equally
long in both before each screenshot. Cover index, form, error state (also for an existing
record), empty state, dialogs. Look at the images with the Read tool. Every comparison so far
found something the specs did not. More technique: `parity_and_verification.md`.

## 5. Cutover

All or nothing: once spec URLs and navigation point to the new routes, every spec of the area
runs against the new screens (an index spec may save the form, too). Switch only when the whole
area works.

- Spec URLs: rewrite the area's hash URLs to route helpers
  (`ruby ~/.claude/skills/deangularize/scripts/rewrite_hash_urls.rb <config.yml> $(grep -rl "anchor:" spec)`),
  fix what it reports as unmapped by hand (parametrized shared examples, URLs built from
  variables), check `git diff --stat spec` for rewrites in unrelated files (comments, examples).
- Specs that assert literal hash links (`admin#/<area>/1/edit`) break too: grep for them.
- Both navigations, the migrated-states map in the SPA, the server's state → path table, review
  or notification link tables.
- Extend `docs/<topic>_hash_urls.yml` with the area's routes and `docs/<topic>_legacy_paths.txt`
  with its legacy files (see `discovery_and_plan.md`).
- Run the area's specs and **all** specs that reach the area (do not truncate the list). Iterate
  until green. Helpers coupled to Angular DOM (`ng-*`, `uib-*`, `.scope()`) may be rewired
  (extend, do not replace, while legacy specs exist). Scenario semantics stay; precedents decided
  by the user (e.g. how lock scenarios end) may be applied.

## 6. Parity checklist (legacy template line by line)

- [ ] Page title, button texts, empty texts, placeholders, flash texts identical
- [ ] Columns, column widths, badges, date formats, "last modified" layout
- [ ] Help texts, required stars (only for unconditional presence validation), tooltips
- [ ] Panels with their titles, order, grid split
- [ ] Conditional fields (`ng-if`/`ng-show` → server condition, `up-switch`, small compiler)
- [ ] Defaults for new records
- [ ] Authorization conditions in templates
- [ ] Error display (where the message sits, comma-joined messages, flash only where legacy had one)
- [ ] Content locks: indicator in lists, claim dialog, release on leaving
- [ ] Localized fields: all locales present, switcher, tables show only the active locale
- [ ] Links into unmigrated areas (hash URL, full load)
- [ ] Delete: confirmation text, cascade confirmation, redirect keeps the search
- [ ] Workflow badges/banners (review state, flags) wherever legacy showed them
- [ ] Cursor over every clickable element (legacy CSS often gave `[ng-click]` a pointer)

## 7. Closing checklist

- Linters on changed files (rubocop with an explicit file list, eslint, brakeman for new
  controllers); right before committing run them over all Ruby files changed since the last push.
- Request specs of the admin, then the area's feature specs.
- Keep the JSON API specs while the endpoint has consumers; note endpoints that lost their last
  consumer for the removal wave.
- Docs: progress (scope, scenario counts), new gotchas, catalog entries, area status.
- Commit ("Migrate the <area>"), stage files individually, check for unstaged modifications.
- If pushing is allowed: push and read the previous pipeline read-only. CI runs all specs and finds
  breaks outside the area; fix red jobs before the next area (check the job trace first: a runner
  timeout is not a test failure).

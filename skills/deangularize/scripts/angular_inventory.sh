#!/usr/bin/env bash
# Inventory of an AngularJS 1.x admin SPA inside a Rails app, as input for the migration plan.
#
#   bash angular_inventory.sh [--js <dir>] [--templates <dir>] [--specs "<dir> ..."] [<area>]
#
# Without <area>: overview of the whole app. With <area> (a top-level ui-router state or route
# name, e.g. "tags"): its states, templates, controllers, directives in use, API calls and specs.
# Run from the repo root. Read-only. Heuristic: verify every number by reading the files.
set -uo pipefail

js_dir=""; tpl_dir=""; spec_dirs=""; area=""
while [ $# -gt 0 ]; do
  case "$1" in
    --js) js_dir="$2"; shift 2 ;;
    --templates) tpl_dir="$2"; shift 2 ;;
    --specs) spec_dirs="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) area="$1"; shift ;;
  esac
done

section() { printf '\n=== %s ===\n' "$1"; }
count() { wc -l | tr -d ' '; }
g() { grep -rE --exclude-dir=node_modules --exclude-dir=.git "$@" 2>/dev/null; }
tpl_globs=(--include='*.haml' --include='*.erb' --include='*.slim' --include='*.html')
js_globs=(--include='*.js' --include='*.coffee' --include='*.ts')

src_roots=$(ls -d app/assets/javascripts app/javascript app/frontend vendor/assets/javascripts 2>/dev/null | tr '\n' ' ')
module_files=$(g -l "angular\.module\(\s*['\"][A-Za-z0-9_.-]+['\"]\s*,\s*\[" $src_roots "${js_globs[@]}")
if [ -z "$js_dir" ]; then
  first_module=$(echo "$module_files" | head -1)
  [ -n "$first_module" ] && js_dir=$(dirname "$first_module")
fi
if [ -z "$js_dir" ] || [ ! -d "$js_dir" ]; then
  echo "No AngularJS module definition found. Pass --js <dir>." >&2
  exit 1
fi
if [ -z "$tpl_dir" ]; then
  tpl_dir=$(g -l "ng-(model|if|show|click|repeat|controller)|ng_[a-z_]+|ui-sref" app/views "${tpl_globs[@]}" \
    | cut -d/ -f1-4 | sort | uniq -c | sort -rn | awk 'NR == 1 { print $2 }')
fi
tpl_roots="$js_dir"
[ -n "$tpl_dir" ] && [ -d "$tpl_dir" ] && tpl_roots="$tpl_dir $js_dir"
if [ -z "$spec_dirs" ]; then
  spec_dirs=$(ls -d spec/features spec/system features 2>/dev/null | tr '\n' ' ')
fi

state_names() { g -ho "\.state\(\s*['\"][^'\"]+['\"]" "$js_dir" "${js_globs[@]}" | sed -E "s/.*['\"]([^'\"]+)['\"]$/\1/"; }
directive_names() { g -ho "\.directive\(\s*['\"][A-Za-z0-9]+['\"]" "$js_dir" "${js_globs[@]}" | sed -E "s/.*['\"]([A-Za-z0-9]+)['\"]$/\1/" | sort -u; }
kebab() { echo "$1" | sed -E 's/([A-Z])/-\1/g' | tr '[:upper:]' '[:lower:]'; }
camel() { echo "$1" | awk -F_ '{ for (i = 1; i <= NF; i++) printf "%s%s", toupper(substr($i, 1, 1)), substr($i, 2); print "" }'; }

echo "JS root:        $js_dir"
echo "Template roots: $tpl_roots"
echo "Spec dirs:      ${spec_dirs:-(none found)}"

if [ -z "$area" ]; then
  section "Angular modules (definitions with a dependency list)"
  for file in $module_files; do
    echo "-- $file"
    awk '/angular\.module\(/ { on = 1 } on { print } on && /\]/ { exit }' "$file" | head -40
  done
  grep -hE '"(angular|@uirouter/angularjs|angular-ui-router|restangular)"' package.json 2>/dev/null | sed 's/^ */package.json: /'

  section "Code in $js_dir (registrations)"
  for kind in controller directive component service factory provider filter; do
    printf '  %-10s %s\n' "$kind" "$(g -ho "\.${kind}\(\s*['\"]" "$js_dir" "${js_globs[@]}" | count)"
  done
  printf '  %-10s %s\n' "files" "$(find "$js_dir" -type f \( -name '*.js' -o -name '*.coffee' -o -name '*.ts' \) | count)"

  section "Routing"
  echo "ui-router states: $(state_names | count)   ngRoute .when(): $(g -ho '\$routeProvider|\.when\(\s*['\''"]/' "$js_dir" "${js_globs[@]}" | count)"
  echo "Dynamic states (state() calls without a literal name): $(g -ho '\.state\(\s*[^'\''" ]' "$js_dir" "${js_globs[@]}" | count)"
  echo "-- top-level states (substates):"
  state_names | cut -d. -f1 | sort | uniq -c | sort -k2 | awk '{ printf "  %-40s %s\n", $2, $1 }'

  section "Templates"
  for root in $tpl_roots; do
    printf '  %-50s %s files\n' "$root" "$(find "$root" -type f \( -name '*.haml' -o -name '*.erb' -o -name '*.slim' -o -name '*.html' \) | count)"
  done

  section "Widget libraries in templates and code"
  g -ho "uib-[a-z-]+" $tpl_roots "${tpl_globs[@]}" "${js_globs[@]}" | sort | uniq -c | sort -rn | head -20
  for pattern in '\$uibModal' 'ui-select' 'ui-sortable' 'ui-tree' 'ngf-[a-z]+|ng-file-upload|FileUploader' 'msd-elastic' 'ng-animate|ngAnimate' 'Restangular' '\$http\.'; do
    printf '  %-36s %s\n' "$pattern" "$(g -ho "$pattern" $tpl_roots "${tpl_globs[@]}" "${js_globs[@]}" | count)"
  done

  section "Data access"
  echo "API controllers: $(find app/controllers -path '*api*' -name '*_controller.rb' 2>/dev/null | count)"
  echo "-- most used endpoints/resources in the SPA:"
  { g -ho "Restangular\.(all|one|service)\(\s*['\"][a-z_]+" "$js_dir" "${js_globs[@]}" | sed -E "s/.*['\"]//";
    g -ho "['\"\`]/api/[a-z_]+" "$js_dir" "${js_globs[@]}" | sed -E "s/^['\"\`]//"; } | sort | uniq -c | sort -rn | head -25

  section "Packages and vendored libraries"
  grep -nE '"(angular[a-z@/-]*|@uirouter/[a-z-]+|restangular|ui-select|bootstrap[a-z-]*|jquery[a-z-]*|unpoly|react|react-dom|tom-select|sortablejs|ng-file-upload)"' package.json 2>/dev/null
  grep -nE "^\s*gem ['\"](unpoly-rails|bootstrap-sass|bootstrap|jquery-rails|angularjs-rails)['\"]" Gemfile 2>/dev/null
  for dir in vendor/asset-libs vendor/assets/javascripts vendor/javascript; do
    [ -d "$dir" ] && echo "-- $dir: $(ls "$dir" | tr '\n' ' ')"
  done
  echo "jQuery plugins defined in vendor/: $(g -l '(\$|jQuery)\.fn\.[a-zA-Z]+\s*=' vendor | count) files"

  section "CoffeeScript"
  echo "$(find app lib spec features -name '*.coffee*' 2>/dev/null | count) files"

  section "Bootstrap 3 markup (views + templates)"
  for cls in 'panel' 'form-group' 'control-label' 'help-block' 'btn-default' 'label-[a-z]+' 'input-group-addon' 'well' 'pull-(left|right)' 'col-xs-[0-9]+' '(hidden|visible)-(xs|sm|md|lg)' 'img-responsive'; do
    printf '  %-28s %s\n' "$cls" "$(g -ho "[.\"' ]${cls}([.\"' ]|$)" app/views $tpl_roots "${tpl_globs[@]}" | count)"
  done

  section "Specs"
  for dir in $spec_dirs; do
    files=$(find "$dir" -type f \( -name '*_spec.rb' -o -name '*.feature' \) | count)
    js=$(g -l "js: true|:js\b|@javascript|type: :system" "$dir" | count)
    hash=$(g -l "anchor: ['\"]/|#/[a-z]" "$dir" | count)
    echo "  $dir: $files files, $js need a browser, $hash address the SPA by hash"
  done
  echo "-- spec support coupled to Angular (ng-*, uib-*, .scope(), angular):"
  g -l "ng-[a-z]+|uib-[a-z]+|\.scope\(\)|angular|\\\$digest" spec/support features/support features/step_definitions | sed 's/^/  /'
  echo "-- Angular test pages: $(g -l "anchor: ['\"]/test|#/test/" $spec_dirs | count) spec files"
  echo "-- Jasmine: $(ls -d spec/javascripts app/assets/javascripts/jasmine jasmine 2>/dev/null | tr '\n' ' ')"
  exit 0
fi

# ---------------------------------------------------------------- one area
camel_area=$(camel "$area")
state_blocks=$(g -h "" "$js_dir" "${js_globs[@]}" | awk -v area="$area" '
  /\.state\(/ { inside = ($0 ~ "state\\([ ]*[\"\x27]" area "[.\"\x27]") }
  inside { print }')

section "States"
g -n "\.state\(\s*['\"]${area}(\.|['\"])" "$js_dir" "${js_globs[@]}" || echo "(none -- dynamic states? search the service that generates them)"

section "Templates"
template_files=""
for url in $(echo "$state_blocks" | grep -oE "templateUrl: *['\"][^'\"]+" | sed -E "s/templateUrl: *['\"]//" | sort -u); do
  base="${url%.html}"
  for root in $tpl_roots; do
    for candidate in "$root/$base" "$root/${base#*/}"; do
      for file in "$candidate".* "$candidate"; do
        [ -f "$file" ] && template_files="$template_files $file"
      done
    done
  done
done
for root in $tpl_roots; do
  [ -d "$root/$area" ] && template_files="$template_files $(find "$root/$area" -type f \( -name '*.haml' -o -name '*.erb' -o -name '*.slim' -o -name '*.html' \))"
done
template_files=$(echo "$template_files" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ -n "$template_files" ]; then
  for file in $template_files; do printf '%5s  %s\n' "$(wc -l < "$file")" "$file"; done
else
  echo "(none found)"
fi

section "Angular controllers"
controllers=$(echo "$state_blocks" | grep -oE "controller: *['\"][A-Za-z0-9_.:]+" | sed -E "s/controller: *['\"]//" | sort -u)
for name in $controllers; do
  echo "state controller $name: $(g -l "controller\(\s*['\"]${name}['\"]" "$js_dir" "${js_globs[@]}" | tr '\n' ' ')"
done
echo "-- files named after the area:"
find "$js_dir" -type f \( -path "*/${area}/*" -o -name "${area}*" -o -name "${camel_area}*" \) 2>/dev/null | sort | sed 's/^/  /'

section "Directives used by the area's templates (each needs a replacement)"
if [ -n "$template_files" ]; then
  for name in $(directive_names); do
    k=$(kebab "$name"); s=$(echo "$k" | tr '-' '_')
    hits=$(grep -lE "(^|[^a-z0-9_-])(${k}|${s})([^a-z0-9_-]|$)" $template_files 2>/dev/null | count)
    [ "$hits" -gt 0 ] && printf '  %-36s %s file(s)\n' "$k" "$hits"
  done
  echo "-- library widgets and template helpers:"
  grep -hoE "uib-[a-z-]+|ui-select|ui-sortable|ui-tree|ngf-[a-z-]+|ng_[a-z_]+|ng-include" $template_files 2>/dev/null | sort | uniq -c | sort -rn
fi

section "API calls from the area's code and templates"
area_code=$(find "$js_dir" -type f \( -path "*/${area}/*" -o -name "${area}*" -o -name "${camel_area}*" \) 2>/dev/null)
for name in $controllers; do area_code="$area_code $(g -l "controller\(\s*['\"]${name}['\"]" "$js_dir" "${js_globs[@]}")"; done
area_code=$(echo "$area_code" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ -n "$area_code$template_files" ]; then
  grep -hoE "\.(all|one|several|allUrl|oneUrl|service)\(\s*['\"][a-z_/]+|['\"\`]/api/[a-z_/]+|\\\$http\.[a-z]+\(\s*['\"\`][^'\"\`]+" \
    $area_code $template_files 2>/dev/null | sort | uniq -c | sort -rn
fi
outside_area() { if [ -n "$area_code" ]; then grep -vF "$area_code"; else cat; fi; }

section "API controller"
for file in $(find app/controllers -path '*api*' \( -name "${area}_controller.rb" -o -name "${area%s}_controller.rb" \) 2>/dev/null); do
  echo "-- $file"
  grep -nE "^\s*(def [a-z_?!]+|power |include |before_action|after_action|around_action)" "$file"
  view_dir="app/views/$(echo "${file#app/controllers/}" | sed 's/_controller\.rb$//')"
  [ -d "$view_dir" ] && echo "-- JSON views in $view_dir: $(ls "$view_dir" | tr '\n' ' ')"
done

section "Other consumers (keep their endpoints; links that must follow the cutover)"
echo "-- API calls from elsewhere in the SPA:"
g -n "\.(all|one|several|allUrl|oneUrl|service)\(\s*['\"]${area}[/'\"]|['\"\`]/api/${area}[/'\"\`?]" "$js_dir" "${js_globs[@]}" | outside_area | head -20
echo "-- links into the area from elsewhere (ui-sref, \$state.go):"
g -n "ui-sref=['\"]${area}\.|\\\$state\.(go|href)\(\s*['\"]${area}\." $tpl_roots "${tpl_globs[@]}" "${js_globs[@]}" | grep -v "/${area}/" | head -20
echo "-- state names stored server-side (models, helpers, mailers):"
g -n "['\"]${area}\.[a-z_.]+['\"]" app/models app/helpers app/mailers app/util app/lib | head -10

section "Navigation entries"
nav_files=$(find app/views $tpl_roots -type f \( -name '*navigation*' -o -name '*_nav*' -o -name '*menu*' \) 2>/dev/null | sort -u)
[ -n "$nav_files" ] && g -n "${area}" $nav_files | head -10

section "Specs reaching the area (heuristic: also grep the nav label and factory names)"
for file in $(g -l "anchor: ['\"]/${area}[/'\"?]|#/${area}[/'\"?]|['\"]/admin/${area}[/'\"]" $spec_dirs | sort); do
  printf '%4s examples  %s\n' "$(grep -cE "^\s*(scenario|it|Scenario:|Scenario Outline:|it_behaves_like) " "$file")" "$file"
done

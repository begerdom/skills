#!/usr/bin/env bash
# After rebasing the migration branch onto main: which upstream commits changed the legacy
# (AngularJS) side of areas that are already migrated? Those changes are invisible in the new UI
# until they are ported by hand. Also lists Ruby methods deleted upstream that the tree still calls
# (textual merges hide those).
#
#   bash legacy_drift.sh [--paths-file <file>] [<old-base> [<new-base>]] [-- <path>...]
#
# <old-base> defaults to `git merge-base ORIG_HEAD HEAD` (right after a rebase), <new-base> to the
# merge base of HEAD and origin's default branch. Paths come from --paths-file (one per line,
# '#' starts a comment) and/or after "--". Run from the repo root. Read-only.
set -uo pipefail

paths_file=""; bases=(); paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --paths-file) paths_file="$2"; shift 2 ;;
    --) shift; paths+=("$@"); break ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) bases+=("$1"); shift ;;
  esac
done
if [ -n "$paths_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "${line%%#*}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [ -n "$line" ] && paths+=("$line")
  done < "$paths_file"
fi
if [ ${#paths[@]} -eq 0 ]; then
  echo "No paths given (--paths-file <file> or -- <path>...)." >&2
  exit 1
fi

main_ref=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
if [ -z "$main_ref" ]; then
  if git rev-parse -q --verify origin/main >/dev/null; then main_ref=origin/main; else main_ref=origin/master; fi
fi
old_base="${bases[0]:-$(git merge-base ORIG_HEAD HEAD 2>/dev/null)}"
new_base="${bases[1]:-$(git merge-base HEAD "$main_ref")}"
if [ -z "$old_base" ]; then
  echo "No ORIG_HEAD: pass the merge base from before the rebase as <old-base>." >&2
  exit 1
fi
if [ "$(git rev-parse "$old_base")" = "$(git rev-parse "$new_base")" ]; then
  echo "old base = new base ($old_base): pass the base from before the rebase explicitly." >&2
  exit 1
fi

section() { printf '\n=== %s ===\n' "$1"; }
echo "Range: $old_base..$new_base ($main_ref)"
echo "Paths: ${paths[*]}"

section "Commits touching the legacy side of migrated areas"
git log --oneline "$old_base..$new_base" -- "${paths[@]}"

section "Files"
git diff --stat=160 "$old_base..$new_base" -- "${paths[@]}"

section "Ruby methods deleted upstream that this tree still calls (candidates: framework and route helpers show up too)"
deleted=$(git diff -U0 "$old_base..$new_base" -- '*.rb' \
  | sed -nE 's/^-[[:space:]]*def (self\.)?([a-z_][A-Za-z0-9_]*[?!]?).*/\2/p' | sort -u)
for name in $deleted; do
  re=$(printf '%s' "$name" | sed 's/[?!]/\\&/g')
  git grep -qE "def (self\.)?${re}([^A-Za-z0-9_?!]|$)" "$new_base" -- '*.rb' && continue
  hits=$(git grep -nE "(^|[^A-Za-z0-9_])${re}([^A-Za-z0-9_?!]|$)" -- \
      '*.rb' '*.haml' '*.erb' '*.slim' '*.jbuilder' 2>/dev/null \
    | grep -vE "def (self\.)?${re}" | head -5)
  [ -n "$hits" ] && printf -- '-- %s\n%s\n' "$name" "$hits"
done

echo
echo "Next: git diff $old_base..$new_base -- <file>, then port each change (references/upstream_sync.md)."

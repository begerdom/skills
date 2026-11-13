# Keeping up with the main branch

While the migration runs, main keeps developing the legacy SPA: new fields, badges, workflows,
new specs written against hash URLs. For migrated areas those changes land in Angular templates,
controllers and API endpoints the new UI no longer uses, or in files the branch already deleted.
They either conflict (modify/delete) or merge cleanly and are silently missing. After every rebase
port the drift before building anything else.

## 1. Rebase (only on instruction)

```bash
git fetch origin
git branch backup/<branch>-pre-rebase-<date> HEAD
git rebase origin/<main>
```

- A sandbox that makes `.claude/skills` read-only breaks rebases that add or remove skill files
  ("untracked working tree files would be overwritten", then `--abort` fails too): run the rebase
  unsandboxed with permission, or move the identical files aside first (`git hash-object` to check).
- Modify/delete conflicts on deleted legacy files: keep them deleted (`git rm`) and port the change
  (step 3).
- If main replaced the test framework (e.g. Cucumber → RSpec feature specs), every branch commit
  touching specs conflicts. Keep main's version, then transfer the branch's spec changes from the
  backup's diff (`git diff <old-base> backup/... -- features/`) into the new spec files.
- Reload the test schema afterwards (pending migrations from main).
- Pushing after a rebase needs a force-push: the user decides.

## 2. Find the drift

```bash
bash ~/.claude/skills/deangularize/scripts/legacy_drift.sh \
  --paths-file docs/<topic>_legacy_paths.txt <old-base> origin/<main>
```

`<old-base>` is the merge base before the rebase (`git merge-base ORIG_HEAD HEAD` right after
it, or `git merge-base backup/<branch>-pre-rebase-<date> origin/<main>`). The paths file lists the
legacy side of every migrated area (templates, Angular controllers, API controllers, JSON views,
specs) plus shared pieces (legacy navigation, template helpers, spec helpers). Add an area's paths
to it at its cutover. The script lists commits and files in range and Ruby methods deleted
upstream that the branch still calls.

## 3. Port each change

Read `git diff <old-base>..origin/<main> -- <file>` hunk by hunk:

| Main changed | Do in the new UI |
|---|---|
| a legacy template of a migrated area | rebuild in the new view (same texts, same classes) |
| a new directive in such a template | find the building block; if missing, build it generically and register it |
| API controller or JSON view (fields, scopes, includes) | the same in the new controller/view |
| a spec of a migrated area | make it pass against the new UI; rewrite hash URLs; keep its meaning |
| a spec helper with Angular DOM | rewire to the new counterpart |
| the legacy navigation | mirror order, sections and badges in the new navigation |
| a new cross-cutting workflow (review badges, new flags) | build it as a block for **all** migrated areas, add it to the recipe and parity checklist |
| new router states that appear in links (mails, review lists) | add them to the redirect page table and the server's state → path helper |
| a deleted method | grep the branch for calls (`legacy_drift.sh` lists them) |

## 4. Verify and close

- Request specs of the admin; feature specs of all migrated areas touched by the drift, the
  changed upstream specs, and every spec using a changed helper.
- A new scenario for every ported behavior no existing scenario covers against the new UI.
- Commit with references to the upstream tickets ("Port <ticket> to the server-rendered <areas>").
- Record learnings in the gotchas doc. Do not push without the user's decision.

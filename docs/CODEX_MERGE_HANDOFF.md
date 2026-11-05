# Codex handoff: main merged into the retail branch (Nov 5, 2026)

The user asked for this so the merge can be undone if the result isn't better than what they had.
Ask the user before undoing anything, and explain the choice in plain words.

## What happened
PR #1 (`codex/retail-store-rebuild`, base `main`) had a merge conflict, so `main` was merged into the branch.

| Commit | What it is | Geometry checks |
|---|---|---|
| `bf8a23b` | The branch just before the merge: **"what we had"**, store layout v55 | Pass |
| `40f455d` | `main` at merge time, store layout v56 | **Fail** |
| `a37a187` | The merge commit (parents `bf8a23b`, `40f455d`) | **Fail**, inherited from `main` |

## What the merge changed
- `src/shared/RetailStoreBlueprint.luau`: the v56 layout from `main`. Shelves, freezers, produce bins, zones, aisle signs,
  an endcap and NPC traffic markers all moved to fill the expanded store. Merged without conflict.
- `plugins/BuildRetailStore.lua`: the only real conflict. Kept `main`'s `PLUGIN_VERSION = 56` and
  `MIN_BLUEPRINT_VERSION = 56`, because the blueprint is now v56. The branch's imported-art protection is kept.
- `tests/blueprint-checks.luau`: the expected `BlueprintVersion` went from 55 to 56. `main` bumped the blueprint without
  updating this check.

## Known problem: shoppers are blocked in the v56 layout
`scripts/test-retail.ps1` stops at the blueprint step with:

> Blocked shopper destinations: ShopProduce, ShopDairy and ShopFrozen intersect Frame and Glass; ShopHousehold and
> CashierSpot intersect BagHolder2; NpcRegisterSpot intersects BaggingShelf

The merge didn't cause this. Run alone, `bf8a23b` passes and `40f455d` fails the same way, so **`main` has this bug too**.

- **Freezers:** `main` moved the freezer cases to x = -50, 0, 50 at z = -8 (glass at z = -6.5), and the Shop markers to the
  same x values at z = -6. Shoppers end up standing inside the glass.
- **Checkout:** `main` moved the register, cashier and household markers from x = 42 to x = 50, into `BaggingShelf` and
  `BagHolder2`.

Because the script stops there, the later steps were run with a temporary copy that continued past it. Those all passed:
private doors, vehicles, imported assets, server startup and both Rojo builds. Updater and NPC order checks also passed.
The Godot game in `game/` doesn't use these files, and its tests were not run. Nothing was checked in Roblox Studio.

## Your options

### 1. Fix forward (keeps v56; recommended if the user likes the new layout)
Move the blocked markers clear of the fixtures, or move the fixtures, then run `scripts/test-retail.ps1` until it passes.
The fix belongs on `main` too, since `main` has the same bug. Don't loosen the check to get a pass.

### 2. Undo the merge (back to "what we had")
```bash
git switch codex/retail-store-rebuild
git pull
git revert -m 1 a37a187
git push
```
This adds a new commit and rewrites nothing. `-m 1` keeps the branch side (`bf8a23b`). Then run `scripts/test-retail.ps1`,
which should pass at v55. This handoff file stays, because it's in a later commit.

**Two catches:**
- Git still counts `main`'s commits as merged. The PR will look mergeable, but **merging it would remove the v56 layout
  from `main`**. Don't merge the PR in that state unless the user wants v56 gone from `main`.
- To bring v56 back later, revert the revert commit. Merging `main` again won't do it.

### 3. Keep the merge, restore only the v55 layout
Restore the blueprint from `bf8a23b` and set `MIN_BLUEPRINT_VERSION` and `PLUGIN_VERSION` to values that accept v55, and
the check back to 55:
```bash
git restore --source=bf8a23b -- src/shared/RetailStoreBlueprint.luau tests/blueprint-checks.luau
```
The updater refuses a blueprint older than `MIN_BLUEPRINT_VERSION`, so skipping the plugin edit breaks **Update Map**.
This has the same catch as option 2: merging the PR would replace `main`'s layout with v55.

### Avoid
Don't `git reset --hard` or force-push this branch unless the user explicitly says to. `git revert` gets the same result
without rewriting shared history.

## Working in this repo
- The `Prodigy Drift/` folder is untracked and belongs to a separate game. Leave it out of commits here.
- `C:\Users\Heemi\Documents\roblox-game` is shared, so check `git status` first.

## Also from Nov 5: SMOKE CULT (separate repo)
If the user meant the drift game's tuning and controller changes, those are one commit, `2bea0be`, in
`C:\Users\Heemi\OneDrive\Documents\ChatGPT\game\smoke-cult` on branch `codex/github-pages`, which publishes the live site.
Undo with `git revert 2bea0be`, then `git push`. That also brings back the old public `SOURCES.md`, including the
Prodigy Drift line, so keep the clean `SOURCES.md` unless the user says otherwise:
```bash
git revert --no-commit 2bea0be
git restore --source=2bea0be --staged --worktree -- SOURCES.md
git commit -m "Undo the tuning and controller changes"
```

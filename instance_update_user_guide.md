# Instance Update — User Guide

Bulk-retarget the master (**MasterLibrary** / **MasterCell**) of instances in
the active view or selection. Companion to the Find Helper form.

## Setup

```tcl
source {<path>/instance_update.tcl}   ;# needs sed_helpers.tcl already sourced
inst_update::show
```

## The form at a glance

| Section | What it does |
|---|---|
| **Target** | Which instances to touch: optional Name regex, Scope, From library, From cell |
| **Replacement** | New master: To library, To cell |
| **History** | Recall form states you actually Ran (Prev/Next) |

## Picking the target

**From cell** offers, besides the real cells of the From library:

- `(none)` — default. Run is disabled; a safety catch so you must choose deliberately.
- `(Regex)` — enables the **From-cell regex** field below: every instance whose
  master cell matches the regex is targeted. Unanchored partial match
  (`nand2` also hits `nand2x4`) — anchor with `^...$` for exact names.
  Run stays disabled while the regex text is empty.
- `(any cell)` — at the bottom, deliberately effortful: every instance of the
  From library. Forces To-cell to `(n/a - keep cell)` (library migration).

**Name regex** (optional) additionally narrows by *instance name*; it composes
with any From-cell choice.

**Get** seeds From library/cell from the currently selected instance(s).

## Choosing the replacement

- **To cell = a real cell** → every matched instance becomes To-library/To-cell
  (many-to-one).
- **To cell = `(n/a - keep cell)`** → each instance keeps its own cell name;
  only MasterLibrary changes (library migration).

Both modes work with a single From-cell, `(Regex)`, or `(any cell)`.

### Instances whose cell is missing from the To library

Before it touches anything, **Run** reads the cell list of the To library. Any
matched instance whose target cell name is **not** in that list is left
completely untouched and reported under **SKIPPED**, with a "did you mean...?"
hint when only the letter case differs.

This matters most in keep-cell mode: the cell name is different for every
instance, so it cannot be validated by picking it from a dropdown. Without the
check, S-Edit accepts the library change, finds no such cell in the new
library, and **silently re-binds the instance to a different master** — no
error, and the old report called that a success.

Run also **refuses to start** in two cases, with different messages:

- the To library's cell list **could not be read** — without it the check
  cannot tell a real cell from a missing one, so it fails closed rather than
  guessing;
- the To library **contains no cells** — there is nothing to retarget to.

**Build Command** warns about those same states instead of quietly saying
"command built", because the command it built would skip every instance.

## Buttons

- **List** — read-only preview of what matches (containing cell, instance name,
  master cell). The only action that runs on **hierarchy** scope — use it to
  check a regex before running.
- **Build Command** — shows the `find` command without running it.
- **Run** — executes on view/selection scope and reports every instance as
  updated, SKIPPED, or FAILED. Only runs that actually started are saved to
  History (an aborted Run is not). The `->` side of an *updated* row is the
  master **read back from the instance afterwards**, not what you asked for —
  if the two disagree the row is marked `** WARNING`.
- **Copy Results** — copies the Results pane (or your selection in it) to the
  Windows clipboard.
- **Reset** — clears the form; History is preserved.

## Hierarchy-wide updates

Build and Run refuse hierarchy scope on purpose. To update across the
hierarchy: **Build** with scope `view`, copy the command, change `-scope view`
to `-scope hierarchy`, and run it at the console.

What Build shows is **self-contained**: a few `set` lines carrying the form's
criteria and the To-library cell list, the `find` command, and a trailing
`inst_update::report_results`. Paste the whole block — you get the same
Results as Run prints, SKIPPED section included. Paste only the `find` line and
the missing-cell guard has nothing to check against, so it skips everything.

## Recommended workflow

1. From library → From cell (or `(Regex)` + pattern)
2. **List** — verify the matched set
3. To library → To cell
4. **Run** — read the report

## Gotchas

- After editing the `.tcl`, re-source it **and** rebuild the window:
  `catch {destroy .instUpdate}` then `inst_update::show`.
- A bad regex isn't pre-checked; it surfaces as `find failed:` in Results.
- FAILED rows may be *partially* updated (library set, cell set failed) — check
  those instances by hand.
- A row marked `?? requested; could not read the master back` means the update
  ran but could not be verified. If *every* row is unverified you get one NOTE
  instead — this S-Edit build does not expose the new master inside the
  traversal, which is not the same as the updates having failed.
- The SKIPPED check compares cell names **exactly**. If the case-differs hint
  fires, the target library really does have that cell under a different
  spelling — retarget with an explicit To-cell instead of keep-cell.
- Recalling a History state re-checks the To cell against the To library and
  falls back to `(n/a - keep cell)` if it has gone.

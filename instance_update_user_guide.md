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

## Buttons

- **List** — read-only preview of what matches (containing cell, instance name,
  master cell). The only action that runs on **hierarchy** scope — use it to
  check a regex before running.
- **Build Command** — shows the `find` command without running it.
- **Run** — executes on view/selection scope and reports every instance as
  updated or FAILED. Runs are saved to History.
- **Copy Results** — copies the Results pane (or your selection in it) to the
  Windows clipboard.
- **Reset** — clears the form; History is preserved.

## Hierarchy-wide updates

Build and Run refuse hierarchy scope on purpose. To update across the
hierarchy: **Build** with scope `view`, copy the command, change `-scope view`
to `-scope hierarchy`, and run it at the console.

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

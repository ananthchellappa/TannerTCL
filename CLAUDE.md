# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Productivity Tcl scripts for the Siemens Tanner EDA tool suite — mostly **S-Edit** (schematic editor), with small setups for **L-Edit** (layout, in `LEdit/`) and **W-Edit** (waveform viewer, `W_Edit_shortcuts.tcl`). There is no build, lint, or test infrastructure: scripts are loaded by `source`-ing them into the tool's Tcl command console (or a startup script), and they run inside the tool's embedded Tcl interpreter with Tk available. Code cannot be exercised outside a running Tanner tool, so verify changes by reading them and reasoning about the Tanner Tcl API, not by running them here.

Much of the newer code was generated with ChatGPT; `*.prompt` / `prompt_*.txt` files preserve the prompts used to produce the matching `.tcl` files (e.g. `label_utils.prompt` → `label_utils.tcl`). Tips and background: https://tannertools.blogspot.com/

## Architecture

Two layers:

1. **Binding/menu layer** — `Ananthmenus.tcl` (current; menu root `CUSTOM`) and `S_Edit_shortcuts.tcl` (older variant; menu root `Ananth`). These contain only `workspace bindkeys -command {Name} -key "..."` and `workspace menu -name {CUSTOM {Submenu} {Name}} -command {proc_name}` lines wiring keyboard shortcuts and custom menu entries to procs. To expose a new utility, add a `workspace menu` entry (and optionally a bindkey) here.

2. **Proc layer** — everything else defines the procs those menus call:
   - `user_fns.tcl` — the `user1`..`user10` procs bound to S-Edit's "User N" commands, plus global state (`schContext`, `viewContext`, `is_docked`, `selmdfull`) shared via `upvar #0`, and many small bus/selection procs (`bussify`, `_up_bus`, `_R_AC_togl`, ...).
   - `sed_helpers.tcl` — shared helpers other files depend on (current-context parsing, cursor position, nearest-pin lookup). `snap_wire.tcl` explicitly requires it.
   - Domain utilities, one concern per file: `port_utils.tcl` (port spacing/sizing), `bus_helpers.tcl`, `label_utils.tcl`, `array_utils.tcl` (array uniformizing/naming — the hardest-won code here), `stubs.tcl`, `snap_wire.tcl`, `suffix_utils.tcl`, etc.
   - Tk UI helpers: `uiutil.tcl` (namespaced `uiutil::`, font setup), `Tk_widgets.tcl`, `multi_line_text_ed.tcl`, `font_utils.tcl`.

Menu/bindkey "User N" commands (e.g. `Alt+D` → `User 1`) dispatch to the `userN` procs in `user_fns.tcl` — that indirection exists because some keys only work in undocked windows when routed through User commands.

## Tanner Tcl idioms used throughout

- **Iterate-and-modify**: `find <type> -scope selection|view -goto none -modify { ...script run per object... }` is the standard way to loop over schematic objects; inside the `-modify` block, `property get/set -system` operates on the current object.
- **Render gating**: wrap multi-object edits in `mode renderoff` / `mode renderon` for speed.
- **Properties**: `property get -name X -system` style for object attributes (`Name`, `X`, `Y`, `FontSize`, `MasterCell`, `MasterLibrary`, `TextJustification.*`). Returns may be 1-element lists — normalize with `lindex`/`join`.
- **Bus naming convention**: net/port names like `name<M:N>` or `name<M>`, manipulated with `regexp`/`regsub` (see `_up_bus`, `_chop_bus`, `bussify` in `user_fns.tcl` for the canonical patterns).
- **Grid units**: snap-grid math must account for schematic units — multiply by `[setup schematicunits get -numerator]/[setup schematicunits get -denominator]` (see `scale_snap_grid`); raw values silently broke when this was missed.
- **Global state**: shared across procs via `upvar #0 varName local` rather than `global`.

## Gotchas

- A command that errors during startup sourcing **aborts everything after it** in that file (see comment near the end of `user_fns.tcl` about `technology simulation set`). Keep risky/design-dependent calls out of setup files or guard them with `catch`.
- Some bindkeys behave differently docked vs. undocked; that's why several `userN` procs exist and why some bindings are commented out with notes rather than deleted. Preserve those comments — they record what was already tried and failed.
- `Ananthmenus.tcl` and `S_Edit_shortcuts.tcl` overlap heavily but have drifted; `Ananthmenus.tcl` is the actively maintained one.
- Behavior differs across S-Edit versions (see the `[workspace version]` regexp check in `Ananthmenus.tcl`).

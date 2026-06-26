# find_helper — a better Find Navigator

## Goal

Replace S-Edit's weak built-in Find Navigator with a Tk form (`find_helper.tcl`)
that exposes the full power of the `find` command — including `-modify` driven
**bulk rename** of the `Name` property and a **report** of which (old) names were
hit. The form assembles a `find ...` command from its widgets and runs it against
the active S-Edit window, exactly like the hand-written `find ... -modify {...}`
one-liners already scattered through `user_fns.tcl`, `font_utils.tcl`, etc.

## Non-goals

- No new matching engine — we only build and run S-Edit `find` commands.
- No persistence of form state across sessions (can be added later).
- We do not try to validate every illegal flag combination; S-Edit rejects bad
  combos and we surface the error.

---

## Form layout

```
┌─ Find Navigator ─────────────────────────────────────────────┐
│ Object: [port ▾]            Scope: [view ▾]                   │
│                                                              │
│ Name:   [____________________________________]               │
│                                                              │
│ Match mode:   ☐ -wildcard   ☐ -regex   ☐ -nocase             │
│               ☐ -exact      ☐ -contains                      │
│                                                              │
│ Selection:    ☐ -first   ☐ -add   ☐ -sub   ☐ -count          │
│                                                              │
│ ☑ -goto none                                                 │
│ ──────────────────────────────────────────────────────────  │
│ Rename (via -modify, regsub on Name):                        │
│   From (regex): [__________________]                         │
│   To   (subst): [__________________]                         │
│ ☐ Report modified (pre-existing) names                       │
│ ──────────────────────────────────────────────────────────  │
│ [ Build Command ]   [ Run ]            [ Close ]             │
│ ──────────────────────────────────────────────────────────  │
│ Command:                                                     │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ find port -name v.*_port[12] -regex -scope view ...   │    │ (read-only)
│ └──────────────────────────────────────────────────────┘    │
│ Results:                                                     │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ 7 matched                                            ▲ │    │ (read-only,
│ │ old_a    ->  new_a                                     │    │  scrollable)
│ │ old_b    ->  new_b                                   ▼ │    │
│ └──────────────────────────────────────────────────────┘    │
│ Status: 7 found, 7 renamed, 0 failed                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Widgets → `find` arguments

| Widget | Type | Default | Emits |
|---|---|---|---|
| **Object** | `ttk::combobox` readonly `port` / `instance` / `netlabel` | `port` | `find <type>` (first token) |
| **Name** | text entry | empty | `-name <value>` (omitted if empty) |
| **Scope** | `ttk::combobox` readonly `selection` / `view` / `hierarchy` | `view` | `-scope <value>` |
| **-wildcard** | checkbox | off | `-wildcard` |
| **-regex** | checkbox | off | `-regex` |
| **-nocase** | checkbox | off | `-nocase` |
| **-exact** | checkbox | off | `-exact` |
| **-contains** | checkbox | off | `-contains` |
| **-first** | checkbox | off | `-first` |
| **-add** | checkbox | off | `-add` |
| **-sub** | checkbox | off | `-sub` |
| **-count** | checkbox | off | `-count` |
| **-goto none** | checkbox | **on** | `-goto none` (omitted when unchecked) |
| **From** | text entry | empty | drives `-modify` (regsub pattern) |
| **To** | text entry | empty | drives `-modify` (regsub replacement) |
| **Report modified names** | checkbox | off | drives `-modify` (collect old names) |

### Checkbox linkage (auto-uncheck rules, per the help text)

Implemented as `-command` callbacks on each checkbutton. **-exact** is the
strict, case-sensitive, plain-text mode, so it is exclusive with every other
match modifier; **-regex** permits **-nocase** but not **-exact**. The
clear-on-check map:

| Checking… | clears |
|---|---|
| **-wildcard** | -regex, -exact |
| **-regex** | -wildcard, -exact  *(keeps -nocase)* |
| **-exact** | -wildcard, -regex, -contains, -nocase |
| **-contains** | -exact |
| **-nocase** | -exact |
| **-add** | -sub |
| **-sub** | -add |

This satisfies: wildcard↔regex exclusive, exact↔contains exclusive, regex↔exact
exclusive (regex does not permit exact), regex+nocase allowed, exact is
case-sensitive (clears/cleared-by nocase), add↔sub exclusive. `-contains` with
`-wildcard`/`-regex` is left unconstrained (not documented as illegal); S-Edit
rejects any combo it dislikes and we surface the error.

### Argument order

```
find <type> [-name <name>] [-wildcard] [-regex] [-nocase] [-exact] [-contains] \
            [-first] [-add] [-sub] [-count] -scope <scope> [-goto none] [-modify {<script>}]
```

---

## The `-modify` script (rename + report)

`-modify` is included **iff** a rename is requested (**From** non-empty) **or**
**Report** is checked. The script operates on the current object via
`property get/set -system`, the same idiom used in `user_fns.tcl`.

Robustness decisions:

- **No string interpolation into the script.** The `-modify` body is a *static*
  braced block. The From/To entry widgets bind to `::find_helper::ffrom` /
  `::find_helper::fto`; at **Run** time these are copied into run-time scratch
  vars `::find_helper::subFrom` / `::find_helper::subTo`, which the static block
  references. (Keeping the entry vars and the script-referenced vars separate
  avoids re-reading a widget mid-sweep and avoids any brace/bracket escaping
  hazard if the regex contains `{ } [ ]`.)
- Results accumulate in namespace lists (`::find_helper::hits`,
  `::find_helper::fails`), cleared before each run. Globals are reachable from a
  `-modify` body (confirmed by `multi_line_text_ed.tcl:31`, which reads a global
  inside `-modify`).
- `property get` may return a 1-element list → normalize with `lindex ... 0`.
- Each `property set` is wrapped in `catch` so one bad/duplicate name does not
  abort the whole sweep; failures are recorded separately.

Two generated variants. When renaming, the script **always** collects
`hits`/`fails` (so the rename count is accurate); the **Report** checkbox then
only controls how much the Results box shows — the full `old -> new` list when
on, just the count when off.

**(a) Rename** (From non-empty — used whether or not Report is on):
```tcl
set _old [lindex [property get -name Name -system] 0]
set _new [regsub -all -- $::find_helper::subFrom $_old $::find_helper::subTo]
if {$_new ne $_old} {
    if {[catch {property set -name Name -system -value $_new}]} {
        lappend ::find_helper::fails [list $_old $_new]
    } else {
        lappend ::find_helper::hits  [list $_old $_new]
    }
}
```

**(b) Report only** (From empty, Report on): no rename, just collect the name of
every matched object:
```tcl
lappend ::find_helper::hits [lindex [property get -name Name -system] 0]
```

If From is empty and Report is off, **no `-modify`** is emitted — a plain find.

> Note: From/To always use Tcl `regsub -all`, independent of the `-wildcard` /
> `-regex` flags (those only affect how `-name` *finds* objects). Empty **To**
> with non-empty **From** is a valid "delete matched text" rename.

---

## Execution

- Build the argument **list** (not a string) and invoke with expansion:
  `find {*}$args`. This passes each argument literally, so the user types
  `v.*_port[12]` in the Name field **with no `[`/`]` escaping** — the brackets
  reach `find` verbatim instead of being command-substituted. (Hand-typed
  console use needs `\[ \]`; the form removes that burden.)
- When `-modify` is active, wrap the call in `mode renderoff` / `mode renderon`,
  restoring render even if `find` throws (via `catch`).
- Capture `find`'s return value: with `-count` it is the match count; otherwise
  it is whatever `find` returns (often the selection count).

### Buttons

- **Build Command** — assemble and show the command in the read-only *Command*
  box **without running**. Lets the user sanity-check before mutating.
- **Run** — assemble, show, and execute; populate *Results* and *Status*.
- **Close** — destroy the form.

### Results / Status

- *Command* box: the assembled command (for transparency / copy).
- *Results* box (read-only, scrollable): one line per hit. Rename → `old  ->  new`;
  report-only → `name`. Failures listed under a `FAILED:` heading.
- *Status* line: e.g. `7 found, 7 renamed, 0 failed`, or the error message if
  `find` threw.
- Everything is also `puts` to the console for log/history.

---

## UX details — fonts & dropdowns (get these right the first time)

This form lives next to `copy_current_cell_dialog.tcl`; match its look and reuse
its proven widget choices. Two specifics that are easy to get wrong:

**Dropdowns: use `ttk::combobox`, NOT `tk_optionMenu`.** On the target platform
`tk_optionMenu`'s popup renders its entries **blank** (the chosen value only
appears after selection). `ttk::combobox` is what `copy_current_cell_dialog.tcl`
uses and it renders correctly. For the two fixed enum pickers use `-state
readonly` (no free typing) bound straight to the namespace vars `build_args`
reads:

```tcl
ttk::combobox $top.obj -state readonly -width 12 \
    -values {port instance netlabel} \
    -textvariable ::find_helper::ftype -font FhEntry
ttk::combobox $top.sc  -state readonly -width 12 \
    -values {selection view hierarchy} \
    -textvariable ::find_helper::fscope -font FhEntry
```

**The combobox *dropdown list* uses a separate font** from the option database —
set it once or the popup entries are tiny/blank even after `-font` is set on the
widget itself (same trick as `copy_current_cell_dialog.tcl`):

```tcl
option add *TCombobox*Listbox.font FhEntry
```

**Fonts: define dedicated, larger fonts** rather than the shared `uiutil::`
sizes (which are too small here and are reused by other dialogs). Create them via
`uiutil::ensure_font` in a `find_helper::init_fonts` proc called at the top of
`show`, so other dialogs keep their sizes:

```tcl
uiutil::ensure_font FhBold   -family Arial   -size 13 -weight bold
uiutil::ensure_font FhLabel  -family Arial   -size 13
uiutil::ensure_font FhEntry  -family Courier -size 14
uiutil::ensure_font FhButton -family Arial   -size 13 -weight bold
uiutil::ensure_font FhSmall  -family Arial   -size 11
option add *TCombobox*Listbox.font FhEntry
```

Use `FhBold` for field labels/labelframes, `FhLabel` for checkbuttons,
`FhEntry` for entries/comboboxes/the read-only text boxes, `FhButton` for the
buttons, `FhSmall` for the status line.

## Public API (`find_helper` namespace)

| Proc | Purpose |
|---|---|
| `find_helper::show` | Build (or raise) the form. Bound to the menu/bindkey. |
| `find_helper::init_fonts` | Create the dedicated `Fh*` fonts + combobox-list font. |
| `find_helper::run` | Assemble + execute; fill results. |
| `find_helper::build_only` | Assemble + show the command without running. |
| `find_helper::build_args` | Return the `find` argument list from current widget state. |
| `find_helper::build_modscript {do_rename do_report}` | Return the `-modify` body. |
| `find_helper::link {which}` | Apply the checkbox auto-uncheck rules. |
| `find_helper::reset` | Restore defaults. |

State helpers (`msg_error`, etc.) reuse the existing `uiutil::` namespace.
`ttk` is already a dependency in the repo (`copy_current_cell_dialog.tcl`).

---

## Menu / bindkey wiring (`Ananthmenus.tcl`)

```tcl
workspace menu -name {CUSTOM {Useful Commands} {Find Navigator}} -command {find_helper::show}
# Ctrl+Shift+F is already taken; propose a free key:
workspace bindkeys -command {Find Navigator} -key "Ctrl+Shift+G"
```

(Bindkey is a proposal — confirm `Ctrl+Shift+G` is free/desired.)

---

## Out-of-scope / future

- Persisting last-used form values (could reuse the `.scratchrc`-style pattern).
- A live preview of matches before committing a rename (dry-run highlighting).
- Choosing the rename target property (always `Name` for now).
- Optional `-nocase` on the regsub substitution.
```

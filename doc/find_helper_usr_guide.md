# Find Navigator — User Guide

A friendlier, far more powerful replacement for S-Edit's built-in Find Navigator.
It lets you **find** ports, instances, or net labels by name (plain text,
wildcard, or regular expression), **select** them, **count** them, and — the part
that saves real time — **bulk-rename** them with a search-and-replace, while
**reporting** exactly which names it touched.

You don't need to know any Tcl to use it. If you *do* know Tcl, every click maps
to a plain `find ...` command you can read in the form.

---

## 1. Opening it

- Menu: **CUSTOM → Useful Commands → Find Navigator**
- Keyboard: **Ctrl+Shift+G**

A window titled *Find Navigator* appears. It stays open; you can run it over and
over. Open the schematic you want to work on first — the tool always acts on the
**active** S-Edit window.

---

## 2. The form at a glance

```
Object: [port ▾]            Scope: [view ▾]
Name:   [______________________________]

Match mode:   □ -wildcard  □ -regex  □ -nocase
              □ -exact     □ -contains
Selection:    □ -first  □ -add  □ -sub  □ -count
              ☑ -goto none

Rename (regsub on Name, via -modify):
   From (regex): [________________]
   To   (subst): [________________]
   □ Report modified (pre-existing) names

[ Build Command ]  [ Run ]  [ Reset ]            [ Close ]

Command:   (read-only — the exact command that will run)
Results:   (read-only, scrollable — what happened)
Status:    7 matched, 7 renamed, 0 failed
```

**Two buttons do the work:**

- **Build Command** — assembles the command and shows it in the *Command* box but
  **does not run it**. Use this to look before you leap.
- **Run** — assembles, shows, and **executes** it, then fills in *Results* and
  *Status*.

`Reset` puts every field back to defaults. `Close` hides the window.

---

## 3. Picking *what* to find

**Object** (dropdown): `port`, `instance`, or `netlabel`. This is the kind of
thing you're searching for.

**Name**: the text/pattern to match. How it's interpreted depends on the *Match
mode* checkboxes below. Leave it empty to match **everything** of that object
type in scope.

> **You never need to escape anything in the Name field.** Type
> `v.*_port[12]` exactly as written — the square brackets, dots, and stars go
> straight to S-Edit. (At the command line you'd have to type `\[12\]`; here you
> don't.)

**Scope** (dropdown): where to look.

| Scope | Meaning |
|---|---|
| `selection` | Only among objects you've already selected |
| `view` | The whole current cell/view (the usual choice) |
| `hierarchy` | The current view **and everything below it** |

---

## 4. Match mode — how the Name is interpreted

| Checkbox | What the Name means | Example Name |
|---|---|---|
| *(none)* | Exact-ish default match as S-Edit sees it | `clk` |
| **-wildcard** | Shell-style wildcards: `*` = any run, `?` = one char | `*_port*` |
| **-regex** | Full regular expression | `v.*_port[12]` |
| **-exact** | Must match the **whole** name, case-sensitive | `clk` |
| **-contains** | Name **contains** this text (partial match) | `<` |
| **-nocase** | Ignore upper/lower case (combine with the above) | — |

These are not all combinable — the form enforces the sensible rules for you by
auto-unchecking conflicting boxes:

- **-wildcard** and **-regex** are mutually exclusive (two different pattern
  languages).
- **-exact** and **-contains** are mutually exclusive.
- **-exact** is strict and case-sensitive, so checking it clears -wildcard,
  -regex, -contains, **and** -nocase.
- **-regex** works *with* **-nocase** but not with **-exact**.

So just start clicking; the form won't let you build a contradictory match mode.

**Worked matches**

- Every port whose name contains `port`, any case:
  `Object=port, Name=*_port*, ☑-wildcard ☑-nocase, Scope=view`
  → `find port -name *_port* -wildcard -nocase -scope view`
- Ports like `v…_port1` or `v…_port2` via regex, any case:
  `Name=v.*_port[12], ☑-regex ☑-nocase`
  → `find port -name v.*_port[12] -regex -nocase -scope view`
- The first port whose name contains a `<`:
  `Name=<, ☑-contains ☑-first`
  → `find port -name < -contains -first -scope view`

---

## 5. Selection options

| Checkbox | Effect |
|---|---|
| **-first** | Stop at the first match instead of all of them |
| **-add** | **Add** the matches to whatever is already selected |
| **-sub** | **Subtract** the matches from the current selection |
| **-count** | Report the number of matches (shown in *Status*) |

**-add** and **-sub** are mutually exclusive (the form enforces it). Use them to
build up or pare down a selection across several searches — e.g. select all
`clk*` ports, then `-add` all `rst*` ports.

**-goto none** (checked by default): keeps S-Edit from scrolling/zooming the view
to each match as it works. Leave it checked for bulk operations. Uncheck it only
if you want the view to jump to a match (handy with **-first**).

---

## 6. The power feature — bulk rename

The **Rename** section renames the `Name` of every matched object using a
**search-and-replace** (a Tcl `regsub`), all in one shot.

- **From (regex)** — a regular expression matched against each object's current
  name.
- **To (subst)** — what to replace the matched part with. May reference captured
  groups as `\1`, `\2`, …

The rename runs on exactly the objects your **find** criteria select (Object +
Name + Match mode + Scope), so you can target precisely.

> The From/To boxes are **always** ordinary Tcl regex/`regsub`, regardless of the
> -wildcard/-regex checkboxes above (those only control how the *Name* field
> *finds* things). Replacement is global within each name (`regsub -all`).

### Rename recipes

| Goal | From | To |
|---|---|---|
| Add a prefix `u_` to the name | `^` | `u_` |
| Add a suffix `_n` | `$` | `_n` |
| Strip a trailing `_old` | `_old$` | *(empty)* |
| Rename exactly `A` → `B` | `^A$` | `B` |
| Bump version: `foo_v1` → `foo_v2` | `(.*)_v1$` | `\1_v2` |
| Swap bus delimiters `<3:0>` → `[3:0]` | `<(\d+):(\d+)>` | `[\1:\2]` |
| Insert before bus suffix: `net<3:0>` → `net_q<3:0>` | `(<.*>)?$` | `_q\1` |

An **empty To** with a non-empty From is valid — it **deletes** the matched text
(that's how "strip a suffix" works).

### See which names changed — the Report checkbox

Tick **Report modified (pre-existing) names** to get a line-by-line list of every
rename in the *Results* box, old name → new name:

```
clk_in_port1            ->  clk_in_port1_n
clk_in_port2            ->  clk_in_port2_n
data_bus<3:0>           ->  data_bus_q<3:0>
```

With renaming, the *Status* line always tells you the totals
(`12 matched, 12 renamed, 0 failed`) even if Report is off — Report just adds the
detailed list. If a particular rename can't be applied (e.g. it would collide
with an existing name), it's listed under a **FAILED** heading and the rest still
proceed.

### Report without renaming

Leave **From** empty but tick **Report**, then **Run**: nothing is renamed, and
the *Results* box simply lists the current names of everything that matched. It's
a quick way to **audit** "what does my pattern actually hit?" before you commit to
a rename.

---

## 7. A safe workflow (recommended)

1. Set **Object**, **Name**, **Match mode**, and **Scope** for what you want.
2. Click **Build Command** and read the *Command* box. Does it look right?
3. (Optional but smart) With **From** empty, tick **Report** and **Run** to see
   the exact list of objects you're about to touch.
4. Fill in **From** / **To**, keep **Report** ticked, and **Run**.
5. Read the *Results* and *Status*. If something looks wrong, **Undo** in S-Edit
   (Ctrl+Z) and adjust.

Because a rename is a real edit, the first time you try a new pattern, narrow the
**Scope** to `selection` (select a couple of objects by hand first) so you can
confirm the result on a small set before unleashing it on the whole view or
hierarchy.

---

## 8. Reading the output

- **Command box** — the literal command being run. If you see your regex wrapped
  in `{ }` (e.g. `-name {v.*_port[12]}`), that's just Tcl showing the value as one
  token; the braces are **not** added to your search.
- **Results box** — the rename list (`old -> new`), the matched-name list
  (report-only), or `find returned: …` for a plain search. Scrollable.
- **Status line** — a one-line summary: matches found, renamed, and failed.
- Everything is also echoed to the S-Edit command console, so you have a history.

---

## 9. Quick reference — recipes

| I want to… | Object | Name | Match mode | Other |
|---|---|---|---|---|
| Select every port in the view | port | *(empty)* | — | Scope=view |
| Count net labels containing `clk` | netlabel | clk | -contains | -count |
| Select all instances named `U…` | instance | U* | -wildcard | — |
| Add `clk*` ports to current selection | port | clk* | -wildcard | -add |
| List ports matching a regex (no change) | port | `v.*_port[12]` | -regex | tick **Report**, From empty |
| Append `_n` to all matched ports | port | *(your filter)* | — | From `$`, To `_n`, **Report** |
| Strip `_tmp` suffix from net labels | netlabel | `*_tmp` | -wildcard | From `_tmp$`, To *(empty)* |

---

## 10. Troubleshooting

- **"Nothing matched."** Widen the Scope (try `view` or `hierarchy`), loosen the
  Match mode (e.g. -contains or -nocase), or check you picked the right Object
  type.
- **Dropdown shows nothing while selecting.** You're on an old copy — the current
  version uses proper combo-boxes; reload the scripts / restart S-Edit.
- **A rename shows under FAILED.** The new name likely duplicates an existing one
  or is otherwise illegal; adjust your To pattern.
- **The view jumps around during a big rename.** Make sure **-goto none** is
  checked (it is by default).
- **I made a mistake.** Use S-Edit **Undo (Ctrl+Z)** right away, then refine your
  From/To and try again on a small selection.

---

*Under the hood this form just builds and runs S-Edit `find <type> … -scope … 
[-goto none] [-modify {…}]` commands — the same mechanism used throughout these
utility scripts. See `find_helper_spec.md` for the design and `find_helper.tcl`
for the code.*

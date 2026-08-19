# instance_update.tcl
#
# Instance Update form for S-Edit: bulk-retarget the master (MasterLibrary /
# MasterCell) of instances in the active view or selection. Companion to
# find_helper.tcl and reuses its patterns (history, Build/Run, read-only
# command + results panes with working copy).
#
# Target section:   optional Name regex, From-library, From-cell.
#   From-cell defaults to "(none)" (Run disabled; Build still works) and offers
#   "(any cell)" at the BOTTOM of the list (deliberately effortful to reach).
#   "(Regex)" (right after (none)) enables the From-cell regex entry below the
#   dropdowns: instances whose MasterCell matches the regex are targeted.
#   Unanchored partial match, same semantics as the Name regex - anchor with
#   ^...$ for exact sets. Run stays disabled while the regex text is empty.
# Replacement:      To-library, To-cell dropdowns; the To-cell list re-reads the
#   cells of the chosen To-library. Picking From-cell = (any cell) forces
#   To-cell to "(n/a - keep cell)": each matched instance keeps its own cell
#   name and only MasterLibrary changes (library migration). Choosing a real
#   To-cell instead performs the many-to-one replacement. The same two modes
#   apply to (Regex): keep-cell = library-only migration of the matched cells,
#   concrete To-cell = many-to-one replacement.
#
# Missing-cell guard: before the traversal, Run snapshots the cells of the
#   To-library. Any instance whose target cell name is absent from that list is
#   left UNTOUCHED and reported under SKIPPED. This matters most in keep-cell
#   mode, where the cell name is per-instance and so cannot be validated by
#   picking it from a dropdown. Without the guard, setting MasterLibrary alone
#   leaves the instance on a library/cell pair that does not exist and S-Edit
#   silently re-binds it to some other master instead of raising.
#   Run also refuses to start if the To-library's cell list comes back empty
#   (empty library, or a failed query) - validating against an empty list would
#   skip everything and look like a broken tool.
#
# Get button:  seed From-library / From-cell from the selected instance(s).
# List button: read-only report of matching instances (From-cell (none) counts
#   as (any cell)): containing cell + instance name, plus the master cell when
#   only the library is specified. List is the one action that runs on
#   hierarchy scope; Build/Run reset hierarchy back to view with a warning
#   (copy the built command and edit -scope to run hierarchy-wide by hand).
#
# Requires sed_helpers.tcl (sed_get_library_names, sed_get_current_library).
#
# Implementation notes (same safety rules as find_helper.tcl):
#  - The command is a Tcl LIST run with `find {*}$args`; the -filter and
#    -modify bodies are STATIC braced scripts that reference namespace scratch
#    vars, so a Name regex containing { } [ ] is never string-interpolated.
#  - Matching happens in -filter (Name regex only if given, plus
#    MasterLibrary / MasterCell equality); the update happens in -modify.
#  - The missing-cell guard also lives in -modify, not -filter: skipped
#    instances stay matched, so List and the Target section keep their meaning
#    and each skip earns a report row instead of silently disappearing.
#  - The report prints the master READ BACK from each instance after the sets,
#    not the master that was requested, so a silent re-bind shows up as
#    ** WARNING instead of being reported as a clean success.
#  - Scope 'selection' adds -add: find -scope selection otherwise REPLACES the
#    selection with whatever it traversed.
#  - Every dropdown re-reads the design database in its -postcommand, so lists
#    stay fresh as libraries/cells are opened or created.
#
# Entry point: inst_update::show

namespace eval inst_update {
    # dropdown sentinels (parenthesized so they cannot collide with real names)
    variable NONE  "(none)"
    variable ANY   "(any cell)"
    variable KEEP  "(n/a - keep cell)"
    variable REGEX "(Regex)"

    # form state (bound to widgets)
    variable nameRegex ""
    variable fromLib   ""
    variable fromCell  "(none)"
    variable cellRegex ""
    variable toLib     ""
    variable toCell    "(n/a - keep cell)"
    variable fscope    view
    variable status    ""

    # run-time scratch (referenced by the static -filter / -modify bodies)
    variable fltName   ""
    variable fltLib    ""
    variable fltCell   ""   ;# empty = any cell
    variable fltCellRe ""   ;# cell-name regex; empty = no regex criterion
    variable newLib    ""
    variable newCell   ""   ;# empty = keep each instance's cell
    # Cells that exist in the To-library, snapshotted ONCE per Run (never per
    # instance). The -modify body consults this to skip any instance whose
    # kept cell name is absent from the target library. Empty = the library is
    # empty OR could not be enumerated - Run refuses to validate against that.
    variable toCells   {}
    variable toCellsOk 0    ;# 0 = toCells could NOT be enumerated (fail closed)

    variable gotonone  1

    variable hits  {}   ;# {name oldLib oldCell wantCell gotLib gotCell}
    variable skips {}   ;# {name oldLib oldCell wantCell caseHint} - untouched
    variable fails {}   ;# {name oldLib oldCell errorText}

    # {MasterLibrary MasterCell} pairs collected from the selection by Get
    variable getpairs {}

    # {containingCell instName masterCell} rows collected by List
    variable listrows {}

    variable inited 0

    # History of form states the user actually RAN (see find_helper.tcl).
    variable statevars {nameRegex fromLib fromCell cellRegex toLib toCell fscope gotonone}
    variable history  {}
    variable histidx  0
    variable histlabel "(empty)"
}

#-----------------------------------------------------------------------------
# Library / cell queries
#-----------------------------------------------------------------------------

proc inst_update::get_libs {} {
    if {[catch {set libs [sed_get_library_names]}]} { set libs {} }
    return [lsort -dictionary $libs]
}

proc inst_update::get_cells {lib} {
    if {$lib eq ""} { return {} }
    # -design FIRST: it is the form proven in this repo (open_scratch.tcl,
    # scratchpad.tcl). `database cells -libraries {...}` was observed to
    # silently ignore its argument and return the ACTIVE design's cells, so it
    # must not be the primary (it "succeeds" and masks the good form).
    if {![catch {set cells [database cells -design $lib]} err1]} {
        return [lsort -dictionary $cells]
    }
    if {![catch {set cells [database cells -libraries [list $lib]]} err2]} {
        return [lsort -dictionary $cells]
    }
    puts "inst_update: cannot list cells of '$lib': -design -> $err1 ; -libraries -> $err2"
    return {}
}

# Strict variant for the WRITE path: returns {ok cellList}. ok=0 means the
# cells could not be enumerated, which is a different thing from a library that
# is genuinely empty - the missing-cell guard must fail CLOSED on the first and
# only skip on the second.
# The `-libraries` fallback is deliberately NOT used here: it was observed to
# answer for the ACTIVE design regardless of its argument, so the guard would
# validate every instance against the wrong library's cell names and wave
# through exactly the retargets it exists to stop. Dropdown population can keep
# using the lenient get_cells - a wrong list there is cosmetic.
proc inst_update::get_cells_strict {lib} {
    if {$lib eq ""} { return [list 0 {}] }
    if {[catch {set cells [database cells -design $lib]} err]} {
        puts "inst_update: cannot list cells of '$lib' (-design): $err"
        return [list 0 {}]
    }
    return [list 1 [lsort -dictionary $cells]]
}

#-----------------------------------------------------------------------------
# Dropdown population (only sets -values; never touches the bound textvariable,
# so these are safe as -postcommand and after a history recall)
#-----------------------------------------------------------------------------

proc inst_update::populate_libs {} {
    set libs [inst_update::get_libs]
    foreach cb {.instUpdate.tgt.fle .instUpdate.rrow.rep.tle} {
        if {[winfo exists $cb]} { $cb configure -values $libs }
    }
}

# Both populate procs return the number of cells found so the change handlers
# can echo it to the status line (visible proof the event fired and of what
# the database returned).
proc inst_update::populate_from_cells {} {
    variable NONE
    variable ANY
    variable REGEX
    variable fromLib
    set cb .instUpdate.tgt.fce
    if {![winfo exists $cb]} { return 0 }
    set cells [inst_update::get_cells $fromLib]
    # (none) first = default; (Regex) next so the regex mode is easy to reach;
    # (any cell) LAST so it takes effort to reach
    $cb configure -values [concat [list $NONE $REGEX] $cells [list $ANY]]
    return [llength $cells]
}

proc inst_update::populate_to_cells {} {
    variable KEEP
    variable toLib
    set cb .instUpdate.rrow.rep.tce
    if {![winfo exists $cb]} { return 0 }
    set cells [inst_update::get_cells $toLib]
    $cb configure -values [concat [list $KEEP] $cells]
    return [llength $cells]
}

#-----------------------------------------------------------------------------
# Change handlers
#-----------------------------------------------------------------------------

proc inst_update::on_from_lib_changed {} {
    variable NONE
    variable fromLib
    variable fromCell
    # the old cell belongs to the old library -> back to the safe default
    set fromCell $NONE
    set n [inst_update::populate_from_cells]
    inst_update::set_status "From library '$fromLib': $n cell(s)"
    inst_update::refresh_run_state
}

proc inst_update::on_to_lib_changed {} {
    variable KEEP
    variable toLib
    variable toCell
    set n [inst_update::populate_to_cells]
    # keep the chosen cell if the new library also has it, else fall back
    if {$toCell ne $KEEP && [lsearch -exact [inst_update::get_cells $toLib] $toCell] < 0} {
        set toCell $KEEP
    }
    inst_update::set_status "To library '$toLib': $n cell(s)"
    inst_update::refresh_run_state
}

proc inst_update::on_from_cell_changed {} {
    variable ANY
    variable KEEP
    variable REGEX
    variable fromCell
    variable toCell
    # (any cell) forces To-cell to n/a: library-only retarget unless the user
    # deliberately picks a concrete To-cell afterwards (many-to-one)
    if {$fromCell eq $ANY} { set toCell $KEEP }
    inst_update::refresh_run_state
    # refresh_run_state has just enabled the regex entry; park the cursor there
    if {$fromCell eq $REGEX && [winfo exists .instUpdate.tgt.cre]} {
        focus .instUpdate.tgt.cre
    }
}

# "Get": seed From-library / From-cell from the selected instance(s).
# One library + one cell -> set both. One library, several cells -> set the
# library, leave From-cell at (none) for the user to pick. No instances or
# mixed libraries -> error in the report pane, form untouched.
# -add preserves the user's selection (find -scope selection without -add
# replaces it); the static -filter body only collects, nothing interpolated.
proc inst_update::get_from_selection {} {
    variable NONE
    variable getpairs
    variable fromLib
    variable fromCell

    set getpairs {}
    set rc [catch {
        find instance -scope selection -add -goto none -filter {lappend ::inst_update::getpairs [list [lindex [property get -name MasterLibrary -system] 0] [lindex [property get -name MasterCell -system] 0]]
expr 1}
    } err]
    if {$rc} {
        inst_update::set_results "Get failed:\n$err"
        inst_update::set_status "ERROR: $err"
        puts "inst_update Get ERROR: $err"
        return
    }

    if {![llength $getpairs]} {
        inst_update::set_results "Get: no instance is selected."
        inst_update::set_status "Get: nothing selected"
        return
    }

    set libs {}
    set cells {}
    foreach p $getpairs {
        foreach {l c} $p break
        if {[lsearch -exact $libs  $l] < 0} { lappend libs  $l }
        if {[lsearch -exact $cells $c] < 0} { lappend cells $c }
    }

    if {[llength $libs] > 1} {
        inst_update::set_results "Get: the [llength $getpairs] selected instance(s) come from multiple libraries ([join $libs {, }]) - nothing set."
        inst_update::set_status "Get: multiple libraries"
        return
    }

    set fromLib [lindex $libs 0]
    inst_update::populate_from_cells
    if {[llength $cells] == 1} {
        set fromCell [lindex $cells 0]
        inst_update::set_status "Get: $fromLib/$fromCell from [llength $getpairs] selected instance(s)"
    } else {
        set fromCell $NONE
        inst_update::set_results "Get: [llength $getpairs] selected instance(s) from '$fromLib' but with differing cells ([join $cells {, }]).\nFrom-cell left at $NONE - pick one manually."
        inst_update::set_status "Get: library set; multiple cells"
    }
    inst_update::refresh_run_state
}

proc inst_update::runnable {} {
    variable NONE
    variable REGEX
    variable fromLib
    variable fromCell
    variable cellRegex
    variable toLib
    variable toCell
    if {$fromCell eq $REGEX && [string trim $cellRegex] eq ""} { return 0 }
    expr {$fromLib ne "" && $toLib ne "" && $toCell ne "" \
          && $fromCell ne "" && $fromCell ne $NONE}
}

proc inst_update::refresh_run_state {} {
    variable REGEX
    variable fromCell
    # the From-cell regex entry is live only while From-cell is (Regex)
    set e .instUpdate.tgt.cre
    if {[winfo exists $e]} {
        $e configure -state [expr {$fromCell eq $REGEX ? "normal" : "disabled"}]
    }
    set b .instUpdate.bb.run
    if {![winfo exists $b]} return
    $b configure -state [expr {[inst_update::runnable] ? "normal" : "disabled"}]
}

#-----------------------------------------------------------------------------
# Command assembly
#-----------------------------------------------------------------------------

# Shared match logic for the -filter bodies: sets _ok from the optional Name
# regex, then MasterLibrary equality, then MasterCell equality (fltCell) or
# MasterCell regex (fltCellRe); at most one of the two is non-empty, both empty
# = any cell. Static braced block; the callers append a static tail, so
# nothing from the user is ever interpolated.
proc inst_update::build_match_script {} {
    return {set _ok 1
if {$::inst_update::fltName ne ""} {
    set _n [lindex [property get -name Name -system] 0]
    if {![regexp -- $::inst_update::fltName $_n]} { set _ok 0 }
}
if {$_ok && [lindex [property get -name MasterLibrary -system] 0] ne $::inst_update::fltLib} { set _ok 0 }
if {$_ok && $::inst_update::fltCell ne "" && [lindex [property get -name MasterCell -system] 0] ne $::inst_update::fltCell} { set _ok 0 }
if {$_ok && $::inst_update::fltCellRe ne "" && ![regexp -- $::inst_update::fltCellRe [lindex [property get -name MasterCell -system] 0]]} { set _ok 0 }}
}

proc inst_update::build_filter_script {} {
    return "[inst_update::build_match_script]\nexpr {\$_ok}"
}

# List variant: additionally collects {containingCell instName masterCell} per
# match. `workspace getactive` inside the find traversal returns
# {cellName viewName libraryName} of the view CONTAINING the instance - that is
# what makes hierarchy-scope listing report locations.
proc inst_update::build_list_script {} {
    set s [inst_update::build_match_script]
    append s \n {if {$_ok} {lappend ::inst_update::listrows [list [lindex [workspace getactive] 0] [lindex [property get -name Name -system] 0] [lindex [property get -name MasterCell -system] 0]]}}
    append s \n "expr {\$_ok}"
    return $s
}

# The update lives in -modify. Three outcomes per instance:
#
#  SKIPPED - the cell name this instance would keep (or the chosen To-cell)
#    does not exist in the To-library, per the toCells snapshot. NOTHING is
#    written. This is the guard the form used to lack: setting MasterLibrary
#    alone leaves the instance on a (newLib, oldCell) pair that does not
#    exist, and S-Edit was observed to silently re-bind it to some other cell
#    rather than raise - so the old "just set it and catch the error" contract
#    reported a clean success for an instance that had been retargeted to the
#    wrong master. Ordering cannot fix this (library-first passes through
#    (newLib, oldCell), cell-first through (oldLib, newCell); both are
#    unresolvable), so the check has to be pre-flight.
#    The guard lives here and not in -filter on purpose: the instance stays
#    matched, so the Target section and List keep their meaning and every
#    skipped instance earns a report row instead of vanishing silently.
#  FAILED  - a property set raised. Library is set before cell, so the
#    instance may be half-updated; reported with the error text.
#  updated - both sets returned. The new master is then READ BACK and the
#    readback (not the request) is what the report prints, so the Results pane
#    can never again assert a retarget that did not happen. Readback inside a
#    -modify body is not yet in specs/sedit_tcl_api_findings.md, so it is
#    caught: on failure the row carries "?" and says so.
proc inst_update::build_mod_script {} {
    return {set _n    [lindex [property get -name Name -system] 0]
set _oldl [lindex [property get -name MasterLibrary -system] 0]
set _oldc [lindex [property get -name MasterCell    -system] 0]
set _newc $::inst_update::newCell
if {$_newc eq ""} { set _newc $_oldc }
if {[lsearch -exact $::inst_update::toCells $_newc] < 0} {
    if {[catch {lsearch -exact -nocase $::inst_update::toCells $_newc} _i]} { set _i -1 }
    if {$_i >= 0} { set _hint [lindex $::inst_update::toCells $_i] } else { set _hint "" }
    lappend ::inst_update::skips [list $_n $_oldl $_oldc $_newc $_hint]
} elseif {[catch {
    property set -name MasterLibrary -system -value $::inst_update::newLib
    property set -name MasterCell    -system -value $_newc
} _err]} {
    lappend ::inst_update::fails [list $_n $_oldl $_oldc $_err]
} else {
    if {[catch {
        set _gotl [lindex [property get -name MasterLibrary -system] 0]
        set _gotc [lindex [property get -name MasterCell    -system] 0]
    }]} { set _gotl "?" ; set _gotc "?" }
    lappend ::inst_update::hits [list $_n $_oldl $_oldc $_newc $_gotl $_gotc]
}}
}

proc inst_update::build_args {} {
    variable fscope
    variable gotonone
    set a [list instance]
    lappend a -scope $fscope
    # -add on selection scope: `find -scope selection` REPLACES the selection
    # with what it traverses unless -add is given (the reason
    # get_from_selection uses it too). Without this a run silently shrinks the
    # user's selection to the matched subset, so a second run with broader
    # criteria under-applies.
    if {$fscope eq "selection"} { lappend a -add }
    if {$gotonone} { lappend a -goto none }
    lappend a -filter [inst_update::build_filter_script]
    lappend a -modify [inst_update::build_mod_script]
    return $a
}

# List is read-only: match criteria + the collecting filter, always -goto none.
proc inst_update::build_list_args {} {
    variable fscope
    set a [list instance]
    lappend a -scope $fscope
    if {$fscope eq "selection"} { lappend a -add }   ;# see build_args
    lappend a -goto none
    lappend a -filter [inst_update::build_list_script]
    return $a
}

# Copy widget state into the scratch vars the static scripts read, mapping the
# sentinels: (any cell) -> empty fltCell, (Regex) -> empty fltCell + the regex
# text in fltCellRe, (n/a - keep cell) -> empty newCell.
proc inst_update::set_scratch {} {
    variable NONE; variable ANY; variable KEEP; variable REGEX
    variable nameRegex; variable fromLib; variable fromCell; variable cellRegex
    variable toLib; variable toCell
    variable fltName; variable fltLib; variable fltCell; variable fltCellRe
    variable newLib; variable newCell; variable toCells; variable toCellsOk

    set fltName [string trim $nameRegex]
    set fltLib  $fromLib
    # if/else, NOT expr ternaries: expr numerically normalizes any operand
    # that parses as a number, so a cell literally named 007 / 1e5 / 1.10
    # would be silently renumbered on its way into the scratch vars.
    if {$fromCell eq $ANY || $fromCell eq $NONE || $fromCell eq $REGEX} {
        set fltCell ""
    } else {
        set fltCell $fromCell
    }
    if {$fromCell eq $REGEX} {
        set fltCellRe [string trim $cellRegex]
    } else {
        set fltCellRe ""
    }
    set newLib $toLib
    if {$toCell eq $KEEP} { set newCell "" } else { set newCell $toCell }

    # One database read per Run/List, never per instance: what the To-library
    # actually contains. build_mod_script skips any instance whose kept cell
    # name is missing from this list. toCellsOk=0 means the list is not
    # trustworthy at all - Run refuses to start rather than validate against it.
    set _tc     [inst_update::get_cells_strict $toLib]
    set toCellsOk [lindex $_tc 0]
    set toCells   [lindex $_tc 1]
}

#-----------------------------------------------------------------------------
# Build / Run
#-----------------------------------------------------------------------------

# Build and Run never operate on hierarchy scope (List does - that is its main
# use). If scope is hierarchy: reset it to view, explain in the Results pane,
# and return 1. The intended hierarchy-update route is deliberate: Build with
# view, copy the command, edit -scope to hierarchy, run at the console.
proc inst_update::hier_guard {} {
    variable fscope
    if {$fscope ne "hierarchy"} { return 0 }
    set fscope view
    inst_update::set_results "WARNING: scope was 'hierarchy' - reset to 'view'.\nBuild and Run never execute on hierarchy from this form. To update across the\nhierarchy: Build with scope 'view', copy the command, change '-scope view' to\n'-scope hierarchy', and run it at the console.\n(List runs on hierarchy directly.)"
    return 1
}

# Build must warn about exactly what Run would REFUSE to start on. The built
# command carries the missing-cell guard, so a state Run rejects does not
# corrupt anything if pasted - it silently skips every instance instead, and
# the copy-to-console route is the documented way to update hierarchy-wide.
# Reporting "command built" for that state would read as success.
proc inst_update::build_only {} {
    variable toCells
    variable toCellsOk
    variable toLib
    variable newCell
    set was_hier [inst_update::hier_guard]
    inst_update::set_scratch
    inst_update::show_cmd [inst_update::build_args] 1

    set warn ""
    if {!$toCellsOk} {
        set warn "WARNING: the cell list of To library '$toLib' could not be read (see console)."
    } elseif {![llength $toCells]} {
        set warn "WARNING: To library '$toLib' contains no cells."
    } elseif {$newCell ne "" && [lsearch -exact $toCells $newCell] < 0} {
        set warn "WARNING: To library '$toLib' has no cell '$newCell'."
    }
    if {$warn ne ""} {
        set short $warn
        append warn "\nRun would refuse to start in this state, and the command above would\nSKIP every instance rather than update it. Fix the Replacement section first."
        set prev ""
        catch {set prev [.instUpdate.res.t get 1.0 end-1c]}
        if {$was_hier && $prev ne ""} {
            inst_update::set_results "$prev\n\n$warn"
        } else {
            inst_update::set_results $warn
        }
        inst_update::set_status "built, but NOT runnable: $short"
        return
    }
    if {$was_hier} {
        inst_update::set_status "scope hierarchy -> view; command built (not run)"
    } elseif {[inst_update::runnable]} {
        inst_update::set_status "command built (not run)"
    } else {
        inst_update::set_status "command built (not run); pick a From-cell (or fill the regex) to enable Run"
    }
}

proc inst_update::run {} {
    variable hits
    variable skips
    variable fails
    variable toCells
    variable toCellsOk
    variable toLib
    variable newCell
    variable KEEP

    if {[inst_update::hier_guard]} {
        inst_update::set_status "Run blocked: scope hierarchy -> view (see Results)"
        return
    }
    if {![inst_update::runnable]} {
        variable REGEX
        variable fromCell
        if {$fromCell eq $REGEX} {
            inst_update::set_status "Run blocked: From-cell regex is empty"
        } else {
            inst_update::set_status "Run blocked: From-cell is (none)"
        }
        return
    }

    set hits  {}
    set skips {}
    set fails {}
    inst_update::set_scratch

    # Guard the guard, failing CLOSED in both directions: an unreadable cell
    # list must never be treated as "no such cell" (that would skip everything
    # and look like a broken tool), and an empty one must never be treated as
    # readable (that would validate every instance against nothing).
    if {!$toCellsOk} {
        inst_update::set_results "Run aborted: the cell list of To library '$toLib' could not be read\n(see the console for the database error).\nWithout it the missing-cell guard cannot tell a real cell from a missing one.\nNothing was changed."
        inst_update::set_status "Run aborted: cannot read cells of '$toLib'"
        return
    }
    if {![llength $toCells]} {
        inst_update::set_results "Run aborted: To library '$toLib' contains no cells.\nThere is nothing any instance could be retargeted to.\nNothing was changed."
        inst_update::set_status "Run aborted: '$toLib' is empty"
        return
    }
    # The To-cell combobox is readonly, so a freshly picked To-cell is real by
    # construction - but apply_state restores a To-cell from History without
    # re-running the on_to_lib_changed validation, and the library can change
    # under an open form. Re-check it here, where it matters.
    if {$newCell ne "" && [lsearch -exact $toCells $newCell] < 0} {
        inst_update::set_results "Run aborted: To library '$toLib' has no cell '$newCell'.\n(Recalled from History, or the library changed while the form was open.)\nPick the To-cell again, or use $KEEP.\nNothing was changed."
        inst_update::set_status "Run aborted: '$toLib' has no cell '$newCell'"
        return
    }

    inst_update::history_save

    set args [inst_update::build_args]
    inst_update::show_cmd $args 1

    catch {mode renderoff}
    set rc [catch {find {*}$args} result]
    catch {mode renderon}

    if {$rc} {
        # Do NOT return without reporting: the traversal may have already
        # updated/skipped/failed instances before the error, and those rows
        # are the only record of what the design now looks like.
        inst_update::report_results "find failed part-way through:\n$result\n"
        inst_update::set_status "ERROR: $result"
        puts "inst_update ERROR: $result"
        return
    }
    inst_update::report_results
}

# The "->" side of an updated row is the master READ BACK from the instance,
# not the master that was requested - a row can therefore contradict the
# request, and when it does it is marked ** WARNING rather than FAILED (the
# sets returned cleanly; it is S-Edit's resolution that differed). `prefix` is
# used by run to report a part-way find failure above the rows it did produce.
proc inst_update::report_results {{prefix ""}} {
    variable hits
    variable skips
    variable fails
    variable newLib

    set nhit  [llength $hits]
    set nskip [llength $skips]
    set nfail [llength $fails]
    set nwarn 0
    set nunk  0

    # Did EVERY row read back as its own PRE-write master, while at least one
    # row actually asked for a change? Then the readback is not observing the
    # write (a commit-at-body-exit model looks exactly like this) - it is not
    # evidence that S-Edit re-bound every instance. Say that once, rather than
    # stamping ** WARNING on N rows that are probably all correct: a marker
    # that fires on healthy runs is a marker nobody reads.
    set stale 0
    if {$nhit > 0} {
        set allsame 1
        set anyreq  0
        foreach h $hits {
            foreach {n oldl oldc wantc gotl gotc} $h break
            if {$gotl ne $oldl || $gotc ne $oldc} { set allsame 0 }
            if {$newLib ne $oldl || $wantc ne $oldc} { set anyreq 1 }
        }
        set stale [expr {$allsame && $anyreq}]
    }

    set lines {}
    if {$prefix ne ""} { lappend lines $prefix }
    if {$nhit == 0} {
        lappend lines "(no instances updated)"
    } else {
        if {$stale} {
            lappend lines "$nhit instance(s) updated (\"->\" = requested; see the note below):"
        } else {
            lappend lines "$nhit instance(s) updated (\"->\" = master read back afterwards):"
        }
        foreach h $hits {
            foreach {n oldl oldc wantc gotl gotc} $h break
            set flag ""
            if {$stale} {
                set shown "$newLib/$wantc"
            } elseif {$gotl eq "?" || $gotl eq "" || $gotc eq ""} {
                # readback threw, or answered with nothing - either way it says
                # nothing about the write, so do not call it a mismatch
                set shown "$newLib/$wantc"
                set flag "   ?? requested; could not read the master back to verify"
                incr nunk
            } else {
                set shown "$gotl/$gotc"
                if {$gotl ne $newLib || $gotc ne $wantc} {
                    set flag "   ** WARNING: $newLib/$wantc was requested"
                    incr nwarn
                }
            }
            lappend lines [format "  %-24s %s/%s  ->  %s%s" $n $oldl $oldc $shown $flag]
        }
        if {$stale} {
            incr nunk $nhit
            lappend lines ""
            lappend lines "NOTE: every instance read back as the master it had BEFORE the write, so"
            lappend lines "this S-Edit build does not expose the new master inside the traversal. The"
            lappend lines "\"->\" column is therefore what was REQUESTED, not what was verified. The"
            lappend lines "updates themselves were accepted without error - check a few by eye."
        }
    }
    if {$nskip > 0} {
        lappend lines ""
        lappend lines "SKIPPED - no such cell in '$newLib', left untouched:"
        foreach sk $skips {
            foreach {n oldl oldc wantc hint} $sk break
            set note ""
            if {$hint ne ""} { set note "   (case differs - did you mean '$hint'?)" }
            lappend lines [format "  %-24s %s/%s : '%s' is not a cell of %s%s" \
                               $n $oldl $oldc $wantc $newLib $note]
        }
    }
    if {$nfail > 0} {
        lappend lines ""
        lappend lines "FAILED (unchanged or partially updated):"
        foreach f $fails {
            foreach {n oldl oldc err} $f break
            lappend lines [format "  %-24s %s/%s : %s" $n $oldl $oldc $err]
        }
    }
    inst_update::set_results [join $lines "\n"]

    set msg "$nhit updated"
    if {$nskip > 0} { append msg ", $nskip skipped" }
    if {$nwarn > 0} { append msg ", $nwarn WARNING" }
    if {$nunk  > 0} { append msg ", $nunk unverified" }
    if {$nfail > 0} { append msg ", $nfail failed" }
    inst_update::set_status $msg
    puts "inst_update: $msg"
}

#-----------------------------------------------------------------------------
# List (report locations of matching instances; read-only, works on hierarchy)
#-----------------------------------------------------------------------------

# From-cell (none) is treated like (any cell) here: set_scratch maps both to an
# empty fltCell, so List only needs the library (+ optional Name regex).
# (Regex) also lists with an empty regex text (= any cell of the library).
# Output: always the containing cell + instance name; when the cell equality
# criterion is empty ((none)/(any cell)/(Regex)) the master cell column is
# added - in regex mode it shows which cells matched.
proc inst_update::list_matches {} {
    variable listrows
    variable fltCell

    set listrows {}
    inst_update::set_scratch

    set args [inst_update::build_list_args]
    inst_update::show_cmd $args

    catch {mode renderoff}
    set rc [catch {find {*}$args} result]
    catch {mode renderon}

    if {$rc} {
        inst_update::set_results "list failed:\n$result"
        inst_update::set_status "ERROR: $result"
        puts "inst_update ERROR: $result"
        return
    }

    set rows [lsort -dictionary -index 0 $listrows]   ;# group by containing cell
    set n [llength $rows]
    set lines {}
    if {$n == 0} {
        lappend lines "(nothing matched)"
    } else {
        lappend lines "$n matching instance(s):"
        if {$fltCell eq ""} {
            lappend lines [format "  %-20s %-24s %s" "In cell" "Instance" "Master cell"]
            foreach r $rows {
                foreach {cont inst master} $r break
                lappend lines [format "  %-20s %-24s %s" $cont $inst $master]
            }
        } else {
            lappend lines [format "  %-20s %s" "In cell" "Instance"]
            foreach r $rows {
                foreach {cont inst master} $r break
                lappend lines [format "  %-20s %s" $cont $inst]
            }
        }
    }
    inst_update::set_results [join $lines "\n"]
    inst_update::set_status "$n listed"
    puts "inst_update: $n listed"
}

#-----------------------------------------------------------------------------
# History (recall states the user actually ran) - same scheme as find_helper
#-----------------------------------------------------------------------------

proc inst_update::snapshot {} {
    variable statevars
    set s {}
    foreach v $statevars {
        variable $v
        lappend s $v [set $v]
    }
    return $s
}

proc inst_update::history_save {} {
    variable history
    variable histidx
    set s [inst_update::snapshot]
    if {![llength $history] || [lindex $history end] ne $s} {
        lappend history $s
    }
    set histidx [llength $history]
    inst_update::hist_update_label
}

# Returns a note to append to the caller's status line ("" when clean).
proc inst_update::apply_state {s} {
    variable KEEP
    variable toLib
    variable toCell
    foreach {v val} $s {
        variable $v
        set $v $val
    }
    # refresh the dependent cell lists for the recalled libraries (populate
    # only sets -values, so the recalled cell selections survive)
    inst_update::populate_from_cells
    inst_update::populate_to_cells

    # A recalled To-cell can be stale: <<ComboboxSelected>> never fires on a
    # history recall, so on_to_lib_changed's existence check is skipped. Fall
    # back to keep-cell rather than let Run act on a name that has since gone.
    set note ""
    if {$toCell ne $KEEP && [lsearch -exact [inst_update::get_cells $toLib] $toCell] < 0} {
        set note " - recalled To-cell '$toCell' is not in '$toLib'; reset to $KEEP"
        set toCell $KEEP
    }
    inst_update::refresh_run_state
    return $note
}

proc inst_update::hist_update_label {} {
    variable history
    variable histidx
    variable histlabel
    set n [llength $history]
    if {$n == 0} {
        set histlabel "(empty)"
    } elseif {$histidx >= $n} {
        set histlabel "$n saved"
    } else {
        set histlabel "[expr {$histidx + 1}] / $n"
    }
}

proc inst_update::history_up {} {
    variable history
    variable histidx
    set n [llength $history]
    if {$n == 0} { inst_update::set_status "history empty"; return }
    if {$histidx > 0} { incr histidx -1 }
    set note [inst_update::apply_state [lindex $history $histidx]]
    inst_update::hist_update_label
    inst_update::set_status "recalled history [expr {$histidx + 1}]/$n$note"
}

proc inst_update::history_down {} {
    variable history
    variable histidx
    set n [llength $history]
    if {$n == 0} { inst_update::set_status "history empty"; return }
    if {$histidx < $n - 1} { incr histidx }
    set note [inst_update::apply_state [lindex $history $histidx]]
    inst_update::hist_update_label
    inst_update::set_status "recalled history [expr {$histidx + 1}]/$n$note"
}

#-----------------------------------------------------------------------------
# Copy pane text to the OS clipboard (S-Edit shadows Tk's `clipboard`; go
# through clip.exe instead - see find_helper.tcl for the full story)
#-----------------------------------------------------------------------------

proc inst_update::copy_results {{t .instUpdate.res.t}} {
    if {![winfo exists $t]} return

    if {[llength [$t tag ranges sel]]} {
        set txt [$t get sel.first sel.last]
    } else {
        set txt [$t get 1.0 end-1c]
    }
    if {$txt eq ""} {
        inst_update::set_status "nothing to copy"
        return
    }

    if {[catch {
        set fh [open "|clip" w]
        puts -nonewline $fh $txt
        close $fh
    } err]} {
        inst_update::set_status "clipboard unavailable; dumped to console"
        puts "inst_update copy failed ($err); text follows:\n$txt"
        return
    }
    inst_update::set_status "copied [string length $txt] chars to clipboard"
}

#-----------------------------------------------------------------------------
# Read-only text helpers
#-----------------------------------------------------------------------------

proc inst_update::set_txt {path text} {
    if {![winfo exists $path]} return
    $path configure -state normal
    $path delete 1.0 end
    $path insert 1.0 $text
    $path configure -state disabled
}

# The -filter and -modify bodies read namespace scratch variables, which the
# command pane's text cannot see once it is copied to the console. `full`
# emits them as literal `set` lines plus the trailing report call, so the
# copied command is self-contained: paste it, change -scope view to
# -scope hierarchy, run it, and you get the same Results as Run would print.
# Every value goes through [list], so cell/library names containing spaces,
# braces or $ survive intact.
proc inst_update::cmd_preamble {} {
    set p {}
    foreach v {fltName fltLib fltCell fltCellRe newLib newCell toCells} {
        variable $v
        lappend p "set ::inst_update::$v [list [set $v]]"
    }
    lappend p "set ::inst_update::hits {} ; set ::inst_update::skips {} ; set ::inst_update::fails {}"
    return [join $p "\n"]
}

proc inst_update::show_cmd {arglist {full 0}} {
    if {$full} {
        set txt "[inst_update::cmd_preamble]\nfind $arglist\ninst_update::report_results"
    } else {
        set txt "find $arglist"
    }
    inst_update::set_txt .instUpdate.cmdf.t $txt
}

proc inst_update::set_results {text} {
    inst_update::set_txt .instUpdate.res.t $text
}

proc inst_update::set_status {text} {
    variable status
    set status $text
}

#-----------------------------------------------------------------------------
# Reset
#-----------------------------------------------------------------------------

proc inst_update::reset {} {
    variable NONE; variable KEEP
    variable nameRegex; set nameRegex ""
    variable cellRegex; set cellRegex ""
    variable fscope;    set fscope view
    variable gotonone;  set gotonone 1

    set libs [inst_update::get_libs]
    if {[catch {set cur [sed_get_current_library]}] || $cur eq "" \
            || [lsearch -exact $libs $cur] < 0} {
        set cur [lindex $libs 0]
    }
    variable fromLib;  set fromLib  $cur
    variable toLib;    set toLib    $cur
    variable fromCell; set fromCell $NONE
    variable toCell;   set toCell   $KEEP

    inst_update::populate_libs
    inst_update::populate_from_cells
    inst_update::populate_to_cells

    # Reset clears the form but PRESERVES history; just re-park the cursor.
    variable history
    variable histidx;  set histidx [llength $history]
    inst_update::hist_update_label
    inst_update::set_status ""
    catch {inst_update::set_results ""}
    catch {inst_update::set_txt .instUpdate.cmdf.t ""}
    inst_update::refresh_run_state
}

#-----------------------------------------------------------------------------
# Form
#-----------------------------------------------------------------------------

proc inst_update::init_fonts {} {
    uiutil::ensure_font IuBold   -family Arial   -size 13 -weight bold
    uiutil::ensure_font IuLabel  -family Arial   -size 13
    uiutil::ensure_font IuEntry  -family Courier -size 14
    uiutil::ensure_font IuButton -family Arial   -size 13 -weight bold
    uiutil::ensure_font IuSmall  -family Arial   -size 11
    # combobox popup list font comes from the option DB (see find_helper.tcl)
    option add *TCombobox*Listbox.font IuEntry
}

proc inst_update::show {} {
    variable inited
    uiutil::init
    inst_update::init_fonts

    set w .instUpdate
    if {[winfo exists $w]} {
        inst_update::populate_libs
        wm deiconify $w
        raise $w
        return
    }

    toplevel $w
    wm title $w "Instance Update"
    wm resizable $w 1 1

    # --- target ---
    labelframe $w.tgt -text "Target (which instances)" -font IuBold
    pack $w.tgt -side top -fill x -padx 10 -pady {10 4}
    label $w.tgt.nml -text "Name regex (optional):" -font IuLabel
    entry $w.tgt.nme -textvariable ::inst_update::nameRegex -font IuEntry -width 26
    label $w.tgt.scl -text "Scope:" -font IuLabel
    ttk::combobox $w.tgt.sce -state readonly -width 10 \
        -values {view selection hierarchy} \
        -textvariable ::inst_update::fscope -font IuEntry
    button $w.tgt.list -text "List" -font IuButton \
        -command inst_update::list_matches
    grid $w.tgt.nml $w.tgt.nme $w.tgt.scl $w.tgt.sce $w.tgt.list -sticky w -padx 4 -pady 2
    grid configure $w.tgt.list -sticky ew

    label $w.tgt.fll -text "From library:" -font IuLabel
    ttk::combobox $w.tgt.fle -state readonly -width 22 \
        -textvariable ::inst_update::fromLib -font IuEntry \
        -postcommand inst_update::populate_libs
    label $w.tgt.fcl -text "From cell:" -font IuLabel
    ttk::combobox $w.tgt.fce -state readonly -width 24 \
        -textvariable ::inst_update::fromCell -font IuEntry \
        -postcommand inst_update::populate_from_cells
    button $w.tgt.get -text "Get" -font IuButton \
        -command inst_update::get_from_selection
    grid $w.tgt.fll $w.tgt.fle $w.tgt.fcl $w.tgt.fce $w.tgt.get -sticky w -padx 4 -pady 2
    grid configure $w.tgt.get -sticky ew
    grid configure $w.tgt.fce -sticky ew
    grid columnconfigure $w.tgt 3 -weight 1
    bind $w.tgt.fle <<ComboboxSelected>> inst_update::on_from_lib_changed
    bind $w.tgt.fce <<ComboboxSelected>> inst_update::on_from_cell_changed

    # From-cell regex row: enabled only while From-cell is (Regex); unanchored
    # partial match like the Name regex. KeyRelease keeps the Run button state
    # in step with the text (empty regex = Run disabled).
    label $w.tgt.crl -text "From-cell regex:" -font IuLabel
    entry $w.tgt.cre -textvariable ::inst_update::cellRegex -font IuEntry \
        -width 26 -state disabled
    grid $w.tgt.crl -row 2 -column 0 -sticky w  -padx 4 -pady 2
    grid $w.tgt.cre -row 2 -column 1 -columnspan 3 -sticky ew -padx 4 -pady 2
    bind $w.tgt.cre <KeyRelease> inst_update::refresh_run_state

    # --- -goto none ---
    checkbutton $w.goto -text "-goto none" -variable ::inst_update::gotonone -font IuLabel
    pack $w.goto -side top -anchor w -padx 14 -pady 2

    # --- replacement + history (side by side) ---
    set rrow [frame $w.rrow]
    pack $rrow -side top -fill x -padx 10 -pady 4

    # Replacement absorbs any extra width (its comboboxes stretch with it);
    # History stays just wide enough for the Prev/Next buttons.
    labelframe $rrow.rep -text "Replacement (new master)" -font IuBold
    pack $rrow.rep -side left -fill both -expand 1
    label $rrow.rep.tll -text "To library:" -font IuLabel
    ttk::combobox $rrow.rep.tle -state readonly -width 22 \
        -textvariable ::inst_update::toLib -font IuEntry \
        -postcommand inst_update::populate_libs
    label $rrow.rep.tcl -text "To cell:" -font IuLabel
    ttk::combobox $rrow.rep.tce -state readonly -width 24 \
        -textvariable ::inst_update::toCell -font IuEntry \
        -postcommand inst_update::populate_to_cells
    grid $rrow.rep.tll $rrow.rep.tle -sticky w -padx 4 -pady 2
    grid $rrow.rep.tcl $rrow.rep.tce -sticky w -padx 4 -pady 2
    grid configure $rrow.rep.tle $rrow.rep.tce -sticky ew
    grid columnconfigure $rrow.rep 1 -weight 1
    bind $rrow.rep.tle <<ComboboxSelected>> inst_update::on_to_lib_changed
    bind $rrow.rep.tce <<ComboboxSelected>> inst_update::refresh_run_state

    labelframe $rrow.hist -text "History" -font IuBold
    pack $rrow.hist -side left -fill y -padx {10 0}
    button $rrow.hist.up -text "▲ Prev" -font IuButton \
        -command inst_update::history_up
    button $rrow.hist.dn -text "▼ Next" -font IuButton \
        -command inst_update::history_down
    label $rrow.hist.lbl -textvariable ::inst_update::histlabel -font IuSmall \
        -anchor center
    pack $rrow.hist.up  -side top -padx 8 -pady {4 2} -fill x
    pack $rrow.hist.dn  -side top -padx 8 -pady 2 -fill x
    pack $rrow.hist.lbl -side top -padx 8 -pady {2 4} -fill x

    # --- buttons ---
    set bb [frame $w.bb]
    pack $bb -side top -fill x -padx 10 -pady 6
    button $bb.build -text "Build Command" -font IuButton -command inst_update::build_only
    button $bb.run   -text "Run"           -font IuButton -command inst_update::run
    button $bb.copy  -text "Copy Results"  -font IuButton -command inst_update::copy_results
    button $bb.reset -text "Reset"         -font IuButton -command inst_update::reset
    button $bb.close -text "Close"         -font IuButton -command [list destroy $w]
    pack $bb.build $bb.run $bb.copy $bb.reset -side left -padx 4
    pack $bb.close -side right -padx 4

    # --- command box (tall enough to scroll: the command embeds the -filter
    # and -modify scripts) ---
    label $w.cmdl -text "Command:" -font IuBold -anchor w
    pack $w.cmdl -side top -fill x -padx 10
    frame $w.cmdf
    pack $w.cmdf -side top -fill x -padx 10
    text $w.cmdf.t -height 6 -wrap word -font IuEntry \
        -yscrollcommand [list $w.cmdf.sb set]
    scrollbar $w.cmdf.sb -command [list $w.cmdf.t yview]
    pack $w.cmdf.sb -side right -fill y
    pack $w.cmdf.t -side left -fill x -expand 1
    $w.cmdf.t configure -state disabled

    # --- results box ---
    label $w.resl -text "Results:" -font IuBold -anchor w
    pack $w.resl -side top -fill x -padx 10
    frame $w.res
    pack $w.res -side top -fill both -expand 1 -padx 10 -pady {0 4}
    text $w.res.t -height 10 -wrap none -font IuEntry \
        -yscrollcommand [list $w.res.sb set]
    scrollbar $w.res.sb -command [list $w.res.t yview]
    pack $w.res.sb -side right -fill y
    pack $w.res.t -side left -fill both -expand 1
    $w.res.t configure -state disabled

    # Preempt the crashing stock copy binding on both read-only panes (the
    # embedded interpreter shadows Tk's `clipboard`; see find_helper.tcl).
    # Text in a disabled text widget is still mouse-selectable, so the built
    # command can be selected and copied.
    foreach _t [list $w.res.t $w.cmdf.t] {
        bind $_t <<Copy>>         {inst_update::copy_results %W; break}
        bind $_t <Control-c>      {inst_update::copy_results %W; break}
        bind $_t <Control-Insert> {inst_update::copy_results %W; break}
    }

    # --- status ---
    label $w.status -textvariable ::inst_update::status -font IuSmall -anchor w
    pack $w.status -side top -fill x -padx 10 -pady {2 8}

    # populate dropdowns from the live database only after the widgets exist
    if {!$inited} { inst_update::reset; set inited 1 }
    inst_update::populate_libs
    inst_update::populate_from_cells
    inst_update::populate_to_cells
    inst_update::refresh_run_state
}

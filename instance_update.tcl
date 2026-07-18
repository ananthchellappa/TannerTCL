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

    variable gotonone  1

    variable hits  {}
    variable fails {}

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

# The update lives in -modify. Library is set before cell so that a keep-cell
# migration validates against the NEW library. Both sets share one catch: if
# the second fails the instance may be half-updated, so it is reported under
# FAILED with the error text.
proc inst_update::build_mod_script {} {
    return {set _n    [lindex [property get -name Name -system] 0]
set _oldl [lindex [property get -name MasterLibrary -system] 0]
set _oldc [lindex [property get -name MasterCell    -system] 0]
set _newc $::inst_update::newCell
if {$_newc eq ""} { set _newc $_oldc }
if {[catch {
    property set -name MasterLibrary -system -value $::inst_update::newLib
    property set -name MasterCell    -system -value $_newc
} _err]} {
    lappend ::inst_update::fails [list $_n $_oldl $_oldc $_err]
} else {
    lappend ::inst_update::hits  [list $_n $_oldl $_oldc $_newc]
}}
}

proc inst_update::build_args {} {
    variable fscope
    variable gotonone
    set a [list instance]
    lappend a -scope $fscope
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
    variable newLib; variable newCell

    set fltName [string trim $nameRegex]
    set fltLib  $fromLib
    set fltCell [expr {($fromCell eq $ANY || $fromCell eq $NONE || $fromCell eq $REGEX) ? "" : $fromCell}]
    set fltCellRe [expr {$fromCell eq $REGEX ? [string trim $cellRegex] : ""}]
    set newLib  $toLib
    set newCell [expr {$toCell eq $KEEP ? "" : $toCell}]
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

proc inst_update::build_only {} {
    set was_hier [inst_update::hier_guard]
    inst_update::set_scratch
    inst_update::show_cmd [inst_update::build_args]
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
    variable fails

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

    set hits {}
    set fails {}
    inst_update::set_scratch
    inst_update::history_save

    set args [inst_update::build_args]
    inst_update::show_cmd $args

    catch {mode renderoff}
    set rc [catch {find {*}$args} result]
    catch {mode renderon}

    if {$rc} {
        inst_update::set_results "find failed:\n$result"
        inst_update::set_status "ERROR: $result"
        puts "inst_update ERROR: $result"
        return
    }
    inst_update::report_results
}

proc inst_update::report_results {} {
    variable hits
    variable fails
    variable newLib

    set nhit  [llength $hits]
    set nfail [llength $fails]

    set lines {}
    if {$nhit == 0} {
        lappend lines "(no instances updated)"
    } else {
        lappend lines "$nhit instance(s) updated:"
        foreach h $hits {
            foreach {n oldl oldc newc} $h break
            lappend lines [format "  %-24s %s/%s  ->  %s/%s" $n $oldl $oldc $newLib $newc]
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

proc inst_update::apply_state {s} {
    foreach {v val} $s {
        variable $v
        set $v $val
    }
    # refresh the dependent cell lists for the recalled libraries (populate
    # only sets -values, so the recalled cell selections survive)
    inst_update::populate_from_cells
    inst_update::populate_to_cells
    inst_update::refresh_run_state
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
    inst_update::apply_state [lindex $history $histidx]
    inst_update::hist_update_label
    inst_update::set_status "recalled history [expr {$histidx + 1}]/$n"
}

proc inst_update::history_down {} {
    variable history
    variable histidx
    set n [llength $history]
    if {$n == 0} { inst_update::set_status "history empty"; return }
    if {$histidx < $n - 1} { incr histidx }
    inst_update::apply_state [lindex $history $histidx]
    inst_update::hist_update_label
    inst_update::set_status "recalled history [expr {$histidx + 1}]/$n"
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

proc inst_update::show_cmd {arglist} {
    inst_update::set_txt .instUpdate.cmdf.t "find $arglist"
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

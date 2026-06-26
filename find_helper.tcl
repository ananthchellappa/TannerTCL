# find_helper.tcl
#
# A better Find Navigator for S-Edit. A Tk form that assembles and runs a
# `find <port|instance|netlabel> ...` command against the active window,
# including -modify-driven bulk rename of the Name property (regsub on
# From -> To) and an optional report of which (old) names were hit.
#
# See find_helper_spec.md for the full design. Entry points:
#   find_helper::show     - raise the form (menu / bindkey)
#   find_helper::run      - assemble + execute
#   find_helper::build_only - assemble + show command, do not run
#   find_helper::reset    - restore defaults
#
# Implementation notes:
#  - The command is built as a Tcl LIST and run with `find {*}$args`, so values
#    like  v.*_port[12]  reach `find` verbatim -- the user never has to escape
#    [ and ] in the form (unlike at the console).
#  - The -modify body is a STATIC braced script that references namespace
#    variables (::find_helper::subFrom / subTo). Nothing from the user is
#    string-interpolated into it, so a regex containing { } [ ] is safe.
#  - Per-object results accumulate in ::find_helper::hits / ::find_helper::fails
#    (reachable from inside a -modify body, as in multi_line_text_ed.tcl).

namespace eval find_helper {
    # form state (bound to widgets)
    variable ftype    port
    variable fname    ""
    variable fscope   view
    variable wildcard 0
    variable regex    0
    variable nocase   0
    variable exact    0
    variable contains 0
    variable first    0
    variable add      0
    variable sub      0
    variable count    0
    variable gotonone 1
    variable ffrom    ""
    variable fto      ""
    variable report   0
    variable status   ""

    # run-time scratch (referenced by the generated -modify body)
    variable subFrom  ""
    variable subTo    ""
    variable hits     {}
    variable fails    {}

    variable inited   0
}

#-----------------------------------------------------------------------------
# Checkbox linkage (auto-uncheck rules)
#-----------------------------------------------------------------------------

proc find_helper::link {which} {
    variable wildcard
    variable regex
    variable nocase
    variable exact
    variable contains
    variable add
    variable sub

    switch -- $which {
        wildcard { if {$wildcard} { set regex 0; set exact 0 } }
        regex    { if {$regex}    { set wildcard 0; set exact 0 } }
        exact    { if {$exact}    { set wildcard 0; set regex 0; set contains 0; set nocase 0 } }
        contains { if {$contains} { set exact 0 } }
        nocase   { if {$nocase}   { set exact 0 } }
        add      { if {$add}      { set sub 0 } }
        sub      { if {$sub}      { set add 0 } }
    }
}

#-----------------------------------------------------------------------------
# Command assembly
#-----------------------------------------------------------------------------

# Return the -modify body. Renaming always collects hits/fails so the rename
# count is accurate; the Report checkbox only controls how much is displayed.
proc find_helper::build_modscript {do_rename do_report} {
    if {$do_rename} {
        return {set _old [lindex [property get -name Name -system] 0]
set _new [regsub -all -- $::find_helper::subFrom $_old $::find_helper::subTo]
if {$_new ne $_old} {
    if {[catch {property set -name Name -system -value $_new}]} {
        lappend ::find_helper::fails [list $_old $_new]
    } else {
        lappend ::find_helper::hits [list $_old $_new]
    }
}}
    } elseif {$do_report} {
        return {lappend ::find_helper::hits [lindex [property get -name Name -system] 0]}
    }
    return ""
}

# Return the argument list that follows the literal `find`.
proc find_helper::build_args {} {
    variable ftype
    variable fname
    variable fscope
    variable wildcard
    variable regex
    variable nocase
    variable exact
    variable contains
    variable first
    variable add
    variable sub
    variable count
    variable gotonone
    variable ffrom
    variable report

    set a [list $ftype]
    if {[string trim $fname] ne ""} { lappend a -name $fname }
    if {$wildcard} { lappend a -wildcard }
    if {$regex}    { lappend a -regex }
    if {$nocase}   { lappend a -nocase }
    if {$exact}    { lappend a -exact }
    if {$contains} { lappend a -contains }
    if {$first}    { lappend a -first }
    if {$add}      { lappend a -add }
    if {$sub}      { lappend a -sub }
    if {$count}    { lappend a -count }
    lappend a -scope $fscope
    if {$gotonone} { lappend a -goto none }

    set do_rename [expr {[string trim $ffrom] ne ""}]
    set do_report $report
    if {$do_rename || $do_report} {
        lappend a -modify [find_helper::build_modscript $do_rename $do_report]
    }
    return $a
}

#-----------------------------------------------------------------------------
# Run
#-----------------------------------------------------------------------------

proc find_helper::build_only {} {
    variable ffrom
    variable fto
    variable subFrom
    variable subTo
    set subFrom $ffrom
    set subTo $fto
    set args [find_helper::build_args]
    find_helper::show_cmd $args
    find_helper::set_status "command built (not run)"
}

proc find_helper::run {} {
    variable ffrom
    variable fto
    variable report
    variable subFrom
    variable subTo
    variable hits
    variable fails

    set hits {}
    set fails {}
    set subFrom $ffrom
    set subTo $fto

    set args [find_helper::build_args]
    find_helper::show_cmd $args

    set do_modify [expr {[string trim $ffrom] ne "" || $report}]

    if {$do_modify} { catch {mode renderoff} }
    set rc [catch {find {*}$args} result]
    if {$do_modify} { catch {mode renderon} }

    if {$rc} {
        find_helper::set_results "find failed:\n$result"
        find_helper::set_status "ERROR: $result"
        puts "find_helper ERROR: $result"
        return
    }
    find_helper::report_results $result
}

proc find_helper::report_results {findret} {
    variable hits
    variable fails
    variable ffrom
    variable report
    variable count

    set do_rename [expr {[string trim $ffrom] ne ""}]
    set nhit  [llength $hits]
    set nfail [llength $fails]

    set lines {}
    if {$do_rename} {
        if {$report} {
            foreach h $hits {
                lappend lines [format "%-30s ->  %s" [lindex $h 0] [lindex $h 1]]
            }
            if {$nhit == 0} { lappend lines "(no names changed)" }
        } else {
            lappend lines "$nhit renamed. Enable 'Report' to list the names."
        }
        if {$nfail > 0} {
            lappend lines ""
            lappend lines "FAILED (name unchanged):"
            foreach f $fails {
                lappend lines [format "%-30s ->  %s" [lindex $f 0] [lindex $f 1]]
            }
        }
    } elseif {$report} {
        foreach h $hits { lappend lines [lindex $h 0] }
        if {$nhit == 0} { lappend lines "(nothing matched)" }
    } else {
        lappend lines "find returned: $findret"
    }
    find_helper::set_results [join $lines "\n"]

    # status line
    set parts {}
    if {$count} {
        lappend parts "$findret found"
    } elseif {$do_rename || $report} {
        lappend parts "$nhit matched"
    } else {
        lappend parts "returned $findret"
    }
    if {$do_rename} { lappend parts "$nhit renamed" }
    if {$nfail > 0} { lappend parts "$nfail failed" }
    set msg [join $parts ", "]
    find_helper::set_status $msg
    puts "find_helper: $msg"
}

#-----------------------------------------------------------------------------
# Read-only text helpers
#-----------------------------------------------------------------------------

proc find_helper::set_txt {path text} {
    if {![winfo exists $path]} return
    $path configure -state normal
    $path delete 1.0 end
    $path insert 1.0 $text
    $path configure -state disabled
}

proc find_helper::show_cmd {arglist} {
    find_helper::set_txt .findHelper.cmd "find $arglist"
}

proc find_helper::set_results {text} {
    find_helper::set_txt .findHelper.res.t $text
}

proc find_helper::set_status {text} {
    variable status
    set status $text
}

#-----------------------------------------------------------------------------
# Reset
#-----------------------------------------------------------------------------

proc find_helper::reset {} {
    variable ftype;    set ftype port
    variable fname;    set fname ""
    variable fscope;   set fscope view
    foreach v {wildcard regex nocase exact contains first add sub count} {
        variable $v
        set $v 0
    }
    variable gotonone; set gotonone 1
    variable ffrom;    set ffrom ""
    variable fto;      set fto ""
    variable report;   set report 0
    find_helper::set_status ""
    catch {find_helper::set_results ""}
    catch {find_helper::set_txt .findHelper.cmd ""}
}

#-----------------------------------------------------------------------------
# Form
#-----------------------------------------------------------------------------

# Dedicated, larger fonts for this form so other dialogs keep their sizes.
proc find_helper::init_fonts {} {
    uiutil::ensure_font FhBold   -family Arial   -size 13 -weight bold
    uiutil::ensure_font FhLabel  -family Arial   -size 13
    uiutil::ensure_font FhEntry  -family Courier -size 14
    uiutil::ensure_font FhButton -family Arial   -size 13 -weight bold
    uiutil::ensure_font FhSmall  -family Arial   -size 11
    # ttk::combobox dropdown list uses a separate font set via the option DB
    # (same trick as copy_current_cell_dialog.tcl) -- without this the popup
    # entries render blank.
    option add *TCombobox*Listbox.font FhEntry
}

proc find_helper::show {} {
    variable inited
    uiutil::init
    find_helper::init_fonts

    set w .findHelper
    if {[winfo exists $w]} {
        wm deiconify $w
        raise $w
        return
    }
    if {!$inited} { find_helper::reset; set inited 1 }

    toplevel $w
    wm title $w "Find Navigator"
    wm resizable $w 1 1

    # --- object + scope ---
    set top [frame $w.top]
    pack $top -side top -fill x -padx 10 -pady {10 4}
    label $top.objl -text "Object:" -font FhBold
    ttk::combobox $top.obj -state readonly -width 12 \
        -values {port instance netlabel} \
        -textvariable ::find_helper::ftype -font FhEntry
    label $top.scl -text "Scope:" -font FhBold
    ttk::combobox $top.sc -state readonly -width 12 \
        -values {selection view hierarchy} \
        -textvariable ::find_helper::fscope -font FhEntry
    grid $top.objl $top.obj $top.scl $top.sc -sticky w -padx 4 -pady 2

    # --- name ---
    set nm [frame $w.nm]
    pack $nm -side top -fill x -padx 10 -pady 4
    label $nm.l -text "Name:" -font FhBold
    entry $nm.e -textvariable ::find_helper::fname -font FhEntry -width 44
    pack $nm.l -side left
    pack $nm.e -side left -fill x -expand 1

    # --- match mode ---
    labelframe $w.mm -text "Match mode" -font FhBold
    pack $w.mm -side top -fill x -padx 10 -pady 4
    foreach {label var} {-wildcard wildcard -regex regex -nocase nocase -exact exact -contains contains} {
        checkbutton $w.mm.$var -text $label -variable ::find_helper::$var \
            -font FhLabel -command [list find_helper::link $var]
    }
    grid $w.mm.wildcard $w.mm.regex $w.mm.nocase -sticky w -padx 6
    grid $w.mm.exact $w.mm.contains -sticky w -padx 6

    # --- selection flags ---
    labelframe $w.sel -text "Selection" -font FhBold
    pack $w.sel -side top -fill x -padx 10 -pady 4
    foreach {label var} {-first first -add add -sub sub -count count} {
        checkbutton $w.sel.$var -text $label -variable ::find_helper::$var \
            -font FhLabel -command [list find_helper::link $var]
    }
    grid $w.sel.first $w.sel.add $w.sel.sub $w.sel.count -sticky w -padx 6

    # --- goto none ---
    checkbutton $w.goto -text "-goto none" -variable ::find_helper::gotonone -font FhLabel
    pack $w.goto -side top -anchor w -padx 14 -pady 2

    # --- rename ---
    labelframe $w.rn -text "Rename (regsub on Name, via -modify)" -font FhBold
    pack $w.rn -side top -fill x -padx 10 -pady 4
    label $w.rn.fl -text "From (regex):" -font FhLabel
    entry $w.rn.fe -textvariable ::find_helper::ffrom -font FhEntry -width 32
    label $w.rn.tl -text "To (subst):" -font FhLabel
    entry $w.rn.te -textvariable ::find_helper::fto -font FhEntry -width 32
    grid $w.rn.fl $w.rn.fe -sticky w -padx 4 -pady 2
    grid $w.rn.tl $w.rn.te -sticky w -padx 4 -pady 2
    checkbutton $w.rn.rep -text "Report modified (pre-existing) names" \
        -variable ::find_helper::report -font FhLabel
    grid $w.rn.rep -sticky w -padx 4 -pady 2 -columnspan 2

    # --- buttons ---
    set bb [frame $w.bb]
    pack $bb -side top -fill x -padx 10 -pady 6
    button $bb.build -text "Build Command" -font FhButton -command find_helper::build_only
    button $bb.run   -text "Run"           -font FhButton -command find_helper::run
    button $bb.reset -text "Reset"         -font FhButton -command find_helper::reset
    button $bb.close -text "Close"         -font FhButton -command [list destroy $w]
    pack $bb.build $bb.run $bb.reset -side left -padx 4
    pack $bb.close -side right -padx 4

    # --- command box ---
    label $w.cmdl -text "Command:" -font FhBold -anchor w
    pack $w.cmdl -side top -fill x -padx 10
    text $w.cmd -height 3 -wrap word -font FhEntry
    pack $w.cmd -side top -fill x -padx 10
    $w.cmd configure -state disabled

    # --- results box ---
    label $w.resl -text "Results:" -font FhBold -anchor w
    pack $w.resl -side top -fill x -padx 10
    frame $w.res
    pack $w.res -side top -fill both -expand 1 -padx 10 -pady {0 4}
    text $w.res.t -height 10 -wrap none -font FhEntry \
        -yscrollcommand [list $w.res.sb set]
    scrollbar $w.res.sb -command [list $w.res.t yview]
    pack $w.res.sb -side right -fill y
    pack $w.res.t -side left -fill both -expand 1
    $w.res.t configure -state disabled

    # --- status ---
    label $w.status -textvariable ::find_helper::status -font FhSmall -anchor w
    pack $w.status -side top -fill x -padx 10 -pady {2 8}
}

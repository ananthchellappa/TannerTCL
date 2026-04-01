proc pop {} {

    # Get active context
    set ctx [workspace getactive -context]
    if {![llength $ctx]} { return }

    # Normalize single-level case into list-of-records
    # (so ctx is always a list of {cell view lib inst} records)
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    set depth [llength $ctx]

    # Instance we are "popping out of" = last record's instance name
    set poppedInst [lindex [lindex $ctx end] end]

    # Anchor info
    set tpc [workspace getactive -toplevel_cell]
    set dsn [workspace getactive -toplevel_design]
    set vu  [workspace getactive -toplevel_view]

    mode renderoff

    if {$depth <= 1} {
        # We were at top or only one level down -> go to top level
        cell open -cell $tpc -design $dsn -type schematic -view $vu

        # Re-select the instance we just popped out of (now visible at top)
        set poppedInst [sed_resolve_inst_names_for_parent $poppedInst]
        find instance -name $poppedInst
        window fit

        mode renderon
        return
    }

    # Build parent context path excluding the last level
    set b [list]
    for {set i 0} {$i < $depth-1} {incr i} {
        lappend b [lindex [lindex $ctx $i] end]
    }
    set parentCxt [join $b "/"]

    # Open the parent context (one level up)
    cell open \
        -cell    $tpc \
        -design  $dsn \
        -type    schematic \
        -view    $vu \
        -context $parentCxt \
        -tracenets

    # Re-select the instance we just popped out of (in the parent schematic)
    set poppedInst [sed_resolve_inst_names_for_parent $poppedInst]
    find instance -name $poppedInst
    window fit

    mode renderon
}

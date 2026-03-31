proc push {} {

    # Read selection FIRST (do NOT clear it)
    set sel [database instances -selected]

    if {[llength $sel] != 1} {
        return
    }

    set iname [lindex $sel 0]

    # Handle bussed instances: foo<4:0> → foo<4>
    if {[regexp {^(.*)<([0-9]+):([0-9]+)>$} $iname -> base i1 i2]} {
        set iname "${base}<${i1}>"
    }

    # Get and normalize current context
    set ctx [workspace getactive -context]
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    # Build current instance path
    set parts [list]
    foreach el $ctx {
        lappend parts [lindex $el end]
    }

    # Descend into selected instance
    lappend parts $iname
    set newCxt [join $parts "/"]

    # Anchor at top-level
    set tpc [workspace getactive -toplevel_cell]
    set dsn [workspace getactive -toplevel_design]
    set vu  [workspace getactive -toplevel_view]

    mode renderoff
    cell open \
        -cell    $tpc \
        -design  $dsn \
        -type    schematic \
        -view    $vu \
        -context $newCxt \
        -tracenets
    mode renderon
}

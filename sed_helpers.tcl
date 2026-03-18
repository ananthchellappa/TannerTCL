# helps with the generic code (pseudo code) that chatGPT sometimes gives you

proc sed_get_current_context {} {
    set ctx [workspace getactive -context]
    if {![llength $ctx]} { return }

    # If ctx is a single record like: "ADC schematic DESIGN ADC1"
    # then wrap it so it becomes: "{ADC schematic DESIGN ADC1}"
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    set depth [llength $ctx]
    if {!$depth} { return }

    upvar #0 viewContext viewL
    upvar #0 schContext  context
    set b     [list]
    set viewL [list]

    foreach el $ctx {
        lappend b     [lindex $el end]   ;# instance name
        lappend viewL [lindex $el 1]     ;# view ("schematic")
    }
    set context [join $b "/"]
	return $context
}


proc sed_get_current_library {} {
    return [workspace getactive -toplevel_design]
}

proc sed_get_top_cell_name {} {
    return [workspace getactive -toplevel_cell]
}

proc sed_get_top_view_name {} {
    return [workspace getactive -toplevel_view]
}

proc sed_get_selected_instance_name {} {
    return [property get -system -name Name]
}

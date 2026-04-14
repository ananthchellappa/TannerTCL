proc mos_op_summary {lib cell view context instName} {
    # Strip any accidental hierarchy prefix from instName
    set instName [file tail $instName]

    # Convert selected schematic MOS instance name into smallsignal subinstance name
    # Example: MPcas_l  ->  xMPcas_l.m_mos
    if {![string match x* $instName]} {
        set subinst "x${instName}.m_mos"
    } else {
        set subinst "${instName}.m_mos"
    }

    set cmd [list simulation smallsignal \
        -cell $cell \
        -library $lib \
        -type schematic \
        -context $context \
        -subinstance $subinst \
        -view $view \
        -log]

    puts "# Running: [join $cmd { }]"

    set opinfo [uplevel #0 $cmd]
    return [summarize_opinfo_pretty $opinfo]
}

proc mos_op_summary_for_selected {} {
    set lib     [sed_get_toplevel_lib_name]; # found out the hard way :)
    set cell    [sed_get_top_cell_name]
    set context [sed_get_current_context]
    set view    [sed_get_top_view_name]
    set inst    [sed_get_selected_instance_name]
	set inst [get_msb_instance_name $inst]

    if {$inst eq ""} {
        error "No instance selected."
    }

    set summary [mos_op_summary $lib $cell $view $context $inst]
    # puts $summary
    return $summary
}

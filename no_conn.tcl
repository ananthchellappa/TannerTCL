proc add_no_conn_at {x y {netlabel_name ""}} {
    mode draw instance
    instance -cell NoConnection -design Misc -view symbol
    point click -units iu -x $x -y $y
    mode escape

    # Preserve the old behavior of appending a bus suffix, if present.
    # Example: NET<3:0>  -> instance name gets its current name plus <3:0>
    if { $netlabel_name ne "" && [regexp {(<\d+:\d+>)$} $netlabel_name -> bus] } {
        set inst_name [property get -name Name -system -host selections]
        property set -name Name -system -value "${inst_name}${bus}"
    }

    property set -name Angle -system -value 180
}

proc no_conn {} {
    set num_netlabels [get_num_selected_netlabels]
    set num_selected  [get_num_selected_objects]

    mode renderoff

    # Case 1:
    # Only netlabels are selected, and at least one is selected.
    if { $num_netlabels > 0 && $num_selected == $num_netlabels } {
        set nl_rows [get_selected_netlabels_by_location]

        foreach row $nl_rows {
            set xy   [lindex $row 0]
            set name [lindex $row 1]
            set x    [lindex $xy 0]
            set y    [lindex $xy 1]

            add_no_conn_at $x $y $name
        }
    } else {
        # Case 2:
        # Nothing selected, or mixed selection, or non-netlabels selected.
        set cursor_pos [get_cursor_pos_in_iu]
        set x [lindex $cursor_pos 0]
        set y [lindex $cursor_pos 1]

        add_no_conn_at $x $y
    }

    mode renderon
}

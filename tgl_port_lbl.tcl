proc tgl_port_lbl {} {
    if {[tgl_port_lbl_selected_count] == 0} {
        puts "Must select a port or label"
        return
    }

    copy
    delete
    mode renderoff

    set dsn [workspace getactive -toplevel_design]
    tgl_port_lbl_load_selection_into_scratchpad $dsn

    set plist [database ports]
    set llist [database netlabels]

    port -type NetLabel
    find none
    foreach portName $plist {
        tgl_port_lbl_toggle_port_to_label $portName
    }

    find none
    foreach labelName $llist {
        tgl_port_lbl_toggle_label_to_port $labelName
    }

    find all
    copy
    window close
    mode renderon

    paste
    mode place -forcemove on
}


#-----------------------------
# Top-level helpers
#-----------------------------

proc tgl_port_lbl_selected_count {} {
    return [expr {
        [find port     -scope selection -add -goto none -count] +
        [find netlabel -scope selection -add -goto none -count]
    }]
}

proc tgl_port_lbl_load_selection_into_scratchpad {dsn} {
    set scratchView [lindex [database views -design $dsn -cell scratchpad -type schematic] 0]

    cell open \
        -design $dsn \
        -cell scratchpad \
        -type schematic \
        -view $scratchView \
        -newwindow

    find all
    delete
    paste
}

proc tgl_port_lbl_toggle_port_to_label {portName} {
    find port $portName -next -goto none

    lassign [tgl_port_lbl_get_common_props] x y font dir hjust vjust

    delete
    mode draw port

    lassign [tgl_port_lbl_map_port_to_label_justification $dir $hjust $vjust] \
        drawHJust drawVJust drawDir

    port \
        -text $portName \
        -hjustify $drawHJust \
        -vjustify $drawVJust \
        -direction $drawDir \
        -size $font \
        -units iu \
        -confirm false

    point click $x $y -units iu
}

proc tgl_port_lbl_toggle_label_to_port {labelName} {
    find netlabel $labelName -next -goto none

    lassign [tgl_port_lbl_get_common_props] x y font dir hjust vjust

    delete
    mode draw port
    port -type In

    set orient [tgl_port_lbl_map_label_to_port_orientation $dir $hjust $vjust]

    port \
        -text $labelName \
        -orientation $orient \
        -size $font \
        -units iu \
        -confirm false

    point click $x $y -units iu
}


#-----------------------------
# Property helpers
#-----------------------------

proc tgl_port_lbl_get_common_props {} {
    set x     [property get -name X -system]
    set y     [property get -name Y -system]
    set font  [property get -name FontSize -system]
    set dir   [property get -name TextJustification.Direction -system]
    set hjust [property get -name TextJustification.Horizontal -system]
    set vjust [property get -name TextJustification.Vertical -system]

    return [list $x $y $font $dir $hjust $vjust]
}


#-----------------------------
# Orientation / justification mapping
#-----------------------------

proc tgl_port_lbl_map_port_to_label_justification {dir hjust vjust} {
    set key "$dir|$hjust|$vjust"

    switch -- $key {
        "Normal|Left|Middle"   { return [list left   middle normal] }
        "Normal|Right|Middle"  { return [list right  middle normal] }
        "Down|Center|Top"      { return [list center top    down]   }
        "Down|Center|Bottom"   { return [list center bottom down]   }
        default                { return [list left   middle normal] }
    }
}

proc tgl_port_lbl_map_label_to_port_orientation {dir hjust vjust} {
    set key "$dir|$hjust|$vjust"

    switch -- $key {
        "Normal|Left|Middle"   { return east  }
        "Normal|Right|Middle"  { return west  }
        "Down|Center|Top"      { return south }
        "Down|Center|Bottom"   { return north }
        default                { return west  }
    }
}

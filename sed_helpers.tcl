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
    return [workspace getactive -library]
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

proc sed_get_instance_names {} {
	return [database instances]
}

proc sed_list_selected_inst_names {} {
	return [database instances -selected]
}

proc sed_get_library_names {} {
	return [database designs]
}

proc sed_get_current_cell_name {} {
	return [workspace getactive -cell]
}


proc sed_get_current_view_name {} {
	return [workspace getactive -view]
}

proc sed_get_current_view_type {} {
	return [workspace getactive -type]
}

proc sed_resolve_inst_names_for_parent {poppedInst} {

    set instNames [sed_get_instance_names]

    # If exact match already exists, use it as-is
    if {[lsearch -exact $instNames $poppedInst] >= 0} {
        return $poppedInst
    }

    # Check whether poppedInst is a single bus iteration: base<idx>
    # base may contain anything before the final <n>
    if {![regexp {^(.*)<([0-9]+)>$} $poppedInst -> base idx]} {
        return $poppedInst
    }

    # Search for a bused instance that contains this index.
    # Matches names like:
    #   xdut<1:4>
    #   xdut<4:1>
    foreach name $instNames {
        if {![regexp {^(.*)<([0-9]+):([0-9]+)>$} $name -> candBase a b]} {
            continue
        }

        if {$candBase ne $base} {
            continue
        }

        set lo [expr {$a < $b ? $a : $b}]
        set hi [expr {$a > $b ? $a : $b}]

        if {$idx >= $lo && $idx <= $hi} {
            return $name
        }
    }

    # No better match found
    return $poppedInst
}

proc select_textlabel_by_internal_name {targetInternalName} {
	mode renderoff
	set retval [_select_textlabel_by_internal_name_raw $targetInternalName]
	mode renderon
	return $retval
}

proc _select_textlabel_by_internal_name_raw {targetInternalName} {
    # How many textlabels exist in the view?

    set n [find textlabel -scope view -count -goto none]

    if {$n <= 0} {
        puts "No textlabels found in current view."
        return 0
    }

    # Start iteration: this selects the first textlabel
    find textlabel -scope view -first -goto none

    for {set i 0} {$i < $n} {incr i} {
        # Get the currently selected label(s) with names
        set sel [database labels -selected -name]

        # We expect exactly one selected textlabel during this walk
        if {[llength $sel] == 1} {
            set one [lindex $sel 0]

            # Format is: {internal_unique_name displayed_label_text}
            set internalName [lindex $one 0]

            if {$internalName eq $targetInternalName} {
                puts "Selected textlabel $targetInternalName"
                return 1
            }
        }

        # Advance unless this was the last iteration
        if {$i < $n-1} {
            find textlabel -scope view -next -goto none
        }
    }

    puts "Did not find textlabel with internal name: $targetInternalName"
    return 0
}

# Given label coordinates and a list like:
#   {{ {x y} portName } { {x y} portName } ...}
# return the nearest port name.
proc nearest_port_name {labelX labelY ports} {
    set bestName ""
    set bestD2 ""

    foreach portEntry $ports {
        set loc  [lindex $portEntry 0]
        set name [lindex $portEntry 1]

        set px [lindex $loc 0]
        set py [lindex $loc 1]

        set dx [expr {$px - $labelX}]
        set dy [expr {$py - $labelY}]
        set d2 [expr {$dx*$dx + $dy*$dy}]

        if {$bestD2 eq "" || $d2 < $bestD2} {
            set bestD2 $d2
            set bestName $name
        }
    }

    return $bestName
}

proc get_selected_ports_in_physical_order {} {
    set ports [database ports -selected -location -name]

    if {[llength $ports] == 0} {
        return {}
    }

    set norm {}
    set xs {}
    set ys {}

    foreach p $ports {
        set loc  [lindex $p 0]
        set name [lindex $p 1]

        set x [lindex $loc 0]
        set y [lindex $loc 1]

        lappend norm [list $name $x $y]
        lappend xs $x
        lappend ys $y
    }

    set minX [lindex [lsort -integer $xs] 0]
    set maxX [lindex [lsort -integer $xs] end]
    set minY [lindex [lsort -integer $ys] 0]
    set maxY [lindex [lsort -integer $ys] end]

    set dx [expr {$maxX - $minX}]
    set dy [expr {$maxY - $minY}]

    if {$dx >= $dy} {
        set sorted [lsort -integer -index 1 $norm]
    } else {
        set sorted [lsort -integer -decreasing -index 2 $norm]
    }

    set result {}
    foreach item $sorted {
        lappend result [lindex $item 0]
    }

    return $result
}

proc print_selected_ports_in_physical_order {} {
    foreach portName [get_selected_ports_in_physical_order] {
        puts $portName
    }
}

proc get_preferred_schematic_view {} {
    set views [database views \
        -cell [sed_get_current_cell_name] \
        -library [sed_get_current_library] \
        -type schematic]

    if {[llength $views] == 0} {
        return ""
    }

    if {[lsearch -exact $views schematic] >= 0} {
        return "schematic"
    }

    return [lindex $views 0]
}

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

proc sed_get_library_names {} {
	return [database designs]
}

proc sed_get_current_cell_name {} {
	return [workspace getactive -cell]
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

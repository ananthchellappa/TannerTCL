# Select some ports and labels together, and it'll ensure all the labels match
# the names of the ports neareest them. 

# depends on sed helpers TCL

proc clean_selected_labels_to_nearest_ports {} {
	mode renderoff
	_clean_selected_labels_to_nearest_ports_raw
	mode renderon
}

# Main procedure:
# Starting with some ports and some textlabels selected,
# rename each selected textlabel to the name of the nearest selected port.
proc _clean_selected_labels_to_nearest_ports_raw {} {
    set ports [database ports -selected -location -name]
    if {[llength $ports] == 0} {
        puts "No ports selected."
        return
    }

    set labels [database labels -selected -name]
    if {[llength $labels] == 0} {
        puts "No textlabels selected."
        return
    }

    set changed 0
    set notFound 0

    foreach labelEntry $labels {
        set internalName [lindex $labelEntry 0]

        # Re-select this label by internal unique name
        if {![select_textlabel_by_internal_name $internalName]} {
            puts "Could not re-select label $internalName"
            incr notFound
            continue
        }

        # Now that exactly this label is selected, get its coordinates
        set lx [property get -name X -system]
        set ly [property get -name Y -system]

        if {$lx eq "" || $ly eq ""} {
            puts "Could not get coordinates for label $internalName"
            incr notFound
            continue
        }

        set nearestName [nearest_port_name $lx $ly $ports]
        if {$nearestName eq ""} {
            puts "Could not determine nearest port for label $internalName"
            incr notFound
            continue
        }

        property set -name Name -value $nearestName -system
        incr changed
    }

    puts "Updated $changed label(s)."
    if {$notFound > 0} {
        puts "$notFound label(s) could not be processed."
    }
}

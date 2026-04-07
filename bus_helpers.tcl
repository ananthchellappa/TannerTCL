# Return 1 if suffix is a bus of width > 1, such as <1:10> or <10:0>
# Return 0 for <1>, <0>, <10>, or no bus at all.
proc _sed_is_multibit_bus_suffix {suffix} {
    if {![regexp {^<([0-9]+):([0-9]+)>$} $suffix -> a b]} {
        return 0
    }
    return [expr {$a != $b}]
}

# Split a port name into:
#   base  = non-bus portion
#   bus   = trailing bus suffix, or "" if none
#
# Examples:
#   DATA<7:0>  -> {DATA <7:0>}
#   A<3>       -> {A <3>}
#   CLK        -> {CLK ""}
proc _sed_split_port_name {name} {
    if {[regexp {^(.*?)(<[^<>]+>)$} $name -> base bus]} {
        return [list $base $bus]
    }
    return [list $name ""]
}

# Build map:
#   base-name -> full schematic port name
#
# Only schematic ports with a true multibit bus are included.
# Example:
#   DATA<7:0> => map(DATA) = DATA<7:0>
proc _sed_build_schematic_multibit_name_map {port_names_from_schematic_view} {
    set nameMap [dict create]

    foreach pname $port_names_from_schematic_view {
        lassign [_sed_split_port_name $pname] base bus
        if {[_sed_is_multibit_bus_suffix $bus]} {
            dict set nameMap $base $pname
        }
    }

    return $nameMap
}

proc sync_symbol_port_bus_widths_to_schematic {} {
	mode renderoff
	_sync_symbol_port_bus_widths_to_schematic
	mode renderon
}

proc _sync_symbol_port_bus_widths_to_schematic {} {

    # Must be in a symbol view
    if {[sed_get_current_view_type] ne "symbol"} {
        return
    }

    # Determine preferred schematic view
    set schView [get_preferred_schematic_view]
    if {$schView eq ""} {
        return
    }

    # Get schematic port names
    set port_names_from_schematic_view [database ports \
        -cell    [sed_get_current_cell_name] \
        -library [sed_get_current_library] \
        -view    $schView]

    if {![llength $port_names_from_schematic_view]} {
        return
    }

    # Build lookup: base name -> full schematic multibit port name
    set schNameMap [_sed_build_schematic_multibit_name_map $port_names_from_schematic_view]

    # Get current symbol-view ports, only to know count
    set symbolPorts [database ports]
    set portCount [llength $symbolPorts]
    if {$portCount == 0} {
        return
    }

    # Select first symbol port
    find port -goto none -first

    for {set i 0} {$i < $portCount} {incr i} {

        # Current selected symbol port name
        set curName [property get -name Name -system]

        # Match by base name only
        lassign [_sed_split_port_name $curName] base curBus

        if {[dict exists $schNameMap $base]} {
            set newName [dict get $schNameMap $base]

            if {$newName ne $curName} {
                property set -name Name -value $newName -system
            }
        }

        # Advance to next symbol port
        if {$i < ($portCount - 1)} {
            find port -goto none -next
        }
    }
}

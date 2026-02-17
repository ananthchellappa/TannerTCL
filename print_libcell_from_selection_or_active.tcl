proc print_libcell_from_selection_or_active {} {

    # What instances are selected?
    set sel [database instances -selected]

    # If more than one instance is selected, do nothing.
    if {[llength $sel] > 1} {
        return
    }

    # ------------------------------------------------------------
    # CASE 1: Exactly one instance selected
    # ------------------------------------------------------------
    if {[llength $sel] == 1} {

        # Get master cell + library from system properties
        set cellName [property get -system -name MasterCell]
        set libName  [property get -system -name MasterLibrary]

        if {$cellName ne "" && $libName ne ""} {
            puts "$libName/$cellName"
        }
        return
    }

    # ------------------------------------------------------------
    # CASE 2: No instance selected -> use active workspace
    # ------------------------------------------------------------
    set ctx [workspace getactive]
    # ctx is: {cellName viewName libraryName}
    set cellName [lindex $ctx 0]
    set libName  [lindex $ctx 2]

    # Basic sanity
    if {$cellName eq "" || $libName eq ""} {
        return
    }

    puts "$libName/$cellName"
}

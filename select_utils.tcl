proc select_same_lib {} {

    # Require exactly one instance selected
    set sel [database instances -selected]
    if {[llength $sel] != 1} {
		puts "Select at least one instance to then select all of that library"
        return
    }

    # Get master library and master cell of the selected instance
    set libName  [property get -system -name MasterLibrary]

    # Normalize in case the return is a 1-element list
    if {[llength $libName]  >= 1} { set libName  [lindex $libName  0] }

    # Basic sanity
    if {$libName eq "" } {
        return
    }

    # Select all matching instances (add to selection)
    # Per your syntax: find instance -mastercell libName-masterdesign cellName -add
    find instance  -masterdesign $libName -add 
}

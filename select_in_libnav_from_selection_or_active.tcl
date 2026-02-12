# Select the currently-selected instance's master in the Library Navigator,
# or (if nothing is selected) select the active cell/view/library.

# basically, to mimic what I have with Cadence - select an inst and do CTRL-ALT-S to locate in the lib manager.
# if no instance selected, then find the currently viewed cellview in the library manager
# workspace menu -name {CUSTOM {Useful Commands} {Find in Lib Navigator} }  -command {select_in_libnav_from_selection_or_active}
# workspace bindkeys -command {Find in Lib Navigator} -key "Ctrl+Alt+S"

proc select_in_libnav_from_selection_or_active {} {

    # What instances are selected?
    set sel [database instances -selected]

    # If more than one instance is selected, do nothing.
    if {[llength $sel] > 1} {
        return
    }

    # If exactly one instance is selected, let S-Edit handle it.
    if {[llength $sel] == 1} {
        librarynavigator select_in_lib_navigator
        return
    }

    # Otherwise, none selected: use the active workspace context.
    set ctx [workspace getactive]
    # ctx is: {cellName viewName libraryName}
    set cellName [lindex $ctx 0]
    set viewName [lindex $ctx 1]
    set libName  [lindex $ctx 2]

    # Basic sanity: if anything is missing, just return.
    if {$cellName eq "" || $viewName eq "" || $libName eq ""} {
        return
    }

    librarynavigator select_in_lib_navigator \
        -library $libName \
        -cell    $cellName \
        -view    $viewName
}

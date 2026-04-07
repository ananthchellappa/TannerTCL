# on Windows, you can use AutoHotKey to send CTRL SHIFT Up (if that's what you want)
# with CTRL SHIFT Mouse_Scroll_up
# ^+WheelUp::
#    SendInput, ^+{Up}
# Return

proc cycle_port_type {} {
    # Get directions of selected ports
    set dirs [database ports -selected -direction]

    # If nothing selected, do nothing
    if {[llength $dirs] == 0} {
        return
    }

    # Use the first selected port's direction as the basis
    set cur [string tolower [lindex $dirs 0]]

    switch -- $cur {
        "in" {
            set newType "Out"
        }
        "out" {
            set newType "InOut"
        }
        "inout" {
            set newType "In"
        }
        default {
            # Any other type: do nothing
            return
        }
    }

    # Apply to all selected ports
    property set -name Type -value $newType -system
}

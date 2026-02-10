# Clear net highlights in S-Edit 2025.4 by repainting highlighted nets
# back to the default wire color (e.g. #3ac0ff).
#
# Usage:
#   clear_all_net_highlights
#   clear_all_net_highlights "#3ac0ff"
#
proc clear_all_net_highlights {{defaultColor "#3ac0ff"}} {

    # Ask S-Edit what is currently highlighted (as TCL-ish command lines)
    set txt [highlight -list -tcl]

    # Collect unique net names from lines like:
    #   highlight ... -net "xpll/vctl" ... -color Plum ...
    set nets {}
    set nLines 0

    foreach line [split $txt "\n"] {
        set line [string trim $line]
        if {$line eq ""} { continue }
        incr nLines

        # Some outputs have a leading "# SED" prefix; ignore it for parsing.
        # Extract the value inside -net " ... "
        if {[regexp {(^|[[:space:]])-net[[:space:]]+"([^"]+)"} $line -> _ netName]} {

            # Dedup
            if {[lsearch -exact $nets $netName] < 0} {
                lappend nets $netName
            }
        }
    }

    # If nothing was found, we're done
    if {[llength $nets] == 0} {
        # Optional: puts "No highlighted nets found."
        return
    }

	mode renderoff
    # Repaint each net to the default wire color (removes the “highlighted” look)
    foreach net $nets {
        # Protect nets with weird characters by passing as a single arg
        highlight -net $net -color $defaultColor
    }

    # Optional: puts "Recolored [llength $nets] highlighted nets to $defaultColor."
	mode renderon
    return
}

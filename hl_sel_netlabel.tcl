# The problem is that going through the GUI, when we issue the highlight command, the net or netlabel 
# that was selected just prior to issuing the highlight command is no longer selected after the highlighting is done. 

# However, issuing the highlight command through TCL (highlight -net name_of_net -color choice_of_color) 
# keeps the element (netlabel or wire (net)) selected. The reason this is important is that we would like 
# to keep issuing the command to highlight the selected net/label till we get the color desired.

# NOTE: set your color list using
# highlight -default {red green blue gold purple yellow magenta brown lemon} # or what you will

# Highlight the currently-selected netlabel's net, using hierarchical context,
# while keeping the selection intact (since we're using TCL highlight).
#
# Usage:
#   hl_sel_netlabel
#   hl_sel_netlabel Red
#   hl_sel_netlabel "#3ac0ff"
#
proc hl_sel_netlabel {{color ""}} {

    # ---- Get selected netlabel's net name (no context) ----
    set sel [database netlabel -selected]
    if {[llength $sel] < 1} {
        return
    }
    set netName [lindex $sel 0]
    if {$netName eq ""} { return }

    # ---- Get active context ----
    set ctx [workspace getactive -context]

    set instPath {}

    # Case 1: single-level context is a flat list: {cell view lib inst}
    if {[llength $ctx] == 4} {
        set inst [lindex $ctx 3]
        if {$inst ne ""} {
            lappend instPath $inst
        }

    # Case 2: multi-level context is a list of frames: {{cell view lib inst} {...} ...}
    } else {
        foreach frame $ctx {
            if {[llength $frame] < 4} { continue }
            set inst [lindex $frame 3]
            if {$inst ne ""} {
                lappend instPath $inst
            }
        }
    }

    # ---- Build full hierarchical net name ----
    if {[llength $instPath] > 0} {
        set fullName "[join $instPath /]/$netName"
    } else {
        set fullName $netName
    }

    # ---- Highlight via TCL using -net ----
    if {$color eq ""} {
        highlight -net $fullName
    } else {
        highlight -net $fullName -color $color
    }

    return
}

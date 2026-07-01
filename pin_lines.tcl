# Symbol-editor helper: for every selected pin (port), draw a straight line
# (path) starting at the pin and extending AWAY from the pin's name text.
#
# The chain being built by hand is:  pin -> line -> [rectangle] -> text display
# so the line must leave the pin on the side OPPOSITE the pin's own name.
#
# Which side the name sits on is read from the port's TextJustification:
#   Direction Normal   -> Horizontal decides:  Left  -> name east
#                                               Right -> name west
#   Direction Up/Down  -> Vertical   decides:  Top   -> name south (name below)
#                                               Bottom-> name north (name above)
# The line is then drawn on the opposite side:
#     name east  -> line west     name west  -> line east
#     name south -> line north    name north -> line south
#
# Line length is an argument in integer units (iu); default 100.
# Orthogonal only; pins with an unrecognized TextJustification are skipped
# with a message.
#
# To flip the convention (draw on the SAME side as the name instead), swap the
# sign of the four ex/ey expressions below.

# Return the compass side the pin's NAME text occupies, or "" if unrecognized.
proc _pin_name_side {dir hjust vjust} {
    if {$dir eq "Normal"} {
        switch -- $hjust {
            Left  { return east }
            Right { return west }
        }
    } elseif {$dir eq "Up" || $dir eq "Down"} {
        switch -- $vjust {
            Top    { return south }
            Bottom { return north }
        }
    }
    return ""
}

proc draw_pin_lines { {len 100} } {

    mode renderoff

    # Collect selected ports' geometry + justification BEFORE drawing, since
    # entering draw mode disturbs the selection/context. The -filter script
    # runs in this proc's variable scope (same pattern as
    # pin_orientation_in_parent_frame in sed_helpers.tcl), so lappend lands here.
    set pins {}
    set filt {
        set n [property get -name Name                       -system]
        set x [property get -name X                          -system]
        set y [property get -name Y                          -system]
        set d [property get -name TextJustification.Direction  -system]
        set h [property get -name TextJustification.Horizontal -system]
        set v [property get -name TextJustification.Vertical   -system]
        lappend pins [list $n $x $y $d $h $v]
        expr {1}
    }
    find port -scope selection -filter $filt -goto none

    if {![llength $pins]} {
        mode renderon
        puts "draw_pin_lines: no pins (ports) selected"
        return
    }

    mode escape
    mode draw path

    set drawn 0
    foreach p $pins {
        lassign $p n x y d h v

        set base [_pin_name_side $d $h $v]
        if {$base eq ""} {
            puts "draw_pin_lines: skipping pin '$n' - unrecognized TextJustification ($d|$h|$v)"
            continue
        }

        # Line leaves the pin opposite the name-text side.
        switch -- $base {
            east  { set ex [expr {$x - $len}]; set ey $y }
            west  { set ex [expr {$x + $len}]; set ey $y }
            north { set ex $x; set ey [expr {$y - $len}] }
            south { set ex $x; set ey [expr {$y + $len}] }
        }

        point click  $x  $y  -units iu
        point click2 $ex $ey -units iu
        incr drawn
    }

    mode escape
    mode renderon
    puts "draw_pin_lines: drew $drawn line(s) of length $len iu"
}

# depends on sed_helpers.tcl (nearest_pin_to_cursor, pin_orientation_in_parent_frame, get_cursor_pos_in_iu)

# Start a wire at the pin nearest to the cursor and lay down the elbow vertex
# that forces the first segment to leave the pin along the pin's facing
# direction (east/west -> horizontal first, north/south -> vertical first).
# Wire mode is left active with the rubber-band hanging off the elbow, so the
# user routes from there to the destination themselves.
#
# If the cursor is not on the side of the pin that the pin faces (e.g. pin
# faces south but cursor is above the pin), the proc warns and exits without
# drawing.
proc snap_start_wire_from_nearest_pin {} {

    set hit [nearest_pin_to_cursor]
    if {[llength $hit] != 12} {
        puts "snap_start_wire_from_nearest_pin: no visible pin found"
        return
    }
    lassign $hit lib cell view inst pname pinX pinY instX instY angle mirror scaling

    set orient [pin_orientation_in_parent_frame \
                    $lib $cell $view $pname \
                    $pinX $pinY $instX $instY $angle $mirror $scaling]
    if {$orient eq ""} {
        puts "snap_start_wire_from_nearest_pin: unknown orientation for pin '$pname' on instance '$inst'"
        return
    }

    set cur [get_cursor_pos_in_iu]
    if {[llength $cur] != 2} {
        puts "snap_start_wire_from_nearest_pin: cannot read cursor position"
        return
    }
    lassign $cur cx cy

    # Validate direction-of-travel matches pin's facing direction.
    # Convention: east = +x, west = -x, north = +y, south = -y.
    switch -- $orient {
        east  {
            if {$cx <= $pinX} {
                puts "snap_start_wire_from_nearest_pin: pin '$pname' faces east; cursor must be east of pin (x_cursor > x_pin)"
                return
            }
        }
        west  {
            if {$cx >= $pinX} {
                puts "snap_start_wire_from_nearest_pin: pin '$pname' faces west; cursor must be west of pin (x_cursor < x_pin)"
                return
            }
        }
        north {
            if {$cy <= $pinY} {
                puts "snap_start_wire_from_nearest_pin: pin '$pname' faces north; cursor must be north of pin (y_cursor > y_pin)"
                return
            }
        }
        south {
            if {$cy >= $pinY} {
                puts "snap_start_wire_from_nearest_pin: pin '$pname' faces south; cursor must be south of pin (y_cursor < y_pin)"
                return
            }
        }
        default {
            puts "snap_start_wire_from_nearest_pin: unrecognized orientation '$orient'"
            return
        }
    }

    # Elbow: first segment runs along pin's facing axis, second perpendicular.
    switch -- $orient {
        east  -
        west  { set ex $cx;    set ey $pinY }
        north -
        south { set ex $pinX;  set ey $cy   }
    }

    mode renderoff
    mode escape
    mode draw wire
    point click $pinX $pinY -units iu
    point click $ex   $ey   -units iu
    mode renderon
}


# Complete an in-progress wire by routing it into the pin nearest the cursor.
# Lays down an elbow vertex (so the final segment enters the pin along the
# pin's facing direction) and then issues `point click2` at the pin to close
# out the wire. Wire mode must already be active when this is called.
#
# If the cursor is not on the side of the pin that the pin faces (e.g. pin
# faces south but cursor is above the pin), the proc warns and exits without
# drawing.
proc snap_complete_wire_to_nearest_pin {} {

    set hit [nearest_pin_to_cursor]
    if {[llength $hit] != 12} {
        puts "snap_complete_wire_to_nearest_pin: no visible pin found"
        return
    }
    lassign $hit lib cell view inst pname pinX pinY instX instY angle mirror scaling

    set orient [pin_orientation_in_parent_frame \
                    $lib $cell $view $pname \
                    $pinX $pinY $instX $instY $angle $mirror $scaling]
    if {$orient eq ""} {
        puts "snap_complete_wire_to_nearest_pin: unknown orientation for pin '$pname' on instance '$inst'"
        return
    }

    set cur [get_cursor_pos_in_iu]
    if {[llength $cur] != 2} {
        puts "snap_complete_wire_to_nearest_pin: cannot read cursor position"
        return
    }
    lassign $cur cx cy

    # Cursor must be on the side the pin faces, so the final segment enters
    # the pin going the right way.
    switch -- $orient {
        east  {
            if {$cx <= $pinX} {
                puts "snap_complete_wire_to_nearest_pin: pin '$pname' faces east; cursor must be east of pin (x_cursor > x_pin)"
                return
            }
        }
        west  {
            if {$cx >= $pinX} {
                puts "snap_complete_wire_to_nearest_pin: pin '$pname' faces west; cursor must be west of pin (x_cursor < x_pin)"
                return
            }
        }
        north {
            if {$cy <= $pinY} {
                puts "snap_complete_wire_to_nearest_pin: pin '$pname' faces north; cursor must be north of pin (y_cursor > y_pin)"
                return
            }
        }
        south {
            if {$cy >= $pinY} {
                puts "snap_complete_wire_to_nearest_pin: pin '$pname' faces south; cursor must be south of pin (y_cursor < y_pin)"
                return
            }
        }
        default {
            puts "snap_complete_wire_to_nearest_pin: unrecognized orientation '$orient'"
            return
        }
    }

    # Elbow: last segment must enter the pin along its facing axis.
    switch -- $orient {
        east  -
        west  { set ex $cx;    set ey $pinY }
        north -
        south { set ex $pinX;  set ey $cy   }
    }

    mode renderoff
    point click  $ex    $ey    -units iu
    point click2 $pinX  $pinY  -units iu
    mode renderon
}

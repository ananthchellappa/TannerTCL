proc sed_get_current_context {} {
    set ctx [workspace getactive -context]
    if {![llength $ctx]} { return }

    # If ctx is a single record like: "ADC schematic DESIGN ADC1"
    # then wrap it so it becomes: "{ADC schematic DESIGN ADC1}"
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    set depth [llength $ctx]
    if {!$depth} { return }

    upvar #0 viewContext viewL
    upvar #0 schContext  context
    set b     [list]
    set viewL [list]

    foreach el $ctx {
        lappend b     [lindex $el end]   ;# instance name
        lappend viewL [lindex $el 1]     ;# view ("schematic")
    }
    set context [join $b "/"]
	return $context
}

proc sed_get_toplevel_lib_name {} {
	workspace getactive -toplevel_design 
}

proc sed_get_current_library {} {
    return [workspace getactive -library]
}

proc sed_get_top_cell_name {} {
    return [workspace getactive -toplevel_cell]
}

proc sed_get_top_view_name {} {
    return [workspace getactive -toplevel_view]
}

proc sed_get_selected_instance_name {} {
    return [property get -system -name Name]
}

proc sed_get_instance_names {} {
	return [database instances]
}

proc sed_list_selected_inst_names {} {
	return [database instances -selected]
}

proc sed_get_library_names {} {
	return [database designs]
}

proc sed_get_current_cell_name {} {
	return [workspace getactive -cell]
}


proc sed_get_current_view_name {} {
	return [workspace getactive -view]
}

proc sed_get_current_view_type {} {
	return [workspace getactive -type]
}

proc sed_resolve_inst_names_for_parent {poppedInst} {

    set instNames [sed_get_instance_names]

    # If exact match already exists, use it as-is
    if {[lsearch -exact $instNames $poppedInst] >= 0} {
        return $poppedInst
    }

    # Check whether poppedInst is a single bus iteration: base<idx>
    # base may contain anything before the final <n>
    if {![regexp {^(.*)<([0-9]+)>$} $poppedInst -> base idx]} {
        return $poppedInst
    }

    # Search for a bused instance that contains this index.
    # Matches names like:
    #   xdut<1:4>
    #   xdut<4:1>
    foreach name $instNames {
        if {![regexp {^(.*)<([0-9]+):([0-9]+)>$} $name -> candBase a b]} {
            continue
        }

        if {$candBase ne $base} {
            continue
        }

        set lo [expr {$a < $b ? $a : $b}]
        set hi [expr {$a > $b ? $a : $b}]

        if {$idx >= $lo && $idx <= $hi} {
            return $name
        }
    }

    # No better match found
    return $poppedInst
}

proc select_textlabel_by_internal_name {targetInternalName} {
	mode renderoff
	set retval [_select_textlabel_by_internal_name_raw $targetInternalName]
	mode renderon
	return $retval
}

proc _select_textlabel_by_internal_name_raw {targetInternalName} {
    # How many textlabels exist in the view?

    set n [find textlabel -scope view -count -goto none]

    if {$n <= 0} {
        puts "No textlabels found in current view."
        return 0
    }

    # Start iteration: this selects the first textlabel
    find textlabel -scope view -first -goto none

    for {set i 0} {$i < $n} {incr i} {
        # Get the currently selected label(s) with names
        set sel [database labels -selected -name]

        # We expect exactly one selected textlabel during this walk
        if {[llength $sel] == 1} {
            set one [lindex $sel 0]

            # Format is: {internal_unique_name displayed_label_text}
            set internalName [lindex $one 0]

            if {$internalName eq $targetInternalName} {
                puts "Selected textlabel $targetInternalName"
                return 1
            }
        }

        # Advance unless this was the last iteration
        if {$i < $n-1} {
            find textlabel -scope view -next -goto none
        }
    }

    puts "Did not find textlabel with internal name: $targetInternalName"
    return 0
}

# Given label coordinates and a list like:
#   {{ {x y} portName } { {x y} portName } ...}
# return the nearest port name.
proc nearest_port_name {labelX labelY ports} {
    set bestName ""
    set bestD2 ""

    foreach portEntry $ports {
        set loc  [lindex $portEntry 0]
        set name [lindex $portEntry 1]

        set px [lindex $loc 0]
        set py [lindex $loc 1]

        set dx [expr {$px - $labelX}]
        set dy [expr {$py - $labelY}]
        set d2 [expr {$dx*$dx + $dy*$dy}]

        if {$bestD2 eq "" || $d2 < $bestD2} {
            set bestD2 $d2
            set bestName $name
        }
    }

    return $bestName
}

proc get_selected_ports_in_physical_order {} {
    set ports [database ports -selected -location -name]

    if {[llength $ports] == 0} {
        return {}
    }

    set norm {}
    set xs {}
    set ys {}

    foreach p $ports {
        set loc  [lindex $p 0]
        set name [lindex $p 1]

        set x [lindex $loc 0]
        set y [lindex $loc 1]

        lappend norm [list $name $x $y]
        lappend xs $x
        lappend ys $y
    }

    set minX [lindex [lsort -integer $xs] 0]
    set maxX [lindex [lsort -integer $xs] end]
    set minY [lindex [lsort -integer $ys] 0]
    set maxY [lindex [lsort -integer $ys] end]

    set dx [expr {$maxX - $minX}]
    set dy [expr {$maxY - $minY}]

    if {$dx >= $dy} {
        set sorted [lsort -integer -index 1 $norm]
    } else {
        set sorted [lsort -integer -decreasing -index 2 $norm]
    }

    set result {}
    foreach item $sorted {
        lappend result [lindex $item 0]
    }

    return $result
}

proc print_selected_ports_in_physical_order {} {
    foreach portName [get_selected_ports_in_physical_order] {
        puts $portName
    }
}

proc get_preferred_schematic_view {} {
    set views [database views \
        -cell [sed_get_current_cell_name] \
        -library [sed_get_current_library] \
        -type schematic]

    if {[llength $views] == 0} {
        return ""
    }

    if {[lsearch -exact $views schematic] >= 0} {
        return "schematic"
    }

    return [lindex $views 0]
}

proc get_msb_instance_name {iname} {
    # If name looks like foo<msb:lsb>, return foo<msb>
    if {[regexp {^(.*)<([0-9]+):([0-9]+)>$} $iname -> base i1 i2]} {
        return "${base}<${i1}>"
    }

    # Otherwise return unchanged
    return $iname
}

proc get_X { } {
	return [property get -name X -system]
}

proc get_Y { } {
	return [property get -name Y -system]
}

proc get_num_selected_netlabels { } {
	return [find netlabel -scope selection -count -goto none -add]
}

proc get_num_selected_objects { } {
	return [find all -scope selection -count -goto none]
}

proc get_cursor_pos_in_iu {} {
	mode renderoff
	set save_units [setup schematicunits get -displayunits]
	setup schematicunits set -displayunits iu
	set cursor_pos [workspace getcursorposition]
	setup schematicunits set -displayunits $save_units
	mode renderon
	return $cursor_pos; # will return x and y as list of 2 elements
}

# Returns a dict whose keys are "{x y}" and whose values are the netlabel names.
# Example returned dict:
#   {100 200} NET_A  {300 400} NET_B

proc get_selected_netlabels_by_location {} {
# classic example of using the find command with -filter to build up a table since
# it loops over objects. The script just has to return 1 so that no filtering is 
# performed, if starting with selected objects
    set rows {}

    set filterScript {
        set x [property get -name X -system]
        set y [property get -name Y -system]
        set name [property get -name Name -system]

        lappend rows [list [list $x $y] $name]

        expr {1}
    }

    find netlabel -scope selection -filter $filterScript -goto none

    return $rows
}

# Return a list of rows describing every instance in the current viewport.
# Each row: {master_library master_cell master_view instance_name X Y Angle Mirror Scaling}
# Uses partiallyenclosed so instances clipped at the edge are included.
proc visible_instances {} {
    set vp [win_viewportrect_iu]
    if {[llength $vp] != 4} {
        return {}
    }
    lassign $vp x0 y0 x1 y1

    set rows {}

    set filterScript {
        set lib     [property get -name MasterLibrary -system]
        set cell    [property get -name MasterCell    -system]
        set view    [property get -name MasterView    -system]
        set name    [property get -name Name          -system]
        set x       [property get -name X             -system]
        set y       [property get -name Y             -system]
        set angle   [property get -name Angle         -system]
        set mirror  [property get -name Mirror        -system]
        set scaling [property get -name Scaling       -system]

        lappend rows [list $lib $cell $view $name $x $y $angle $mirror $scaling]

        expr {1}
    }

    find instance -scope view \
        -x0 $x0 -y0 $y0 -x1 $x1 -y1 $y1 \
        -selectionmode partiallyenclosed \
        -goto none -units iu \
        -filter $filterScript

    return $rows
}

# Transform a symbol's pin locations into the current (parent) frame of
# reference, given how the instance is placed.
#
# Inputs:
#   lib, cell, view         master cell to query for pin locations
#   inst_name               instance name (carried for the caller's benefit;
#                           used only to label warnings)
#   instX, instY            instance origin in the parent frame
#   angle                   Angle property: 0/90/180/270. Rotation is CCW
#                           with the property reading "minus the angle":
#                           Angle 270 = 90 deg CCW; Angle 90 = 270 deg CCW.
#                           (Equivalently: Angle is degrees CW.)
#   mirror                  Mirror property: true/false. Y-axis mirror
#                           (x -> -x), applied AFTER rotation.
#   scaling                 Scaling property (e.g. 1.0, 0.5)
#
# Returns: list of {pin_name {X Y}} pairs, same shape as
#   database ports ... -name -location, but with X,Y in the parent frame.
proc instance_pins_in_parent_frame {lib cell view inst_name instX instY angle mirror scaling} {
    set raw [database ports -library $lib -cell $cell -view $view -name -location]
    if {![llength $raw]} {
        puts "instance_pins_in_parent_frame: no ports found for $lib/$cell/$view (instance $inst_name)"
        return {}
    }

    set mflag [string is true -strict $mirror]

    set out {}
    foreach p $raw {
        set pname [lindex $p 0]
        set loc   [lindex $p 1]
        set px    [lindex $loc 0]
        set py    [lindex $loc 1]

        # 1) Scale
        set px [expr {$px * $scaling}]
        set py [expr {$py * $scaling}]

        # 2) Rotate (Angle is degrees CW; multiples of 90 in practice)
        switch -- $angle {
            0   { set rx $px;            set ry $py           }
            90  { set rx $py;            set ry [expr {-$px}] }
            180 { set rx [expr {-$px}];  set ry [expr {-$py}] }
            270 { set rx [expr {-$py}];  set ry $px           }
            default {
                set theta [expr {$angle * 3.14159265358979323846 / 180.0}]
                set c [expr {cos($theta)}]
                set s [expr {sin($theta)}]
                set rx [expr {$px*$c + $py*$s}]
                set ry [expr {-$px*$s + $py*$c}]
            }
        }

        # 3) Mirror across Y-axis (flip X), AFTER rotate
        if {$mflag} {
            set rx [expr {-$rx}]
        }

        # 4) Translate by instance origin
        set fx [expr {$rx + $instX}]
        set fy [expr {$ry + $instY}]

        lappend out [list $pname [list $fx $fy]]
    }

    return $out
}

# Find the pin (across all visible instances) nearest to the current cursor.
# Returns a flat 12-element list:
#   {lib cell view inst_name pin_name pinX pinY instX instY angle mirror scaling}
# pinX,pinY are in the current frame (iu); the trailing fields describe the
# instance transform and let downstream callers (e.g. orientation lookup,
# wire stub placement) reuse the same transform without re-querying.
# Returns {} if there are no visible instances or no pins.
proc nearest_pin_to_cursor {} {
    set cursor [get_cursor_pos_in_iu]
    if {[llength $cursor] != 2} {
        return {}
    }
    lassign $cursor cx cy

	mode renderoff
    set insts [visible_instances]
	find none
	mode renderon
    if {![llength $insts]} {
        return {}
    }

    set best    {}
    set best_d2 ""

    foreach row $insts {
        # row: {lib cell view inst_name X Y Angle Mirror Scaling}
        lassign $row lib cell view iname ix iy angle mirror scaling

        set pins [instance_pins_in_parent_frame \
            $lib $cell $view $iname $ix $iy $angle $mirror $scaling]

        foreach p $pins {
            set pname [lindex $p 0]
            set loc   [lindex $p 1]
            set px    [lindex $loc 0]
            set py    [lindex $loc 1]

            set dx [expr {$px - $cx}]
            set dy [expr {$py - $cy}]
            set d2 [expr {$dx*$dx + $dy*$dy}]

            if {$best_d2 eq "" || $d2 < $best_d2} {
                set best_d2 $d2
                set best [list $lib $cell $view $iname $pname $px $py \
                               $ix $iy $angle $mirror $scaling]
            }
        }
    }

    return $best
}

# Map a port's TextJustification triplet to the compass direction the port
# faces in its symbol's local frame. Returns one of east/west/north/south,
# or "" if the triplet isn't one of the four supported edge cases.
proc _port_base_compass {dir hjust vjust} {
    switch -- "$dir|$hjust|$vjust" {
        "Normal|Left|Middle"  { return east  }
        "Normal|Right|Middle" { return west  }
        "Down|Center|Top"     { return south }
        "Down|Center|Bottom"  { return north }
        default               { return ""    }
    }
}

# Return the compass side the port's NAME text occupies (east/west/north/south),
# or "" if the justification is unrecognized. Unlike _port_base_compass this
# keys off only the relevant axis and handles both Up and Down text directions:
#   Direction Normal  -> Horizontal decides:  Left -> east,  Right -> west
#   Direction Up/Down -> Vertical   decides:  Top  -> south (name below),
#                                             Bottom -> north (name above)
# The off-axis justification (and Up-vs-Down) is intentionally ignored, so
# degenerate pins (e.g. a top-edge pin justified horizontally) still resolve.
# Used by callers that place something on the side OPPOSITE the name
# (draw_pin_lines, add_port_labels).
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

# Apply an instance's angle (CW degrees) and mirror (Y-axis, after rotate)
# to a base compass direction. Returns east/west/north/south, or "" if the
# input is invalid.
proc _xform_compass {orient angle mirror} {
    switch -- $orient {
        east    { set dx  1; set dy  0 }
        west    { set dx -1; set dy  0 }
        north   { set dx  0; set dy  1 }
        south   { set dx  0; set dy -1 }
        default { return "" }
    }

    switch -- $angle {
        0   { set rx $dx;            set ry $dy           }
        90  { set rx $dy;            set ry [expr {-$dx}] }
        180 { set rx [expr {-$dx}];  set ry [expr {-$dy}] }
        270 { set rx [expr {-$dy}];  set ry $dx           }
        default {
            set theta [expr {$angle * 3.14159265358979323846 / 180.0}]
            set c [expr {cos($theta)}]
            set s [expr {sin($theta)}]
            set rx [expr {round($dx*$c + $dy*$s)}]
            set ry [expr {round(-$dx*$s + $dy*$c)}]
        }
    }

    if {[string is true -strict $mirror]} {
        set rx [expr {-$rx}]
    }

    if {$rx ==  1 && $ry ==  0} { return east  }
    if {$rx == -1 && $ry ==  0} { return west  }
    if {$rx ==  0 && $ry ==  1} { return north }
    if {$rx ==  0 && $ry == -1} { return south }
    return ""
}

# Return the outward direction (east/west/north/south) the given pin
# faces in the parent (current) frame of reference.
#
# pinX/pinY (parent frame) disambiguate among duplicate-named ports in
# the symbol -- e.g. supplies that appear multiple times, or pass-through
# pins shown on both edges. We open the symbol view briefly, collect every
# port's name+local-XY+TextJustification, transform each candidate's local
# XY to the parent frame (same chain as instance_pins_in_parent_frame),
# and pick the one closest to pinX,pinY.
# Returns {compass fontsize} on success, "" on failure.
# fontsize is the symbol-view port's FontSize property (NOT the textlabel's),
# read as-is from `property get -name FontSize -system`. Use `-units iu` on
# `property set` when writing it back.
# Decide which edge of the symbol a pin sits on from its LOCAL position
# relative to the port bounding box, and return the outward compass direction
# (east/west/north/south) in the symbol's own frame.
#
# Position, not TextJustification, is the primary signal: some symbols have
# degenerate pins (e.g. a pin on the top edge but justified horizontally),
# where the text orientation would imply a facing that juts back into the body.
# The pin's edge is the bbox edge it is CLOSEST to -- not the dominant axis of
# its offset from the bbox center, which misclassifies pins near a corner of a
# wide/tall symbol (a bottom-edge pin at the far left of a wide block is much
# farther from the horizontal center than from the vertical one, but it still
# faces south). An edge pin defines the bbox extent on its side, so its
# distance to its own edge is exactly 0. Local +y is up (north).
#
# An axis with no extent (all ports at one x, or one y) carries no positional
# signal, so its two edges are excluded. On an exact tie (a true corner pin,
# closest to two edges at once), the optional justification hint -- the facing
# implied by the pin's name text, from _pin_name_side -- breaks the tie if it
# matches one of the tied edges; otherwise the tie falls to horizontal.
# Returns "" only for a degenerate bbox (all ports coincident).
proc _edge_compass_from_pos {lx ly xmin xmax ymin ymax {hint ""}} {
    set cands {}
    if {$xmax > $xmin} {
        lappend cands [list [expr {$lx - $xmin}] west]
        lappend cands [list [expr {$xmax - $lx}] east]
    }
    if {$ymax > $ymin} {
        lappend cands [list [expr {$ly - $ymin}] south]
        lappend cands [list [expr {$ymax - $ly}] north]
    }
    if {![llength $cands]} { return "" }

    set dmin ""
    foreach c $cands {
        set d [lindex $c 0]
        if {$dmin eq "" || $d < $dmin} { set dmin $d }
    }
    set tied {}
    foreach c $cands {
        if {[lindex $c 0] == $dmin} { lappend tied [lindex $c 1] }
    }
    if {[llength $tied] > 1 && $hint ne "" && $hint in $tied} {
        return $hint
    }
    return [lindex $tied 0]
}

proc pin_orientation_in_parent_frame {lib cell view pin_name pinX pinY instX instY angle mirror scaling} {

    mode renderoff
    cell open -cell $cell -design $lib -view $view -newwindow

    set ports {}
    set filterScript {
        set n      [property get -name Name -system]
        set lx     [property get -name X -system]
        set ly     [property get -name Y -system]
        set ddir   [property get -name TextJustification.Direction  -system]
        set dhjust [property get -name TextJustification.Horizontal -system]
        set dvjust [property get -name TextJustification.Vertical   -system]
        set fs     [property get -name FontSize                     -system]
        lappend ports [list $n $lx $ly $ddir $dhjust $dvjust $fs]
        expr {1}
    }
    find port -scope view -filter $filterScript -goto none

    window close
    mode renderon

    if {![llength $ports]} {
        puts "pin_orientation_in_parent_frame: no ports in $lib/$cell/$view"
        return ""
    }

    set mflag [string is true -strict $mirror]

    # Port bounding box in the symbol's local frame -- defines which edge each
    # pin sits on. Computed over ALL ports (every pin defines the extent).
    set xmin ""; set xmax ""; set ymin ""; set ymax ""
    foreach row $ports {
        lassign $row n lx ly
        if {$xmin eq "" || $lx < $xmin} { set xmin $lx }
        if {$xmax eq "" || $lx > $xmax} { set xmax $lx }
        if {$ymin eq "" || $ly < $ymin} { set ymin $ly }
        if {$ymax eq "" || $ly > $ymax} { set ymax $ly }
    }

    set best_lx ""
    set best_ly ""
    set best_fs ""
    set best_d2 ""
    set best_just {}

    foreach row $ports {
        lassign $row n lx ly ddir dhjust dvjust fs
        if {$n ne $pin_name} { continue }

        # local -> parent transform (mirrors instance_pins_in_parent_frame;
        # keep the two in sync if either is corrected). Only used here to pick
        # the right port among duplicate names by nearness to pinX,pinY.
        set sx [expr {$lx * $scaling}]
        set sy [expr {$ly * $scaling}]
        switch -- $angle {
            0   { set rx $sx;            set ry $sy           }
            90  { set rx $sy;            set ry [expr {-$sx}] }
            180 { set rx [expr {-$sx}];  set ry [expr {-$sy}] }
            270 { set rx [expr {-$sy}];  set ry $sx           }
            default {
                set theta [expr {$angle * 3.14159265358979323846 / 180.0}]
                set c [expr {cos($theta)}]
                set s [expr {sin($theta)}]
                set rx [expr {$sx*$c + $sy*$s}]
                set ry [expr {-$sx*$s + $sy*$c}]
            }
        }
        if {$mflag} { set rx [expr {-$rx}] }
        set fx [expr {$rx + $instX}]
        set fy [expr {$ry + $instY}]

        set dx [expr {$fx - $pinX}]
        set dy [expr {$fy - $pinY}]
        set d2 [expr {$dx*$dx + $dy*$dy}]

        if {$best_d2 eq "" || $d2 < $best_d2} {
            set best_d2 $d2
            set best_lx $lx
            set best_ly $ly
            set best_fs $fs
            set best_just [list $ddir $dhjust $dvjust]
        }
    }

    if {$best_lx eq ""} {
        puts "pin_orientation_in_parent_frame: no port named '$pin_name' in $lib/$cell/$view"
        return ""
    }

    # Facing is decided by the pin's position on the symbol (nearest bbox
    # edge) -- robust to degenerate pins (e.g. a top-edge pin justified
    # horizontally). Text justification is only a tie-break hint for true
    # corner pins. _xform_compass then applies the instance angle/mirror.
    set hint [_pin_name_side {*}$best_just]
    set base [_edge_compass_from_pos $best_lx $best_ly $xmin $xmax $ymin $ymax $hint]
    if {$base eq ""} {
        puts "pin_orientation_in_parent_frame: cannot infer edge for '$pin_name' (degenerate port bbox in $lib/$cell/$view)"
        return ""
    }

    return [list [_xform_compass $base $angle $mirror] $best_fs]
}


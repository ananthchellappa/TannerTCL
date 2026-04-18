# ============================================================
# Port spacing utility for Tanner S-Edit
#
# Behavior:
#   - Uses only selected ports
#   - Infers whether the selected set extends mainly in X or Y
#   - Computes current average spacing along that axis
#   - User supplies ratio = new_spacing / old_spacing
#   - New spacing = old average spacing * ratio
#   - Actual applied spacing is snapped ONCE to the snap grid
#   - If snapped new spacing < snap grid spacing, do nothing
#   - Anchor port stays fixed:
#         * horizontal series -> leftmost port stays fixed
#         * vertical series   -> lowest-Y port stays fixed
#   - In the final moved condition, all ports are forced onto the
#     anchor port's coordinate in the OTHER dimension
#         * horizontal series -> all ports get anchor Y
#         * vertical series   -> all ports get anchor X
#   - The originally operated-on ports are reselected at the end
#   - Move order avoids temporary overlap problems:
#         * increasing spacing -> farthest from anchor first
#         * decreasing spacing -> nearest to anchor first
# ============================================================


# ------------------------------------------------------------
# Return snap grid size
# ------------------------------------------------------------
proc get_snap_grid_size {} {
    return [setup schematicgrid get -snapgridsize]
}


# ------------------------------------------------------------
# Snap a coordinate/value to nearest grid point
# ------------------------------------------------------------
proc snap_to_grid {value grid} {
    if {$grid <= 0} {
        return $value
    }
    return [expr {round(double($value) / double($grid)) * $grid}]
}

# ------------------------------------------------------------
# Snap upward to next grid point (ceiling)
# ------------------------------------------------------------
proc snap_up_to_grid {value grid} {
    if {$grid <= 0} {
        return $value
    }
    return [expr {ceil(double($value) / double($grid)) * $grid}]
}

# ------------------------------------------------------------
# Snap downward to previous grid point (floor)
# ------------------------------------------------------------
proc snap_down_to_grid {value grid} {
    if {$grid <= 0} {
        return $value
    }
    return [expr {floor(double($value) / double($grid)) * $grid}]
}


# ------------------------------------------------------------
# Read selected ports into normalized records:
#   {id name x y}
# ------------------------------------------------------------
proc collect_selected_port_records {} {
    set rawPorts [database ports -selected -location -name]

    if {[llength $rawPorts] == 0} {
        return {}
    }

    set recs {}
    set id 0

    foreach p $rawPorts {
        set loc  [lindex $p 0]
        set name [lindex $p 1]
        set x    [lindex $loc 0]
        set y    [lindex $loc 1]

        lappend recs [list $id $name $x $y]
        incr id
    }

    return $recs
}


# ------------------------------------------------------------
# Infer dominant axis from bounding-box spread
# Returns "X" or "Y"
# ------------------------------------------------------------
proc infer_port_series_axis {portRecs} {
    set xs {}
    set ys {}

    foreach rec $portRecs {
        lappend xs [lindex $rec 2]
        lappend ys [lindex $rec 3]
    }

    set sx [lsort -integer $xs]
    set sy [lsort -integer $ys]

    set minX [lindex $sx 0]
    set maxX [lindex $sx end]
    set minY [lindex $sy 0]
    set maxY [lindex $sy end]

    set dx [expr {$maxX - $minX}]
    set dy [expr {$maxY - $minY}]

    if {$dx >= $dy} {
        return "X"
    } else {
        return "Y"
    }
}


# ------------------------------------------------------------
# Sort records physically along axis
# record format: {id name x y}
# ------------------------------------------------------------
proc sort_port_records_along_axis {portRecs axis} {
    set tmp {}

    if {$axis eq "X"} {
        foreach rec $portRecs {
            set id   [lindex $rec 0]
            set name [lindex $rec 1]
            set x    [lindex $rec 2]
            set y    [lindex $rec 3]
            lappend tmp [list $x $y $id $name]
        }

        # secondary Y, then primary X
        set tmp [lsort -integer -index 0 [lsort -integer -index 1 $tmp]]

        set out {}
        foreach t $tmp {
            set x    [lindex $t 0]
            set y    [lindex $t 1]
            set id   [lindex $t 2]
            set name [lindex $t 3]
            lappend out [list $id $name $x $y]
        }
        return $out
    } else {
        foreach rec $portRecs {
            set id   [lindex $rec 0]
            set name [lindex $rec 1]
            set x    [lindex $rec 2]
            set y    [lindex $rec 3]
            lappend tmp [list $y $x $id $name]
        }

        # secondary X, then primary Y
        set tmp [lsort -integer -index 0 [lsort -integer -index 1 $tmp]]

        set out {}
        foreach t $tmp {
            set y    [lindex $t 0]
            set x    [lindex $t 1]
            set id   [lindex $t 2]
            set name [lindex $t 3]
            lappend out [list $id $name $x $y]
        }
        return $out
    }
}


# ------------------------------------------------------------
# Compute average adjacent spacing along dominant axis
# ------------------------------------------------------------
proc compute_average_port_spacing {sortedPortRecs axis} {
    set n [llength $sortedPortRecs]
    if {$n < 2} {
        error "Need at least two selected ports"
    }

    set sum 0.0
    set cnt 0

    for {set i 0} {$i < $n-1} {incr i} {
        set a [lindex $sortedPortRecs $i]
        set b [lindex $sortedPortRecs [expr {$i+1}]]

        if {$axis eq "X"} {
            set d [expr {[lindex $b 2] - [lindex $a 2]}]
        } else {
            set d [expr {[lindex $b 3] - [lindex $a 3]}]
        }

        set sum [expr {$sum + $d}]
        incr cnt
    }

    return [expr {$sum / double($cnt)}]
}


# ------------------------------------------------------------
# Build target records:
#   {id name oldX oldY targetX targetY}
#
# Applied spacing is already snapped once, then reused.
# The first record is always the anchor (fixed port).
#
# IMPORTANT:
#   In the final moved condition, all ports are aligned to the
#   anchor port in the OTHER dimension.
# ------------------------------------------------------------
proc build_target_port_positions {sortedPortRecs axis appliedSpacing} {
    set targets {}

    set anchor  [lindex $sortedPortRecs 0]
    set anchorX [lindex $anchor 2]
    set anchorY [lindex $anchor 3]

    set n [llength $sortedPortRecs]
    for {set i 0} {$i < $n} {incr i} {
        set rec  [lindex $sortedPortRecs $i]
        set id   [lindex $rec 0]
        set name [lindex $rec 1]
        set oldX [lindex $rec 2]
        set oldY [lindex $rec 3]

        if {$axis eq "X"} {
            set targetX [expr {$anchorX + $i * $appliedSpacing}]
            set targetY $anchorY
        } else {
            set targetX $anchorX
            set targetY [expr {$anchorY + $i * $appliedSpacing}]
        }

        lappend targets [list $id $name $oldX $oldY $targetX $targetY]
    }

    return $targets
}


# ------------------------------------------------------------
# Select a port by exact X,Y using filtered find.
#
# add = 0  -> replace selection with this port
# add = 1  -> add this port to existing selection
# ------------------------------------------------------------
proc select_port_at_xy {knownX knownY {add 0}} {
    set filterScript [format {
        set X [property get -name X -system]
        set Y [property get -name Y -system]
        expr { $X == %s && $Y == %s }
    } $knownX $knownY]

    if {$add} {
        set rc [catch {
            find port -scope view -filter $filterScript -goto none -add
        } msg]
    } else {
        set rc [catch {
            find port -scope view -filter $filterScript -goto none
        } msg]
    }

    if {$rc} {
        return 0
    }

    set sel [database ports -selected -location -name]
    if {[llength $sel] < 1} {
        return 0
    }

    return 1
}


# ------------------------------------------------------------
# Move one port from old -> target using exact original XY
# ------------------------------------------------------------
proc move_port_from_original_to_target {name oldX oldY targetX targetY} {
    set dx [expr {$targetX - $oldX}]
    set dy [expr {$targetY - $oldY}]

    if {$dx == 0 && $dy == 0} {
        return 1
    }

    catch {select clear}

    if {![select_port_at_xy $oldX $oldY 0]} {
        puts "Could not reselect port '$name' at ($oldX,$oldY)"
        return 0
    }

    draw moveby -x $dx -y $dy -units iu
    return 1
}


# ------------------------------------------------------------
# Apply all target moves
#
# Move-order rule to avoid temporary collisions:
#   increasing spacing -> farthest from anchor first
#   decreasing spacing -> nearest to anchor first
#
# targets are already in anchor-relative order:
#   index 0 = anchor, index end = farthest
# ------------------------------------------------------------
proc apply_target_port_positions {targets appliedSpacing oldAvg} {
    set n [llength $targets]

    if {$appliedSpacing > $oldAvg} {
        # increasing spacing:
        # move farthest first, keep anchor fixed
        for {set i [expr {$n - 1}]} {$i >= 1} {incr i -1} {
            set t [lindex $targets $i]

            set name    [lindex $t 1]
            set oldX    [lindex $t 2]
            set oldY    [lindex $t 3]
            set targetX [lindex $t 4]
            set targetY [lindex $t 5]

            if {![move_port_from_original_to_target $name $oldX $oldY $targetX $targetY]} {
                return 0
            }
        }
    } else {
        # decreasing spacing or unchanged:
        # move nearest first, keep anchor fixed
        for {set i 1} {$i < $n} {incr i} {
            set t [lindex $targets $i]

            set name    [lindex $t 1]
            set oldX    [lindex $t 2]
            set oldY    [lindex $t 3]
            set targetX [lindex $t 4]
            set targetY [lindex $t 5]

            if {![move_port_from_original_to_target $name $oldX $oldY $targetX $targetY]} {
                return 0
            }
        }
    }

    return 1
}


# ------------------------------------------------------------
# Reselect all operated-on ports by FINAL XY
# First one selects normally; rest use -add.
# ------------------------------------------------------------
proc reselect_ports_by_final_records {targets} {
    catch {select clear}

    set first 1
    foreach t $targets {
        set x [lindex $t 4]
        set y [lindex $t 5]

        if {$first} {
            if {![select_port_at_xy $x $y 0]} {
                puts "Warning: could not reselect final port at ($x,$y)"
            }
            set first 0
        } else {
            if {![select_port_at_xy $x $y 1]} {
                puts "Warning: could not reselect final port at ($x,$y)"
            }
        }
    }
}


# ------------------------------------------------------------
# Main utility
# ------------------------------------------------------------
proc change_selected_port_spacing_by_ratio {ratio} {
    if {$ratio <= 0} {
        puts "Ratio must be > 0."
        return
    }

    set ports [collect_selected_port_records]

    set n [llength $ports]
    if {$n == 0} {
        puts "No selected ports found."
        return
    }
    if {$n < 2} {
        puts "Need at least two selected ports."
        return
    }

    set snapGrid [get_snap_grid_size]
    if {$snapGrid <= 0} {
        puts "Invalid snap grid size: $snapGrid"
        return
    }

    set axis    [infer_port_series_axis $ports]
    set ordered [sort_port_records_along_axis $ports $axis]
    set oldAvg  [compute_average_port_spacing $ordered $axis]

    set requestedNewSpacing [expr {$oldAvg * $ratio}]

    # Direction-aware snapping:
    #   increase -> snap upward, and ensure at least one grid more than old spacing
    #   decrease -> snap downward
    if {$requestedNewSpacing > $oldAvg} {
        set appliedSpacing [snap_up_to_grid $requestedNewSpacing $snapGrid]

        # Ensure a real increase of at least one snap-grid step
        set minIncreasedSpacing [expr {[snap_up_to_grid $oldAvg $snapGrid] + $snapGrid}]
        if {$appliedSpacing < $minIncreasedSpacing} {
            set appliedSpacing $minIncreasedSpacing
        }
    } elseif {$requestedNewSpacing < $oldAvg} {
        set appliedSpacing [snap_down_to_grid $requestedNewSpacing $snapGrid]
    } else {
        set appliedSpacing [snap_to_grid $requestedNewSpacing $snapGrid]
    }

    if {$appliedSpacing < $snapGrid} {
        puts "No action taken."
        puts "Requested spacing after grid rounding ($appliedSpacing) is less than snap grid ($snapGrid)."
        return
    }

    set targets [build_target_port_positions $ordered $axis $appliedSpacing]

    if {![apply_target_port_positions $targets $appliedSpacing $oldAvg]} {
        puts "Aborted: failed while moving one or more ports."
        return
    }

    reselect_ports_by_final_records $targets

    puts "Port spacing update complete."
    puts "Axis inferred                : $axis"
    puts "Number of ports              : $n"
    puts "Previous average spacing     : $oldAvg"
    puts "Ratio applied                : $ratio"
    puts "Requested new spacing        : $requestedNewSpacing"
    puts "Applied on-grid spacing      : $appliedSpacing"
    puts "Snap grid                    : $snapGrid"
}


# ------------------------------------------------------------
# Convenience wrapper
# ------------------------------------------------------------
proc respace_selected_ports {ratio} {
    mode renderoff
    change_selected_port_spacing_by_ratio $ratio
    mode renderon
}

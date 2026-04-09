# ------------------------------------------------------------------
# report_array_row_dimensionality
#
# Goal:
#   Infer how many ROWS are present in the currently selected instances,
#   using an X-unit-cell-consistency criterion rather than naive "same Y".
#
# Idea:
#   For candidate row counts = 1..N:
#     1) Sort points by Y
#     2) Split into rows at the largest Y gaps
#     3) For each row, sort by X and compute adjacent dX values
#     4) Score the candidate by how tight those dX values are
#        (plus penalties for extra rows / singleton rows / suspicious
#        duplicate-X adjacency inside an inferred row)
#   Pick the row count with the best score.
#
# Notes:
#   - Focus is ONLY on inferred row count for now.
#   - X min/max unit-cell distances are reported, along with instance pairs.
#   - This assumes helper proc sed_list_selected_inst_names exists.
#   - This uses property get -name X/Y -system on a selected instance.
#
# If your local "clear selection" command differs, adjust _arr_select_only_inst.
# ------------------------------------------------------------------

proc _arr_abs {v} {
    expr {abs($v)}
}

proc _arr_min {a b} {
    expr {$a < $b ? $a : $b}
}

proc _arr_max {a b} {
    expr {$a > $b ? $a : $b}
}

proc _arr_sort_points_by_y_desc {points} {
    # point = {name x y}
    lsort -real -decreasing -index 2 $points
}

proc _arr_sort_points_by_x {points} {
    # point = {name x y}
    lsort -real -index 1 $points
}

proc _arr_median {vals} {
    set n [llength $vals]
    if {$n == 0} { return "" }

    set s [lsort -real $vals]
    if {$n % 2} {
        return [lindex $s [expr {$n / 2}]]
    } else {
        set a [lindex $s [expr {$n / 2 - 1}]]
        set b [lindex $s [expr {$n / 2}]]
        expr {($a + $b) / 2.0}
    }
}

proc _arr_select_only_inst {instName} {
    # Adjust these commands if your local S-Edit environment uses a different
    # clear-selection command.
    catch {unselect all}
    catch {deselect all}
    catch {edit deselect}
    catch {find instance -scope view -name $instName -goto none}
}

proc _arr_get_inst_xy {instName} {
    _arr_select_only_inst $instName
    set x [property get -name X -system]
    set y [property get -name Y -system]
    return [list $x $y]
}

proc _arr_collect_selected_points {} {
    set names [sed_list_selected_inst_names]
    set points {}

    foreach name $names {
        set xy [_arr_get_inst_xy $name]
        if {[llength $xy] != 2} {
            continue
        }
        lassign $xy x y
        lappend points [list $name [expr {double($x)}] [expr {double($y)}]]
    }
    return $points
}

proc _arr_partition_by_largest_y_gaps {points rowCount} {
    # points expected sorted by descending Y
    set n [llength $points]
    if {$n == 0} { return {} }
    if {$rowCount <= 1} { return [list $points] }
    if {$rowCount >= $n} {
        set out {}
        foreach p $points { lappend out [list $p] }
        return $out
    }

    # Build list of gaps between consecutive Y-sorted points.
    # entry = {gap idxBeforeCut}
    set gaps {}
    for {set i 0} {$i < $n-1} {incr i} {
        set y1 [lindex [lindex $points $i] 2]
        set y2 [lindex [lindex $points [expr {$i+1}]] 2]
        set gap [_arr_abs [expr {$y1 - $y2}]]
        lappend gaps [list $gap $i]
    }

    # Pick the largest (rowCount-1) gaps as cut boundaries.
    set sortedGaps [lsort -real -decreasing -index 0 $gaps]
    set cuts {}
    for {set i 0} {$i < $rowCount-1 && $i < [llength $sortedGaps]} {incr i} {
        lappend cuts [lindex [lindex $sortedGaps $i] 1]
    }
    set cuts [lsort -integer $cuts]

    # Partition.
    set rows {}
    set start 0
    foreach cut $cuts {
        lappend rows [lrange $points $start $cut]
        set start [expr {$cut + 1}]
    }
    lappend rows [lrange $points $start end]

    return $rows
}

proc _arr_row_dx_stats {rowPoints} {
    # Returns dict with:
    #   dxCount, dxVals, dxMin, dxMinPair, dxMax, dxMaxPair,
    #   medianDx, relSpread, zeroishDxCount, medianPositiveDx
    #
    # zeroishDxCount is used to penalize "stacked" same-X points that were
    # incorrectly put into one inferred row.

    set rowPoints [_arr_sort_points_by_x $rowPoints]
    set m [llength $rowPoints]

    set dxVals {}
    set positiveDxVals {}
    set dxMin ""
    set dxMax ""
    set dxMinPair ""
    set dxMaxPair ""

    for {set i 0} {$i < $m-1} {incr i} {
        set p1 [lindex $rowPoints $i]
        set p2 [lindex $rowPoints [expr {$i+1}]]

        set n1 [lindex $p1 0]
        set x1 [lindex $p1 1]
        set n2 [lindex $p2 0]
        set x2 [lindex $p2 1]

        set dx [_arr_abs [expr {$x2 - $x1}]]
        lappend dxVals $dx

        if {$dx > 0} {
            lappend positiveDxVals $dx
        }

        if {$dxMin eq "" || $dx < $dxMin} {
            set dxMin $dx
            set dxMinPair [list $n1 $n2]
        }
        if {$dxMax eq "" || $dx > $dxMax} {
            set dxMax $dx
            set dxMaxPair [list $n1 $n2]
        }
    }

    set dxCount [llength $dxVals]
    set medianDx [_arr_median $dxVals]
    set medianPositiveDx [_arr_median $positiveDxVals]

    if {$dxCount <= 1 || $medianDx eq "" || $medianDx == 0} {
        set relSpread 0.0
    } else {
        set relSpread [expr {($dxMax - $dxMin) / double($medianDx)}]
    }

    # Count "zero-ish" adjacent dX values.
    # If we have a meaningful positive pitch, use 10% of it as threshold.
    # Otherwise fall back to exact zero.
    set zeroishDxCount 0
    if {$medianPositiveDx ne "" && $medianPositiveDx > 0} {
        set zeroThresh [expr {0.10 * $medianPositiveDx}]
    } else {
        set zeroThresh 0.0
    }

    foreach dx $dxVals {
        if {$dx <= $zeroThresh} {
            incr zeroishDxCount
        }
    }

    return [dict create \
        dxCount          $dxCount \
        dxVals           $dxVals \
        dxMin            $dxMin \
        dxMinPair        $dxMinPair \
        dxMax            $dxMax \
        dxMaxPair        $dxMaxPair \
        medianDx         $medianDx \
        relSpread        $relSpread \
        zeroishDxCount   $zeroishDxCount \
        medianPositiveDx $medianPositiveDx]
}

proc _arr_score_partition {rows} {
    # Lower is better.
    #
    # Terms:
    #   spread term         : weighted average of per-row relative dX spread
    #   row penalty         : modest bias against too many rows
    #   singleton penalty   : penalize rows with only one point
    #   zero-dX penalty     : penalize duplicate/near-duplicate X inside a row
    #
    # The zero-dX penalty fixes the case where vertically stacked rows with the
    # same X coordinates are incorrectly merged into one row.

    set totalDx 0
    set weightedSpread 0.0
    set singletonRows 0
    set totalZeroishDx 0

    foreach row $rows {
        set rowN [llength $row]
        if {$rowN <= 1} {
            incr singletonRows
        }

        set st [_arr_row_dx_stats $row]
        set dxCount        [dict get $st dxCount]
        set relSpread      [dict get $st relSpread]
        set zeroishDxCount [dict get $st zeroishDxCount]

        set totalDx [expr {$totalDx + $dxCount}]
        set weightedSpread [expr {$weightedSpread + $dxCount * $relSpread}]
        set totalZeroishDx [expr {$totalZeroishDx + $zeroishDxCount}]
    }

    if {$totalDx > 0} {
        set spreadScore [expr {$weightedSpread / double($totalDx)}]
        set zeroishFrac [expr {$totalZeroishDx / double($totalDx)}]
    } else {
        set spreadScore 0.0
        set zeroishFrac 0.0
    }

    set rowPenalty       [expr {0.20 * ([llength $rows] - 1)}]
    set singletonPenalty [expr {0.35 * $singletonRows}]

    # Strong penalty for rows that contain same-X neighbors.
    set zeroDxPenalty [expr {1.50 * $zeroishFrac}]

    expr {$spreadScore + $rowPenalty + $singletonPenalty + $zeroDxPenalty}
}

proc _arr_choose_best_row_partition {points} {
    set n [llength $points]
    if {$n == 0} {
        return [dict create rows {} rowCount 0 score 0.0]
    }

    set pointsY [_arr_sort_points_by_y_desc $points]

    set bestScore ""
    set bestRows  {}
    set bestCount 1

    for {set r 1} {$r <= $n} {incr r} {
        set rows  [_arr_partition_by_largest_y_gaps $pointsY $r]
        set score [_arr_score_partition $rows]

        if {$bestScore eq "" || $score < $bestScore} {
            set bestScore $score
            set bestRows  $rows
            set bestCount $r
        }
    }

    return [dict create rows $bestRows rowCount $bestCount score $bestScore]
}

proc _arr_global_dx_report {rows} {
    set allDxVals {}
    set globalMin ""
    set globalMax ""
    set globalMinPair ""
    set globalMaxPair ""

    foreach row $rows {
        set st [_arr_row_dx_stats $row]
        foreach dx [dict get $st dxVals] {
            lappend allDxVals $dx
        }

        set dxMin [dict get $st dxMin]
        set dxMax [dict get $st dxMax]

        if {$dxMin ne ""} {
            if {$globalMin eq "" || $dxMin < $globalMin} {
                set globalMin $dxMin
                set globalMinPair [dict get $st dxMinPair]
            }
        }

        if {$dxMax ne ""} {
            if {$globalMax eq "" || $dxMax > $globalMax} {
                set globalMax $dxMax
                set globalMaxPair [dict get $st dxMaxPair]
            }
        }
    }

    return [dict create \
        dxCount    [llength $allDxVals] \
        dxMedian   [_arr_median $allDxVals] \
        dxMin      $globalMin \
        dxMinPair  $globalMinPair \
        dxMax      $globalMax \
        dxMaxPair  $globalMaxPair]
}

proc report_array_row_dimensionality {} {
	mode renderoff
	_report_array_row_dimensionality
	mode renderon
}

proc _report_array_row_dimensionality {} {
    set points [_arr_collect_selected_points]
    set n [llength $points]

    if {$n < 2} {
        puts "----------------------------------------"
        puts "Array analysis"
        puts "----------------------------------------"
        puts "Need at least 2 selected instances."
        return
    }

    set best [_arr_choose_best_row_partition $points]
    set rows      [dict get $best rows]
    set rowCount  [dict get $best rowCount]

    if {$rowCount <= 1} {
        set classification "1-D array (single row)"
    } else {
        set classification "2-D array (multiple inferred rows)"
    }

    set gdx [_arr_global_dx_report $rows]

    puts "----------------------------------------"
    puts "Array analysis"
    puts "----------------------------------------"
    puts [format "Instances analyzed : %d" $n]
    puts [format "Estimated rows     : %d" $rowCount]
    puts ""

    puts [format "Classification     : %s" $classification]
    puts ""

    set dxCount [dict get $gdx dxCount]
    if {$dxCount > 0} {
        set dxMedian  [dict get $gdx dxMedian]
        set dxMin     [dict get $gdx dxMin]
        set dxMax     [dict get $gdx dxMax]
        set dxMinPair [dict get $gdx dxMinPair]
        set dxMaxPair [dict get $gdx dxMaxPair]

        puts [format "Representative pitch X : %.3f" $dxMedian]
        puts ""
        puts "Raw X adjacent-diff stats:"
        puts [format "  count                : %d" $dxCount]
        puts [format "  min                  : %.3f   (%s , %s)" \
            $dxMin [lindex $dxMinPair 0] [lindex $dxMinPair 1]]
        puts [format "  max                  : %.3f   (%s , %s)" \
            $dxMax [lindex $dxMaxPair 0] [lindex $dxMaxPair 1]]
    } else {
        puts "No X adjacent-diff stats available."
        puts "This can happen if every inferred row has only one instance."
    }

    puts ""
    puts "Per-row membership:"
    set idx 0
    foreach row $rows {
        incr idx
        set names {}
        foreach p [_arr_sort_points_by_x $row] {
            lappend names [lindex $p 0]
        }
        puts [format "  Row %d : %s" $idx [join $names { }]]
    }
}


# ---------------------------------------------------------------
# make_selected_array_uniform
#
# Uses inferred rows to regularize the selected instance array.
#
# Geometry used:
#   - Rows are ordered bottom -> top   (increasing Y)
#   - Within a row, instances are ordered left -> right (increasing X)
#
# Pitch extraction:
#   - X pitch = distance between first two instances in first row
#   - Y pitch = distance between first instance in first row and
#               first instance in second row
#
# Anchor:
#   - First instance in first row is the anchor.
#   - We explicitly write its original X/Y back to it, then read back
#     and verify they still match. If not, abort.
#
# Motion:
#   - targetX = anchorX + colIndex * xPitch
#   - targetY = anchorY + rowIndex * yPitch
#
# Notes:
#   - Requires at least:
#       * 2 inferred rows for Y pitch
#       * 2 instances in first row for X pitch
#   - Uses:
#       property set -name X -system -value <value> -units iu
#       property set -name Y -system -value <value> -units iu
# ---------------------------------------------------------------

proc _arr_sort_rows_bottom_to_top {rows} {
    set keyed {}
    foreach row $rows {
        if {[llength $row] == 0} { continue }

        # Use median Y of the row as the row's representative Y
        set yVals {}
        foreach p $row {
            lappend yVals [lindex $p 2]
        }
        set rowY [_arr_median $yVals]

        # Also sort the row left->right now
        set sortedRow [_arr_sort_points_by_x $row]

        lappend keyed [list $rowY $sortedRow]
    }

    set keyed [lsort -real -index 0 $keyed]

    set out {}
    foreach item $keyed {
        lappend out [lindex $item 1]
    }
    return $out
}

proc _arr_select_only_inst_strict {instName} {
    catch {unselect all}
    catch {deselect all}
    catch {edit deselect}
    catch {find instance -scope view -name $instName -goto none}
}

proc _arr_get_inst_xy_strict {instName} {
    _arr_select_only_inst_strict $instName
    set x [property get -name X -system]
    set y [property get -name Y -system]
    return [list [expr {double($x)}] [expr {double($y)}]]
}

proc _arr_set_inst_xy_iu {instName x y} {
    _arr_select_only_inst_strict $instName
    property set -name X -system -value $x -units iu
    property set -name Y -system -value $y -units iu
}

proc make_selected_array_uniform {} {
	mode renderoff
	_make_selected_array_uniform
	mode renderon
}

proc _make_selected_array_uniform {} {
    set points [_arr_collect_selected_points]
    set n [llength $points]

    if {$n < 4} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "Need enough selected instances to infer at least two rows."
        return
    }

    # Infer row structure using the previously built row-detection logic.
    set best [_arr_choose_best_row_partition $points]
    set rows [dict get $best rows]
    set rowCount [dict get $best rowCount]

    if {$rowCount < 2} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "Could not infer at least two rows."
        puts "Need at least two inferred rows to extract Y pitch."
        return
    }

    # Normalize row ordering:
    #   rows[0] = bottom row
    #   each row sorted left->right
    set rows [_arr_sort_rows_bottom_to_top $rows]

    set firstRow  [lindex $rows 0]
    set secondRow [lindex $rows 1]

    if {[llength $firstRow] < 2} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "First inferred row has fewer than 2 instances."
        puts "Cannot extract X pitch."
        return
    }

    if {[llength $secondRow] < 1} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "Second inferred row is empty."
        puts "Cannot extract Y pitch."
        return
    }

    # Anchor = first instance in first (bottom) row
    set anchorPoint [lindex $firstRow 0]
    set anchorName  [lindex $anchorPoint 0]
    set anchorXOld  [lindex $anchorPoint 1]
    set anchorYOld  [lindex $anchorPoint 2]

    # X pitch from first two instances in first row
    set p10 [lindex $firstRow 0]
    set p11 [lindex $firstRow 1]
    set xPitch [expr {abs([lindex $p11 1] - [lindex $p10 1])}]

    if {$xPitch == 0} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "Extracted X pitch is zero."
        puts "Cannot build a uniform horizontal pitch from first row."
        return
    }

    # Y pitch from first instance of first two rows
    set p20 [lindex $firstRow 0]
    set p30 [lindex $secondRow 0]
    set yPitch [expr {abs([lindex $p30 2] - [lindex $p20 2])}]

    if {$yPitch == 0} {
        puts "----------------------------------------"
        puts "Uniformize array"
        puts "----------------------------------------"
        puts "Extracted Y pitch is zero."
        puts "Cannot build a uniform vertical pitch from first two rows."
        return
    }

    puts "----------------------------------------"
    puts "Uniformize array"
    puts "----------------------------------------"
    puts [format "Instances analyzed : %d" $n]
    puts [format "Estimated rows     : %d" $rowCount]
    puts [format "Anchor instance    : %s" $anchorName]
    puts [format "Anchor location    : (%.3f, %.3f)" $anchorXOld $anchorYOld]
    puts [format "Pitch X            : %.3f" $xPitch]
    puts [format "Pitch Y            : %.3f" $yPitch]
    puts ""

    # Explicitly write anchor back to its original coordinates.
    # Then read back and verify.
    _arr_set_inst_xy_iu $anchorName $anchorXOld $anchorYOld
    set anchorXYNew [_arr_get_inst_xy_strict $anchorName]
    set anchorXNew [lindex $anchorXYNew 0]
    set anchorYNew [lindex $anchorXYNew 1]

    if {$anchorXNew != $anchorXOld || $anchorYNew != $anchorYOld} {
        puts "ERROR: Anchor instance did not preserve its original location after write/readback."
        puts [format "  Instance : %s" $anchorName]
        puts [format "  Expected : X=%.3f  Y=%.3f" $anchorXOld $anchorYOld]
        puts [format "  Readback : X=%.3f  Y=%.3f" $anchorXNew $anchorYNew]
        puts "Aborting without moving remaining instances."
        return
    }

    # Move all instances onto the grid defined by the anchor and pitches.
    set movedCount 0
    for {set r 0} {$r < [llength $rows]} {incr r} {
        set row [lindex $rows $r]
        set row [_arr_sort_points_by_x $row]

        for {set c 0} {$c < [llength $row]} {incr c} {
            set p [lindex $row $c]
            set instName [lindex $p 0]

            set targetX [expr {$anchorXOld + $c * $xPitch}]
            set targetY [expr {$anchorYOld + $r * $yPitch}]

            _arr_set_inst_xy_iu $instName $targetX $targetY
            incr movedCount
        }
    }

    puts [format "Moved instances    : %d" $movedCount]
    puts "Done."
}

# ------------------------------------------------------------
# Array instance renamer for Tanner S-Edit
#
# Naming:
#   1-D : <stem>_<i>
#   2-D : <stem>_<i>_<j>
#
# Stem + starting index come from the real "first" instance,
# where "first" = smallest X, then smallest Y.
#
# Examples:
#   MYDEV_5     -> stem=MYDEV,     start=(5)
#   XBANK_4_3   -> stem=XBANK,     start=(4,3)
#
# If the first instance name does not end in numeric suffix(es):
#   1-D default start -> 0
#   2-D default start -> (0,0)
# and the whole name is used as the stem.
#
# Assumptions for this version:
#   - same row  => same Y
#   - same col  => same X
#   - helper proc sed_list_selected_inst_names exists
# ------------------------------------------------------------

proc _arr_rename_select_only_inst {instName} {
    catch {unselect all}
    catch {deselect all}
    catch {edit deselect}
    catch {find instance -scope view -name $instName -goto none}
}

proc _arr_rename_get_inst_xy {instName} {
    _arr_rename_select_only_inst $instName
    set x [property get -name X -system]
    set y [property get -name Y -system]
    return [list [expr {double($x)}] [expr {double($y)}]]
}

proc _arr_rename_set_inst_name {instName newName} {
    _arr_rename_select_only_inst $instName
    property set -name Name -system -value $newName
}

proc _arr_collect_selected_inst_points {} {
    set names [sed_list_selected_inst_names]
    set points {}

    foreach instName $names {
        set xy [_arr_rename_get_inst_xy $instName]
        if {[llength $xy] != 2} {
            continue
        }
        lassign $xy x y
        lappend points [list $instName $x $y]
    }
    return $points
}

proc _arr_unique_sorted_coords {points coordIndex} {
    set vals {}
    foreach p $points {
        lappend vals [lindex $p $coordIndex]
    }
    return [lsort -real -unique $vals]
}

proc _arr_find_first_point {points} {
    # "first" = smallest X, then smallest Y
    set best ""
    foreach p $points {
        set x [lindex $p 1]
        set y [lindex $p 2]

        if {$best eq ""} {
            set best $p
            continue
        }

        set bx [lindex $best 1]
        set by [lindex $best 2]

        if {$x < $bx || ($x == $bx && $y < $by)} {
            set best $p
        }
    }
    return $best
}

proc _arr_parse_name_1d {name} {
    # Returns {stem startIndex}
    #
    # Match: <stem>_<n>
    if {[regexp {^(.*)_([-+]?\d+)$} $name -> stem idx]} {
        return [list $stem $idx]
    }

    # No numeric suffix found: use full name as stem, start at 0
    return [list $name 0]
}

proc _arr_parse_name_2d {name} {
    # Returns {stem startI startJ}
    #
    # Preferred match: <stem>_<i>_<j>
    if {[regexp {^(.*)_([-+]?\d+)_([-+]?\d+)$} $name -> stem i j]} {
        return [list $stem $i $j]
    }

    # Fallback: <stem>_<i>
    if {[regexp {^(.*)_([-+]?\d+)$} $name -> stem i]} {
        return [list $stem $i 0]
    }

    # No numeric suffix found: use full name as stem, start at (0,0)
    return [list $name 0 0]
}

proc _arr_build_rowcol_maps {points} {
    set xs [_arr_unique_sorted_coords $points 1]
    set ys [_arr_unique_sorted_coords $points 2]

    array set xToCol {}
    array set yToRow {}

    for {set c 0} {$c < [llength $xs]} {incr c} {
        set xToCol([lindex $xs $c]) $c
    }
    for {set r 0} {$r < [llength $ys]} {incr r} {
        set yToRow([lindex $ys $r]) $r
    }

    return [list $xs $ys [array get xToCol] [array get yToRow]]
}

proc _arr_sort_points_1d {points} {
    set xs [_arr_unique_sorted_coords $points 1]
    set ys [_arr_unique_sorted_coords $points 2]

    if {[llength $xs] > 1} {
        return [lsort -real -index 1 $points]
    } else {
        return [lsort -real -index 2 $points]
    }
}

proc _arr_group_points_2d {points} {
    set grouped {}

    set info [_arr_build_rowcol_maps $points]
    lassign $info xs ys xMapList yMapList

    array set xToCol $xMapList
    array set yToRow $yMapList

    set keyed {}
    foreach p $points {
        set x [lindex $p 1]
        set y [lindex $p 2]
        set row $yToRow($y)
        set col $xToCol($x)
        lappend keyed [list $row $col $p]
    }

    set keyed [lsort -integer -index 1 $keyed]
    set keyed [lsort -integer -index 0 $keyed]

    foreach item $keyed {
        lappend grouped [lindex $item 2]
    }
    return $grouped
}

proc name_selected_array_instances {} {
	mode renderoff
	_name_selected_array_instances
	mode renderon
}

proc _name_selected_array_instances {} {
    set points [_arr_collect_selected_inst_points]
    set n [llength $points]

    if {$n == 0} {
        puts "No selected instances found."
        return
    }

    set xs [_arr_unique_sorted_coords $points 1]
    set ys [_arr_unique_sorted_coords $points 2]

    set numX [llength $xs]
    set numY [llength $ys]

    if {$numX > 1 && $numY > 1} {
        set is2D 1
    } else {
        set is2D 0
    }

    set firstPoint [_arr_find_first_point $points]
    set firstName  [lindex $firstPoint 0]

    if {$is2D} {
        lassign [_arr_parse_name_2d $firstName] stem startI startJ
    } else {
        lassign [_arr_parse_name_1d $firstName] stem startI
    }

    set info [_arr_build_rowcol_maps $points]
    lassign $info xs ys xMapList yMapList
    array set xToCol $xMapList
    array set yToRow $yMapList

    puts "----------------------------------------"
    puts "Array instance renaming"
    puts "----------------------------------------"
    puts "Instances analyzed : $n"
    puts "Unique X values    : $numX"
    puts "Unique Y values    : $numY"
    puts "Anchor instance    : $firstName"
    puts [format "Anchor location    : (%.3f, %.3f)" \
        [lindex $firstPoint 1] [lindex $firstPoint 2]]
    puts "Stem used          : $stem"

    if {$is2D} {
        puts "Classification     : 2-D"
        puts "Start indices      : ($startI,$startJ)"
    } else {
        puts "Classification     : 1-D"
        puts "Start index        : $startI"
    }
    puts ""

    set renamedCount 0

    if {$is2D} {
        set orderedPoints [_arr_group_points_2d $points]

        foreach p $orderedPoints {
            set oldName [lindex $p 0]
            set x       [lindex $p 1]
            set y       [lindex $p 2]

            set col $xToCol($x)
            set row $yToRow($y)

            set newI [expr {$startI + $col}]
            set newJ [expr {$startJ + $row}]
            set newName "${stem}_${newI}_${newJ}"

            if {$oldName ne $newName} {
                _arr_rename_set_inst_name $oldName $newName
            }

            puts [format "%s  ->  %s" $oldName $newName]
            incr renamedCount
        }
    } else {
        set orderedPoints [_arr_sort_points_1d $points]

        for {set k 0} {$k < [llength $orderedPoints]} {incr k} {
            set p [lindex $orderedPoints $k]
            set oldName [lindex $p 0]
            set newName "${stem}_[expr {$startI + $k}]"

            if {$oldName ne $newName} {
                _arr_rename_set_inst_name $oldName $newName
            }

            puts [format "%s  ->  %s" $oldName $newName]
            incr renamedCount
        }
    }

    puts ""
    puts "Renamed instances  : $renamedCount"
    puts "Done."
}

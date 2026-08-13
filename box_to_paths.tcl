# box_to_paths.tcl
#
# Turn selected box (rectangle) shapes into an outline PATH, so a box that frames
# circuitry stops behaving like one big solid object that eats clicks and
# rubber-band selections. The outline looks the same; the middle is no longer a
# click target, so objects inside it can be selected normally.
#
#     each box  ->  ONE closed path: {x0 y0  x1 y0  x1 y1  x0 y1  x0 y0}
#
# Usage (S-Edit command console, with one or more boxes selected):
#     box_to_paths              ;# convert every selected box
#     box_to_paths -dryrun 1    ;# print the plan, change nothing
#     box_to_paths -keep 1      ;# draw the outlines, keep the boxes
#     box_to_paths -lines 1     ;# legacy: 4 separate 2-point paths (see below)
#
# ...or every box in the view at once, nothing selected beforehand:
#     box_to_paths_all          ;# = box_to_paths -scope view
#     box_to_paths_all -dryrun 1
# On a view full of frames that is a lot of undo steps (one per box, plus one
# for the delete), so dry-run it and save first.
#
# ONE path, not four, because a single closed path still selects, moves and
# deletes as a unit -- so no companion "select the other 3 sides" step is needed,
# and the conversion costs one undo step per box instead of four.
#
# It is drawn with `mode draw path` + `path -points`, which takes the geometry as
# DATA: no simulated clicks, so nothing is snapped and the outline lands exactly
# on the old box edge (verified 2026-08-13, specs/sedit_tcl_api_findings.md
# §6.1/§6.2). One `mode draw path` per path -- the arming is consumed by the
# first `path` call and a second call without re-arming silently does nothing.
#
# Going back the other way, when the frame needs resizing -- a box is far easier
# to adjust than a polyline, so convert, adjust, convert back:
#     path_to_box               ;# selected rectangular path -> box
#     path_to_box -tol 50       ;# ...allowing 50 iu of slop at the corners
#     path_to_box -dryrun 1     ;# print the box it would draw, change nothing
#
# ...or don't think about which direction you are going at all -- this swaps
# whatever is selected to the other form, boxes and rectangular paths together,
# and is the one worth binding to a key:
#     convert_box_paths         ;# box <-> path-box, on the selection
#     convert_box_paths -dryrun 1
# It refuses anything that is not an axis-aligned rectangle: an L, a Z, a
# diagonal or a 3-distinct-X polyline is rejected rather than approximated. A
# 4-vertex path that never closes IS accepted -- the four corners define the box.
#
# -lines 1 and select_box_paths cover the older 4-separate-paths outline, kept
# because designs already contain them: with any ONE side selected,
#     select_box_paths          ;# select the other 3 sides of this box
#     select_box_paths -tol 50  ;# ...allowing 50 iu of slop at the corners
# It reads every path's Vertices in one pass and walks the rectangle in memory
# (pure Tcl, unit-tested), not by stepping outward with region finds: no delta to
# tune, no risk of a region strip picking up a wire or a neighbouring shape that
# merely crosses the corner, and no dependence on bbox search working for `path`
# (verified only for wire/port/netlabel).
#
# A box's X,Y is its LOWER-LEFT corner (confirmed 2026-08-12), so the outline
# runs X,Y .. X+Width,Y+Height -- all four in iu.
#
# Snap grid: only the click-driven paths still care. `path -points` does not
# snap, but drawing a BOX (path_to_box) and the -lines fallback both go through
# `point click`, which does -- so those set the snap grid to 1 iu and restore it
# afterwards, and warn naming any coordinate that was off grid.
#
# Not carried over: the box's Color / line style. The new paths take whatever the
# current path drawing style is. (Colouring paths from Tcl is unverified -- see
# specs/sedit_tcl_api_findings.md before adding it.)
#
# This file follows the repo's pure/Tanner split: the b2p_* geometry procs below
# have no Tanner dependency and are unit-tested in tests/box_to_paths.test.

#=============================================================================
# PURE LAYER  (no Tanner API -- runs under stock tclsh, covered by tests)
#=============================================================================

# Property reads may come back as a 1-element list. Unwrap only those -- a
# blanket lindex truncates multi-element values (see the Vertices note in
# specs/sedit_tcl_api_findings.md §4).
proc b2p_scalar {v} {
    if {[llength $v] == 1} {
        return [lindex $v 0]
    }
    return $v
}

# -opt value parsing against a defaults dict; unknown/odd args are hard errors.
proc b2p_parse_opts {defaults arglist} {
    array set opt $defaults
    if {[llength $arglist] % 2} {
        error "options must come in -name value pairs (got: $arglist)"
    }
    foreach {k v} $arglist {
        if {![info exists opt($k)]} {
            error "unknown option '$k' -- valid: [lsort [array names opt]]"
        }
        set opt($k) $v
    }
    return [array get opt]
}

# Lower-left corner + extents -> the segments to draw, counter-clockwise from the
# bottom edge, each as {x1 y1 x2 y2}. A degenerate box (zero width or height)
# collapses to the one line that survives, not four stacked copies.
proc b2p_segs {x y w h} {
    set x0 $x
    set y0 $y
    set x1 [expr {$x + abs($w)}]
    set y1 [expr {$y + abs($h)}]
    if {$x0 == $x1 && $y0 == $y1} {
        return {}
    }
    set out {}
    set seen {}
    foreach seg [list \
            [list $x0 $y0 $x1 $y0] \
            [list $x1 $y0 $x1 $y1] \
            [list $x1 $y1 $x0 $y1] \
            [list $x0 $y1 $x0 $y0]] {
        lassign $seg ax ay bx by
        if {$ax == $bx && $ay == $by} continue
        set key [lsort [list "$ax,$ay" "$bx,$by"]]
        if {[lsearch -exact $seen $key] >= 0} continue
        lappend seen $key
        lappend out $seg
    }
    return $out
}

# Lower-left corner + extents -> ONE closed outline as a flat vertex list, ready
# for `path -points`: the four corners counter-clockwise from the lower left,
# with the first repeated to close it. A box with one zero extent collapses to
# the single line that survives; a zero-by-zero box to nothing.
proc b2p_rect_points {x y w h} {
    set x0 $x
    set y0 $y
    set x1 [expr {$x + abs($w)}]
    set y1 [expr {$y + abs($h)}]
    if {$x0 == $x1 && $y0 == $y1} {
        return {}
    }
    if {$x0 == $x1 || $y0 == $y1} {
        return [list $x0 $y0 $x1 $y1]
    }
    return [list $x0 $y0  $x1 $y0  $x1 $y1  $x0 $y1  $x0 $y0]
}

# The inverse: a path's flat vertex list -> the box {x y w h} it describes, or
# {} when it describes no box. x,y is the lower-left corner, matching how S-Edit
# reports a box.
#
# Accepted: exactly 4 corners, either left open (8 numbers, 3 sides drawn) or
# closed by repeating the first point (10 numbers). The four corners must be the
# four DIFFERENT corners of an axis-aligned rectangle, and every drawn side must
# be horizontal or vertical.
#
# Rejected, deliberately rather than approximated: diagonals, an L (only 3
# corners), a Z or bowtie (corners visited out of order -- caught because such an
# order always needs a diagonal side), and anything spanning more or fewer than
# two distinct X and two distinct Y values. `tol` allows slop for hand-drawn
# outlines whose corners do not quite meet.
proc b2p_path_rect {flat {tol 0}} {
    if {[llength $flat] != 8 && [llength $flat] != 10} {
        return {}
    }
    set pts {}
    foreach {px py} $flat {
        if {![string is double -strict $px] || ![string is double -strict $py]} {
            return {}
        }
        lappend pts [list $px $py]
    }

    # A closed outline repeats its first point; drop it and judge the 4 corners.
    if {[llength $pts] == 5} {
        lassign [lindex $pts 0]   fx fy
        lassign [lindex $pts end] lx ly
        if {abs($fx - $lx) > $tol || abs($fy - $ly) > $tol} {
            return {}
        }
        set pts [lrange $pts 0 3]
    }

    set x0 [lindex $pts 0 0] ; set x1 $x0
    set y0 [lindex $pts 0 1] ; set y1 $y0
    foreach p $pts {
        lassign $p px py
        if {$px < $x0} { set x0 $px } ; if {$px > $x1} { set x1 $px }
        if {$py < $y0} { set y0 $py } ; if {$py > $y1} { set y1 $py }
    }
    if {$x1 - $x0 <= $tol || $y1 - $y0 <= $tol} {
        return {}
    }

    # Each corner must sit ON a bounding-box corner, and on a DIFFERENT one --
    # that is what makes it a rectangle rather than a shape that merely fits in
    # the same bbox.
    set seen {}
    foreach p $pts {
        lassign $p px py
        set atx0 [expr {abs($px - $x0) <= $tol}]
        set atx1 [expr {abs($px - $x1) <= $tol}]
        set aty0 [expr {abs($py - $y0) <= $tol}]
        set aty1 [expr {abs($py - $y1) <= $tol}]
        if {!($atx0 || $atx1) || !($aty0 || $aty1)} {
            return {}
        }
        set key "[expr {$atx0 ? 0 : 1}],[expr {$aty0 ? 0 : 1}]"
        if {[lsearch -exact $seen $key] >= 0} {
            return {}
        }
        lappend seen $key
    }

    # Sides axis-aligned, and alternating H/V. Given four distinct corners the
    # alternation is implied, but checking it states the intent and is what
    # actually rejects a diagonal.
    set prev ""
    for {set i 0} {$i < 3} {incr i} {
        lassign [lindex $pts $i]             ax ay
        lassign [lindex $pts [expr {$i+1}]]  bx by
        set d [b2p_seg_dir [list $ax $ay $bx $by] $tol]
        if {$d eq "" || $d eq $prev} {
            return {}
        }
        set prev $d
    }

    return [list $x0 $y0 [expr {$x1 - $x0}] [expr {$y1 - $y0}]]
}

# Do two {x y w h} rectangles describe the same box? Compared numerically, not
# as strings: one side comes from a property read and the other from arithmetic,
# so "10" and "10.0" must not count as different boxes.
proc b2p_rect_same {a b {tol 0}} {
    if {[llength $a] != 4 || [llength $b] != 4} {
        return 0
    }
    foreach va $a vb $b {
        if {![string is double -strict $va] || ![string is double -strict $vb]} {
            return 0
        }
        if {abs($va - $vb) > $tol} {
            return 0
        }
    }
    return 1
}

# "x1, y1, x2, y2" (the Vertices property) -> flat {x1 y1 x2 y2}.
# Same normalisation as hnp_parse_vertices; duplicated so this file stays
# sourceable on its own.
proc b2p_parse_verts {s} {
    set flat {}
    foreach t [split [string map {, " "} $s]] {
        if {$t ne ""} { lappend flat $t }
    }
    return $flat
}

# Orientation of a 2-point segment: v (vertical), h (horizontal), or "" for
# diagonal / degenerate / not-a-2-point-segment.
proc b2p_seg_dir {seg {tol 0}} {
    if {[llength $seg] != 4} { return "" }
    lassign $seg x1 y1 x2 y2
    if {abs($x1-$x2) <= $tol && abs($y1-$y2) >  $tol} { return v }
    if {abs($y1-$y2) <= $tol && abs($x1-$x2) >  $tol} { return h }
    return ""
}

# The far end of `seg` given one of its endpoints, or {} if (x,y) is neither end.
proc b2p_other_end {seg x y {tol 0}} {
    lassign $seg x1 y1 x2 y2
    if {abs($x1-$x) <= $tol && abs($y1-$y) <= $tol} { return [list $x2 $y2] }
    if {abs($x2-$x) <= $tol && abs($y2-$y) <= $tol} { return [list $x1 $y1] }
    return {}
}

# Indices of the segments with an endpoint at (x,y), `skip` excluded.
proc b2p_ends_at {segs x y {tol 0} {skip -1}} {
    set out {}
    for {set i 0} {$i < [llength $segs]} {incr i} {
        if {$i == $skip} continue
        if {[llength [b2p_other_end [lindex $segs $i] $x $y $tol]]} {
            lappend out $i
        }
    }
    return $out
}

# Swap x/y throughout, so the rectangle search only ever has to handle a
# vertical seed.
proc b2p_transpose {segs} {
    set out {}
    foreach s $segs {
        lassign $s x1 y1 x2 y2
        lappend out [list $y1 $x1 $y2 $x2]
    }
    return $out
}

# The four segments of the axis-aligned rectangle that segment `i` is a side of,
# as sorted indices into `segs`; {} when there is no such closed rectangle.
# Both orientations are handled by transposing a horizontal seed into a vertical
# one -- indices survive the transpose, so the answer is returned as-is.
proc b2p_rect_through {segs i {tol 0}} {
    if {$i < 0 || $i >= [llength $segs]} { return {} }
    switch -- [b2p_seg_dir [lindex $segs $i] $tol] {
        v { return [b2p_rect_vertical $segs $i $tol] }
        h { return [b2p_rect_vertical [b2p_transpose $segs] $i $tol] }
    }
    return {}
}

# Seed is the vertical side x=X spanning ya..yb. Walk the rectangle: a
# horizontal side off each end, their far ends on a common X', and a vertical
# side closing X' back up. Every candidate combination is tried, so a corner
# shared with some other shape cannot derail it.
proc b2p_rect_vertical {segs i tol} {
    lassign [lindex $segs $i] sx1 sy1 sx2 sy2
    set x  $sx1
    set ya [expr {min($sy1,$sy2)}]
    set yb [expr {max($sy1,$sy2)}]

    foreach j [b2p_ends_at $segs $x $ya $tol $i] {
        if {[b2p_seg_dir [lindex $segs $j] $tol] ne "h"} continue
        lassign [b2p_other_end [lindex $segs $j] $x $ya $tol] bx by
        if {abs($bx - $x) <= $tol} continue

        foreach k [b2p_ends_at $segs $x $yb $tol $i] {
            if {$k == $j} continue
            if {[b2p_seg_dir [lindex $segs $k] $tol] ne "h"} continue
            lassign [b2p_other_end [lindex $segs $k] $x $yb $tol] cx cy
            if {abs($cx - $bx) > $tol} continue

            foreach m [b2p_ends_at $segs $bx $ya $tol $i] {
                if {$m == $j || $m == $k} continue
                if {[b2p_seg_dir [lindex $segs $m] $tol] ne "v"} continue
                lassign [b2p_other_end [lindex $segs $m] $bx $ya $tol] dx dy
                if {abs($dx - $cx) > $tol || abs($dy - $yb) > $tol} continue
                return [lsort -integer [list $i $j $k $m]]
            }
        }
    }
    return {}
}

# Coordinate lists present in `after` but not in `before` -- i.e. what a draw
# added to the view. Multiset aware, so drawing a second copy of a line that was
# already there still counts as new. Deduplicated: the result is used as a
# match set, and a match set does not care how many copies it names.
proc b2p_new_coords {before after} {
    array set cnt {}
    foreach c $before { incr cnt($c) -1 }
    foreach c $after  { incr cnt($c)  1 }
    set out {}
    foreach c $after {
        if {$cnt($c) > 0 && [lsearch -exact $out $c] < 0} {
            lappend out $c
        }
    }
    return $out
}

# Coordinates in `segs` that do not sit on `grid` (i.e. that point click would
# move). Empty list = the outline will be drawn exactly where the box was.
proc b2p_offgrid_coords {segs grid} {
    if {![string is double -strict $grid] || $grid <= 0} {
        return {}
    }
    set bad {}
    foreach s $segs {
        foreach v $s {
            set q [expr {double($v) / double($grid)}]
            if {abs($q - round($q)) > 1e-9 && [lsearch -exact $bad $v] < 0} {
                lappend bad $v
            }
        }
    }
    return $bad
}

#=============================================================================
# TANNER-FACING LAYER  (needs a schematic/symbol view open)
#=============================================================================

# Narrows the selection to just the objects of `type` in it, and returns how
# many there are.
proc b2p_count_selected {type} {
    set n 0
    catch {set n [b2p_scalar [find $type -scope selection -count -goto none]]}
    if {![string is integer -strict $n]} { set n 0 }
    return $n
}

# Read every box in `scope` as {x y w h}.
#
# The filter's return value decides what stays selected afterwards: in
# `selection` scope it returns true, because the caller handed us that selection
# and the delete step still needs it. In `view` scope it returns false and the
# read leaves no selection behind (the b2p_collect_paths idiom) -- the boxes are
# reselected deliberately by b2p_select_all_boxes when it is time to delete, so
# a dry run over the whole view changes nothing at all.
proc b2p_collect_boxes {{scope selection}} {
    set boxes {}
    set keep [expr {$scope eq "selection"}]
    set filt {
        lappend boxes [list \
            [b2p_scalar [property get -name X      -system]] \
            [b2p_scalar [property get -name Y      -system]] \
            [b2p_scalar [property get -name Width  -system]] \
            [b2p_scalar [property get -name Height -system]]]
        expr {$keep}
    }
    find box -scope $scope -filter $filt -goto none
    return $boxes
}

# Read every selected box as {x y w h}. Leaves the boxes selected.
proc b2p_collect_selected {} {
    return [b2p_collect_boxes selection]
}

# Select every box in the view. Returns how many.
proc b2p_select_all_boxes {} {
    catch {find none}
    catch {find box -scope view -filter {expr {1}} -goto none}
    return [b2p_count_selected box]
}

# Narrow the selection to exactly the boxes that were read, prove it is still
# that same set, and delete them -- so `delete` can never take anything else
# with it. Returns how many went.
proc b2p_delete_boxes {scope nb} {
    if {$scope eq "view"} {
        set n [b2p_select_all_boxes]
    } else {
        set n [b2p_count_selected box]
    }
    if {$n != $nb} {
        error "expected $nb box(es) at delete time but found $n\
               -- nothing deleted, nothing drawn"
    }
    delete
    return $n
}

proc b2p_grid_get {} {
    set g ""
    catch {set g [b2p_scalar [setup schematicgrid get -snapgridsize]]}
    if {![string is double -strict $g]} { return "" }
    return $g
}

# Try to make the snap grid 1 iu so corners land exactly. Returns the grid that
# is actually in force afterwards ("" if unknown).
proc b2p_grid_fine {} {
    catch {setup schematicgrid set -snapgridsize 1 -units iu}
    return [b2p_grid_get]
}

proc b2p_grid_restore {g} {
    if {$g eq ""} return
    catch {setup schematicgrid set -snapgridsize $g -units iu}
}

# One path per segment: click the start, click2 the end (as in pin_lines.tcl).
# Used by -lines 1; the default path uses b2p_draw_paths, which does not click.
proc b2p_draw_segs {segs} {
    mode escape
    catch {find none}
    mode draw path
    foreach s $segs {
        lassign $s ax ay bx by
        point click  $ax $ay -units iu
        point click2 $bx $by -units iu
    }
    mode escape
}

# How many objects of `type` the whole view holds.
proc b2p_count_view {type} {
    set n 0
    catch {set n [b2p_scalar [find $type -scope view -count -goto none]]}
    if {![string is integer -strict $n]} { set n 0 }
    return $n
}

# Draw each flat vertex list as one path, coordinates handed over as DATA --
# no clicks, so nothing snaps and the vertices land exactly where asked.
#
# `mode draw path` MUST be re-issued for every path: the arming is consumed by
# the first `path` call, and a second call without it silently creates nothing
# (verified 2026-08-13 -- two calls, one object). The trailing `mode escape` is
# bookkeeping; each path already exists by the time its `path` call returns.
proc b2p_draw_paths {plist} {
    mode escape
    catch {find none}
    foreach pts $plist {
        mode draw path
        path -points $pts -units iu
    }
    mode escape
}

# Draw one box from corner to corner. `second` is which mouse op finishes it:
# S-Edit's box tool takes two corners, but whether the second is a plain click
# or a double-click is NOT verified, so path_to_box tries click2 and falls back
# to click, then reports which one worked.
proc b2p_draw_box {x0 y0 x1 y1 {second click2}} {
    mode escape
    catch {find none}
    mode draw box
    point click   $x0 $y0 -units iu
    point $second $x1 $y1 -units iu
    mode escape
}

# Select the boxes matching any of `rects` ({x y w h} each). Width/Height are
# compared as magnitudes: S-Edit reports a box's own extents, but a negative
# value would still name the same rectangle. `add` keeps whatever is already
# selected, for building a mixed selection. Returns how many boxes are selected.
proc b2p_select_boxes_by_rect {rects {tol 0} {add 0}} {
    set filt {
        set _ok 0
        if {![catch {property get -name X -system} _x]} {
            set _r [list [b2p_scalar $_x] \
                         [b2p_scalar [property get -name Y -system]] \
                         [expr {abs([b2p_scalar [property get -name Width  -system]])}] \
                         [expr {abs([b2p_scalar [property get -name Height -system]])}]]
            foreach _want $rects {
                if {[b2p_rect_same $_r $_want $tol]} { set _ok 1 ; break }
            }
        }
        expr {$_ok}
    }
    if {$add} {
        find box -scope view -add -filter $filt -goto none
    } else {
        catch {find none}
        find box -scope view -filter $filt -goto none
    }
    return [b2p_count_selected box]
}

proc b2p_select_box_at {x y w h {tol 0}} {
    return [b2p_select_boxes_by_rect [list [list $x $y $w $h]] $tol]
}

# Draw one box, working out how the box tool wants its second corner: `click2`
# first, then a plain `click`. Returns which took, or "" if neither did.
proc b2p_draw_box_verified {x0 y0 x1 y1} {
    set before [b2p_count_view box]
    foreach how {click2 click} {
        b2p_draw_box $x0 $y0 $x1 $y1 $how
        if {[b2p_count_view box] > $before} {
            return $how
        }
    }
    return ""
}

#=============================================================================
# MAIN
#=============================================================================

proc box_to_paths {args} {
    set defaults {-keep 0 -dryrun 0 -lines 0 -scope selection}
    if {[catch {array set opt [b2p_parse_opts $defaults $args]} err]} {
        puts "box_to_paths: $err"
        return
    }
    if {[lsearch -exact {selection view} $opt(-scope)] < 0} {
        puts "box_to_paths: -scope must be selection or view (got '$opt(-scope)')"
        return
    }
    if {$opt(-scope) eq "view"} {
        if {[b2p_count_view box] == 0} {
            puts "box_to_paths: this view has no boxes -- nothing to convert"
            return
        }
    } elseif {[b2p_count_selected box] == 0} {
        puts "box_to_paths: no boxes selected -- select the box(es) first,\
              or run box_to_paths_all to convert every box in the view"
        return
    }

    set saved_grid [b2p_grid_get]
    mode renderoff
    set rc [catch {b2p_run [array get opt]} res]
    catch {mode escape}
    b2p_grid_restore $saved_grid
    catch {mode renderon}

    if {$rc} {
        puts "box_to_paths: ABORTED -- $res"
        puts "box_to_paths: (the message says so when nothing was touched; if it does"
        puts "box_to_paths:  not, the box(es) were already deleted -- undo restores them)"
        return
    }
    puts $res
}

# Every box in the open view, converted in one go -- for framed-up schematics
# where the boxes were never meant to be clickable objects in the first place.
# Nothing needs selecting beforehand, and the selection you had is not consulted.
#
#     box_to_paths_all             ;# convert every box in this view
#     box_to_paths_all -dryrun 1   ;# list them, change nothing  <-- worth doing first
#     box_to_paths_all -keep 1     ;# draw the outlines, keep the boxes
#
# It is one undo step per box plus one for the delete, so box_to_paths_undo (or
# that many Ctrl-Z) still winds the whole thing back -- but on a view full of
# boxes that is a long undo list, so run -dryrun 1 first and save beforehand.
proc box_to_paths_all {args} {
    box_to_paths -scope view {*}$args
}

# Everything between renderoff and renderon. Returns the summary to print.
proc b2p_run {optlist} {
    array set opt $optlist

    set boxes [b2p_collect_boxes $opt(-scope)]
    set nb [llength $boxes]
    if {$nb == 0} {
        error "could not read the box(es) -- find box -scope $opt(-scope) -filter\
               returned nothing"
    }
    if {$opt(-lines)} {
        return [b2p_run_lines $boxes $optlist]
    }

    # One plan per convertible box, so the box, its outline and its rectangle
    # stay together -- a zero-by-zero box drops out here and must not shift the
    # lists out of step with each other.
    set plans {}
    set skipped 0
    foreach b $boxes {
        lassign $b bx by bw bh
        set p [b2p_rect_points $bx $by $bw $bh]
        if {![llength $p]} {
            incr skipped
            continue
        }
        lappend plans [list $b $p [list $bx $by [expr {abs($bw)}] [expr {abs($bh)}]]]
    }
    if {![llength $plans]} {
        error "the selected box(es) have zero width AND height -- nothing to draw"
    }
    set draws {}
    set rects {}
    foreach pl $plans {
        lappend draws [lindex $pl 1]
        lappend rects [lindex $pl 2]
    }

    if {$opt(-dryrun)} {
        set out "box_to_paths: DRY RUN -- nothing changed"
        if {$opt(-scope) eq "view"} {
            append out "\n  $nb box(es) found in this view"
        }
        set i 0
        foreach pl $plans {
            lassign [lindex $pl 0] bx by bw bh
            incr i
            append out "\n  box $i: X=$bx Y=$by W=$bw H=$bh\
                        -> ($bx,$by) .. ([expr {$bx + abs($bw)}],[expr {$by + abs($bh)}])"
            append out "\n    path -points {[join [lindex $pl 1] { }]} -units iu"
        }
        if {$skipped} {
            append out "\n  ($skipped selected box(es) are zero by zero and will be skipped)"
        }
        return $out
    }

    set deleted 0
    if {!$opt(-keep)} {
        set deleted [b2p_delete_boxes $opt(-scope) $nb]
    }

    set before [b2p_count_view path]
    b2p_draw_paths $draws
    set made [expr {[b2p_count_view path] - $before}]

    # Reselect by SHAPE, not by literal vertices: S-Edit may store a closed
    # outline without the repeated closing point, or renumber it from a different
    # corner, and either would defeat a string match. Exact vertices are the
    # fallback, which is also what catches a degenerate (line) box, since a
    # 2-point path describes no rectangle.
    set nsel [b2p_select_paths_by_rect $rects]
    if {$nsel == 0} {
        set nsel [b2p_select_paths_by_coords $draws]
    }

    # S-Edit has no transaction command, so the conversion is one undo step per
    # object touched. Remember how many, so box_to_paths_undo can wind the whole
    # thing back in one action instead of N presses of Ctrl-Z.
    set ::b2p_last_ops [expr {[llength $draws] + ($deleted > 0 ? 1 : 0)}]

    set out "box_to_paths: [llength $draws] outline path(s) drawn for $nb box(es)"
    if {$opt(-scope) eq "view"} {
        append out " (every box in the view)"
    }
    append out ", $deleted box(es) deleted, $nsel left selected"
    append out "\n  to reverse: box_to_paths_undo (or $::b2p_last_ops x Ctrl-Z)"
    append out "\n  to resize one: select it, path_to_box, adjust, box_to_paths again"
    if {$made != [llength $draws]} {
        append out "\n  NOTE: [llength $draws] path(s) were asked for but the view gained\
                    $made -- if that is short, a `mode draw path` did not take (it arms\
                    exactly one path); check the outline."
    }
    if {$skipped} {
        append out "\n  ($skipped selected box(es) were zero by zero and were skipped)"
    }
    if {$opt(-keep)} {
        append out "\n  -keep 1: the original box(es) are still there, under the new paths"
    }
    return $out
}

# Legacy -lines 1: the outline as 4 separate 2-point paths, drawn by clicking.
# Kept because designs already contain outlines in this form (select_box_paths
# is what puts them back together). Clicks snap, hence the grid dance and the
# before/after diff -- neither of which the default single-path route needs.
proc b2p_run_lines {boxes optlist} {
    array set opt $optlist
    set nb [llength $boxes]

    set segs {}
    foreach b $boxes {
        lassign $b bx by bw bh
        foreach s [b2p_segs $bx $by $bw $bh] { lappend segs $s }
    }
    if {![llength $segs]} {
        error "the selected box(es) have zero width AND height -- nothing to draw"
    }

    if {$opt(-dryrun)} {
        set out "box_to_paths: DRY RUN (-lines 1) -- nothing changed"
        set i 0
        foreach b $boxes {
            lassign $b bx by bw bh
            incr i
            append out "\n  box $i: X=$bx Y=$by W=$bw H=$bh\
                        -> ($bx,$by) .. ([expr {$bx + abs($bw)}],[expr {$by + abs($bh)}])"
        }
        foreach s $segs {
            append out "\n    path [join $s { }]"
        }
        return $out
    }

    set deleted 0
    if {!$opt(-keep)} {
        set deleted [b2p_delete_boxes $opt(-scope) $nb]
    }

    set before [b2p_collect_paths]
    set fine [b2p_grid_fine]
    set off  [b2p_offgrid_coords $segs $fine]
    b2p_draw_segs $segs
    set new [b2p_new_coords $before [b2p_collect_paths]]

    set nsel 0
    if {[llength $new]} {
        set nsel [b2p_select_paths_by_coords $new]
    } else {
        catch {find none}
    }

    set ::b2p_last_ops [expr {[llength $segs] + ($deleted > 0 ? 1 : 0)}]

    set out "box_to_paths: [llength $segs] path(s) drawn for $nb box(es) (-lines 1),\
             $deleted box(es) deleted, $nsel left selected"
    append out "\n  to reverse: box_to_paths_undo (or $::b2p_last_ops x Ctrl-Z)"
    append out "\n  to reselect all 4 sides later: select_box_paths"
    if {[llength $new] < [llength [lsort -unique $segs]]} {
        append out "\n  NOTE: [llength $segs] line(s) were drawn but only [llength $new]\
                    new one(s) appeared -- either a line landed exactly on a path that was\
                    already there, or a click did not take. Check the outline."
    }
    if {[llength $off]} {
        append out "\n  WARNING: snap grid is $fine iu, so these coordinates were snapped\
                    and the outline may not sit exactly on the old edge: [join $off {, }]"
    }
    if {$opt(-keep)} {
        append out "\n  -keep 1: the original box(es) are still there, under the new paths"
    }
    return $out
}

#=============================================================================
# REVERSING A CONVERSION IN ONE ACTION
#=============================================================================

# S-Edit (158-command surface, checked 2026-08-13) has no transaction / undo-group
# command, so a conversion costs 1 undo step for the delete plus 1 per line
# drawn. `undo -count <n>` reverses the lot in one action.
#
#     box_to_paths_undo        ;# undo the whole of the last conversion
#     box_to_paths_undo 1      ;# just list what would be undone (undo -preview)
#
# CAVEAT: this winds back the last N steps, whatever they now are. If you have
# edited anything since the conversion, those edits go first -- preview if in
# doubt. It refuses to run twice for the same conversion.
set ::b2p_last_ops 0

proc box_to_paths_undo {{preview 0}} {
    if {$::b2p_last_ops <= 0} {
        puts "box_to_paths_undo: nothing recorded -- run box_to_paths or path_to_box\
              first (and note this only reverses the most recent conversion, once)"
        return
    }
    set n $::b2p_last_ops
    if {$preview} {
        puts "box_to_paths_undo: $n step(s) would be undone:"
        if {[catch {undo -preview} msg]} {
            puts "  (undo -preview not available: $msg)"
        } elseif {$msg ne ""} {
            puts $msg
        }
        return
    }
    set ::b2p_last_ops 0
    set done 0
    if {![catch {undo -count $n}]} {
        set done $n
    } elseif {![catch {undo $n}]} {
        set done $n
    } else {
        # No count form on this version -- step back one at a time.
        for {set i 0} {$i < $n} {incr i} {
            if {[catch {undo}]} break
            incr done
        }
    }
    puts "box_to_paths_undo: wound back $done of $n step(s) -- check the box(es) are back"
}

#=============================================================================
# SELECTING A BOX BACK -- the four lines, from a click on any one of them
#=============================================================================

# Every 2-point path in the view as a flat {x1 y1 x2 y2} coord list. Longer
# polylines are skipped: the rectangle walk is over straight lines. The filter
# returns false (the hnp_sed_collect_wires idiom) so this stays a read.
proc b2p_collect_paths {} {
    set rows {}
    set filt {
        if {![catch {property get -name Vertices -system} _v]} {
            set _c [b2p_parse_verts $_v]
            if {[llength $_c] == 4} { lappend rows $_c }
        }
        expr {0}
    }
    catch {find path -scope view -filter $filt -goto none}
    return $rows
}

# Select exactly the paths whose vertices appear in `wanted` (each a flat coord
# list). Matching is on parsed coordinates, so it does not depend on how S-Edit
# spaces the Vertices string. Returns how many ended up selected.
proc b2p_select_paths_by_coords {wanted} {
    set filt {
        set _ok 0
        if {![catch {property get -name Vertices -system} _v]} {
            set _ok [expr {[lsearch -exact $wanted [b2p_parse_verts $_v]] >= 0}]
        }
        expr {$_ok}
    }
    catch {find none}
    find path -scope view -filter $filt -goto none
    return [b2p_count_selected path]
}

# The selected paths' vertices, as flat coord lists.
#
# Goes through a `-filter` body rather than reading `property get -name Vertices
# -system` off the selection directly: property reads are only PROVEN inside a
# filter/modify body (specs/sedit_tcl_api_findings.md §4), where the current
# object is unambiguous. The filter returns true, so the selection survives the
# read and the caller can still delete what it looked at.
proc b2p_selected_path_verts {} {
    set rows {}
    set filt {
        if {![catch {property get -name Vertices -system} _v]} {
            lappend rows [b2p_parse_verts $_v]
        }
        expr {1}
    }
    find path -scope selection -filter $filt -goto none
    return $rows
}

# Select the outline paths that describe any of `rects` ({x y w h} each) --
# matching on the rectangle a path DESCRIBES rather than on its literal vertex
# string, so it survives S-Edit storing the closing point differently or
# starting the outline at another corner.
proc b2p_select_paths_by_rect {rects {tol 0} {add 0}} {
    set filt {
        set _ok 0
        if {![catch {property get -name Vertices -system} _v]} {
            set _r [b2p_path_rect [b2p_parse_verts $_v] $tol]
            if {[llength $_r]} {
                foreach _want $rects {
                    if {[b2p_rect_same $_r $_want $tol]} { set _ok 1 ; break }
                }
            }
        }
        expr {$_ok}
    }
    if {$add} {
        find path -scope view -add -filter $filt -goto none
    } else {
        catch {find none}
        find path -scope view -filter $filt -goto none
    }
    return [b2p_count_selected path]
}

# Read a MIXED selection in one pass: the boxes as {x y w h}, the paths as flat
# vertex lists. Both finds carry -add, without which the second would clobber
# what the first left selected (the aggregate_bus.tcl idiom -- a bare
# `find <type> -scope selection` replaces the selection rather than narrowing
# within it). Nothing else in the selection is disturbed.
proc b2p_collect_selection {} {
    set boxes {}
    set verts {}
    set capbox {
        lappend boxes [list \
            [b2p_scalar [property get -name X      -system]] \
            [b2p_scalar [property get -name Y      -system]] \
            [b2p_scalar [property get -name Width  -system]] \
            [b2p_scalar [property get -name Height -system]]]
        expr {1}
    }
    set cappath {
        if {![catch {property get -name Vertices -system} _v]} {
            lappend verts [b2p_parse_verts $_v]
        }
        expr {1}
    }
    catch {find box  -scope selection -add -filter $capbox  -goto none}
    catch {find path -scope selection -add -filter $cappath -goto none}
    return [list $boxes $verts]
}

# With ONE line of a path-drawn box selected, select all four of its sides -- so
# the box can be moved or deleted as a unit again.
#
#     select_box_paths           ;# corners must meet exactly
#     select_box_paths -tol 50   ;# allow 50 iu of slop at the corners
#
# -tol exists for boxes drawn by hand, where the corners may not quite close.
# Anything box_to_paths drew meets exactly, so the default is 0.
proc select_box_paths {args} {
    set defaults {-tol 0}
    if {[catch {array set opt [b2p_parse_opts $defaults $args]} err]} {
        puts "select_box_paths: $err"
        return
    }

    set n [b2p_count_selected path]
    if {$n != 1} {
        puts "select_box_paths: select exactly ONE line (path) of the box first (found $n)"
        return
    }
    set rows [b2p_selected_path_verts]
    if {[llength $rows] != 1} {
        puts "select_box_paths: could not read the selected path's Vertices\
              ([llength $rows] read, expected 1)"
        return
    }
    set seed [lindex $rows 0]
    if {[llength $seed] != 4} {
        puts "select_box_paths: that path has [expr {[llength $seed]/2}] vertices --\
              this works on the 2-point lines a box outline is made of"
        return
    }

    mode renderoff
    set rc [catch {b2p_select_rect $seed $opt(-tol)} res]
    catch {mode renderon}
    if {$rc} {
        puts "select_box_paths: $res"
        return
    }
    puts $res
}

proc b2p_select_rect {seed tol} {
    set rows [b2p_collect_paths]
    set i [lsearch -exact $rows $seed]
    if {$i < 0} {
        b2p_select_paths_by_coords [list $seed]
        error "the selected line is not among the view's paths -- selection restored"
    }
    set idx [b2p_rect_through $rows $i $tol]
    if {![llength $idx]} {
        b2p_select_paths_by_coords [list $seed]
        set hint "corners must meet exactly here -- try -tol <iu>"
        if {$tol > 0} { set hint "within $tol iu" }
        error "no closed 4-line rectangle through this line ($hint)\
               -- only that line is left selected"
    }
    set want {}
    foreach j $idx { lappend want [lindex $rows $j] }
    set n [b2p_select_paths_by_coords $want]

    set out "select_box_paths: $n path(s) selected -- the box is now one selection"
    if {$n > 4} {
        append out "\n  (more than 4: some of these lines are duplicated on top of each other)"
    }
    return $out
}

#=============================================================================
# BACK TO A BOX -- for when the frame needs resizing
#=============================================================================

# A rectangular path is the right thing to LEAVE in a schematic (it does not eat
# clicks) but the wrong thing to EDIT: dragging one corner of a polyline is
# fiddly where a box just has handles. So the round trip is
#
#     path_to_box     ->  adjust the box  ->  box_to_paths
#
# With one rectangular path selected:
#     path_to_box              ;# -> box, path deleted, box left selected
#     path_to_box -dryrun 1    ;# print the box it would draw, change nothing
#     path_to_box -tol 50      ;# allow 50 iu of slop at the corners
#     path_to_box -keep 1      ;# draw the box, keep the path underneath
#
# Only an axis-aligned rectangle converts. 4 corners, open or closed; sides
# horizontal or vertical. An L, a Z, a diagonal or a polyline spanning three
# distinct X values is REFUSED rather than approximated into the nearest box --
# the whole point is that the box must be the same frame the path was.
#
# Unlike the path drawing, this one clicks: `path -points` creates paths, and
# nothing has been verified for creating a BOX from data, so the box tool is
# driven with two corner clicks and the snap grid is pinned to 1 iu around it.
proc path_to_box {args} {
    set defaults {-tol 0 -dryrun 0 -keep 0}
    if {[catch {array set opt [b2p_parse_opts $defaults $args]} err]} {
        puts "path_to_box: $err"
        return
    }

    set n [b2p_count_selected path]
    if {$n != 1} {
        puts "path_to_box: select exactly ONE path -- the box outline (found $n)"
        return
    }
    set rows [b2p_selected_path_verts]
    if {[llength $rows] != 1} {
        puts "path_to_box: could not read the selected path's Vertices\
              ([llength $rows] read, expected 1)"
        return
    }
    set flat [lindex $rows 0]

    set rect [b2p_path_rect $flat $opt(-tol)]
    if {![llength $rect]} {
        puts "path_to_box: that path is not an axis-aligned rectangle, so it has no box:"
        puts "  [expr {[llength $flat] / 2}] vertice(s): [join $flat {, }]"
        puts "  needs 4 corners (5 numbers per point pair if closed), sides horizontal"
        puts "  or vertical, spanning exactly 2 distinct X and 2 distinct Y values."
        if {$opt(-tol) == 0} {
            puts "  If it was drawn by hand and the corners do not quite meet: -tol <iu>"
        }
        return
    }
    lassign $rect rx ry rw rh

    if {$opt(-dryrun)} {
        puts "path_to_box: DRY RUN -- nothing changed"
        puts "  path: [join $flat {, }]"
        puts "  ->    box X=$rx Y=$ry W=$rw H=$rh\
              (($rx,$ry) .. ([expr {$rx + $rw}],[expr {$ry + $rh}]))"
        return
    }

    set saved_grid [b2p_grid_get]
    mode renderoff
    set rc [catch {b2p_to_box_run $rect [array get opt]} res]
    catch {mode escape}
    b2p_grid_restore $saved_grid
    catch {mode renderon}

    if {$rc} {
        puts "path_to_box: ABORTED -- $res"
        return
    }
    puts $res
}

#=============================================================================
# ONE COMMAND, BOTH DIRECTIONS
#=============================================================================

# Convert whatever is selected to the other form: every box becomes an outline
# path, every rectangular path becomes a box. Mixed selections are fine -- the
# two directions are independent, and a selection of one box and one path-box
# swaps both. Anything else in the selection is ignored, and so is any path that
# is not an axis-aligned rectangle (a Z, an L, a diagonal, a wire-like polyline);
# those are counted and named in the summary rather than mangled.
#
#     convert_box_paths            ;# swap every selected box / rectangular path
#     convert_box_paths -dryrun 1  ;# print what it would do, change nothing
#     convert_box_paths -tol 50    ;# allow 50 iu of slop at a path's corners
#
# This is the toggle to put on a key: it needs no memory of which direction the
# frame is currently in.
#
# Deleting comes before ANY drawing, both directions at once, so a shape that is
# about to be created can never be confused with one that is about to be
# deleted. And because deletion needs a selection, the objects are matched back
# by geometry first, in a pre-flight that aborts before touching anything if the
# view holds an identical shape that was NOT selected -- otherwise `delete`
# could take an innocent twin with it.
proc convert_box_paths {args} {
    set defaults {-tol 0 -dryrun 0}
    if {[catch {array set opt [b2p_parse_opts $defaults $args]} err]} {
        puts "convert_box_paths: $err"
        return
    }

    # Collect BEFORE anything else: b2p_count_selected narrows the selection to
    # one type, which would throw away the other half of a mixed selection.
    lassign [b2p_collect_selection] boxes verts

    set torect {}      ;# paths that ARE rectangles: {verts rect}
    set notrect {}     ;# paths that are not -- reported, never touched
    foreach v $verts {
        set r [b2p_path_rect $v $opt(-tol)]
        if {[llength $r]} {
            lappend torect [list $v $r]
        } else {
            lappend notrect $v
        }
    }

    set topath {}      ;# boxes: {box points rect}
    set degenerate 0
    foreach b $boxes {
        lassign $b bx by bw bh
        set p [b2p_rect_points $bx $by $bw $bh]
        if {![llength $p]} {
            incr degenerate
            continue
        }
        lappend topath [list $b $p [list $bx $by [expr {abs($bw)}] [expr {abs($bh)}]]]
    }

    if {![llength $torect] && ![llength $topath]} {
        puts "convert_box_paths: nothing convertible in the selection"
        if {[llength $notrect]} {
            puts "  [llength $notrect] selected path(s) are not axis-aligned rectangles:"
            foreach v $notrect { puts "    [join $v {, }]" }
            if {$opt(-tol) == 0} {
                puts "  If the corners nearly meet, try -tol <iu>"
            }
        }
        if {$degenerate} {
            puts "  $degenerate selected box(es) are zero by zero"
        }
        if {![llength $notrect] && !$degenerate} {
            puts "  select a box (-> outline path) or a rectangular path (-> box)"
        }
        return
    }

    if {$opt(-dryrun)} {
        puts "convert_box_paths: DRY RUN -- nothing changed"
        foreach pl $topath {
            lassign [lindex $pl 0] bx by bw bh
            puts "  box X=$bx Y=$by W=$bw H=$bh"
            puts "    -> path -points {[join [lindex $pl 1] { }]} -units iu"
        }
        foreach pr $torect {
            lassign [lindex $pr 1] rx ry rw rh
            puts "  path [join [lindex $pr 0] {, }]"
            puts "    -> box X=$rx Y=$ry W=$rw H=$rh"
        }
        foreach v $notrect {
            puts "  path [join $v {, }]\n    -> SKIPPED, not an axis-aligned rectangle"
        }
        if {$degenerate} {
            puts "  $degenerate zero-by-zero box(es) skipped"
        }
        return
    }

    set saved_grid [b2p_grid_get]
    mode renderoff
    set rc [catch {b2p_convert_run $topath $torect [array get opt]} res]
    catch {mode escape}
    b2p_grid_restore $saved_grid
    catch {mode renderon}

    if {$rc} {
        puts "convert_box_paths: ABORTED -- $res"
        return
    }
    puts $res
    if {[llength $notrect]} {
        puts "  [llength $notrect] selected path(s) left alone (not rectangles)"
    }
    if {$degenerate} {
        puts "  $degenerate zero-by-zero box(es) left alone"
    }
}

#=============================================================================
# ONE KEY, TWO JOBS  (the Ctrl+Alt+B dispatcher)
#=============================================================================

# Look at what is selected and do the obvious thing with it:
#
#     a box or a path selected  ->  convert_box_paths (swap it to the other form)
#     anything else             ->  _fracture (the comma-separated bus splitter)
#
# So one key serves both, and neither has to be remembered separately. Any
# arguments are passed through to convert_box_paths, so
# `fracture_or_convert -dryrun 1` works when a box or path is selected.
#
# _fracture is NOT defined in this repo -- it comes from elsewhere in the S-Edit
# startup -- so it is called only if the interpreter actually has it, and its
# absence is reported rather than raised as a Tcl error.
#
# The probe uses b2p_collect_selection, whose finds carry -add precisely so a
# mixed selection survives being looked at. If a bus netlabel selection were
# ever cleared by the probe, _fracture would be handed nothing -- that is the
# one thing to watch for the first time this runs.
proc fracture_or_convert {args} {
    lassign [b2p_collect_selection] boxes paths

    if {[llength $boxes] || [llength $paths]} {
        return [convert_box_paths {*}$args]
    }

    if {![llength [info commands _fracture]]} {
        puts "fracture_or_convert: no box or path selected, and _fracture is not\
              defined in this interpreter"
        puts "  select a box (-> outline path) or a rectangular path (-> box),"
        puts "  or check that whatever defines _fracture has been sourced"
        return
    }
    return [_fracture]
}

proc b2p_convert_run {topath torect optlist} {
    array set opt $optlist
    set tol $opt(-tol)

    set boxrects {}
    foreach pl $topath { lappend boxrects [lindex $pl 2] }
    set pathverts {}
    foreach pr $torect { lappend pathverts [lindex $pr 0] }

    # Pre-flight. Matching back by geometry can name a shape that merely LOOKS
    # like a selected one, so check both directions before deleting either.
    if {[llength $pathverts]} {
        set n [b2p_select_paths_by_coords $pathverts]
        if {$n != [llength $pathverts]} {
            error "[llength $pathverts] path(s) to convert but $n in the view have those\
                   exact vertices -- an identical path is sitting somewhere else.\
                   Nothing changed."
        }
    }
    if {[llength $boxrects]} {
        set n [b2p_select_boxes_by_rect $boxrects $tol]
        if {$n != [llength $boxrects]} {
            error "[llength $boxrects] box(es) to convert but $n in the view have those\
                   dimensions -- an identical box is sitting somewhere else.\
                   Nothing changed."
        }
    }

    # Delete both directions first: nothing drawn below can then be mistaken for
    # an original when the originals are matched by geometry.
    set steps 0
    if {[llength $pathverts]} {
        b2p_select_paths_by_coords $pathverts
        delete
        incr steps
    }
    if {[llength $boxrects]} {
        b2p_select_boxes_by_rect $boxrects $tol
        delete
        incr steps
    }

    set madepaths 0
    if {[llength $topath]} {
        set draws {}
        foreach pl $topath { lappend draws [lindex $pl 1] }
        set before [b2p_count_view path]
        b2p_draw_paths $draws
        set madepaths [expr {[b2p_count_view path] - $before}]
        incr steps [llength $draws]
    }

    set madeboxes 0
    set how ""
    if {[llength $torect]} {
        set fine [b2p_grid_fine]
        foreach pr $torect {
            lassign [lindex $pr 1] rx ry rw rh
            set took [b2p_draw_box_verified $rx $ry [expr {$rx + $rw}] [expr {$ry + $rh}]]
            if {$took ne ""} {
                incr madeboxes
                set how $took
            }
            incr steps
        }
    }

    # Leave the new shapes selected, both kinds together.
    set nsel 0
    if {[llength $topath]} {
        set nsel [b2p_select_paths_by_rect $boxrects $tol]
    } else {
        catch {find none}
    }
    if {[llength $torect]} {
        set rects {}
        foreach pr $torect { lappend rects [lindex $pr 1] }
        incr nsel [b2p_select_boxes_by_rect $rects $tol [expr {[llength $topath] > 0}]]
    }

    set ::b2p_last_ops $steps

    set out "convert_box_paths: [llength $topath] box(es) -> path(s),\
             [llength $torect] path(s) -> box(es), $nsel selected"
    append out "\n  to reverse: box_to_paths_undo (or $steps x Ctrl-Z),\
                  or just run convert_box_paths again on the result"
    if {$how ne ""} {
        append out "\n  box corners took as `point $how`"
    }
    if {$madepaths != [llength $topath]} {
        append out "\n  NOTE: [llength $topath] path(s) asked for, view gained $madepaths"
    }
    if {$madeboxes != [llength $torect]} {
        append out "\n  NOTE: [llength $torect] box(es) asked for, [expr {[llength $torect] - $madeboxes}]\
                    did not appear -- neither click form finished them"
    }
    return $out
}

proc b2p_to_box_run {rect optlist} {
    array set opt $optlist
    lassign $rect rx ry rw rh
    set x1 [expr {$rx + $rw}]
    set y1 [expr {$ry + $rh}]

    # Proves the selection is still the single path that was read, so `delete`
    # cannot take anything else with it.
    set deleted 0
    if {!$opt(-keep)} {
        set n [b2p_count_selected path]
        if {$n != 1} {
            error "expected 1 selected path at delete time but found $n -- nothing changed"
        }
        delete
        set deleted 1
    }

    set fine [b2p_grid_fine]
    set off  [b2p_offgrid_coords [list [list $rx $ry $x1 $y1]] $fine]

    # Two corner clicks. Whether the box tool wants a plain second click or a
    # double-click is unverified, so try one and fall back to the other; the
    # summary reports which took, and that answer belongs in the API spec.
    set before [b2p_count_view box]
    set how [b2p_draw_box_verified $rx $ry $x1 $y1]
    set made [expr {[b2p_count_view box] - $before}]
    if {$how eq ""} {
        error "the box did not appear -- neither `point click2` nor `point click` finished\
               it. The path [expr {$deleted ? {was deleted, so undo once to bring it back}
                                            : {is untouched}}]."
    }

    set nsel [b2p_select_box_at $rx $ry $rw $rh $opt(-tol)]
    set ::b2p_last_ops [expr {1 + $deleted}]

    set out "path_to_box: box X=$rx Y=$ry W=$rw H=$rh drawn,\
             $deleted path(s) deleted, $nsel selected"
    append out "\n  second corner took as `point $how`"
    append out "\n  to reverse: box_to_paths_undo (or $::b2p_last_ops x Ctrl-Z);\
                  when the box is the size you want, box_to_paths turns it back"
    if {$made > 1} {
        append out "\n  NOTE: the view gained $made boxes, not 1 -- both click forms may\
                    have taken; check for a duplicate box on top."
    }
    if {$nsel != 1} {
        append out "\n  NOTE: $nsel box(es) matched X=$rx Y=$ry W=$rw H=$rh when selecting\
                    -- 0 means the snap grid moved it, more than 1 means there was already\
                    an identical box there."
    }
    if {[llength $off]} {
        append out "\n  WARNING: snap grid is $fine iu, so these coordinates were snapped\
                    and the box may not match the path exactly: [join $off {, }]"
    }
    if {$opt(-keep)} {
        append out "\n  -keep 1: the path is still there, under the new box"
    }
    return $out
}

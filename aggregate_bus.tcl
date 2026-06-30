# aggregate_bus.tcl
#
# Aggregate a set of selected ports / netlabels into one or more fixed-width
# bus netlabels that the user then click-places.
#
# Usage (from the S-Edit command console, with ports/netlabels selected):
#     aggregate_bus            ;# width 8 (default)
#     aggregate_bus 16
#
# Behaviour:
#   * The selected ports and netlabels are read in physical top-to-bottom order
#     (descending Y). Their names are concatenated MSB-first into one conceptual
#     bus, e.g. reg1<2:0>, reg2<2:0>, trim<7:0> -> a 14-bit bus.
#   * That bus is split into chunks of at most <width> bits. The most-
#     significant chunk is first; any short remainder is the last chunk.
#         reg1<2:0>,reg2<2:0>,trim<7:6>   (8 bits)
#         trim<5:0>                        (6 bits)
#   * Each chunk becomes ONE netlabel whose text is the comma-joined bus
#     expression, with contiguous same-name bits collapsed back into ranges in
#     their original direction (ascending stays ascending, descending stays
#     descending).
#   * The original selection is left untouched. The new netlabels are stacked
#     vertically (MSB chunk on top), spaced by the average spacing of the
#     originals, and handed to the user in place mode to click down.
#   * Geometry (TextJustification + FontSize) is inherited from the physically
#     topmost selected item.
#
# This file is split into a PURE layer (ab_parse_name / ab_expand / ab_chunk /
# ab_format_chunk / ab_compute) with no Tanner dependencies -- unit-tested in
# tests/aggregate_bus.test -- and a Tanner-facing layer (aggregate_bus and its
# helpers) that drives selection and placement.

#=============================================================================
# PURE LAYER  (no Tanner API -- runs under stock tclsh, covered by tests)
#=============================================================================

# Parse one selected name into an ordered list of {base index} tokens.
#   "reg1<2:0>" -> {{reg1 2} {reg1 1} {reg1 0}}   (MSB-first, descending)
#   "trim<0:2>" -> {{trim 0} {trim 1} {trim 2}}   (ascending preserved)
#   "x<5>"      -> {{x 5}}
#   "clk"       -> {{clk {}}}                      (scalar: empty index)
# The literal order of the indices is preserved so the bit direction survives
# the round-trip through chunking and reformatting.
proc ab_parse_name {name} {
    if {[regexp {^(.+)<([0-9]+):([0-9]+)>$} $name -> base a b]} {
        set step [expr {$b >= $a ? 1 : -1}]
        set toks {}
        for {set k $a} {1} {incr k $step} {
            lappend toks [list $base $k]
            if {$k == $b} break
        }
        return $toks
    }
    if {[regexp {^(.+)<([0-9]+)>$} $name -> base a]} {
        return [list [list $base $a]]
    }
    return [list [list $name ""]]
}

# Flatten a list of names (already in physical order) into one token list.
proc ab_expand {names} {
    set toks {}
    foreach n $names {
        foreach t [ab_parse_name $n] {
            lappend toks $t
        }
    }
    return $toks
}

# Split a flat token list into chunks of at most <width> tokens. Chunks are
# filled in order, so the most-significant chunk is first and any short
# remainder lands in the final chunk.
proc ab_chunk {tokens width} {
    if {$width < 1} {
        error "ab_chunk: width must be >= 1 (got $width)"
    }
    set chunks {}
    set cur {}
    foreach t $tokens {
        lappend cur $t
        if {[llength $cur] == $width} {
            lappend chunks $cur
            set cur {}
        }
    }
    if {[llength $cur] > 0} {
        lappend chunks $cur
    }
    return $chunks
}

# Render one chunk of tokens back into a comma-joined bus expression.
# Contiguous runs of the same base with a consistent +/-1 step are collapsed
# into base<first:last> (preserving direction); a single bit becomes base<n>;
# a scalar (empty index) becomes base. Scalars and base changes break a run.
proc ab_format_chunk {tokens} {
    set out {}
    set n [llength $tokens]
    set i 0
    while {$i < $n} {
        lassign [lindex $tokens $i] base idx
        if {$idx eq ""} {
            lappend out $base
            incr i
            continue
        }
        # Grow a run of the same base with a consistent +/-1 step.
        set first $idx
        set last  $idx
        set step  0
        set j [expr {$i + 1}]
        while {$j < $n} {
            lassign [lindex $tokens $j] b2 idx2
            if {$b2 ne $base || $idx2 eq ""} break
            set d [expr {$idx2 - $last}]
            if {$step == 0} {
                if {$d != 1 && $d != -1} break
                set step $d
            } elseif {$d != $step} {
                break
            }
            set last $idx2
            incr j
        }
        if {$first == $last} {
            lappend out "${base}<${first}>"
        } else {
            lappend out "${base}<${first}:${last}>"
        }
        set i $j
    }
    return [join $out ","]
}

# End-to-end pure transform: names (physical order) + width -> list of netlabel
# strings, MSB chunk first.
proc ab_compute {names width} {
    set chunks [ab_chunk [ab_expand $names] $width]
    set out {}
    foreach c $chunks {
        lappend out [ab_format_chunk $c]
    }
    return $out
}

#=============================================================================
# TANNER-FACING LAYER  (selection + placement -- verified by reading)
#=============================================================================

# Collect the selected ports and netlabels as rows
#   {Y X Name FontSize Dir Hjust Vjust}
# sorted physically top-to-bottom (descending Y). Mirrors the find -filter
# table-building idiom used in sed_helpers.tcl.
proc ab_collect_selected {} {
    set rows {}
    set capture {
        set nm [property get -name Name -system]
        set xx [property get -name X -system]
        set yy [property get -name Y -system]
        set ff [property get -name FontSize -system]
        set dd [property get -name TextJustification.Direction  -system]
        set hh [property get -name TextJustification.Horizontal -system]
        set vv [property get -name TextJustification.Vertical    -system]
        lappend rows [list $yy $xx $nm $ff $dd $hh $vv]
        expr {1}
    }
    # -add on BOTH finds is essential: without it the first find replaces the
    # active selection, deselecting the other object type before its find runs
    # (same reason tgl_port_lbl_selected_count uses -add).
    find port     -scope selection -add -filter $capture -goto none
    find netlabel -scope selection -add -filter $capture -goto none

    # Top-to-bottom == descending Y.
    return [lsort -real -decreasing -index 0 $rows]
}

# Average centre-to-centre spacing of the selected items (already sorted by Y).
# With a single item there is nothing to average, so fall back to its font size
# so the stacked labels do not overlap.
proc ab_avg_spacing {items} {
    set n [llength $items]
    if {$n < 2} {
        set font [lindex $items 0 3]
        if {$font eq "" || $font <= 0} { return 1.0 }
        return [expr {double($font)}]
    }
    set total 0.0
    for {set i 1} {$i < $n} {incr i} {
        set y0 [lindex $items [expr {$i - 1}] 0]
        set y1 [lindex $items $i 0]
        set total [expr {$total + abs($y0 - $y1)}]
    }
    return [expr {$total / ($n - 1)}]
}

# Open (and clear) the schematic scratchpad cell in a new window, so the new
# netlabels can be built in isolation, copied, and pasted into place.
proc ab_open_scratch {dsn} {
    set scratchView [lindex [database views -design $dsn -cell scratchpad -type schematic] 0]
    cell open \
        -design $dsn \
        -cell scratchpad \
        -type schematic \
        -view $scratchView \
        -newwindow
    find all
    delete
}

proc aggregate_bus {{width 8}} {
    set items [ab_collect_selected]
    if {[llength $items] == 0} {
        puts "aggregate_bus: select one or more ports/netlabels first."
        return
    }

    set names {}
    foreach it $items {
        lappend names [lindex $it 2]
    }

    set labels [ab_compute $names $width]
    if {[llength $labels] == 0} {
        puts "aggregate_bus: nothing to aggregate."
        return
    }

    # Geometry from the physically topmost item.
    lassign [lindex $items 0] ty tx tname tfont tdir thj tvj
    lassign [tgl_port_lbl_map_port_to_label_justification $tdir $thj $tvj] \
        drawHJust drawVJust drawDir

    set spacing [ab_avg_spacing $items]

    # Resolve the scratchpad BEFORE touching anything, so a cancel/missing
    # scratchpad leaves the schematic untouched (same guard as tgl_port_lbl).
    set dsn [scratch_design]
    if {$dsn eq ""} {
        return
    }

    ab_open_scratch $dsn

    mode renderoff
    set y 0
    foreach lab $labels {
        find none
        mode draw port
        port -type NetLabel
        port \
            -text $lab \
            -hjustify $drawHJust \
            -vjustify $drawVJust \
            -direction $drawDir \
            -size $tfont \
            -units iu \
            -confirm false
        point click 0 $y -units iu
        set y [expr {$y - $spacing}]
    }

    find all
    copy
    window close
    mode renderon

    paste
    mode place -forcemove on
}

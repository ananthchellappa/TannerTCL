# ============================================================
# Add textlabels corresponding to ports in Tanner S-Edit
# ============================================================

proc apl_get_snap_grid {} {
    set snap [setup schematicgrid get -snapgridsize]
    if {$snap eq ""} {
        error "Could not retrieve snap grid size."
    }
    return $snap
}


proc apl_select_port_by_name_xy {pname px py} {

    catch {unselect all}

    set filt [format {
        set _n [property get -name Name -system]
        set _x [property get -name X -system]
        set _y [property get -name Y -system]
        expr { $_n eq "%s" && $_x == %s && $_y == %s }
    } $pname $px $py]

    catch {
        find port -filter $filt -goto none
    }

    set cnt [find port -scope selection -count -goto none]
    return [expr {$cnt > 0}]
}


proc apl_get_selected_port_props {} {
    set dir      [property get -name TextJustification.Direction  -system]
    set hjust    [property get -name TextJustification.Horizontal -system]
    set vjust    [property get -name TextJustification.Vertical   -system]
    set fontsize [property get -name FontSize -system]

    return [list $dir $hjust $vjust $fontsize]
}


proc apl_compute_label_placement {X Y dir hjust vjust offset} {

    set dir_l   [string tolower $dir]
    set hjust_l [string tolower $hjust]
    set vjust_l [string tolower $vjust]

    # Case 1
    if {$dir_l eq "normal" && $hjust_l eq "left" && $vjust_l eq "middle"} {
        set lx [expr {$X - $offset}]
        set ly $Y
        return [list $lx $ly right middle normal]
    }

    # Case 2
    if {$dir_l eq "normal" && $hjust_l eq "right" && $vjust_l eq "middle"} {
        set lx [expr {$X + $offset}]
        set ly $Y
        return [list $lx $ly left middle normal]
    }

    # Case 3
    # Port on bottom edge, label physically above port
    # Corrected created-label vjustify is BOTTOM
    if {$dir_l eq "down" && $hjust_l eq "center" && $vjust_l eq "top"} {
        set lx $X
        set ly [expr {$Y + $offset}]
        return [list $lx $ly center bottom down]
    }

    # Case 4
    # Port on top edge, label physically below port
    # Corrected created-label vjustify is TOP
    if {$dir_l eq "down" && $hjust_l eq "center" && $vjust_l eq "bottom"} {
        set lx $X
        set ly [expr {$Y - $offset}]
        return [list $lx $ly center top down]
    }

    return ""
}


proc apl_create_textlabel {txt lx ly lhjust lvjust ldir fontsize} {
    mode draw textlabel
    textlabel -text $txt \
              -hjustify $lhjust \
              -vjustify $lvjust \
              -direction $ldir \
              -size $fontsize \
              -units iu \
              -confirm false
    point click $lx $ly -units iu
    mode escape
}


proc apl_process_one_port {port_entry offset} {

    set pname [lindex $port_entry 0]
    set xy    [lindex $port_entry 1]
    set X     [lindex $xy 0]
    set Y     [lindex $xy 1]

    if {![apl_select_port_by_name_xy $pname $X $Y]} {
        puts "WARNING: Could not uniquely reselect port '$pname' at {$X $Y}; skipping."
        return
    }

    lassign [apl_get_selected_port_props] dir hjust vjust fontsize

    set placement [apl_compute_label_placement $X $Y $dir $hjust $vjust $offset]
    if {$placement eq ""} {
        puts "WARNING: Unsupported justification for port '$pname' at {$X $Y}: Direction='$dir' Horizontal='$hjust' Vertical='$vjust'. Skipping."
        return
    }

    lassign $placement lx ly lhjust lvjust ldir

    apl_create_textlabel $pname $lx $ly $lhjust $lvjust $ldir $fontsize
}


proc add_port_labels {{whisker_length 2}} {
    mode renderoff
    set sel_count [find port -scope selection -count -goto none]

    if {$sel_count > 0} {
        set ports [database ports -selected -name -location]
        if {![llength $ports]} {
            puts "No selected ports found."
            return
        }
    } else {
        catch {
            find textlabel -goto none
            delete
        }

        set ports [database ports -name -location]
        if {![llength $ports]} {
            puts "No ports found in cellview."
            return
        }
    }

    set snap   [apl_get_snap_grid]
    set offset [expr {$snap * (1 + $whisker_length)}]

    foreach p $ports {
        apl_process_one_port $p $offset
    }

    mode escape
    mode renderon
}

proc cycle_netlabel_text_justification {{next 1}} {

    # Ordered cycle table.
    #
    # NOTE:
    # This table is the actual order used by the code.
    # Current -> next means moving downward in this list.
    #
    # Right Bottom -> Right Middle -> Right Top ->
    # Center Bottom -> Center Middle -> Center Top ->
    # Left Bottom -> Left Middle -> Left Top -> wrap
    set cycle {
        {Right Bottom}
        {Right Middle}
        {Right Top}
        {Center Bottom}
        {Center Middle}
        {Center Top}
        {Left Bottom}
        {Left Middle}
        {Left Top}
    }

    set curr_h [property get TextJustification.Horizontal -system]
    set curr_v [property get TextJustification.Vertical   -system]

    set curr_pair [list $curr_h $curr_v]

    set idx [lsearch -exact $cycle $curr_pair]

    if {$idx < 0} {
        puts "Current TextJustification combination not recognized: Horizontal=$curr_h Vertical=$curr_v"
        puts "Defaulting to first entry: [lindex $cycle 0]"

        set default_pair [lindex $cycle 0]
        property set TextJustification.Horizontal -system -value [lindex $default_pair 0]
        property set TextJustification.Vertical   -system -value [lindex $default_pair 1]
        return
    }

    set n [llength $cycle]

    if {$next == 1} {
        set new_idx [expr {($idx + 1) % $n}]
    } else {
        set new_idx [expr {($idx - 1 + $n) % $n}]
    }

    set new_pair [lindex $cycle $new_idx]

    set new_h [lindex $new_pair 0]
    set new_v [lindex $new_pair 1]

    property set TextJustification.Horizontal -system -value $new_h
    property set TextJustification.Vertical   -system -value $new_v

    puts "TextJustification: $curr_h,$curr_v -> $new_h,$new_v"
}

proc cycle_port_or_netlabel { {next 1} } {
	
    # Count selected ports and netlabels.
    #
    # Use -add so that the first find does not destroy/replace the
    # current selection before the second count is taken.
    set n_ports     [find port     -scope selection -add -goto none -count]
    set n_netlabels [find netlabel -scope selection -add -goto none -count]

    if {($n_ports == 0) && ($n_netlabels == 0)} {
        puts "Nothing to cycle: select one or more ports OR one or more netlabels."
        return
    }

    if {($n_ports > 0) && ($n_netlabels > 0)} {
        puts "Cannot cycle mixed selection: selected objects include both ports and netlabels."
        puts "Please select only ports, or only netlabels, then try again."
        return
    }

    if {$n_ports > 0} {
        cycle_port_type
        return
    }

    # Only netlabels are selected.
    #
    # Braces are intentionally NOT used around the -modify body here,
    # because we want Tcl to substitute the outer proc's $next value
    # before S-Edit evaluates the modify script for each netlabel.
	mode renderoff
    find netlabel -scope selection -modify "cycle_netlabel_text_justification $next" -goto none
	mode renderon
}

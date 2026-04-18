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

# edit_netlabel.tcl — custom "Edit Netlabel" form for S-Edit.
#
# Why: the native netlabel edit dialog has a tiny font, and when a netlabel
# carries multiple comma-separated bus strands (net_A,net_B,net_C) there is
# no way to double-click one strand and edit just that strand.
#
# Usage: select exactly ONE netlabel, then run edit_netlabel_dialog
# (menu: CUSTOM > Wires > Edit Netlabel).
#
# Features:
#   * Copy-cell entry/command fonts; labels get a larger dialog-local font.
#   * Double-click in a text field selects just the word portion under the
#     pointer (myBusName in myBusName<7:0>); triple-click selects the whole
#     comma-separated strand.
#   * "Edit strands vertically": one entry per strand, at most 8 rows visible
#     (vertical scrollbar beyond that), always one empty row at the end so a
#     new strand can be appended.
#   * "Reverse strand order": reverses the displayed order in both modes;
#     whatever is displayed is what gets applied.
#   * Live preview of the exact text that will be written to the netlabel.
#
# Keys: Return applies in single-line mode; in vertical mode Return/Down/Up
# move between strand rows (use the OK button to apply).

# ----------------------------------------------------------------------
# Pure helpers (no Tanner API — testable under stock tclsh)
# ----------------------------------------------------------------------

proc enl_split_strands {text} {
    set out {}
    foreach s [split $text ,] {
        set s [string trim $s]
        if {$s ne ""} { lappend out $s }
    }
    return $out
}

proc enl_join_strands {strands} {
    return [join $strands ,]
}

# ----------------------------------------------------------------------
# Dialog
# ----------------------------------------------------------------------

proc edit_netlabel_dialog {} {
    set nNl  [find netlabel -scope selection -count -goto none -add]
    set nAll [find all      -scope selection -count -goto none -add]
    if {$nNl != 1 || $nAll != 1} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Edit Netlabel" \
            -message "Select exactly one netlabel and nothing else.\n(selected: $nNl netlabel(s), $nAll object(s) total)"
        return
    }

    set curName ""
    find netlabel -scope selection -add -goto none -filter {
        set curName [join [property get -name Name -system]]
    }

    set w .editNetlabel
    catch {destroy $w}
    toplevel $w
    wm title $w "Edit Netlabel"
    wm resizable $w 1 0

    # Entry/command fonts shared with the copy-cell dialog; labels and
    # checkboxes get a larger font of their own (CopyCellLabelFont is
    # Arial 10 — too small here).
    if {[lsearch -exact [font names] EditNLLabelFont] < 0} {
        font create EditNLLabelFont -family Arial -size 13 -weight bold
    }
    if {[lsearch -exact [font names] CopyCellEntryFont] < 0} {
        font create CopyCellEntryFont -family Arial -size 13
    }
    if {[lsearch -exact [font names] CopyCellCmdFont] < 0} {
        font create CopyCellCmdFont -family Courier -size 14 -weight bold
    }

    array unset ::editNL
    set ::editNL(vertical) 0
    set ::editNL(reverse)  0
    set ::editNL(nrows)    0
    set ::editNL(maxrows)  8

    checkbutton $w.vertChk \
        -text "Edit strands vertically (one per row)" \
        -variable ::editNL(vertical) \
        -command edit_netlabel_mode_toggled \
        -anchor w \
        -font EditNLLabelFont

    checkbutton $w.revChk \
        -text "Reverse strand order" \
        -variable ::editNL(reverse) \
        -command edit_netlabel_reverse_toggled \
        -anchor w \
        -font EditNLLabelFont

    # --- single-line mode ---
    frame $w.single
    label $w.single.lbl \
        -text "Netlabel text (2-click: name, 3-click: strand):" \
        -anchor w \
        -font EditNLLabelFont
    entry $w.single.ent -width 44 -font CopyCellEntryFont
    pack $w.single.lbl -side top -fill x -pady {0 3}
    pack $w.single.ent -side top -fill x
    $w.single.ent insert 0 $curName
    bind $w.single.ent <Double-Button-1> {edit_netlabel_select_word %W %x; break}
    bind $w.single.ent <Triple-Button-1> {edit_netlabel_select_token %W %x; break}
    bind $w.single.ent <KeyRelease> {edit_netlabel_update_preview}
    bind $w.single.ent <Return> {edit_netlabel_ok}

    # --- vertical (per-strand) mode ---
    frame $w.vert
    label $w.vert.lbl \
        -text "Strands (top to bottom):" \
        -anchor w \
        -font EditNLLabelFont
    frame $w.vert.area
    canvas $w.vert.area.c -highlightthickness 0 -bd 0 \
        -yscrollcommand [list $w.vert.area.sb set]
    scrollbar $w.vert.area.sb -orient vertical \
        -command [list $w.vert.area.c yview]
    frame $w.vert.area.c.rows
    $w.vert.area.c create window 0 0 -anchor nw -window $w.vert.area.c.rows
    pack $w.vert.lbl  -side top -fill x -pady {0 3}
    pack $w.vert.area -side top -fill x
    pack $w.vert.area.c -side left
    # scrollbar packed on demand by edit_netlabel_fit_canvas

    # --- preview of what will be applied ---
    label $w.prevLbl \
        -text "Will apply:" \
        -anchor w \
        -font EditNLLabelFont
    set prevWidth [expr {[string length $curName] + 10}]
    if {$prevWidth < 50} { set prevWidth 50 }
    text $w.prevTxt \
        -width $prevWidth \
        -height 2 \
        -wrap char \
        -font CopyCellCmdFont
    $w.prevTxt configure -state disabled

    frame $w.btns
    button $w.btns.ok     -text "OK"     -command edit_netlabel_ok
    button $w.btns.apply  -text "Apply"  -command edit_netlabel_apply
    button $w.btns.cancel -text "Cancel" -command edit_netlabel_cancel

    pack $w.vertChk -side top -fill x -padx 10 -pady {10 0}
    pack $w.revChk  -side top -fill x -padx 10 -pady {0 5}
    pack $w.single  -side top -fill x -padx 10 -pady {8 3}
    pack $w.prevLbl -side top -fill x -padx 10 -pady {10 3}
    pack $w.prevTxt -side top -fill both -expand 1 -padx 10 -pady {0 8}
    pack $w.btns    -side top -fill x -padx 10 -pady 10
    pack $w.btns.ok     -side left -padx 5
    pack $w.btns.apply  -side left -padx 5
    pack $w.btns.cancel -side right -padx 5

    bind $w <Escape>     {edit_netlabel_cancel}
    bind $w <MouseWheel> {edit_netlabel_wheel %D}
    bind $w <Button-4>   {edit_netlabel_wheel 120}
    bind $w <Button-5>   {edit_netlabel_wheel -120}

    edit_netlabel_update_preview
    focus $w.single.ent
    $w.single.ent icursor end
}

# Double-click: select just the word portion (letters/digits/underscore)
# under the pointer — myBusName out of myBusName<7:0>. Clicking on a
# non-word character (e.g. the <7:0> punctuation) falls back to selecting
# the whole strand.
proc edit_netlabel_select_word {ent x} {
    set txt [$ent get]
    set len [string length $txt]
    set idx [$ent index @$x]
    if {$idx >= $len} { set idx [expr {$len - 1}] }
    if {$idx < 0} { return }
    if {![string match {[A-Za-z0-9_]} [string index $txt $idx]]} {
        if {$idx > 0 && [string match {[A-Za-z0-9_]} [string index $txt [expr {$idx - 1}]]]} {
            incr idx -1
        } else {
            edit_netlabel_select_token $ent $x
            return
        }
    }
    set start $idx
    while {$start > 0 && [string match {[A-Za-z0-9_]} [string index $txt [expr {$start - 1}]]]} {
        incr start -1
    }
    set end $idx
    while {$end < $len && [string match {[A-Za-z0-9_]} [string index $txt $end]]} {
        incr end
    }
    $ent selection clear
    if {$end > $start} {
        $ent selection range $start $end
    }
    $ent icursor $end
}

# Triple-click: select the whole comma-separated strand under the pointer
# (instead of Tk's whitespace-word selection).
proc edit_netlabel_select_token {ent x} {
    set txt [$ent get]
    set len [string length $txt]
    set idx [$ent index @$x]
    if {$idx > $len} { set idx $len }
    set start $idx
    while {$start > 0 && [string index $txt [expr {$start - 1}]] ne ","} {
        incr start -1
    }
    set end $idx
    while {$end < $len && [string index $txt $end] ne ","} {
        incr end
    }
    $ent selection clear
    if {$end > $start} {
        $ent selection range $start $end
    }
    $ent icursor $end
}

# ----------------------------------------------------------------------
# Vertical-mode row machinery
# ----------------------------------------------------------------------

proc edit_netlabel_add_row {value} {
    set w .editNetlabel
    set rows $w.vert.area.c.rows
    set i $::editNL(nrows)
    set r $rows.r$i
    frame $r
    label $r.n -text [expr {$i + 1}] -width 3 -anchor e -font EditNLLabelFont
    entry $r.e -width 40 -font CopyCellEntryFont
    $r.e insert 0 $value
    pack $r.n -side left -padx {0 4}
    pack $r.e -side left -fill x -expand 1
    pack $r -side top -fill x -pady 1
    bind $r.e <KeyRelease> {edit_netlabel_row_changed}
    bind $r.e <Double-Button-1> {edit_netlabel_select_word %W %x; break}
    bind $r.e <Return> [list edit_netlabel_focus_row [expr {$i + 1}]]
    bind $r.e <Down>   [list edit_netlabel_focus_row [expr {$i + 1}]]
    bind $r.e <Up>     [list edit_netlabel_focus_row [expr {$i - 1}]]
    incr ::editNL(nrows)
}

# (Re)build all rows from a strand list; always one empty row at the end.
proc edit_netlabel_build_rows {strands} {
    set w .editNetlabel
    set rows $w.vert.area.c.rows
    foreach child [winfo children $rows] { destroy $child }
    set ::editNL(nrows) 0
    lappend strands ""
    foreach s $strands { edit_netlabel_add_row $s }
    edit_netlabel_fit_canvas
    $w.vert.area.c yview moveto 0
}

# Size the canvas to the rows, capped at maxrows visible; scrollbar on demand.
proc edit_netlabel_fit_canvas {} {
    set w .editNetlabel
    set c $w.vert.area.c
    set rows $c.rows
    update idletasks
    set innerW [winfo reqwidth  $rows]
    set innerH [winfo reqheight $rows]
    set n $::editNL(nrows)
    if {$n < 1} { set n 1 }
    set rowH [expr {($innerH + $n - 1) / $n}]
    set max $::editNL(maxrows)
    if {$n > $max} {
        set visH [expr {$max * $rowH}]
        pack $w.vert.area.sb -side right -fill y
    } else {
        set visH $innerH
        pack forget $w.vert.area.sb
    }
    $c configure -width $innerW -height $visH \
        -yscrollincrement $rowH \
        -scrollregion [list 0 0 $innerW $innerH]
}

proc edit_netlabel_row_changed {} {
    set w .editNetlabel
    set rows $w.vert.area.c.rows
    set last [expr {$::editNL(nrows) - 1}]
    if {[string trim [$rows.r$last.e get]] ne ""} {
        # last row got text: append a fresh empty row and keep it visible
        edit_netlabel_add_row ""
        edit_netlabel_fit_canvas
        $w.vert.area.c yview moveto 1.0
    }
    edit_netlabel_update_preview
}

proc edit_netlabel_focus_row {i} {
    set w .editNetlabel
    set last [expr {$::editNL(nrows) - 1}]
    if {$i < 0} { set i 0 }
    if {$i > $last} { set i $last }
    focus $w.vert.area.c.rows.r$i.e
    edit_netlabel_see_row $i
}

# Scroll so row i is inside the visible window (rows are equal height).
proc edit_netlabel_see_row {i} {
    set w .editNetlabel
    set c $w.vert.area.c
    if {$::editNL(nrows) <= $::editNL(maxrows)} { return }
    set view [$c yview]
    set top [lindex $view 0]
    set bot [lindex $view 1]
    set f0 [expr {double($i) / $::editNL(nrows)}]
    set f1 [expr {double($i + 1) / $::editNL(nrows)}]
    if {$f0 < $top} {
        $c yview moveto $f0
    } elseif {$f1 > $bot} {
        $c yview moveto [expr {$f1 - ($bot - $top)}]
    }
}

proc edit_netlabel_wheel {delta} {
    set w .editNetlabel
    if {![winfo exists $w] || !$::editNL(vertical)} { return }
    if {$::editNL(nrows) <= $::editNL(maxrows)} { return }
    $w.vert.area.c yview scroll [expr {-$delta / 120}] units
}

# ----------------------------------------------------------------------
# State readers / mode + reverse toggles
# ----------------------------------------------------------------------

proc edit_netlabel_rows_strands {} {
    set rows .editNetlabel.vert.area.c.rows
    set out {}
    for {set i 0} {$i < $::editNL(nrows)} {incr i} {
        set s [string trim [$rows.r$i.e get]]
        if {$s ne ""} { lappend out $s }
    }
    return $out
}

proc edit_netlabel_current_strands {} {
    set w .editNetlabel
    if {$::editNL(vertical)} {
        return [edit_netlabel_rows_strands]
    }
    return [enl_split_strands [$w.single.ent get]]
}

proc edit_netlabel_mode_toggled {} {
    set w .editNetlabel
    if {$::editNL(vertical)} {
        set strands [enl_split_strands [$w.single.ent get]]
        pack forget $w.single
        edit_netlabel_build_rows $strands
        pack $w.vert -side top -fill x -padx 10 -pady {8 3} -before $w.prevLbl
        edit_netlabel_focus_row 0
    } else {
        set strands [edit_netlabel_rows_strands]
        pack forget $w.vert
        $w.single.ent delete 0 end
        $w.single.ent insert 0 [enl_join_strands $strands]
        pack $w.single -side top -fill x -padx 10 -pady {8 3} -before $w.prevLbl
        focus $w.single.ent
        $w.single.ent icursor end
    }
    edit_netlabel_update_preview
}

proc edit_netlabel_reverse_toggled {} {
    set w .editNetlabel
    if {$::editNL(vertical)} {
        edit_netlabel_build_rows [lreverse [edit_netlabel_rows_strands]]
    } else {
        set strands [lreverse [enl_split_strands [$w.single.ent get]]]
        $w.single.ent delete 0 end
        $w.single.ent insert 0 [enl_join_strands $strands]
    }
    edit_netlabel_update_preview
}

proc edit_netlabel_update_preview {} {
    set w .editNetlabel
    set t [enl_join_strands [edit_netlabel_current_strands]]
    $w.prevTxt configure -state normal
    $w.prevTxt delete 1.0 end
    $w.prevTxt insert 1.0 $t
    $w.prevTxt configure -state disabled
}

# ----------------------------------------------------------------------
# Apply / OK / Cancel
# ----------------------------------------------------------------------

proc edit_netlabel_apply {} {
    set strands [edit_netlabel_current_strands]
    if {![llength $strands]} {
        tk_messageBox -icon error -type ok -title "Edit Netlabel" \
            -message "The netlabel text is empty — nothing to apply."
        return 0
    }
    foreach s $strands {
        if {[regexp {\s} $s]} {
            tk_messageBox -icon error -type ok -title "Edit Netlabel" \
                -message "Strand \"$s\" contains whitespace."
            return 0
        }
    }
    set newName [enl_join_strands $strands]

    # The selection may have changed while the form was open — re-verify.
    set nNl  [find netlabel -scope selection -count -goto none -add]
    set nAll [find all      -scope selection -count -goto none -add]
    if {$nNl != 1 || $nAll != 1} {
        tk_messageBox -icon error -type ok -title "Edit Netlabel" \
            -message "The selection changed — exactly one netlabel must still be selected.\n(selected: $nNl netlabel(s), $nAll object(s) total)"
        return 0
    }

    find netlabel -scope selection -add -goto none -modify {
        property set -name Name -system -value $newName
    }
    return 1
}

proc edit_netlabel_ok {} {
    if {[edit_netlabel_apply]} {
        edit_netlabel_cancel
    }
}

proc edit_netlabel_cancel {} {
    catch {array unset ::editNL}
    catch {destroy .editNetlabel}
}

proc copy_current_cell_dialog {} {
    # Current context
    set currentLib  [sed_get_current_library]
    set currentCell [sed_get_current_cell_name]
    set allLibs     [lsort -dictionary [sed_get_library_names]]

    if {$currentLib eq "" || $currentCell eq ""} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Copy Cell" \
            -message "Could not determine current library/cell."
        return
    }

    if {![llength $allLibs]} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Copy Cell" \
            -message "No libraries were found."
        return
    }

    set w .copyCurrentCell
    catch {destroy $w}
    toplevel $w
    wm title $w "Copy Current Cell"
    wm resizable $w 1 0

    # Fonts
    if {[lsearch -exact [font names] CopyCellLabelFont] < 0} {
        font create CopyCellLabelFont -family Arial -size 12 -weight bold
    }
    if {[lsearch -exact [font names] CopyCellEntryFont] < 0} {
        font create CopyCellEntryFont -family Arial -size 14 -weight bold
    }
    if {[lsearch -exact [font names] CopyCellCmdFont] < 0} {
        font create CopyCellCmdFont -family Courier -size 14 -weight bold
    }

    option add *TCombobox*Listbox.font CopyCellEntryFont
	

    # State
    set ::copyCell_allLibs($w)      $allLibs
    set ::copyCell_toLibEntry($w)   $currentLib
    set ::copyCell_comboDisplay($w) $currentLib

    # Initial command preview text
    set initialCmd "cell copy -library $currentLib -cell $currentCell -to_library $currentLib -to_cell "
    set cmdWidth [expr {[string length $initialCmd] + 10}]
    if {$cmdWidth < 50} {
        set cmdWidth 50
    }

    label $w.src \
        -text "Source:  $currentLib / $currentCell" \
        -anchor w \
        -font CopyCellLabelFont

    label $w.nameLbl \
        -text "New Cell Name:" \
        -anchor w \
        -font CopyCellLabelFont

    entry $w.nameEnt \
        -width 40 \
        -font CopyCellEntryFont

    label $w.toLibEntryLbl \
        -text "To Library (type to filter):" \
        -anchor w \
        -font CopyCellLabelFont

    entry $w.toLibEnt \
        -width 40 \
        -textvariable ::copyCell_toLibEntry($w) \
        -font CopyCellEntryFont

    label $w.libLbl \
        -text "Matching Libraries:" \
        -anchor w \
        -font CopyCellLabelFont

    ttk::combobox $w.libCombo \
        -width 30 \
        -state readonly \
        -values $allLibs \
        -textvariable ::copyCell_comboDisplay($w) \
        -font CopyCellEntryFont

    label $w.cmdLbl \
        -text "Command to be executed:" \
        -anchor w \
        -font CopyCellLabelFont

    text $w.cmdTxt \
        -width $cmdWidth \
        -height 3 \
        -wrap none \
        -font CopyCellCmdFont

    $w.cmdTxt insert 1.0 $initialCmd
    $w.cmdTxt configure -state disabled

    frame $w.btns

    button $w.btns.proceed \
        -text "Proceed" \
        -command [list copy_current_cell_dialog_do $w $currentLib $currentCell]

    button $w.btns.cancel \
        -text "Cancel" \
        -command [list copy_current_cell_dialog_cancel $w]

    pack $w.src           -side top -fill x -padx 10 -pady {10 5}
    pack $w.nameLbl       -side top -fill x -padx 10 -pady {8 3}
    pack $w.nameEnt       -side top -fill x -padx 10 -pady {0 5}
    pack $w.toLibEntryLbl -side top -fill x -padx 10 -pady {8 3}
    pack $w.toLibEnt      -side top -fill x -padx 10 -pady {0 5}
    pack $w.libLbl        -side top -fill x -padx 10 -pady {8 3}
    pack $w.libCombo      -side top -fill x -padx 10 -pady {0 5}
    pack $w.cmdLbl        -side top -fill x -padx 10 -pady {10 3}
    pack $w.cmdTxt        -side top -fill both -expand 1 -padx 10 -pady {0 8}
    pack $w.btns          -side top -fill x -padx 10 -pady 10
    pack $w.btns.proceed  -side left -padx 5
    pack $w.btns.cancel   -side right -padx 5

    bind $w.nameEnt <KeyRelease> \
        [list copy_current_cell_dialog_update_command $w $currentLib $currentCell]

    bind $w.toLibEnt <KeyRelease> \
        [list copy_current_cell_dialog_filter_libs $w $currentLib $currentCell]

    bind $w.libCombo <<ComboboxSelected>> \
        [list copy_current_cell_dialog_combo_selected $w $currentLib $currentCell]

    bind $w.nameEnt <Return> \
        [list copy_current_cell_dialog_do $w $currentLib $currentCell]

    bind $w.toLibEnt <Return> \
        [list copy_current_cell_dialog_do $w $currentLib $currentCell]

    focus $w.nameEnt
}

proc copy_current_cell_dialog_filter_libs {w currentLib currentCell} {
    set typed [string trim $::copyCell_toLibEntry($w)]
    set allLibs $::copyCell_allLibs($w)

    set matches {}
    foreach lib $allLibs {
        if {$typed eq "" || [string match -nocase ${typed}* $lib]} {
            lappend matches $lib
        }
    }

    $w.libCombo configure -values $matches

    if {$typed eq ""} {
        set ::copyCell_comboDisplay($w) $currentLib
    } elseif {[llength $matches] > 0} {
        set ::copyCell_comboDisplay($w) [lindex $matches 0]
    } else {
        set ::copyCell_comboDisplay($w) "*INVALID*"
    }

    copy_current_cell_dialog_update_command $w $currentLib $currentCell
}

proc copy_current_cell_dialog_combo_selected {w currentLib currentCell} {
    set sel $::copyCell_comboDisplay($w)

    # Reflect dropdown choice into entry field
    set ::copyCell_toLibEntry($w) $sel

    # Restore full list, because combobox selection itself should not filter
    $w.libCombo configure -values $::copyCell_allLibs($w)

    # Keep display consistent with selected value
    set ::copyCell_comboDisplay($w) $sel

    copy_current_cell_dialog_update_command $w $currentLib $currentCell
}

proc copy_current_cell_dialog_get_valid_to_library {w currentLib} {
    set typed [string trim $::copyCell_toLibEntry($w)]
    set allLibs $::copyCell_allLibs($w)

    if {$typed eq ""} {
        return $currentLib
    }

    foreach lib $allLibs {
        if {[string match -nocase ${typed}* $lib]} {
            return $lib
        }
    }

    return ""
}

proc copy_current_cell_dialog_update_command {w currentLib currentCell} {
    set toLib [copy_current_cell_dialog_get_valid_to_library $w $currentLib]
    if {$toLib eq ""} {
        set toLib "*INVALID*"
    }

    set toCell [string trim [$w.nameEnt get]]

    set cmd "cell copy -library $currentLib -cell $currentCell -to_library $toLib -to_cell $toCell"

    $w.cmdTxt configure -state normal
    $w.cmdTxt delete 1.0 end
    $w.cmdTxt insert 1.0 $cmd
    $w.cmdTxt configure -state disabled
}

proc copy_current_cell_dialog_do {w currentLib currentCell} {
    set toLib  [copy_current_cell_dialog_get_valid_to_library $w $currentLib]
    set toCell [string trim [$w.nameEnt get]]

    if {$toLib eq ""} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Copy Cell" \
            -message "Please enter a valid destination library."
        return
    }

    if {$toCell eq ""} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Copy Cell" \
            -message "Please enter a new cell name."
        return
    }

    set rc [catch {
        cell copy \
            -library    $currentLib \
            -cell       $currentCell \
            -to_library $toLib \
            -to_cell    $toCell
    } err]

    copy_current_cell_dialog_cancel $w

    if {$rc} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Copy Cell" \
            -message "Cell copy failed:\n$err"
    }
}

proc copy_current_cell_dialog_cancel {w} {
    catch {unset ::copyCell_allLibs($w)}
    catch {unset ::copyCell_toLibEntry($w)}
    catch {unset ::copyCell_comboDisplay($w)}
    catch {destroy $w}
}

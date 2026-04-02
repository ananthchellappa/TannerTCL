proc rename_current_view_to_symbol_review {} {
    # Get current context
    set libName  [workspace getactive -library]
    set cellName [workspace getactive -cell]
    set viewName [workspace getactive -view]
    set viewType [workspace getactive -type]

    # Basic sanity
    if {$libName eq "" || $cellName eq "" || $viewName eq ""} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Rename View" \
            -message "Could not determine active library/cell/view."
        return
    }

    # Only proceed if current view type is "symbol"
    if {$viewType ne "symbol"} {
        tk_messageBox \
            -icon info \
            -type ok \
            -title "Rename View" \
            -message "Active view type is \"$viewType\", not \"symbol\".\nNothing to do."
        return
    }

    # Build command string for review
    set cmd "cell renameview -library $libName -cell $cellName -view $viewName -newname symbol"

    # Create dialog
    set w .renameViewReview
    catch {destroy $w}
    toplevel $w
    wm title $w "Review Rename Command"
    wm resizable $w 1 0
#	font create RenameCmdFont -family Arial -size 18 -weight bold

    label $w.msg \
        -text "The following command will be executed:" \
        -anchor w

    text $w.txt \
        -width 90 \
        -height 4 \
        -wrap word \
		-font UiCmdFont

    $w.txt insert 1.0 $cmd
    $w.txt configure -state disabled

    frame $w.btns

    button $w.btns.proceed \
        -text "Proceed" \
        -command [list rename_current_view_to_symbol_do $w $libName $cellName $viewName]

    button $w.btns.cancel \
        -text "Cancel" \
        -command [list destroy $w]

    pack $w.msg -side top -fill x -padx 10 -pady {10 5}
    pack $w.txt -side top -fill both -expand 1 -padx 10 -pady 5
    pack $w.btns -side top -fill x -padx 10 -pady 10
    pack $w.btns.proceed -side left -padx 5
    pack $w.btns.cancel  -side right -padx 5

    focus $w.btns.cancel
}

proc rename_current_view_to_symbol_do {w libName cellName viewName} {
    catch {
        cell renameview \
            -library $libName \
            -cell    $cellName \
            -view    $viewName \
            -newname symbol
    } err

    destroy $w

    if {[info exists err] && $err ne ""} {
        tk_messageBox \
            -icon error \
            -type ok \
            -title "Rename View" \
            -message "Rename failed:\n$err"
    }
}

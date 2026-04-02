proc rename_current_view_prompt_newname {} {
    foreach {libName cellName viewName} [uiutil::get_active_lcv] break

    if {$libName eq "" || $cellName eq "" || $viewName eq ""} {
        uiutil::msg_error "Rename View" "Could not determine active library/cell/view."
        return
    }

    set w [uiutil::create_dialog .renameViewPrompt "Rename Current View"]

    uiutil::add_title $w "Rename current view"

    set msg [uiutil::add_label $w.msg "Enter new view name:"]
    pack $msg -side top -fill x -padx 10 -pady {0 5}

    set ent [uiutil::add_entry $w.newname 40]
    pack $ent -side top -fill x -padx 10 -pady 5

    set cmdlbl [uiutil::add_label $w.cmdlabel "Command to be executed:"]
    pack $cmdlbl -side top -fill x -padx 10 -pady {10 5}

	set initialCmd "cell renameview -library $libName -cell $cellName -view $viewName -newname "

	set cmdtxt [uiutil::add_cmd_text_for_string $w.cmd $initialCmd 10 3]
	pack $cmdtxt -side top -fill both -expand 1 -padx 10 -pady 5

	uiutil::set_readonly_text $cmdtxt $initialCmd

    uiutil::add_button_row \
        $w \
        [list rename_current_view_prompt_newname_do $w $libName $cellName $viewName] \
        [list destroy $w]

    bind $ent <KeyRelease> \
        [list rename_current_view_prompt_newname_update $w $libName $cellName $viewName]

    bind $ent <Return> \
        [list rename_current_view_prompt_newname_do $w $libName $cellName $viewName]

    focus $ent
}

proc rename_current_view_prompt_newname_update {w libName cellName viewName} {
    set newName [$w.newname get]
    set cmd "cell renameview -library $libName -cell $cellName -view $viewName -newname $newName"
    uiutil::set_readonly_text $w.cmd $cmd
}

proc rename_current_view_prompt_newname_do {w libName cellName viewName} {
    set newName [string trim [$w.newname get]]

    if {$newName eq ""} {
        uiutil::msg_error "Rename View" "Please enter a new view name."
        return
    }

    set rc [catch {
        cell renameview \
            -library $libName \
            -cell    $cellName \
            -view    $viewName \
            -newname $newName
    } err]

    destroy $w

    if {$rc} {
        uiutil::msg_error "Rename View" "Rename failed:\n$err"
    }
}

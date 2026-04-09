namespace eval uiutil {
    variable inited 0
}

proc uiutil::ensure_font {name args} {
    if {[lsearch -exact [font names] $name] == -1} {
        eval [list font create $name] $args
    } else {
        eval [list font configure $name] $args
    }
    return $name
}

proc uiutil::init {} {
    variable inited
    if {$inited} {
        return
    }

	uiutil::ensure_font UiAlertFont   -family Arial   -size 18 -weight bold
    uiutil::ensure_font UiTitleFont   -family Arial   -size 12 -weight bold
    uiutil::ensure_font UiLabelFont   -family Arial   -size 10
    uiutil::ensure_font UiBoldFont    -family Arial   -size 10 -weight bold
    uiutil::ensure_font UiEntryFont   -family Courier -size 13
    uiutil::ensure_font UiCmdFont     -family Courier -size 14 -weight bold
    uiutil::ensure_font UiButtonFont  -family Arial   -size 10 -weight bold
    uiutil::ensure_font UiSmallFont   -family Arial   -size 9

    set inited 1
}

proc uiutil::create_dialog {w title} {
    uiutil::init

    catch {destroy $w}
    toplevel $w
    wm title $w $title
    wm resizable $w 1 0
    return $w
}

proc uiutil::add_title {parent text} {
    label $parent.title -text $text -anchor w -font UiTitleFont
    pack $parent.title -side top -fill x -padx 10 -pady {10 6}
    return $parent.title
}

proc uiutil::add_label {path text} {
    label $path -text $text -anchor w -font UiBoldFont
    return $path
}

proc uiutil::add_entry {path {width 40}} {
    entry $path -width $width -font UiEntryFont
    return $path
}



proc uiutil::add_cmd_text_for_string {path text {extraChars 10} {height 3}} {
    set width [expr {[string length $text] + $extraChars}]
    if {$width < 40} {
        set width 40
    }
    text $path -width $width -height $height -wrap none -font UiCmdFont
    return $path
}

proc uiutil::set_readonly_text {w text} {
    $w configure -state normal
    $w delete 1.0 end
    $w insert 1.0 $text
    $w configure -state disabled
}

proc uiutil::add_button_row {parent proceedCmd cancelCmd} {
    frame $parent.btns

    button $parent.btns.proceed \
        -text "Proceed" \
        -font UiButtonFont \
        -command $proceedCmd

    button $parent.btns.cancel \
        -text "Cancel" \
        -font UiButtonFont \
        -command $cancelCmd

    pack $parent.btns -side top -fill x -padx 10 -pady 10
    pack $parent.btns.proceed -side left -padx 5
    pack $parent.btns.cancel  -side right -padx 5

    return $parent.btns
}

proc uiutil::msg_error {title message} {
    tk_messageBox -icon error -type ok -title $title -message $message
}

proc uiutil::msg_info {title message} {
    tk_messageBox -icon info -type ok -title $title -message $message
}

proc uiutil::get_active_lcv {} {
    set libName  [workspace getactive -library]
    set cellName [workspace getactive -cell]
    set viewName [workspace getactive -view]
    return [list $libName $cellName $viewName]
}

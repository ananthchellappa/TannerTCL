proc countdown_popup {seconds message} {
    if {$seconds <= 0} {
        return
    }

    set w .countdownPopup

    if {[winfo exists $w]} {
        destroy $w
    }

    toplevel $w
    wm title $w "Countdown"
    wm resizable $w 0 0

    set ::countdown_total_slots($w) 30
    set ::countdown_total_ms($w) [expr {int($seconds * 1000)}]
    set ::countdown_end_ms($w) [expr {[clock milliseconds] + $::countdown_total_ms($w)}]
    set ::countdown_message($w) $message

    # User-supplied alert/message
    label $w.alert \
        -text $message \
        -font UiAlertFont \
        -padx 10 -pady 8 \
        -justify center

    # Routine countdown status
    label $w.status \
        -text "" \
        -font UiLabelFont \
        -padx 10 -pady 2 \
        -justify center

    # Text progress bar
    label $w.bar \
        -text "" \
        -font UiCmdFont \
        -padx 10 -pady 4

    button $w.ok \
        -text "OK" \
        -width 10 \
        -font UiButtonFont \
        -command [list destroy $w]

    pack $w.alert  -side top -fill x
    pack $w.status -side top -fill x
    pack $w.bar    -side top -fill x
    pack $w.ok     -side top -pady 10

    ::countdown_popup_update $w
}

proc ::countdown_popup_update {w} {
    if {![winfo exists $w]} {
        return
    }

    set now_ms      [clock milliseconds]
    set end_ms      $::countdown_end_ms($w)
    set total_ms    $::countdown_total_ms($w)
    set total_slots $::countdown_total_slots($w)

    set remaining_ms [expr {$end_ms - $now_ms}]
    if {$remaining_ms < 0} {
        set remaining_ms 0
    }

    set fraction [expr {double($remaining_ms) / $total_ms}]
    set filled   [expr {int(round($fraction * $total_slots))}]

    if {$filled < 0} { set filled 0 }
    if {$filled > $total_slots} { set filled $total_slots }

    set empty [expr {$total_slots - $filled}]
    set bar "[string repeat # $filled][string repeat . $empty]"
    set sec [expr {($remaining_ms + 999) / 1000}]

    $w.status configure -text "Closing in $sec second(s)..."
    $w.bar configure -text "\[$bar\]"

    if {$remaining_ms <= 0} {
        destroy $w
        return
    }

    after 100 [list ::countdown_popup_update $w]
}

# scratchpad.tcl
#
# Several utilities here (tgl_port_lbl / Ctrl+Shift+T, mul_text, open_scratch)
# use a throwaway schematic cell named "scratchpad" as a scratch canvas:
# copy a selection into it, mutate it, copy back. The old code assumed the
# scratchpad lived in the *active* library, so editing in a library that has
# no scratchpad cell failed with "scratchpad cell does not exist".
#
# This file decouples the scratchpad from the active library. The scratchpad
# may live in ANY open library. The chosen library is:
#   - resolved lazily, the first time a scratchpad consumer runs (not at
#     startup -- at startup the libraries from lib.defs are usually not open
#     yet, and a modal dialog during sourcing is risky);
#   - cached in a global for the rest of the session;
#   - persisted to a .scratchrc file next to the session's lib.defs, so the
#     choice survives restarts.
#
# Public entry points:
#   scratch_design   -> returns the library/design name that holds the
#                       scratchpad (resolving + prompting on first use).
#                       Returns "" if unresolved (user cancelled).
#   scratch_choose   -> force a re-pick (also: scratch_reset). Bound in the
#                       menu under Useful Commands.
#
# To re-pick the scratchpad later: delete the .scratchrc file, or run
# scratch_choose.

# Session cache: name of the design/library that holds the scratchpad cell.
if {![info exists ::scratch_design_g]} {
    set ::scratch_design_g ""
}

#-----------------------------------------------------------------------------
# Persistence: .scratchrc lives next to the session's lib.defs (per
# "database paths -defs"), falling back to $HOME if that location is missing
# or not writable.
#-----------------------------------------------------------------------------

proc scratch_rc_path {} {
    set dir ""
    if {![catch {set defs [database paths -defs]}] && [llength $defs] > 0} {
        set dir [file dirname [lindex $defs 0]]
    }
    if {$dir eq "" || ![file isdirectory $dir] || ![file writable $dir]} {
        if {[info exists ::env(HOME)]} {
            set dir $::env(HOME)
        } else {
            set dir [pwd]
        }
    }
    return [file join $dir .scratchrc]
}

proc scratch_save {design} {
    set path [scratch_rc_path]
    if {[catch {
        set f [open $path w]
        puts $f "# S-Edit scratchpad library. Delete this file or run 'scratch_choose' to re-pick."
        puts $f "design $design"
        close $f
    } err]} {
        puts "scratchpad: could not write $path ($err)"
        return 0
    }
    return 1
}

proc scratch_load {} {
    set path [scratch_rc_path]
    if {![file exists $path]} {
        return ""
    }
    if {[catch {
        set f [open $path r]
        set data [read $f]
        close $f
    }]} {
        return ""
    }
    foreach line [split $data "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} {
            continue
        }
        if {[regexp {^design\s+(.+)$} $line -> d]} {
            return [string trim $d]
        }
    }
    return ""
}

#-----------------------------------------------------------------------------
# Discovery
#-----------------------------------------------------------------------------

# Does $design (which must be an open design) contain a *schematic* scratchpad?
proc scratch_has_pad {design} {
    if {[catch {set cells [database cells -design $design]}]} {
        return 0    ;# design not open / unknown
    }
    if {[lsearch -exact $cells scratchpad] == -1} {
        return 0
    }
    if {[catch {set views [database views -design $design -cell scratchpad -type schematic]}]} {
        return 0
    }
    return [expr {[llength $views] > 0}]
}

# All currently-open designs that hold a schematic scratchpad cell.
proc scratch_find_candidates {} {
    set out [list]
    if {[catch {set designs [database designs]}]} {
        return $out
    }
    foreach d $designs {
        if {[scratch_has_pad $d]} {
            lappend out $d
        }
    }
    return $out
}

#-----------------------------------------------------------------------------
# Main accessor: lazy resolve + cache. Consumers call this.
#-----------------------------------------------------------------------------

proc scratch_design {} {
    global scratch_design_g

    # 1. cached choice still valid?
    if {$scratch_design_g ne "" && [scratch_has_pad $scratch_design_g]} {
        return $scratch_design_g
    }

    # 2. remembered in .scratchrc and still valid?
    set saved [scratch_load]
    if {$saved ne "" && [scratch_has_pad $saved]} {
        set scratch_design_g $saved
        puts "scratchpad: using '$saved' (remembered in [scratch_rc_path])."
        puts "           Delete that file or run 'scratch_choose' to re-pick."
        return $saved
    }

    # 3. discover / prompt.
    return [scratch_resolve 0]
}

# force == 1 means re-pick even when exactly one candidate exists.
proc scratch_resolve {force} {
    global scratch_design_g

    set cands [scratch_find_candidates]
    set n [llength $cands]
    set chosen ""

    if {$n == 0} {
        set chosen [scratch_offer_create]
    } elseif {$n == 1 && !$force} {
        set chosen [lindex $cands 0]
    } else {
        set chosen [scratch_pick_dialog $cands]
    }

    if {$chosen eq ""} {
        puts "scratchpad: no scratchpad library selected."
        return ""
    }

    set scratch_design_g $chosen
    scratch_save $chosen
    puts "scratchpad: using '$chosen' (saved to [scratch_rc_path])."
    return $chosen
}

# Re-pick the scratchpad library (menu / console entry point).
proc scratch_choose {} {
    global scratch_design_g
    set scratch_design_g ""
    return [scratch_resolve 1]
}
proc scratch_reset {} {
    return [scratch_choose]
}

#-----------------------------------------------------------------------------
# Dialogs (use the shared uiutil:: helpers / tk_messageBox)
#-----------------------------------------------------------------------------

# No scratchpad anywhere: offer to create one in the active library.
proc scratch_offer_create {} {
    uiutil::init

    set active ""
    catch {set active [workspace getactive -toplevel_design]}

    set msg "No 'scratchpad' schematic cell was found in any open library."

    if {$active eq ""} {
        uiutil::msg_info "Scratchpad" \
            "$msg\n\nOpen a library, create a schematic cell named 'scratchpad', then try again."
        return ""
    }

    set ans [tk_messageBox -icon question -type yesno -title "Scratchpad" \
        -message "$msg\n\nCreate one now in the active library '$active'?"]
    if {$ans ne "yes"} {
        return ""
    }
    if {[catch {scratch_create_in $active} err]} {
        uiutil::msg_error "Scratchpad" "Could not create scratchpad in '$active':\n$err"
        return ""
    }
    return $active
}

proc scratch_create_in {design} {
    cell new -cell scratchpad -design $design -view schematic \
        -type schematic -interface view0 -newwindow
    catch {window close}    ;# leave no stray scratchpad window open
}

# Several libraries have a scratchpad: let the user pick. Modal; returns "" on
# cancel.
proc scratch_pick_dialog {cands} {
    global scratch_pick_result scratch_pick_var
    uiutil::init

    set w .scratchPick
    catch {destroy $w}
    toplevel $w
    wm title $w "Choose scratchpad library"

    set scratch_pick_result ""
    set scratch_pick_var [lindex $cands 0]

    uiutil::add_title $w "Multiple libraries contain a 'scratchpad' cell.\nChoose which to use:"

    frame $w.opts
    pack $w.opts -side top -fill x -padx 16 -pady 4
    set i 0
    foreach d $cands {
        radiobutton $w.opts.r$i -text $d -value $d \
            -variable scratch_pick_var -font UiLabelFont -anchor w
        pack $w.opts.r$i -side top -fill x
        incr i
    }

    frame $w.btns
    pack $w.btns -side top -fill x -padx 10 -pady 10
    button $w.btns.ok -text "Use" -font UiButtonFont \
        -command {set scratch_pick_result $scratch_pick_var; destroy .scratchPick}
    button $w.btns.cancel -text "Cancel" -font UiButtonFont \
        -command {set scratch_pick_result ""; destroy .scratchPick}
    pack $w.btns.ok -side left -padx 5
    pack $w.btns.cancel -side right -padx 5

    catch {grab set $w}
    tkwait window $w
    catch {grab release $w}

    return $scratch_pick_result
}

# depends on sed_helpers.tcl conventions (symbol-view port iteration via `find port`)
#
# Add wire stubs to a SELECTED instance, sizing the stub text and the stub
# length from the instance's symbol-view PIN font sizes.
#
# Why the median: a symbol has many pins and there is no reliable way to know
# which one is "the right" font size to copy, so we sample EVERY pin and use
# the median FontSize. We look only at ports (pins) -- text labels / notes are
# textlabel objects, not ports, so `find port` already ignores them.
#
# The stub wirelength is set to 1/10 of that median font size (integerized),
# mirroring the documented form:
#     draw addwirestubs -wirelength 10 -fontsize 100pt
#
# Requires exactly one instance to be selected.
proc addwirestubs_from_pin_median {} {

    # Unit suffix understood by `draw addwirestubs -fontsize`. The symbol-view
    # FontSize property is read in iu (see pin_orientation_in_parent_frame in
    # sed_helpers.tcl, which writes it back with `-units iu`), so iu keeps the
    # stub text the same size as the pins. Change to pt if your flow needs it.
    set FS_UNITS iu

    # --- 1. Resolve the selected instance's master cell/view. ---
    set masters {}
    find instance -scope selection -goto none -filter {
        set ml [lindex [property get -name MasterLibrary -system] 0]
        set mc [lindex [property get -name MasterCell    -system] 0]
        set mv [lindex [property get -name MasterView    -system] 0]
        lappend masters [list $ml $mc $mv]
        expr {1}
    }

    if {![llength $masters]} {
        puts "addwirestubs_from_pin_median: no instance selected"
        return
    }
    if {[llength $masters] > 1} {
        puts "addwirestubs_from_pin_median: select exactly one instance (got [llength $masters])"
        return
    }
    lassign [lindex $masters 0] lib cell view

    # --- 2. Open the symbol view and collect every PIN's FontSize. ---
    mode renderoff
    cell open -cell $cell -design $lib -view $view -newwindow

    set fsizes {}
    set filterScript {
        set fs [lindex [property get -name FontSize -system] 0]
        if {$fs ne ""} { lappend fsizes $fs }
        expr {1}
    }
    find port -scope view -filter $filterScript -goto none

    window close
    mode renderon

    if {![llength $fsizes]} {
        puts "addwirestubs_from_pin_median: no pins/font sizes found in $lib/$cell/$view"
        return
    }

    # --- 3. Median font size across all pins. ---
    set sorted [lsort -real $fsizes]
    set n      [llength $sorted]
    set mid    [expr {$n / 2}]
    if {$n % 2 == 1} {
        set median [lindex $sorted $mid]
    } else {
        set a [lindex $sorted [expr {$mid - 1}]]
        set b [lindex $sorted $mid]
        set median [expr {($a + $b) / 2.0}]
    }

    # --- 4. Integerize: fontsize = round(median), wirelength = fontsize/10. ---
    set fs_int [expr {int(round($median))}]
    set wl     [expr {int($fs_int / 10)}]
    if {$wl < 1} { set wl 1 }

    puts "addwirestubs_from_pin_median: $cell -- ${n} pins, median fontsize=$fs_int$ ({FS_UNITS}), wirelength=$wl"

    # --- 5. Add the stubs to the still-selected instance. ---
    draw addwirestubs -wirelength $wl -fontsize ${fs_int} -units iu
}

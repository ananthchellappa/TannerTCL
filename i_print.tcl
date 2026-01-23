proc i_print {} {

    # ---- 1) Require exactly one selected instance (do this first) ----
    set selInst [database instances -selected]
    if {[llength $selInst] != 1} {
        return
    }
    set instSel [lindex $selInst 0]

    # ---- 2) Get and normalize current context (list of {cell view lib inst} records) ----
    set ctx [workspace getactive -context]

    # Normalize depth=1 case where ctx may come back as a single 4-word record
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    # Instance names from context (the "path from top" at current level)
    set ctxInsts [list]
    foreach el $ctx {
        lappend ctxInsts [lindex $el end]
    }

    # ---- 3) Build the instance path: Xctx1.Xctx2.Xselected ----
    set instParts [list]
    foreach nm $ctxInsts {
        lappend instParts "X$nm"
    }
    lappend instParts "X$instSel"
    set instPath [join $instParts "."]

    # ---- 4) Determine whether we're using a PORT name or NETLABEL name ----
    set netOrPortName ""

    # Prefer port if exactly one port is selected
    set selPorts [database ports -selected]
    if {[llength $selPorts] == 1} {
        # Narrow selection to the port and read its Name
        find port -scope selection
        set tmp [property get Name -system]
        if {[llength $tmp] == 1} {
            set netOrPortName [lindex $tmp 0]
        } else {
            return
        }
    } else {
        # Otherwise require a netlabel in the selection
        find netlabel -scope selection
        set tmp [property get Name -system]
        if {[llength $tmp] == 1} {
            set netOrPortName [lindex $tmp 0]
        } else {
            return
        }
    }

    # ---- 5) Build the net/port path: Xctx1.Xctx2.<name> ----
    set netParts [list]
    foreach nm $ctxInsts {
        lappend netParts "X$nm"
    }
    lappend netParts $netOrPortName
    set netPath [join $netParts "."]

    # ---- 6) Emit the SPICE print command ----
    puts ".print tran i($instPath,$netPath)"
}

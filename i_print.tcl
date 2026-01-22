proc i_print {} {

    # ---- 1) Get exactly one selected instance (DO THIS FIRST; selection may change later) ----
    set selInst [database instances -selected]
    if {[llength $selInst] != 1} {
        return
    }
    set instSel [lindex $selInst 0]

    # ---- 2) Get and normalize current context (list of {cell view lib inst}) records ----
    set ctx [workspace getactive -context]

    # Normalize depth=1 case where ctx may come back as a single 4-word record
    # e.g. "ADC schematic LIB ADC1" instead of "{ADC schematic LIB ADC1}"
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    # Build the hierarchy instance chain for the *current schematic level*
    # ctxInsts = {ADC1 anatop1 ...}  (instance names from context)
    set ctxInsts [list]
    foreach el $ctx {
        lappend ctxInsts [lindex $el end]
    }

    # ---- 3) Create the instance path: Xctx1.Xctx2.Xselected ----
    set instParts [list]
    foreach nm $ctxInsts {
        lappend instParts "X$nm"
    }
    lappend instParts "X$instSel"
    set instPath [join $instParts "."]

    # ---- 4) Find exactly one netlabel in the current selection ----
    # This will typically leave only the netlabel selected.
    find netlabel -scope selection

    set netName [property get Name -system]
    if {[llength $netName] != 1} {
        return
    }
    set netName [lindex $netName 0]

    # ---- 5) Create the net path: Xctx1.Xctx2.netLabel ----
    set netParts [list]
    foreach nm $ctxInsts {
        lappend netParts "X$nm"
    }
    lappend netParts $netName
    set netPath [join $netParts "."]

    # ---- 6) Emit the SPICE print command ----
    puts ".print tran i($instPath,$netPath)"
}

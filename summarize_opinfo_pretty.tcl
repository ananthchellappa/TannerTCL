proc summarize_opinfo_pretty {opinfo} {
    set kv [dict create]

    # Parse opinfo into dictionary
    foreach line [split $opinfo "\n"] {
        set line [string trim $line]
        if {[regexp {^\s*([^=]+)=(.*)$} $line -> key val]} {
            dict set kv [string trim $key] [string trim $val]
        }
    }

    set lines {}

    # Helper to append formatted line
    proc _add {kvVar linesVar key} {
        upvar 1 $kvVar kv $linesVar lines
        if {[dict exists $kv $key]} {
            lappend lines "$key : [dict get $kv $key]"
        }
    }

    # Ordered fields
    _add kv lines Region
    _add kv lines vbs
    _add kv lines vds

    # vdsat OR vgt
    if {[dict exists $kv vdsat]} {
        lappend lines "vdsat : [dict get $kv vdsat]"
    } elseif {[dict exists $kv vgt]} {
        lappend lines "vgt : [dict get $kv vgt]"
    }

    _add kv lines vgs
    _add kv lines vth

    # id OR ids
    if {[dict exists $kv id]} {
        lappend lines "id : [dict get $kv id]"
    } elseif {[dict exists $kv ids]} {
        lappend lines "ids : [dict get $kv ids]"
    }

    _add kv lines gm
    _add kv lines gds

    rename _add {}

    return [join $lines "\n"]
}

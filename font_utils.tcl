# always retrieved in units of iu
# when you set using units of pt, it doesn't match what is displayed in property form
proc scaled_font_size { old_size up } {
    # Force integer input, in case FontSize comes back as a string/number.
    set old_size [expr {int(round($old_size))}]

    if { $up >= 0 } {
        # Scale upward by 10%, rounded to nearest integer.
        set new_size [expr {int(round($old_size * 1.1))}]

        # Guarantee at least +1.
        if { $new_size <= $old_size } {
            set new_size [expr {$old_size + 1}]
        }

    } else {
        # Scale downward by 10%, rounded to nearest integer.
        set new_size [expr {int(round($old_size / 1.1))}]

        # Guarantee at least -1, but never go below 1.
        if { $old_size <= 1 } {
            set new_size 1
        } elseif { $new_size >= $old_size } {
            set new_size [expr {$old_size - 1}]
        }

        # Safety clamp.
        if { $new_size < 1 } {
            set new_size 1
        }
    }

    return $new_size
}


proc scale_text { up } {
    find port -scope selection -add -goto none -regex -modify {
        set old_size [property get FontSize -system]
        set new_size [scaled_font_size $old_size $up]
        property set FontSize -system -units iu -value $new_size
    }

    find netlabel -scope selection -add -goto none -regex -modify {
        set old_size [property get FontSize -system]
        set new_size [scaled_font_size $old_size $up]
        property set FontSize -system -units iu -value $new_size
    }

    find textlabel -scope selection -add -goto none -regex -modify {
        set old_size [property get FontSize -system]
        set new_size [scaled_font_size $old_size $up]
        property set FontSize -system -units iu -value $new_size
    }
}

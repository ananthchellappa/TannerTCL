# ============================================================
# Suffix utilities for ports and netlabels in Tanner S-Edit
#
# Public procs:
#   get_suffix     - extract trailing _<suffix> from selected port/netlabel
#                    Names. If found, updates global _SUFFIX. If not
#                    found, leaves _SUFFIX unchanged.
#                    Returns the last extracted suffix, or "".
#
#   add_suffix     - appends "_$_SUFFIX" to every selected port and
#                    netlabel Name. No-op if _SUFFIX is empty.
#                    Append is unconditional (does not check whether
#                    the name already ends in _$_SUFFIX).
#
#   remove_suffix  - if a selected port or netlabel Name ends in
#                    "_$_SUFFIX", strips that trailing portion.
#                    Other names are left alone. No-op if _SUFFIX
#                    is empty.
#
# Bus-suffix handling:
#   A trailing <...> bus marker (e.g. <7:0>, <3>) is preserved in
#   place. Suffix work happens on the base portion only:
#       DATA<7:0>          + add_suffix(1p8) -> DATA_1p8<7:0>
#       DATA_1p8<7:0>      + get_suffix      -> 1p8
#       DATA_1p8<7:0>      + remove_suffix   -> DATA<7:0>
#
# Selection rule:
#   Both find commands run with -scope selection -add -goto none.
#   The two finds together cover any mix of ports and netlabels in
#   the current selection without disturbing the viewport, and -add
#   keeps the OTHER type alive between the two passes.
# ============================================================

# Loaded once at S-Edit startup.
set _SUFFIX ""


# ------------------------------------------------------------
# Per-object helpers (invoked inside -modify bodies)
# ------------------------------------------------------------

# Split name into {base bus}, where bus is a trailing <...> if present.
proc _suffix_split_bus {name} {
    if {[regexp {^(.*?)(<[^<>]+>)$} $name -> base bus]} {
        return [list $base $bus]
    }
    return [list $name ""]
}

# Inspect current selection's Name; if its base portion has an _<suffix>,
# write that into ::_SUFFIX and ::_suffix_last_extracted.
proc _suffix_capture_current {} {
    set name [property get -name Name -system]
    lassign [_suffix_split_bus $name] base bus
    if {[regexp {^.*_([^_]+)$} $base -> sfx]} {
        set ::_SUFFIX                $sfx
        set ::_suffix_last_extracted $sfx
    }
}

# Insert "_$sfx" between base and trailing bus marker.
proc _suffix_append_to_current {sfx} {
    set name [property get -name Name -system]
    lassign [_suffix_split_bus $name] base bus
    property set -name Name -system -value "${base}_${sfx}${bus}"
}

# If base ends in "_$sfx", strip it; reattach trailing bus marker.
proc _suffix_strip_to_current {sfx} {
    set name [property get -name Name -system]
    lassign [_suffix_split_bus $name] base bus
    set tail "_${sfx}"
    set tlen [string length $tail]
    set blen [string length $base]
    if {$blen > $tlen
        && [string range $base [expr {$blen - $tlen}] end] eq $tail} {
        set newbase [string range $base 0 [expr {$blen - $tlen - 1}]]
        property set -name Name -system -value "${newbase}${bus}"
    }
}


# ------------------------------------------------------------
# Selection guard: are any ports or netlabels selected?
# Returns 1 if yes, 0 (and prints) if no.
# ------------------------------------------------------------
proc _suffix_have_port_or_netlabel_selection {} {
    set n_ports     [find port     -scope selection -add -goto none -count]
    set n_netlabels [find netlabel -scope selection -add -goto none -count]
    if {$n_ports + $n_netlabels == 0} {
        puts "Select one or more ports and/or netlabels first."
        return 0
    }
    return 1
}


# ------------------------------------------------------------
# Public procs
# ------------------------------------------------------------

proc get_suffix {} {
    global _SUFFIX
    global _suffix_last_extracted

    if {![_suffix_have_port_or_netlabel_selection]} {
        return ""
    }

    set _suffix_last_extracted ""

    mode renderoff
    find port     -scope selection -add -goto none -modify _suffix_capture_current
    find netlabel -scope selection -add -goto none -modify _suffix_capture_current
    mode renderon

    return $_suffix_last_extracted
}


proc add_suffix {} {
    global _SUFFIX

    if {$_SUFFIX eq ""} {
        puts "_SUFFIX is empty; nothing to add. Set it (e.g. via get_suffix) first."
        return
    }

    if {![_suffix_have_port_or_netlabel_selection]} {
        return
    }

    # Double-quoted -modify so $_SUFFIX is substituted by Tcl before
    # S-Edit evaluates the body once per selected object.
    mode renderoff
    find port     -scope selection -add -goto none -modify "_suffix_append_to_current $_SUFFIX"
    find netlabel -scope selection -add -goto none -modify "_suffix_append_to_current $_SUFFIX"
    mode renderon
}


proc remove_suffix {} {
    global _SUFFIX

    if {$_SUFFIX eq ""} {
        puts "_SUFFIX is empty; nothing to remove."
        return
    }

    if {![_suffix_have_port_or_netlabel_selection]} {
        return
    }

    mode renderoff
    find port     -scope selection -add -goto none -modify "_suffix_strip_to_current $_SUFFIX"
    find netlabel -scope selection -add -goto none -modify "_suffix_strip_to_current $_SUFFIX"
    mode renderon
}

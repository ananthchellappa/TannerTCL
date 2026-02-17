proc bookmark_or_follow {} {
    upvar #0 schContext context

    set n [find textlabel -scope selection -goto none -count]

    if {$n == 0} {
        set xy [workspace getcursorposition]
		puts Bookmarking..
        textlabel -text $context -x [lindex $xy 0] -y [lindex $xy 1]
        return
    } elseif {$n == 1} {
        # TODO: if Name isn't the displayed label text, replace with the correct property
        set context [property get Name -system]
		puts Navigating..
        user3
        return
    } else {
        # multiple selected -> ignore
        return
    }
}

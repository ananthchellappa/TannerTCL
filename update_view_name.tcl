proc update_view_name {} {
    set n [find textlabel -scope selection -goto none -count]
    set ctx [workspace getactive]
    # ctx is: {cellName viewName libraryName}
    set viewName [lindex $ctx 1]

    if {$n == 0} {
        set xy [workspace getcursorposition]
		puts Adding view name..
        textlabel -text $viewName -x [lindex $xy 0] -y [lindex $xy 1]
        return
    } elseif {$n == 1} {
        # TODO: replace with the correct property
        property set -name Name -system -value $viewName
		puts Updating text with view name..
        return
    } else {
        # multiple selected -> ignore
        return
    }
}

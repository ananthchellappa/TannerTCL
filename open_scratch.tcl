proc open_scratch {} {
	# Prefer the remembered/located scratchpad library; if none is resolved
	# (user cancelled), fall back to the active design and create there.
	set dsn [scratch_design]
	if {$dsn eq ""} {
		set dsn [workspace getactive -toplevel_design]
	}
	set cells [database cells -design $dsn]

	if { -1 == [lsearch -exact $cells scratchpad] } {
	# scratchpad don't exist mate, create it, and then open
		cell new -cell scratchpad -design $dsn -view schematic -type schematic -interface view0 -newwindow
	} else {
	# exists, so just open it..
		cell open -design $dsn -cell scratchpad -type schematic -view [lindex [database views -design $dsn -cell scratchpad -type schematic] 0] -newwindow
	}

}

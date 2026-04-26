proc open_scratch {} {
	set dsn [workspace getactive -toplevel_design]
	set cells [database cells -design $dsn]
	
	if { -1 == [lsearch -exact $cells scratchpad] } {
	# scratchpad don't exist mate, create it, and then open
		cell new -cell scratchpad -design $dsn -view schematic -type schematic -interface view0 -newwindow
	} else {
	# exists, so just open it..
		cell open -design $dsn -cell scratchpad -type schematic -view [lindex [database views -design $dsn -cell scratchpad -type schematic] 0] -newwindow
	}

}

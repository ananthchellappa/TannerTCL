# Not as nice as what I have in Cadence, but a good start
# Select the pin (must have a whisker - path - touching it) on symbol, and an arrow will be added to the whisker, pointing left
# So, you'd want to use this for an output port on left edge or input port on right edge of symbol

proc sel_rect { x y object_type } {
	# path, port, wire, etc..
	allowselect none
	allowselect shape $object_type
	setup selection set -selectionmode partiallyenclosed
	set saved_sn_gr [expr { ( [setup schematicgrid get -snapgridsize] ) * 1.0 * [setup schematicunits get -numerator]/ [setup schematicunits get -denominator] } ]
	setup schematicgrid set -snapgridsize [expr $saved_sn_gr/4.0]
	find none
	point down [expr $x-1] [expr $y-1] -units iu
	point up [expr $x+1] [expr $y+1] -units iu
	allowselect all
	setup selection set -selectionmode fullyenclosed
	setup schematicgrid set -snapgridsize $saved_sn_gr
	allowselect all
}

proc arrow {} {
	
	if { 1 != [find all -scope selection -count -goto none] } {
		puts "Must select exactly one pin"
		return
	}
	mode renderoff
	find port -scope selection -count -goto none
	set x_p [property get -system X]
	set y_p [property get -system Y]
	sel_rect $x_p $y_p path

	set x [ expr min( [lindex [split [join [property get -system Vertices] ] , ] 0] , [lindex [split [join [property get -system Vertices] ] , ] 2 ] ) ]
	set y [lindex [split [join [property get -system Vertices] ] , ] 1]	 ;# only supports horizontal lines :-)
	delete
	set saved_sn_gr [expr { ( [setup schematicgrid get -snapgridsize] ) * 1.0 * [setup schematicunits get -numerator]/ [setup schematicunits get -denominator] } ]
	setup schematicgrid set -snapgridsize [expr $saved_sn_gr/4.0]
	mode draw path
	
	mode -drawstyle aa; # aa = any angle
	point click $x_p $y_p -units iu
	point click2 [expr $x+2] $y -units iu
	point click $x $y -units iu
	point click [expr $x+4] [expr $y-2] -units iu
	point click [expr $x+2] $y -units iu
	point click [expr $x+4] [expr $y+2] -units iu
	point click2 $x $y -units iu
	mode escape
	setup schematicgrid set -snapgridsize $saved_sn_gr
	puts "Sorry, mode drawstyle was changed.. Restore manually :)"
	mode renderon
}

# Arrowhead horizontal extent as a fraction of the wire stub length - change to taste
set ARROW_HEAD_FRACTION 0.50

proc sel_rect { x y object_type } {
	# path, port, wire, etc..
	allowselect none
	allowselect shape $object_type
	setup selection set -selectionmode partiallyenclosed
	set saved_sn_gr [setup schematicgrid get -snapgridsize]
	setup schematicgrid set -snapgridsize [expr $saved_sn_gr/4.0] -units iu
	find none
	point down [expr $x-1] [expr $y-1] -units iu
	point up [expr $x+1] [expr $y+1] -units iu
	setup selection set -selectionmode fullyenclosed
	setup schematicgrid set -snapgridsize $saved_sn_gr -units iu
	allowselect all
}

proc arrow {} {
	
	if { 1 != [find all -scope selection -count -goto none] } {
		puts "Must select exactly one pin"
		return
	}
	mode renderoff
	if { 1 != [find port -scope selection -count -goto none] } {
		mode renderon
		puts "Must select exactly one pin"
		return
	}
	set x_p [property get -system X]
	set y_p [property get -system Y]
	set orient [property get TextJustification.Horizontal -system]
	sel_rect $x_p $y_p path

	if { 1 != [find path -scope selection -count -goto none] } {
		mode renderon
		puts "No (single) wire stub found at the pin - nothing done"
		return
	}
	set verts [split [join [property get -system Vertices] ] , ]
	if { [lindex $verts 1] != [lindex $verts 3] } {
		mode renderon
		puts "Stub is not horizontal - only east/west pins supported"
		return
	}
	set x [ expr min( [lindex $verts 0] , [lindex $verts 2] ) ]
	set x_max [ expr max( [lindex $verts 0] , [lindex $verts 2] ) ]
	set y [lindex $verts 1]	 ;# only supports horizontal lines :-)
	delete
	set saved_sn_gr [setup schematicgrid get -snapgridsize]
	set stub_len [expr {$x_max - $x}]
	if { $stub_len < $saved_sn_gr } {
		puts "Warning: wire stub at pin ($stub_len iu) is shorter than the snap grid ($saved_sn_gr iu) - arrow may come out malformed"
	}
	setup schematicgrid set -snapgridsize [expr $saved_sn_gr/4.0] -units iu

	# Arrowhead horizontal extent = ARROW_HEAD_FRACTION of the stub length,
	# full height = extent (2:1 depth:half-height proportions).
	# Round the half-extent to the active quarter-grid so the clicks survive snapping
	# instead of collapsing onto each other.
	global ARROW_HEAD_FRACTION
	set quarter_grid [expr {$saved_sn_gr/4.0}]
	set head_half [expr {round($stub_len * $ARROW_HEAD_FRACTION / 2.0 / $quarter_grid) * $quarter_grid}]
	if { $head_half < $quarter_grid } { set head_half $quarter_grid }
	set head [expr {2.0 * $head_half}]

	mode draw path

	mode -drawstyle aa; # aa = any angle
	if {"Right" eq $orient} {
		point click [expr $x+$head_half] $y -units iu
		point click2 $x_max $y -units iu
	} else {
		point click $x_p $y_p -units iu
		point click2 [expr $x+$head_half] $y -units iu
	}
	point click $x $y -units iu
	point click [expr $x+$head] [expr $y-$head_half] -units iu
	point click [expr $x+$head_half] $y -units iu
	point click [expr $x+$head] [expr $y+$head_half] -units iu
	point click2 $x $y -units iu
	mode escape
	setup schematicgrid set -snapgridsize $saved_sn_gr -units iu
	puts "Sorry, mode drawstyle was changed.. Restore manually :)"
	mode renderon
}

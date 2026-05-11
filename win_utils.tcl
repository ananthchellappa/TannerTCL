proc win_viewportrect_iu {} {
# return view port coordinates in integer units
	set save_dispunits [setup schematicunits get -displayunits]
	mode renderoff
	setup schematicunits set -displayunits iu
	set win_vprect [window viewportrect]
	setup schematicunits set -displayunits $save_dispunits
	mode renderon
	return $win_vprect
}

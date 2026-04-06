proc toggleDynamicTooltip {} {
	puts "toggling Dynamic Tooltip"
	set cur [setup dynamicinfo get -displaytooltip]
	if {$cur } {
		setup dynamicinfo set -displaytooltip false
	} else {
		setup dynamicinfo set -displaytooltip true
	}
}

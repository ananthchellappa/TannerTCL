# updated 8/27 to set orientation based on which edge of the symbol the pin is on..

proc make_stubs {} {

	set xpos [property get -name X -system]
	set ypos [property get -name Y -system]


	mode renderoff
	cell open -cell [property get -name MasterCell -system] -design [property get -name MasterDesign -system] -view [property get -name MasterView -system] -newwindow

	set plist [database ports]			;# PORTS elements
	set puniq [lsort -unique $plist]	;# UNQ elements
	set pnum [list] 	;# know how many we will process.	UNQ elements
	set pcount [list]	;# keep track of how many we've processed. UNQ elements
						;# manipulate using lset pcount index newVal
	set i 0
	set pX [list]
	set pY [list]
	set hjL [list]
	set dir [list]
	set Xmin 1000000
	set Xmax -1000000
	set Ymin 1000000
	set Ymax -1000000
	
	foreach port $puniq {
		lappend pnum [llength [lsearch -all $plist $port] ]
		lappend pcount 0
	}
	
	foreach port $plist {
		find port -name $port -first -goto none
		set id [lsearch $puniq $port]
		if {  [lindex $pnum $id] > 1 } {
			for { set i 0} { $i < [lindex $pcount $id] } {incr i} {
				find port -name $port -next -goto none
			}
			lset pcount $id [expr $i + 1]
		}
		set x [property get -name X -host selections -system]
		if { $x < $Xmin } { set Xmin $x}
		if { $x > $Xmax } { set Xmax $x}
		lappend pX [lindex $x end]
		set x [property get -name Y -host selections -system]
		if { $x < $Ymin } { set Ymin $x}
		if { $x > $Ymax } { set Ymax $x}
		lappend pY [lindex $x end]
	}
	window close

	port -type NetLabel

	set i 0 	;# was eine gotcha before..
	foreach port $plist {
		set x [lindex $pX $i]
		set y [lindex $pY $i]

		if { ( $x == $Xmin ) } {
			mode draw wire
			point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			point click2 [expr -0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			mode draw port
			port -text $port -hjustify right -vjustify bottom -direction normal -size 4pt -confirm false
			point click [expr -0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			mode escape
		} else {
			if { ( $x == $Xmax ) } {
				mode draw wire
				point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				point click2 [expr 0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				mode draw port
				port -text $port -hjustify left -vjustify bottom -direction normal -size 4pt -confirm false
				point click [expr 0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				mode escape
			} else {
				 if { ( $y == $Ymax ) } {
				 	 mode draw wire
				 	 point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				 	 point click2 [expr ($x+$xpos)/1000.0] [expr 0.1 + ($y+$ypos)/1000.0]
				 	 mode draw port
				 	 port -text $port -hjustify left -vjustify bottom -direction down -size 4pt -confirm false
				 	 point click [expr ($x+$xpos)/1000.0] [expr 0.1 + ($y+$ypos)/1000.0]
				 	 mode escape
				 } else { if { ( $y == $Ymin ) } {
				 	 mode draw wire
				 	 point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				 	 point click2 [expr ($x+$xpos)/1000.0] [expr -0.1 + ($y+$ypos)/1000.0]
				 	 mode draw port
				 	 port -text $port -hjustify right -vjustify top -direction up -size 4pt -confirm false
				 	 point click [expr ($x+$xpos)/1000.0] [expr -0.1 + ($y+$ypos)/1000.0]
				 	 mode escape
					 }
				 }
			}
		} ;# else

		incr i

	}

	mode renderon
	mode draw wire
	point click [expr ($xpos + ($Xmax + $Xmin)/2.0 )/1000.0] [expr ($ypos + ($Ymax + $Ymin)/2.0 )/1000.0 ]
	mode escape
	point click [expr ($xpos + ($Xmax + $Xmin)/2.0 )/1000.0] [expr ($ypos + ($Ymax + $Ymin)/2.0 )/1000.0 ]

}


proc h_stubs {} {
# this one creates stubs with all names horizontally oriented

	set xpos [property get -name X -system]
	set ypos [property get -name Y -system]


	mode renderoff
	cell open -cell [property get -name MasterCell -system] -design [property get -name MasterDesign -system] -type symbol -newwindow

	set plist [database ports]
	set puniq [lsort -unique $plist]	;# UNQ elements
	set pnum [list] 	;# know how many we will process.	UNQ elements
	set pcount [list]	;# keep track of how many we've processed. UNQ elements
						;# manipulate using lset pcount index newVal
	set i 0
	set pX [list]
	set pY [list]
	set Xmin 1000000
	set Xmax -1000000
	set Ymin 1000000
	set Ymax -1000000
	foreach port $puniq {
		lappend pnum [llength [lsearch -all $plist $port] ]
		lappend pcount 0
	}
	
	foreach port $plist {
		find port -name $port -first -goto none
		set id [lsearch $puniq $port]
		if {  [lindex $pnum $id] > 1 } {
			for { set i 0} { $i < [lindex $pcount $id] } {incr i} {
				find port -name $port -next -goto none
			}
			lset pcount $id [expr $i + 1]
		}
		set x [property get -name X -host selections -system]
		if { $x < $Xmin } { set Xmin $x}
		if { $x > $Xmax } { set Xmax $x}
		lappend pX [lindex $x end]
		set x [property get -name Y -host selections -system]
		if { $x < $Ymin } { set Ymin $x}
		if { $x > $Ymax } { set Ymax $x}
		lappend pY [lindex $x end]
	}
	window close

	port -type NetLabel

	set xTop [list]
	set pTop [list]
	set xBot [list]
	set pBot [list]

	set i 0 	;# was eine gotcha before..
	foreach port $plist {
		set x [lindex $pX $i]
		set y [lindex $pY $i]

		if { ( $x == $Xmin ) } {
			mode draw wire
			point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			point click2 [expr -0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			mode draw port
			port -text $port -hjustify right -vjustify bottom -direction normal -size 4pt -confirm false
			point click [expr -0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
			mode escape
		} else { 
			if { ( $x == $Xmax ) } {
				mode draw wire
				point click [expr ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				point click2 [expr 0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				mode draw port
				port -text $port -hjustify left -vjustify bottom -direction normal -size 4pt -confirm false
				point click [expr 0.1 + ($x+$xpos)/1000.0] [expr ($y+$ypos)/1000.0]
				mode escape
			} else {
				if { ( $y == $Ymax ) } {
					lappend pTop [lindex $port end]
					lappend xTop [lindex $x end]
				} else { if { ( $y == $Ymin ) } {
					lappend pBot [lindex $port end]
					lappend xBot [lindex $x end]
					}
				}
			}

		}	;# else
		incr i
	}

	set len 0.1
	foreach x_ord [lsort -increasing -integer $xTop] {
		set pname [lindex $pTop [lsearch -integer $xTop $x_ord ] ]
		mode draw wire
		point click [expr ($x_ord+$xpos)/1000.0] [expr ($Ymax+$ypos)/1000.0]
		point click2 [expr ($x_ord+$xpos)/1000.0] [expr $len + ($Ymax+$ypos)/1000.0]
		mode draw port
		port -text $pname -hjustify right -vjustify middle -direction normal -size 4pt -confirm false
		point click [expr ($x_ord+$xpos)/1000.0] [expr $len + ($Ymax+$ypos)/1000.0]
		mode escape
		set len [expr $len + 0.1]
	}

	set len 0.1
	foreach x_ord [lsort -increasing -integer $xBot] {
		set pname [lindex $pBot [lsearch -integer $xBot $x_ord ] ]
		mode draw wire
		point click [expr ($x_ord+$xpos)/1000.0] [expr ($Ymin+$ypos)/1000.0]
		point click2 [expr ($x_ord+$xpos)/1000.0] [expr -$len + ($Ymin+$ypos)/1000.0]
		mode draw port
		port -text $pname -hjustify right -vjustify middle -direction normal -size 4pt -confirm false
		point click [expr ($x_ord+$xpos)/1000.0] [expr -$len + ($Ymin+$ypos)/1000.0]
		mode escape
		set len [expr $len + 0.1]
	}


	mode renderon
	mode draw wire
	point click [expr ($xpos + ($Xmax + $Xmin)/2.0 )/1000.0] [expr ($ypos + ($Ymax + $Ymin)/2.0 )/1000.0 ]
	mode escape
	point click [expr ($xpos + ($Xmax + $Xmin)/2.0 )/1000.0] [expr ($ypos + ($Ymax + $Ymin)/2.0 )/1000.0 ]

}

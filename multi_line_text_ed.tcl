# was useful till Tanner (Mentor) put in support for multi-line text editing. But
# maybe useful to you for something else you want to do..
# To process the selected text using a TCL Tk widget, no option but to 
# copy the selection to the scratchpad and then go looking for each of
# text units.. :(

# what text font size to use? Have to get it from the text you've processed.. 
# a lot of work :)

# limitations : first line of the text block must be unique within the schematic..

# this lim below was overcome through use of globals.. :(
### doesn't support changing the top-most line AND keeping the form open for more
### edits :( If you change the top line, you have to close the form..

# how to use - when you start, just put down on TextLabel (default) and go from there..


# proc update_text { args  } {
#	set top_tlabel [lindex $args 0]
#	set space [lindex $args 1]
 proc update_text {  } {
	global mltxt_args	;# a sad day - but, this was the best I could do
	set top_tlabel [lindex $mltxt_args 0]	;# gave up on arguments :(
	set space [lindex $mltxt_args 1]

	puts "Top label : $top_tlabel"
	puts $space
 	global .mltext			;# this is the actual GUI thing
	mode renderoff
	find textlabel -scope selection -goto none -add -modify { if { $top_tlabel ne [property get -name Name -system] } { delete } }
		# above basically takes the selection and deletes every textlabel that doesn't match the top one - which we
		# already know -- $top_tlabel
	set x [property get -name X -system]
	set y [property get -name Y -system]
	set yUL $y			;# UL is for Upper Left  -- used later for the selection rectangle
	set size [property get -name FontSize -system]
	if { [expr abs($space - 3.1415926535897)] < 0.00001 } { 	;# when they use the special value, they're 
																# telling us to use the text size to determine spacing
		set space [expr 100.0 * $size/92]	;# with a font size of 20 (278), you'll get a spacing of 3 :)
	}
	delete

	set nLines [.mltext.t count -lines 1.0 end] 		;# how many lines does the text widget have?
	for {set i 1} { $i <= $nLines } {incr i } {
		set line [.mltext.t get $i.0 $i.end]	
		if { 1 == $i } { set top_tlabel $line}		;# for the first line - we'll be send this back..
#		puts stdout [format "line : %s" $line]
		mode draw textlabel
		if { "" ne $line } {		;# if the line is not blank.. do something
			textlabel -text $line -hjustify left -vjustify middle -direction normal -size $size -units iu
			point click [expr $x/1000.0] [expr ($y)/1000.0]
		}
		mode escape
		set y [expr $y - $space]	;# move the cursor :)
	} ;#end for loop
	allowselect none				;# now begins the hard part (thank you Tanner) of selecting the stuff we just updated
	allowselect shape textlabel 	;# we basically go into select partially enclosed mode and then draw the rectangle
	setup selection set -selectionmode partiallyenclosed
	point down [expr $x/1000.0 - 0.5] [expr ($yUL)/1000.0 + 0.5]	;# start just NW of UL
	point up [expr $x/1000.0 + 0.5] [expr ($y)/1000.0 - 0.5]		;# end just SE of LR
	setup selection set -selectionmode fullyenclosed
	allowselect all
	mode renderon

	set mltxt_args [list $top_tlabel $space]

}


proc mul_text {} {
	global mltxt_args
	copy
	mode renderoff
    set dsn [database design -active]
	cell open -design $dsn -cell scratchpad -type schematic -view [lindex [database views -design $dsn -cell scratchpad -type schematic] 0] -newwindow
	find all
	delete
	paste
	set pY [list]

	set tlist [database labels]
	set tuniq [lsort -unique $tlist]	;# unique elements
	set tnum [list]
	set tcount [list]	;# keep tradck of how many we'll have to process..

	foreach tlabel $tuniq {
		lappend tnum [llength [lsearch -all $tlist $tlabel] ]
		lappend tcount 0
	}
# therefore, if you started off with labels A B C C D D D E
# you now have
# tlist : A B C C D D D E
# tuniq : A B C D E
# tnum : 1 1 2 3 1
# tcount : 0 0 0 0 0  ;# as high tech as it gets :)


	foreach tlabel $tlist {
		find textlabel -name $tlabel -first -goto none
		set id [lsearch $tuniq $tlabel]
		if { [lindex $tnum $id] > 1 } { 	;# so that this one has more than 1 to process
			for { set i 0} { $i < [lindex $tcount $id] } { incr i } {
				find textlabel -name $tlabel -next -goto none
			}
			lset tcount $id [expr $i + 1]
		}
		lappend pY [property get -name Y -system]		;# get the location
	}
	window close		;# done with the scratchpad
	mode renderon
	
	# get the highest y-ordinate value using lsort (then lindex 0)
	# then, use that value to get the index of that value
	# then, use that index to look up the corresponding textlabel value
	set top_tlbl [lindex $tlist [lsearch -integer $pY [lindex [lsort -decreasing -integer $pY] 0] ] ]
	if { [llength $tlist ] > 1 } {	;# concept of spacing only arises when you have more than one :)
		set spc [expr 1.0 * ([lindex [lsort -decreasing -integer $pY] 0] - [lindex [lsort -decreasing -integer $pY] end] ) / ([llength $tlist]-1)  ]
	} else {
		set spc 3.1415926535897932384	;# update_text will use this special number to use the font-size intelligently..
	}		
#	set cmd [join [list {[} set top_tlbl {[} update_text $top_tlbl $spc {]} {]} ] ]

	set mltxt_args [ list $top_tlbl $spc]

	toplevel .mltext
#	button .mltext.button -text "Apply" -command {set top_tlbl [update_text $top_tlbl $spc ] }
#	button .mltext.button -text "Apply" -command [join [list {[} set top_tlbl {[} update_text $top_tlbl $spc {]} {]} ] ]

#	button .mltext.button -text "Apply" -command [list update_text $top_tlbl $spc]
#	button .mltext.button -text "Apply" -command "set top_tlbl \[ update_text $top_tlbl $spc\]"

#	button .mltext.button -text "Apply" \
#		-command {set last_set [update_text [join $last_set] ]}

	button .mltext.button -text "Apply" -command update_text

	pack .mltext.button -padx 10 -pady 10

	text .mltext.t -bd 2 -bg white -height [expr 2 + [llength $tlist]]\
		 -font {-family Courier -size -18}
	pack .mltext.t

	.mltext.t delete 1.0 end
	foreach y_ord [lsort -decreasing -integer $pY] {
		set tlabel [lindex $tlist [lsearch -integer $pY $y_ord ] ]
		.mltext.t insert end [format "%s\n" $tlabel]
	}

}

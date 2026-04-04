set schContext ""
set viewContext [list]    ;# empty list
set special_fn 0	;# user must explicitly set to 1 for bindkey running User10 to have effect
set selmdfull true	;#  for fully enclosed only added
set is_docked true

proc user1 {} {
  # Use 'variable' to declare that 'gridOn' is a global variable
  # within the scope of this procedure. This is generally preferred
  # over 'upvar #0' for global variables as it's clearer and often
  # avoids unexpected behavior with some Tcl interpreters.
  variable is_docked

  if {$is_docked} {
    window move -undock
	set is_docked false
  } else {
    window move -dock
    set is_docked true
  }
}


proc user10 {} {
	window close
}

proc user11 {} {
    upvar #0 special_fn chkval
    if $chkval {
	# run these commands
    } else {
		puts "Please explicitly set the variable 'special_fn' to 1" 
    }
}

proc scale_snap_grid { factor } {
	# set newg [expr { ( [setup schematicgrid get -snapgridsize] ) * $factor / 1000 } ]
	# messed up since 3/2/26
	set newg [expr { ( [setup schematicgrid get -snapgridsize] ) * $factor * [setup schematicunits get -numerator]/ [setup schematicunits get -denominator] } ]
	puts "setting grid to $newg"
	setup schematicgrid set -snapgridsize $newg
	puts "to reset do\nsetup schematicgrid set -snapgridsize 0.1\n"
}

proc res_grid {} {
	# setup schematicgrid set -snapgridsize 0.1
	setup schematicgrid set -snapgridsize [expr { 50.0 * [setup schematicunits get -numerator]/ [setup schematicunits get -denominator] } ]
	# messed up since 3/2/26
	puts "setting grid to 50"
}

# updated 6/10/2015 to handle selections.. # then 6/25/2015 to be able to get instant undo
proc scale_text { up } {
	find port -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
	find netlabel -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
	find textlabel -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
}

proc user2 {} {
    find none

    set ctx [workspace getactive -context]
    if {![llength $ctx]} { return }

    # If ctx is a single record like: "ADC schematic DESIGN ADC1"
    # then wrap it so it becomes: "{ADC schematic DESIGN ADC1}"
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    set depth [llength $ctx]
    if {!$depth} { return }

    upvar #0 viewContext viewL
    upvar #0 schContext  context
    set b     [list]
    set viewL [list]

    foreach el $ctx {
        lappend b     [lindex $el end]   ;# instance name
        lappend viewL [lindex $el 1]     ;# view ("schematic")
    }
    set context [join $b "/"]
	set tpc [workspace getactive -toplevel_cell]
	set dsn [workspace getactive -toplevel_design]
	set vu [workspace getactive -toplevel_view]

    ;# now for the difficult business of single stepping from deep to top-level
    ;# a workaround for preserving net highlighting..
    mode renderoff
    set depth [expr {$depth -1 } ]
    while { $depth } {
        set b [lreplace $b $depth $depth]
		set cxt [join $b "/"]
        set depth [expr {$depth -1 } ]
    }

    cell open -cell $tpc -design $dsn -type schematic -view $vu -tracenets
    mode renderon
}

proc user3 {} {
	find none
    upvar #0 schContext context
    set insts [split $context "/"]
    set b [list]    ;# empty
    mode renderoff
    set depth 0
	set tpc [workspace getactive -toplevel_cell]
	set dsn [workspace getactive -toplevel_design]
	set vu [workspace getactive -toplevel_view]
    foreach el $insts {
        lappend b $el
		set cxt [join $b "/"]
;# 7/10/2015 - took out -view..  -- see note above - CPD_ADC_sim with hierarchy..
;#		puts "cell open -cell  $tpc -design $dsn -type schematic -view $vu -context $cxt -tracenets"
        cell open -cell $tpc -design $dsn -type schematic -view $vu -context $cxt -tracenets
        incr depth
    }
    mode renderon
}
# added -view view0 on 5/6/15

proc user4 {} {
	scale_snap_grid { 0.5 }
# suggest ALT Down-Arrow
# workspace bindkey -key {Alt+Down Arrow} -command {User 4}

}

proc user5 {} {
	select_in_libnav_from_selection_or_active
# used to be increase snap grid, but this one is more important CTRL-ALT-S
# needed in undocked window
}

proc user6 {} {
	mode renderoff
	scale_text { 1 }
	mode renderon
# CTRL Num pad +
# workspace bindkey -key {Ctrl+Num +} -command { User 6 }
# workspace bindkey -key {Ctrl+Shift+=} -command { User 6 }
}

proc user7 {} {
	mode renderoff
	scale_text { -1 }
	mode renderon
# workspace bindkey -key {Ctrl+-} -command { User 7 }
# workspace bindkey -key {Ctrl+Num -} -command { User 7 }
}

proc user8 {} {
	push
# recovering loss in undocked win
}

proc user9 {} {
	pop
}

proc ports_bigger {} {
	mode renderoff
	find port -scope view  -goto none -regex -modify {property set FontSize -system -units iu -value [expr 1.1*([property get FontSize -system]) ]}
	mode renderon
}

proc ports_smaller {} {
	mode renderoff
	find port -scope view  -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1/1.1)*([property get FontSize -system]) ]}
	mode renderon
}

proc labels_bigger {} {
	mode renderoff
	find textlabel -scope view  -goto none -regex -modify {property set FontSize -system -units iu -value [expr 1.1*([property get FontSize -system]) ]}
	mode renderon
}

proc printperlcmd {dname} {
	set pre {perl -n -e 'print if s/^[ \t?]*(\S+)\s+\(\s*\S+:\s+schematic.+?}
	set post {/$1/;' | sort | uniq | perl -n -e 'print unless /^\s*$/;'}
	puts "$pre$dname$post"

}

proc bussify {} {
	find all -scope selection -add -goto none -modify {
		if { [regexp {^(.*?)<(\d+)>$} [property get -system Name] all name m] } {
			; property set -system Name -value $name<$m:0>; 
		} else {
			if { ![regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] ] } {
				; property set -system Name -value [regsub {([^>])$} [property get -system Name] {\1<1:0>} ]; }
			}
		}
}

proc inc_bus {} {
	find all -scope selection -add -goto none -modify {if { [regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] all name m n] } {; incr m;; property set -system Name -value $name<$m:$n>; } else {; property set -system Name -value [regsub {([^>])$} [property get -system Name] {\1<1:0>} ]; }}
}

proc dec_bus {} {
	find all -scope selection -add -goto none -modify {if { [regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] all name m n] } {; set m [expr $m -1];; if { 0 == $m } {; property set -system Name -value $name; } else {; property set -system Name -value $name<$m:$n>; }; }}
}

proc GBG {} {
	setup schematicpage set -host view -framestyle none
}

proc _rev_bus {} {
	find all -scope selection -add -goto none -modify {if { [regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] all name m n] } { property set -system Name -value $name<$n:$m>; }  }
}

proc _up_id {} {
	find all -scope selection -add -goto none -modify {if { [regexp {^(.+)_(\d+)(<.+>)?$} [property get -system Name] all name m ary ] } {; incr m;; property set -system Name -value ${name}_$m$ary; } else {; property set -system Name -value [regsub {^(.+?)_?(<.+>)?$} [property get -system Name] {\1_1\2} ]; }}
}

proc _dwn_id {} {
	find all -scope selection -add -goto none -modify {if { [regexp {^(.+)_(\d+)(<.+>)?$} [property get -system Name] all name m ary ] } {; set m [expr $m-1];; property set -system Name -value ${name}_$m$ary; } else {; property set -system Name -value [regsub {^(.+?)_?(<.+>)?$} [property get -system Name] {\1_1\2} ]; }}
}

proc _up_bus {} {
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] all name m n] } {; incr m; incr n; property set -system Name -value $name<$m:$n>; } }
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+)>$} [property get -system Name] all name m ] } {; incr m; property set -system Name -value $name<$m>; } }
}

proc _dwn_bus {} {
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+):(\d+)>$} [property get -system Name] all name m n] } {; set m [expr $m-1]; set n [expr $n-1]; property set -system Name -value $name<$m:$n>; } }
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+)>$} [property get -system Name] all name m ] } {; set m [expr $m-1]; property set -system Name -value $name<$m>; } }
}

proc _rmv_bus {} {
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+):(-?\d+)>$} [property get -system Name] all name m n] } { property set -system Name -value $name; } }
}

proc _chop_bus {} {
	find all -scope selection -add -goto none -modify { if { [regexp {^(.*?)<(\d+):(-?\d+)>$} [property get -system Name] all name m n] } { property set -system Name -value $name<$m>; } }
}

proc _inout {} {
	find port -scope selection -add -goto none -modify {  if { [regexp {Right} [property get -system -name TextJustification.Horizontal] ] } { property set Type -system -value In  } ; if { [regexp {Left} [property get -system -name TextJustification.Horizontal] ] } { property set Type -system -value Out  } }
}

proc _up_ctxt { {up 1} } {
	upvar #0 schContext context
	if { [regexp {<(\d+)>([^<>]+)$} $context all m rest] } {
		set m [expr $m + $up]
		regsub {<(\d+)>([^<>]+)$} $context <$m>$rest context
	}
	puts $context
}

proc _dn_ctxt {} {
	_up_ctxt {-1}
}

proc _R_AC_togl {} {
	find instance -scope selection -add -goto none -modify {  if { [property get -name AC -host selections] < 11000 } { property set AC -value 1e12  } else { property set AC -value 100 } }
#    if { [property get -name AC -host selections] < 11000 } {
#		property set AC -value 1e12
#    } else {
#		property set AC -value 100
#    }
}

proc tgl_sel_mod {} {
    upvar #0 selmdfull mySel
    if $mySel {
		setup selection set -selectionmode partiallyenclosed
		set mySel false
    } else {
		setup selection set -selectionmode fullyenclosed
		set mySel true	
    }
}

proc go_to { context } {
	    upvar #0 schContext mycontext
		set mycontext $context
		user3
}
set canteen "dry"

#technology simulation set general -results C:/Temp
# above doesn't work because a design isn't open at this point. 
# more importantly, it generates an abort-error - so, whatever you
# put after this point, will not work!! Found the hard way :)


proc open_cell_from_note {} {

    # Read selected text label (may come back as word-list → join)
    set txt [property get Name -system]
    if {![llength $txt]} { return }
    set s [join $txt " "]

    # Look ONLY for  alphanumeric_or_underscore / alphanumeric_or_underscore
    # Example match: myLib/myCell
    set lib ""
    set cell ""
    if {![regexp {(\w+)/(\w+)} $s -> lib cell]} {
        return
    }

    # Try schematic first, then view0
    if {![catch {cell open $cell $lib schematic -activate}]} {
        return
    }
    if {![catch {cell open $cell $lib view0 -activate}]} {
        return
    }

    puts "Could not open cell '$cell' in library '$lib' (tried views: schematic, view0)."
}

proc select_similar_instances {} {

    # Require exactly one instance selected
    set sel [database instances -selected]
    if {[llength $sel] != 1} {
        return
    }

    # Get master library and master cell of the selected instance
    set libName  [property get -system -name MasterLibrary]
    set cellName [property get -system -name MasterCell]

    # Normalize in case the return is a 1-element list
    if {[llength $libName]  >= 1} { set libName  [lindex $libName  0] }
    if {[llength $cellName] >= 1} { set cellName [lindex $cellName 0] }

    # Basic sanity
    if {$libName eq "" || $cellName eq ""} {
        return
    }

    # Select all matching instances (add to selection)
    # Per your syntax: find instance -mastercell libName-masterdesign cellName -add
    find instance -mastercell $cellName -masterdesign $libName -add
}






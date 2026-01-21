

# AC
# workspace menu -name {Ananth {} }  -command {}
# workspace bindkeys -command {} -key ""
workspace bindkeys -command {Command Window} -key "1"
workspace bindkeys -command {Hide Docked Views} -key "Ctrl+F1"
workspace bindkeys -command {Highlight net} -key "9"
workspace bindkeys -command {Library Navigator} -key "Ctrl+F2"
workspace bindkeys -command {Snap to Grid} -key "Alt+G"
# workspace bindkeys -command {Pop Out} -key ​"Alt+Q" # trying to figure out why this doesn't work anymore
workspace bindkeys -command Properties -key "Q"
workspace bindkeys -command Fit -key "F"
workspace bindkeys -command Close -key "Ctrl+W"
workspace bindkeys -command {View} -key "Shift+X"
workspace bindkeys -command {Wire} -key "W"
workspace bindkeys -command {Save All Changes} -key "Ctrl+S"
workspace bindkeys -command {Net Label} -key "L"

workspace bindkeys -command {User 1} -key "Ctrl+G"
workspace bindkeys -command {User 2} -key "Ctrl+E"
workspace bindkeys -command {User 3} -key "Alt+X"
workspace bindkeys -command {User 4} -key "Alt+Down Arrow"
workspace bindkeys -command {User 5} -key "Alt+Up Arrow"
workspace bindkeys -command {User 6} -key "Ctrl+Num +"
workspace bindkeys -command {User 7} -key "Ctrl+Num -"
workspace bindkeys -command {User 8} -key "C"
workspace bindkeys -command {User 9} -key "M"
workspace bindkeys -command {Circle} -key {Ctrl+Alt+C}


workspace menu -name {Ananth R_AC_toggle}  -command {_R_AC_togl}
workspace bindkeys -command {R_AC_toggle} -key "Ctrl+R"

workspace menu -name {Ananth {Sel Mod Togl} }  -command {tgl_sel_mod}
workspace bindkeys -command {Sel Mod Togl} -key "Ctrl+M"

workspace menu -name {Ananth {pageID} }  -command {pageID}
workspace bindkeys -command {pageID} -key "Ctrl+Alt+I"

workspace menu -name {Ananth {Text Edit} }  -command {mul_text}
workspace bindkeys -command {Text Edit} -key "Ctrl+T"

workspace menu -name {Ananth {Useful Commands} {Prop Disp Togl} }  -command {mode -disppropeval toggle}
workspace bindkeys -command {Prop Disp Togl} -key "Ctrl+D"

workspace menu -name {Ananth {Useful Commands} {Clear Highlights} }  -command {puts "clearing highlights"; highlight -clear}
workspace bindkeys -command {Clear Highlights} -key "0"

workspace menu -name {ADDON {Useful Commands} {Mode Renderon} }  -command {puts "mode renderon"; mode renderon}
workspace bindkeys -command {Mode Renderon} -key "Ctrl+Alt+M"

workspace menu -name {Ananth {Simulations} {Plot Voltages} }  -command {mode crossprobev}
workspace bindkeys -command {Plot Voltages} -key "Alt+2"

workspace menu -name {Ananth {Simulations} {Plot Currents} }  -command {mode crossprobei}
workspace bindkeys -command {Plot Currents} -key "Ctrl+2"

workspace menu -name {Ananth {Useful Commands} {Open Scratch} }  -command {open_scratch}
workspace bindkeys -command {Open Scratch} -key "Ctrl+Alt+S"

workspace menu -name {Ananth {Useful Commands} {Reset Grid} }  -command {res_grid}
workspace bindkeys -command {Reset Grid} -key "Alt+R"

workspace menu -name {Ananth {Useful Commands} {None Selectable} }  -command {puts "allowselect none"; allowselect none}
workspace bindkeys -command {None Selectable} -key "Alt+N"

workspace menu -name {Ananth {Useful Commands} {All Selectable} }  -command {puts "allowselect all"; allowselect all}
workspace bindkeys -command {All Selectable} -key "Ctrl+Shift+A"

workspace menu -name {Ananth {Useful Commands} {Wires Selectable} }  -command {puts "allowselect shape wire"; allowselect shape wire}
workspace bindkeys -command {Wires Selectable} -key "Ctrl+Shift+W"

# workspace menu -name {Ananth {Useful Commands} {Render On} }  -command {puts "mode renderon"; mode renderon}
# S/R 2805926178 -- had to do button text as TCL approach
# workspace bindkeys -command {mode renderon} -key "Shift+R"
# also didn't work :(

workspace menu -name {Ananth {Useful Commands} {Execute Text Label} }  -command {puts [property get Name -system];eval [property get Name -system]}
workspace bindkeys -command {Execute Text Label} -key "Ctrl+Shift+E"

workspace menu -name {Ananth {Useful Commands} {Migrate to Iso} }  -command {mig_iso}

workspace menu -name {Ananth {Useful Commands} {Go To Text Label} }  -command {puts Navigating; go_to [property get Name -system] }
workspace bindkeys -command {Go To Text Label} -key "Ctrl+X"

workspace menu -name {Ananth {Useful Commands} {Arrow} }  -command {puts arrow; arrow }
workspace bindkeys -command {Arrow} -key "Ctrl+Alt+A"

workspace menu -name {Ananth {Useful Commands} {Remove Frame} }  -command {puts "removing frame"; setup schematicpage set -host view -framestyle none }
workspace bindkeys -command {Remove Frame} -key "Ctrl+Alt+Shift+F"

# simulation aids..

workspace menu -name {Ananth {Simulations} {Display Node V} }  -command {mode -propevalstyle voltage}
workspace bindkeys -command {Display Node V} -key "Ctrl+Alt+V"

workspace menu -name {Ananth {Simulations} {Display Terminal I} }  -command {mode -propevalstyle current}
workspace bindkeys -command {Display Terminal I} -key "Ctrl+I"

workspace menu -name {Ananth {Simulations} {Display Terminal I} }  -command {mode -propevalstyle current}
workspace bindkeys -command {Display Terminal I} -key "Ctrl+I"

workspace menu -name {Ananth {Simulations} {Send to Calculator} }  -command {mode crossprobev; mode -probeto calculator}
workspace bindkeys -command {Send to Calculator} -key "Alt+3"

workspace menu -name {Ananth {Simulations} {Send I to Calculator} }  -command {mode crossprobei; mode -probeto calculator}
workspace bindkeys -command {Send I to Calculator} -key "Ctrl+3"

workspace menu -name {Ananth {Simulations} {ONC18 Cryo} }  -command {_go_CRYO}

workspace menu -name {Ananth {Simulations} {ONC18 Room} }  -command {_go_ROOM}

# Bus

workspace menu -name {Ananth Bus {Bus 8 bit} }  -command {bus 8}

workspace menu -name {Ananth Bus Bussify }  -command {bussify}
workspace bindkeys -command Bussify -key "Ctrl+Shift+B"

workspace menu -name {Ananth Bus {Increment :N>} }  -command {inc_bus}
workspace bindkeys -command {Increment :N>} -key "Alt+Num +"

workspace menu -name {Ananth Bus {Decrement :N>} }  -command {dec_bus}
workspace bindkeys -command {Decrement :N>} -key "Alt+Num -"

workspace menu -name {Ananth Bus {Reverse Bus <M:N> -> <N:M>} }  -command {_rev_bus}
workspace bindkeys -command {Reverse Bus <M:N> -> <N:M>} -key "Ctrl+Alt+R"

workspace menu -name {Ananth Bus {Up Bus <M:N> -> <M+1:N+1>} }  -command {_up_bus}
workspace bindkeys -command {Up Bus <M:N> -> <M+1:N+1>} -key "Ctrl+Up Arrow"

workspace menu -name {Ananth Bus {Down Bus <M:N> -> <M-1:N-1>} }  -command {_dwn_bus}
workspace bindkeys -command {Down Bus <M:N> -> <M-1:N-1>} -key "Ctrl+Down Arrow"

workspace menu -name {Ananth Bus {Chop Bus <M:N> -> <M>} }  -command {_chop_bus}
workspace bindkeys -command {Chop Bus <M:N> -> <M>} -key "Ctrl+Shift+C"

workspace menu -name {Ananth Bus {Fracture Bus} }  -command {frac_bus}
workspace bindkeys -command {Fracture Bus} -key "Ctrl+Alt+F"

# Ports

workspace menu -name {Ananth Ports {Toggle Port NetLabel} }  -command {tgl_port_lbl}
workspace bindkeys -command {Toggle Port NetLabel} -key "Ctrl+Shift+T"

workspace menu -name {Ananth Ports {Fill Labels} }  -command {fill_labels}
workspace bindkeys -command {Fill Labels} -key "Ctrl+Shift+F"

workspace menu -name {Ananth Ports {Ports Bigger} }  -command {ports_bigger}
# workspace bindkeys -command {Ports Bigger} -key ""

workspace menu -name {Ananth Ports {Ports Smaller} }  -command {ports_smaller}
# workspace bindkeys -command {Ports Smaller} -key ""

workspace menu -name {Ananth Ports {Increment Pin Spacing} }  -command {inc_space}
workspace bindkeys -command {Increment Pin Spacing} -key "Ctrl+Shift+0"

workspace menu -name {Ananth Ports {Decrement Pin Spacing} }  -command {dec_space}
workspace bindkeys -command {Decrement Pin Spacing} -key "Ctrl+Shift+9"

# Wires

workspace menu -name {Ananth Wires {Stubs Hor+Ver Labels} }  -command {make_stubs}
workspace bindkeys -command {Stubs Hor+Ver Labels} -key "Ctrl+Space"

workspace menu -name {Ananth Wires {Stubs Hor-Only Labels} }  -command {h_stubs}
workspace bindkeys -command {Stubs Hor-Only Labels} -key "Shift+Space"

workspace menu -name {Ananth Wires {Fracture Comma Sep. Bus} }  -command {_fracture}
workspace bindkeys -command {Fracture Comma Sep. Bus} -key "Ctrl+Alt+B"

workspace menu -name {Ananth Wires {Install noConn} }  -command {no_conn}
workspace bindkeys -command {Install noConn} -key "Ctrl+Shift+N"



# AC
# workspace menu -name {CUSTOM {} }  -command {}
# workspace bindkeys -command {} -key ""
workspace bindkeys -command {Command Window} -key "1"
workspace bindkeys -command {Hide Docked Views} -key "Ctrl+F1"
workspace bindkeys -command {Highlight net} -key "9"
workspace bindkeys -command {Library Navigator} -key "Ctrl+F2"
workspace bindkeys -command {Snap to Grid} -key "Alt+G"
workspace bindkeys -command {Pop Out} -key "Alt+Q"
workspace bindkeys -command Properties -key "Q"
workspace bindkeys -command Fit -key "F"
workspace bindkeys -command Close -key "Ctrl+W"
workspace bindkeys -command {View} -key "Shift+X"
workspace bindkeys -command {Wire} -key "W"
workspace bindkeys -command {Save All Changes} -key "Ctrl+S"
workspace bindkeys -command {Net Label} -key "L"

workspace bindkeys -command {User 1} -key "Ctrl+G"
workspace bindkeys -command {User 2} -key "Ctrl+E"
workspace bindkeys -command {User 3} -key "Alt+X"
workspace bindkeys -command {User 4} -key "Alt+Up Arrow"
workspace bindkeys -command {User 5} -key "Alt+Down Arrow"
workspace bindkeys -command {User 6} -key "Ctrl+Num +"
workspace bindkeys -command {User 7} -key "Ctrl+Num -"
workspace bindkeys -command {User 8} -key "C"
workspace bindkeys -command {User 9} -key "M"


workspace menu -name {CUSTOM R_AC_toggle}  -command {_R_AC_togl}
workspace bindkeys -command {R_AC_toggle} -key "Ctrl+R"

workspace menu -name {CUSTOM {Sel Mod Togl} }  -command {tgl_sel_mod}
workspace bindkeys -command {Sel Mod Togl} -key "Ctrl+M"

workspace menu -name {CUSTOM {pageID} }  -command {pageID}
workspace bindkeys -command {pageID} -key "Ctrl+Alt+I"

workspace menu -name {CUSTOM {Text Edit} }  -command {mul_text}
workspace bindkeys -command {Text Edit} -key "Ctrl+T"

workspace menu -name {CUSTOM {Useful Commands} {Prop Disp Togl} }  -command {mode -disppropeval toggle}
workspace bindkeys -command {Prop Disp Togl} -key "Ctrl+D"

workspace menu -name {CUSTOM {Simulations} {Plot Voltages} }  -command {mode crossprobev}
workspace bindkeys -command {Plot Voltages} -key "Alt+2"

workspace menu -name {CUSTOM {Simulations} {Plot Currents} }  -command {mode crossprobei}
workspace bindkeys -command {Plot Currents} -key "Ctrl+2"

workspace menu -name {CUSTOM {Useful Commands} {Open Scratch} }  -command {open_scratch}
workspace bindkeys -command {Open Scratch} -key "Ctrl+Alt+S"

workspace menu -name {CUSTOM {Useful Commands} {Reset Grid} }  -command {res_grid}
workspace bindkeys -command {Reset Grid} -key "Alt+R"

workspace menu -name {CUSTOM {Useful Commands} {None Selectable} }  -command {puts "allowselect none"; allowselect none}
workspace bindkeys -command {None Selectable} -key "Alt+N"

workspace menu -name {CUSTOM {Useful Commands} {All Selectable} }  -command {puts "allowselect all"; allowselect all}
workspace bindkeys -command {All Selectable} -key "Ctrl+Shift+A"

workspace menu -name {CUSTOM {Useful Commands} {Wires Selectable} }  -command {puts "allowselect shape wire"; allowselect shape wire}
workspace bindkeys -command {Wires Selectable} -key "Ctrl+Shift+W"

# workspace menu -name {CUSTOM {Useful Commands} {Render On} }  -command {puts "mode renderon"; mode renderon}
# S/R 2805926178 -- had to do button text as TCL approach
# workspace bindkeys -command {mode renderon} -key "Shift+R"
# also didn't work :(

workspace menu -name {CUSTOM {Useful Commands} {Execute Text Label} }  -command {puts [property get Name -system];eval [property get Name -system]}
workspace bindkeys -command {Execute Text Label} -key "Ctrl+Shift+E"

workspace menu -name {CUSTOM {Useful Commands} {Migrate to Iso} }  -command {mig_iso}

workspace menu -name {CUSTOM {Useful Commands} {Go To Text Label} }  -command {puts Navigating; go_to [property get Name -system] }
workspace bindkeys -command {Go To Text Label} -key "Ctrl+X"

workspace menu -name {CUSTOM {Useful Commands} {Pop} }  -command {pop}
workspace bindkeys -command {Pop} -key "Alt+Q"

workspace menu -name {CUSTOM {Useful Commands} {Push} }  -command {push}
workspace bindkeys -command {Push} -key "Ctrl+X"

# simulation aids..

workspace menu -name {CUSTOM {Simulations} {Display Node V} }  -command {mode -propevalstyle voltage}
workspace bindkeys -command {Display Node V} -key "Ctrl+Alt+V"

workspace menu -name {CUSTOM {Simulations} {Display Terminal I} }  -command {mode -propevalstyle current}
workspace bindkeys -command {Display Terminal I} -key "Ctrl+I"

workspace menu -name {CUSTOM {Simulations} {Display Terminal I} }  -command {mode -propevalstyle current}
workspace bindkeys -command {Display Terminal I} -key "Ctrl+I"

workspace menu -name {CUSTOM {Simulations} {Send to Calculator} }  -command {mode crossprobev; mode -probeto calculator}
workspace bindkeys -command {Send to Calculator} -key "Alt+3"

workspace menu -name {CUSTOM {Simulations} {Send I to Calculator} }  -command {mode crossprobei; mode -probeto calculator}
workspace bindkeys -command {Send I to Calculator} -key "Ctrl+3"

workspace menu -name {CUSTOM {Simulations} {ONC18 Cryo} }  -command {_go_CRYO}

workspace menu -name {CUSTOM {Simulations} {ONC18 Room} }  -command {_go_ROOM}

# Bus

workspace menu -name {CUSTOM Bus {Bus 8 bit} }  -command {bus 8}

workspace menu -name {CUSTOM Bus Bussify }  -command {bussify}
workspace bindkeys -command Bussify -key "Ctrl+Shift+B"

workspace menu -name {CUSTOM Bus {Increment :N>} }  -command {inc_bus}
workspace bindkeys -command {Increment :N>} -key "Alt+Num +"

workspace menu -name {CUSTOM Bus {Decrement :N>} }  -command {dec_bus}
workspace bindkeys -command {Decrement :N>} -key "Alt+Num -"

workspace menu -name {CUSTOM Bus {Reverse Bus <M:N> -> <N:M>} }  -command {_rev_bus}
workspace bindkeys -command {Reverse Bus <M:N> -> <N:M>} -key "Ctrl+Alt+R"

workspace menu -name {CUSTOM Bus {Up Bus <M:N> -> <M+1:N+1>} }  -command {_up_bus}
workspace bindkeys -command {Up Bus <M:N> -> <M+1:N+1>} -key "Ctrl+Up Arrow"

workspace menu -name {CUSTOM Bus {Down Bus <M:N> -> <M-1:N-1>} }  -command {_dwn_bus}
workspace bindkeys -command {Down Bus <M:N> -> <M-1:N-1>} -key "Ctrl+Down Arrow"

workspace menu -name {CUSTOM Bus {Chop Bus <M:N> -> <M>} }  -command {_chop_bus}
workspace bindkeys -command {Chop Bus <M:N> -> <M>} -key "Ctrl+Shift+C"

workspace menu -name {CUSTOM Bus {Fracture Bus} }  -command {_frac_bus}
workspace bindkeys -command {Fracture Bus} -key "Ctrl+Alt+F"

# Ports

workspace menu -name {CUSTOM Ports {Toggle Port NetLabel} }  -command {tgl_port_lbl}
workspace bindkeys -command {Toggle Port NetLabel} -key "Ctrl+Shift+T"

workspace menu -name {CUSTOM Ports {Fill Labels} }  -command {fill_labels}
workspace bindkeys -command {Fill Labels} -key "Ctrl+Shift+F"

workspace menu -name {CUSTOM Ports {Ports Bigger} }  -command {ports_bigger}
# workspace bindkeys -command {Ports Bigger} -key ""

workspace menu -name {CUSTOM Ports {Ports Smaller} }  -command {ports_smaller}
# workspace bindkeys -command {Ports Smaller} -key ""

workspace menu -name {CUSTOM Ports {Increment Pin Spacing} }  -command {inc_space}
workspace bindkeys -command {Increment Pin Spacing} -key "Ctrl+Shift+0"

workspace menu -name {CUSTOM Ports {Decrement Pin Spacing} }  -command {dec_space}
workspace bindkeys -command {Decrement Pin Spacing} -key "Ctrl+Shift+9"

# Wires

workspace menu -name {CUSTOM Wires {Stubs Hor+Ver Labels} }  -command {make_stubs}
workspace bindkeys -command {Stubs Hor+Ver Labels} -key "Ctrl+Space"

workspace menu -name {CUSTOM Wires {Stubs Hor-Only Labels} }  -command {h_stubs}
workspace bindkeys -command {Stubs Hor-Only Labels} -key "Shift+Space"

workspace menu -name {CUSTOM Wires {Fracture Comma Sep. Bus} }  -command {_fracture}
workspace bindkeys -command {Fracture Comma Sep. Bus} -key "Ctrl+Alt+B"

workspace menu -name {CUSTOM Wires {Install noConn} }  -command {no_conn}
workspace bindkeys -command {Install noConn} -key "Ctrl+Shift+N"




​

set schContext ""
set viewContext [list]    ;# empty list
set special_fn 0	;# user must explicitly set to 1 for bindkey running User10 to have effect
set selmdfull true	;#  for fully enclosed only added

proc user10 {} {
    upvar #0 special_fn chkval
    if $chkval {
	# run these commands
    } else {
		puts "Please explicitly set the variable 'special_fn' to 1" 
    }
}

proc scale_snap_grid { factor } {
	set newg [expr { ( [setup schematicgrid get -snapgridsize] ) * $factor / 1000 } ]
	puts "setting grid to $newg"
	setup schematicgrid set -snapgridsize $newg
	puts "to reset do\nsetup schematicgrid set -snapgridsize 0.1\n"
}

proc res_grid {} {
	setup schematicgrid set -snapgridsize 0.1
	puts "setting grid to 0.1"
}

# updated 6/10/2015 to handle selections.. # then 6/25/2015 to be able to get instant undo
proc scale_text { up } {
	find port -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
	find netlabel -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
	find textlabel -scope selection -add -goto none -regex -modify {property set FontSize -system -units iu -value [expr (1.1**$up)*([property get FontSize -system]) ]}
}

proc user2 {} {
    ;# also need to exit WITHOUT doing anything in the case that the user accidentally
    ;# hit CTRL-E when already at top-level, else you mess up schContext
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
    set context [join $b "/"]    ;# now we've captured the context
	set tpc [workspace getactive -toplevel_cell]
	set dsn [workspace getactive -toplevel_design]
	set vu [workspace getactive -toplevel_view]

    ;# now for the difficult business of single stepping from deep to top-level
    ;# a workaround for preserving net highlighting..
    mode renderoff
    set depth [expr {$depth -1 } ]
    while { $depth } {
        set b [lreplace $b $depth $depth]
;#        cell open -cell [workspace getactive -toplevel_cell] -design [workspace getactive -toplevel_design] -type schematic -view [lindex $viewL [expr $depth -1 ] ] -context [join $b "/"]  -tracenets
;# 7/13/2015 - put back -view view0 - had trouble with the CPD_ADC_sim when using model vw_ideal_mdl.. :(
		set cxt [join $b "/"]
#		puts "cell open -cell  $tpc -design $dsn -type schematic -view $vu -context $cxt  -tracenets"
		cell open -cell $tpc -design $dsn -type schematic -view $vu -context $cxt  -tracenets
;# 7/10/2015 - took out -view..
#		set vu [lindex $viewL [expr $depth -1 ] ]
#;#        cell open -cell [workspace getactive -toplevel_cell] -design [workspace getactive -toplevel_design] -type schematic -context [join $b "/"]  -tracenets
#        puts "cell open -cell $tpc -design $dsn -type schematic -view $vu -context $cxt  -tracenets"
#		cell open -cell  $tpc -design $dsn -type schematic -view $vu -context $cxt  -tracenets
        set depth [expr {$depth -1 } ]
    }

#    cell open -cell [workspace getactive -toplevel_cell] -design [workspace getactive -toplevel_design] -type schematic -tracenets
#	puts "cell open -cell  $tpc -design $dsn -type schematic -view $vu -tracenets"
    cell open -cell $tpc -design $dsn -type schematic -view $vu -tracenets
;# 7/13/2015 - put in -view view0
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
	scale_snap_grid { 2.0 }
# suggest ALT Up-Arrow
# workspace bindkey -key {Alt+Up Arrow} -command {User 5}
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
	copy
	paste
	mode place -forcemove on
}

proc user9 {} {
	copy
	delete
	paste
	mode place -forcemove on
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

technology simulation set general -results C:/Temp
# above doesn't work because a design isn't open at this point. 
# more importantly, it generates an abort-error - so, whatever you
# put after this point, will not work!! Found the hard way :)


proc pop {} {
    find none

    # Get and normalize context
    set ctx [workspace getactive -context]
    if {![llength $ctx]} { return }

    # Normalize single-level case into list-of-records
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    set depth [llength $ctx]
    if {$depth <= 1} {
        # Already at top or only one level down → go to top
        mode renderoff
        set tpc [workspace getactive -toplevel_cell]
        set dsn [workspace getactive -toplevel_design]
        set vu  [workspace getactive -toplevel_view]
        cell open -cell $tpc -design $dsn -type schematic -view $vu
        mode renderon
        return
    }

    # Build instance path excluding the last level
    set b [list]
    for {set i 0} {$i < $depth-1} {incr i} {
        set el [lindex $ctx $i]
        lappend b [lindex $el end]
    }

    set cxt [join $b "/"]

    # Reopen one level up
    set tpc [workspace getactive -toplevel_cell]
    set dsn [workspace getactive -toplevel_design]
    set vu  [workspace getactive -toplevel_view]

    mode renderoff
    cell open \
        -cell   $tpc \
        -design $dsn \
        -type   schematic \
        -view   $vu \
        -context $cxt \
        -tracenets
    mode renderon
}

proc push {} {

    # Read selection FIRST (do NOT clear it)
    set sel [database instances -selected]

    if {[llength $sel] != 1} {
        return
    }

    set iname [lindex $sel 0]

    # Handle bussed instances: foo<4:0> → foo<4>
    if {[regexp {^(.*)<([0-9]+):([0-9]+)>$} $iname -> base i1 i2]} {
        set iname "${base}<${i1}>"
    }

    # Get and normalize current context
    set ctx [workspace getactive -context]
    if {[llength $ctx] == 4 && [llength [lindex $ctx 0]] == 1} {
        set ctx [list $ctx]
    }

    # Build current instance path
    set parts [list]
    foreach el $ctx {
        lappend parts [lindex $el end]
    }

    # Descend into selected instance
    lappend parts $iname
    set newCxt [join $parts "/"]

    # Anchor at top-level
    set tpc [workspace getactive -toplevel_cell]
    set dsn [workspace getactive -toplevel_design]
    set vu  [workspace getactive -toplevel_view]

    mode renderoff
    cell open \
        -cell    $tpc \
        -design  $dsn \
        -type    schematic \
        -view    $vu \
        -context $newCxt \
        -tracenets
    mode renderon
}

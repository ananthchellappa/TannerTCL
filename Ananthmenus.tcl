# # AC
# # workspace menu -name {CUSTOM {} }  -command {}
# # workspace bindkeys -command {} -key ""
workspace bindkeys -command {Command Window} -key "1"
workspace bindkeys -command {Hide Docked Views} -key "Ctrl+F1"
workspace bindkeys -command {Highlight net} -key "9"
workspace bindkeys -command {Library Navigator} -key "Ctrl+F2"
workspace bindkeys -command {Snap to Grid} -key "Alt+G"
# workspace bindkeys -command {Pop Out} -key "Alt+Q"
workspace bindkeys -command Properties -key "Q"
workspace bindkeys -command Fit -key "F"
# workspace bindkeys -command Close -key "Ctrl+W" # doesn't work in undocked..
workspace bindkeys -command {View} -key "Shift+X"
workspace bindkeys -command {Wire} -key "W"
workspace bindkeys -command {Save All Changes} -key "Ctrl+S"
workspace bindkeys -command {Net Label} -key "L"
workspace bindkeys -command {Text Label} -key "T"

workspace bindkeys -command {User 1} -key "Alt+D"
# to get toggle docked working - using TCL (not perfect)
workspace bindkeys -command {User 2} -key "Ctrl+E"
workspace bindkeys -command {User 3} -key "Alt+X"
workspace bindkeys -command {User 4} -key "Alt+Down Arrow"
workspace bindkeys -command {User 5} -key "Ctrl+Alt+S"
workspace bindkeys -command {User 6} -key "Ctrl+Num +"
workspace bindkeys -command {User 7} -key "Ctrl+Num -"
workspace bindkeys -command {User 8} -key "Ctrl+X"
workspace bindkeys -command {User 9} -key "Alt+Q"
workspace bindkeys -command {User 10} -key "Ctrl+W"
workspace bindkeys -command {Circle} -key {Ctrl+Alt+C}
# workspace bindkeys -command {SPICE Simulation} -key {Ctrl+Shift+S} # hack 1/14/26 remove AC


if { [ regexp {\s16.3} [workspace version] ]  } { 
#	workspace bindkeys -command {Pop Out} -key "Alt+Q"
	} else {
#	workspace bindkeys -command {Pop context} -key {Alt+Q}
	}



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

workspace menu -name {CUSTOM {Useful Commands} {Clear Highlights} }  -command {highlight -allviews -clear}
workspace bindkeys -command {Clear Highlights} -key "0"

workspace menu -name {CUSTOM {Useful Commands} {Mode Renderon} }  -command {puts "mode renderon"; mode renderon}
workspace bindkeys -command {Mode Renderon} -key "Ctrl+Alt+M"

workspace menu -name {CUSTOM {Simulations} {Plot Voltages} }  -command {mode crossprobev}
workspace bindkeys -command {Plot Voltages} -key "Alt+2"

workspace menu -name {CUSTOM {Simulations} {Plot Currents} }  -command {mode crossprobei}
workspace bindkeys -command {Plot Currents} -key "Ctrl+2"

workspace menu -name {CUSTOM {Useful Commands} {Open Scratch} }  -command {open_scratch}
workspace bindkeys -command {Open Scratch} -key "Ctrl+Alt+Shift+S"

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

workspace menu -name {CUSTOM {Useful Commands} {Bookmark or Follow} }  -command {bookmark_or_follow }
workspace bindkeys -command {Bookmark or Follow} -key "Ctrl+Alt+D"

workspace menu -name {CUSTOM {Useful Commands} {Arrow} }  -command {puts arrow; arrow }
workspace bindkeys -command {Arrow} -key "Ctrl+Alt+A"

workspace menu -name {CUSTOM {Useful Commands} {Remove Frame} }  -command {puts "removing frame"; setup schematicpage set -host view -framestyle none }
workspace bindkeys -command {Remove Frame} -key "Ctrl+Alt+Shift+F"

# workspace menu -name {CUSTOM {Useful Commands} {Capture WMF} }  -command {puts "window capture.. wmf"; window capture -format bwmetafile -file {C:\Users\Ananth.Chellappa\Desktop\junk\Tanner\test_capture.wmf} }
# workspace bindkeys -command {Capture WMF} -key "Ctrl+Alt+Shift+C"
# retired - doesn't work anymore. Just dump to PDF from now on..

workspace menu -name {CUSTOM {Useful Commands} {Goto Change Circle} }  -command {browse_change_circles}
workspace bindkeys -command {Goto Change Circle} -key "Ctrl+Alt+Shift+C"

# workspace menu -name {CUSTOM {Useful Commands} {Pop} }  -command {pop}
# workspace bindkeys -command {Pop} -key "Alt+Q"

# workspace menu -name {CUSTOM {Useful Commands} {Push} }  -command {push}
# workspace bindkeys -command {Push} -key "Ctrl+X"

workspace menu -name {CUSTOM {Useful Commands} {Toggle ToolTip} }  -command {toggleDynamicTooltip}
workspace bindkeys -command {Toggle ToolTip} -key "Ctrl+Alt+Shift+T"

# workspace menu -name {CUSTOM {Useful Commands} {Find in Lib Navigator} }  -command {librarynavigator select_in_lib_navigator}
# workspace menu -name {CUSTOM {Useful Commands} {Find in Lib Navigator} }  -command {select_in_libnav_from_selection_or_active}
# workspace bindkeys -command {Find in Lib Navigator} -key "Ctrl+Alt+S"
# 4/4/26 - need this to work in undocked..

workspace menu -name {CUSTOM {Useful Commands} {Open Cell from Note} }  -command {open_cell_from_note }
workspace bindkeys -command {Open Cell from Note} -key "Ctrl+Shift+N"

workspace menu -name {CUSTOM {Useful Commands} {Select Similar} }  -command {select_similar_instances }
workspace bindkeys -command {Select Similar} -key "Ctrl+Alt+H"

workspace menu -name {CUSTOM {Useful Commands} {Print Lib/Cell} }  -command {print_libcell_from_selection_or_active}
workspace bindkeys -command {Print Lib/Cell} -key "Alt+Shift+C"

workspace menu -name {CUSTOM {Useful Commands} {Update View Name} }  -command {update_view_name}
workspace bindkeys -command {Update View Name} -key "Ctrl+Shift+S"

# workspace menu -name {CUSTOM {Window} {Close Window} }  -command {window close}
# workaround for {Close} not working in undocked, but stopped after putting in CTRL-X,ALT-Q through user 8,9
# workspace bindkeys -command {Close Window} -key "Ctrl+W"

workspace menu -name {CUSTOM {Useful Commands} {My Copy} }  -command {my_copy}
workspace bindkeys -command {My Copy} -key "C"

workspace menu -name {CUSTOM {Useful Commands} {My Move} }  -command {my_move}
workspace bindkeys -command {My Move} -key "M"

workspace menu -name {CUSTOM {Useful Commands} {Toggle Grid} }  -command {toggle_grid}
workspace bindkeys -command {Toggle Grid} -key "Ctrl+G"

workspace menu -name {CUSTOM {Useful Commands} {Delete Circles} }  -command {puts "nuking circles"; find circle -goto none; delete}
workspace bindkeys -command {Delete Circles} -key "Ctrl+Shift+D"

workspace menu -name {CUSTOM {Useful Commands} {Increase snap grid} }  -command {scale_snap_grid { 2.0 }}
workspace bindkeys -command {Increase snap grid} -key "Alt+Up Arrow"

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

workspace menu -name {CUSTOM {Simulations} {Print i Cmd} }  -command {i_print}
workspace bindkeys -command {Print i Cmd} -key "Ctrl+Alt+Shift+I"

workspace menu -name {CUSTOM {Simulations} {OP Info Summary} }  -command {puts [mos_op_summary_for_selected]}
workspace bindkeys -command {OP Info Summary} -key "Ctrl+Alt+1"


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

workspace menu -name {CUSTOM Bus {Fracture Bus} }  -command {frac_bus}
workspace bindkeys -command {Fracture Bus} -key "Ctrl+Alt+F"

# Ports

workspace menu -name {CUSTOM Ports {Toggle Port NetLabel} }  -command {tgl_port_lbl}
workspace bindkeys -command {Toggle Port NetLabel} -key "Ctrl+Shift+T"

workspace menu -name {CUSTOM Ports {Fill Labels} }  -command {add_port_labels}

workspace bindkeys -command {Fill Labels} -key "Ctrl+Shift+F"
workspace menu -name {CUSTOM Ports {make pins} }  -command {make_pins}
workspace menu -name {CUSTOM Ports {Ports Bigger} }  -command {ports_bigger}
# workspace bindkeys -command {Ports Bigger} -key ""

workspace menu -name {CUSTOM Ports {Ports Smaller} }  -command {ports_smaller}
# workspace bindkeys -command {Ports Smaller} -key ""

workspace menu -name {CUSTOM Ports {Increment Pin Spacing} }  -command {respace_selected_ports 1.2}
workspace bindkeys -command {Increment Pin Spacing} -key "Ctrl+Shift+Num +"

workspace menu -name {CUSTOM Ports {Decrement Pin Spacing} }  -command {respace_selected_ports 0.8}
workspace bindkeys -command {Decrement Pin Spacing} -key "Ctrl+Shift+Num -"

workspace menu -name {CUSTOM Ports {List CSV} }  -command {list_ports_csv}

workspace menu -name {CUSTOM Ports {Equalize Labels and Ports} }  -command {clean_selected_labels_to_nearest_ports}
workspace bindkeys -command {Equalize Labels and Ports} -key "Ctrl+Alt+L"

workspace menu -name {ADDON Ports {Cycle Port/Netlabel Next} }  -command {cycle_port_or_netlabel}
workspace bindkeys -command {Cycle Port/Netlabel Next} -key "Ctrl+Shift+Up Arrow"

workspace menu -name {ADDON Ports {Cycle Port/Netlabel Prev} }  -command {cycle_port_or_netlabel 0}
workspace bindkeys -command {Cycle Port/Netlabel Prev} -key "Ctrl+Shift+Down Arrow"

workspace menu -name {CUSTOM Ports {Sync Bus Widths to Schematic} }  -command {sync_symbol_port_bus_widths_to_schematic}

workspace menu -name {CUSTOM Ports {Incr Port Index} }  -command {txpose_port_index}
workspace bindkeys -command {Incr Port Index} -key "Alt+Page Up"

workspace menu -name {CUSTOM Ports {Decr Port Index} }  -command {txpose_port_index -1}
workspace bindkeys -command {Decr Port Index} -key "Alt+Page Down"

# Wires

workspace menu -name {CUSTOM Wires {Stubs Hor+Ver Labels} }  -command {make_stubs}
workspace bindkeys -command {Stubs Hor+Ver Labels} -key "Ctrl+Space"

workspace menu -name {CUSTOM Wires {Stubs Hor-Only Labels} }  -command {h_stubs}
workspace bindkeys -command {Stubs Hor-Only Labels} -key "Shift+Space"

workspace menu -name {CUSTOM Wires {Make stubs} }  -command {draw addwirestubs -wirelength 3 -fontsize 7pt }
workspace bindkeys -command {Make stubs} -key "Space"

workspace menu -name {CUSTOM Wires {Fracture Comma Sep. Bus} }  -command {_fracture}
workspace bindkeys -command {Fracture Comma Sep. Bus} -key "Ctrl+Alt+B"

workspace menu -name {CUSTOM Wires {Install noConn} }  -command {no_conn}
workspace bindkeys -command {Install noConn} -key "Ctrl+Alt+N"

workspace menu -name {CUSTOM Wires {Highlight} }  -command {hl_sel_netlabel}
workspace bindkeys -command {Highlight} -key "7"

workspace menu -name {CUSTOM Wires {Set Hilite Colors} }  -command {highlight -default {blue gold red brown pink yellow magenta lemon purple}}
workspace bindkeys -command {Set Hilite Colors} -key "Ctrl+9"

workspace menu -name {CUSTOM Cell {Rename to symbol} }  -command {rename_current_view_to_symbol_review}

workspace menu -name {CUSTOM Cell {Rename view} }  -command {rename_current_view_prompt_newname}

workspace menu -name {CUSTOM Cell {Copy Cell} }  -command {copy_current_cell_dialog}

workspace menu -name {CUSTOM Cell {Make Array Uniform} }  -command {make_selected_array_uniform}

workspace menu -name {CUSTOM Cell {Name Array Instances} }  -command {name_selected_array_instances}

workspace menu -name {CUSTOM Cell {Re-instantiate selected} }  -command {re_place_selected_instances}
workspace bindkeys -command {Re-instantiate selected} -key "Ctrl+Alt+Shift+R"

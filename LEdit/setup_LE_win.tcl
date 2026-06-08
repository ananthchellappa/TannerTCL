source C:/Users/USERNAME/Documents/SiemensEDA/CustomIC_2026.1/FeaturesByTool/L-Edit/BindKeys/ledit_bindkeys_3rdParty_compatability.tcl; # to get Cadence bindkeys (worth reading through that file once)
# Edit out the Nibble command - it doesn't exist

workspace bindkeys -command {Window Close} -key "Ctrl+W"
workspace bindkeys -command {Command Window} -key "1"
workspace bindkeys -command {Command Window} -key "Alt+4"


workspace bindkeys -command FlipHorizontal -delete
workspace bindkeys -command FlipHorizontal -key H

workspace bindkeys -command FlipVertical -delete
workspace bindkeys -command FlipVertical -key V

workspace bindkeys -command {Edit Object(s)} -delete
workspace bindkeys -command {Edit Object(s)} -key Q

workspace bindkeys -command Rotate -delete
workspace bindkeys -command Rotate -key Shift+R


workspace bindkeys -command {Orthogonal Wire} -delete
workspace bindkeys -command {Orthogonal Wire} -key W

workspace bindkeys -command {Home View} -key "F"
workspace bindkeys -command {Find Next} -key "Shift+F"

workspace bindkeys -command {Hide Docked Views} -key Ctrl+F1

proc DismissMarkers {} {
	puts "Clearing markers";LCell_RemoveAllMarkers [workspace getactive -cell]
	# thank you Mark Forsythe
}

workspace menu -name {ADDON {Dismiss Markers}} -command {DismissMarkers}
workspace bindkeys -command {DismissMarkers} -key "Shift+K"

workspace menu -name {ADDON {SDL Extract Connectivity}}  -command {LSDL_ExtractConnectivity}
workspace bindkeys -command {LSDL_ExtractConnectivity} -key "Shift+X"


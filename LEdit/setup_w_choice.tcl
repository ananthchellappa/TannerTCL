
proc bind_dismiss_markers_after_design_open {} {
    package require Tk

    set answer [tk_messageBox \
        -title "Open Design First" \
        -message "Press OK only after a design has been opened" \
        -type okcancel \
        -default ok \
        -icon info]

    if {$answer eq "ok"} {
        workspace bindkeys -command {Dismiss Markers} -key "Shift+K"
        workspace bindkeys -command {SDL Extract Connectivity} -key "Shift+X"
    }
}

set answer [tk_messageBox \
    -title "Load Bindkeys" \
    -message "Click OK to load Ananth's bindkeys." \
    -type okcancel \
    -icon question]

if {$answer eq "ok"} {
  source /home/$USER/SiemensEDA/CustomIC_$VERSION/FeaturesByTool/L-Edit/BindKeys/ledit_bindkeys_3rdParty_compatability.tcl; # to get Cadence bindkeys (worth reading through that file once)
  
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
  
  puts "Run manually:\nworkspace bindkeys -command {Dismiss Markers} -key \"Shift+K\""
  workspace menu -name {ADDON {Dismiss Markers}}  -command {puts "Clearing markers";LCell_RemoveAllMarkers [workspace getactive -cell]}
  workspace menu -name {ADDON {SDL Extract Connectivity}}  -command {LSDL_ExtractConnectivity}

  bind_dismiss_markers_after_design_open
}


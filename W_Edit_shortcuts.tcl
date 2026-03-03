workspace bindkeys -command {Hide Docked Views} -key "Ctrl+F1"
workspace bindkeys -command {Command Window} -key "1"
workspace bindkeys -command Fit -key "F"
workspace bindkeys -command {New Chart} -key "Ctrl+N"
workspace bindkeys -command {Draw Labeled Marker} -key "M"
workspace bindkeys -command {Close Chart} -key "Ctrl+W"


# workspace menu -name {ADDON {Chart} {New Chart Win} }  -command {chart new -analysis Transient -newwindow}
# workspace bindkeys -command {New Chart Win} -key "Ctrl+N"

proc New_Win {} {
    chart new -analysis Transient -newwindow
}
# having done this, now, right click on blank portion of the toolbar and choose customize
# then, change to the Commands tab and, in the left pane (Categories), scroll down and select "Custom"
# in the right pane, click on "Excecute button text as TCL" and drag that onto the toolbar
# Then, you can right-click on the new button and use the drop-down to edit the "Execute button text.." to
# be New_Win. Now, you can press ALT-N to get a new Window

# proc user1 {} {
    # upvar #0 gridOn myGO
    # if $myGO {
		# setup schematicgrid set -units iu -majorgriddisplayed false 	
		# setup schematicgrid set -units iu -minorgriddisplayed false 
	# set myGO false
    # } else {
		# setup schematicgrid set -units iu -majorgriddisplayed true 
        # setup schematicgrid set -units iu -minorgriddisplayed true 
	# set myGO true	
    # }
# }

# set gridOn true

if {![info exists gridOn]} {
    set gridOn true
}

proc toggle_grid {} {
  # Use 'variable' to declare that 'gridOn' is a global variable
  # within the scope of this procedure. This is generally preferred
  # over 'upvar #0' for global variables as it's clearer and often
  # avoids unexpected behavior with some Tcl interpreters.
  variable gridOn

  if {$gridOn} {
    setup schematicgrid set -units iu -majorgriddisplayed false
    setup schematicgrid set -units iu -minorgriddisplayed false
    set gridOn false
  } else {
    setup schematicgrid set -units iu -majorgriddisplayed true
    setup schematicgrid set -units iu -minorgriddisplayed true
    set gridOn true
  }
}

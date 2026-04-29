proc re_place_selected_instances {} {

    # Snapshot the selected instance names first, before deleting/recreating anything.
    set instNames [database instances -selected]

    if {[llength $instNames] == 0} {
        puts "No instances selected."
        return
    }

	mode renderoff
    foreach name $instNames {

        # Select exactly this instance.
        find instance -name $name -goto none

        # Capture properties before delete.
        set libraryName [property get -name MasterLibrary -system]
        set cellName    [property get -name MasterCell    -system]
        set x           [property get -name X             -system]
        set y           [property get -name Y             -system]
        set mirror      [property get -name Mirror        -system]
        set angle       [property get -name Angle         -system]

        puts "Re-placing instance $name : $libraryName/$cellName at ($x,$y), Mirror=$mirror, Angle=$angle"

        # Delete the original instance.
        delete

        # Place the same symbol cell at the same location.
        instance -cell $cellName -library $libraryName -view symbol

        mode draw instance
        point click -x $x -y $y -units iu
        mode escape

        # Restore original instance properties.
        property set -name Name   -value $name   -system
        property set -name Mirror -value $mirror -system
        property set -name Angle  -value $angle  -system
		property set -name X  -value $x  -system
		property set -name Y  -value $y  -system
    }
	mode renderon
}

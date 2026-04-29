proc re_place_selected_instances {} {

    set instNames [database instances -selected]

    if {[llength $instNames] == 0} {
        puts "No instances selected."
        return
    }
	mode renderoff
    foreach name $instNames {

        find instance -name [list $name] -goto none

        set libraryName [property get -name MasterLibrary -system]
        set cellName    [property get -name MasterCell    -system]
        set x           [property get -name X             -system]
        set y           [property get -name Y             -system]

        puts "Re-placing instance $name : $libraryName/$cellName at ($x,$y)"

        delete

        instance -cell $cellName -library $libraryName -view symbol

        mode draw instance
        point click -x $x -y $y -units iu
        mode escape

        property set -name Name -value $name -system
		property set -name X -value $x -system
		property set -name Y -value $y -system
    }
	mode renderon
}

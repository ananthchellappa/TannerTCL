# usually, you can make the property form useful by setting the switch to only display visible (displayed on schematic) properties
# if not working, a workaround might be to "edit" (found that get/set - no change - is actually good enough)
# that's what this proc does with the selected devices. Extra credit : can you make sure it only processes instances if the cell name contains "fet"? :)

proc make_NEWPDK_FET_params_visible {} {
	find instance -scope selection -goto none -modify {if {"NEWPDK" eq [property get -name MasterLibrary -system]} {; property set m  -value [property get m]  -docallback; property set nf -value [property get nf] -docallback; property set l  -value [property get l]  -docallback; property set wt -value [property get wt] -docallback; property set wf -value [property get wf] -docallback; }}
}

workspace menu -name {CUSTOM {NEWPDK} {Make FET params visible} }  -command {make_NEWPDK_FET_params_visible }


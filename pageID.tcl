proc pageID {} {
	clock seconds
	set date [clock format [clock seconds] -format "%D"]
	set time [clock format [clock seconds] -format "%T"]
	mode renderoff
	if { "?{Author}" eq [property get -name Author] } {
		property set Author  -value [workspace username]
		property set Address1  -value {YOUR CO NAME}
		property set Address2  -value {YOUR CO ADDR}
		property set Tel  -value YOUR-CO-TELNO
		property set Created -value "$date $time"
		property set Modified -value "$date $time"
		property set Library -value [sed_get_current_library]
		property set Module -value [sed_get_current_cell_name]
		property set View -value [sed_get_current_view_name]
	} else {
		property set Modified -value "$date $time"
	}
	mode renderon
}

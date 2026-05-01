proc toggle_case {} {
	find all -scope selection -goto none -modify {
		if { [catch {property get -name Name -system} name] } {
			# Object has no Name property, such as a wire. Skip it.
			return
		}

		if { $name eq "" } {
			return
		}

		if { $name eq [string toupper $name] } {
			set toggled_case_name [string tolower $name]
		} else {
			set toggled_case_name [string toupper $name]
		}

		property set -name Name -value $toggled_case_name -system
	}
}

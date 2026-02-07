proc list_ports_csv {} {
	# Print CSV header
	puts "name,direction"

	# Get all ports
	set ports [database ports -all]

	# Loop through each port entry
	foreach port $ports {
		# Each port is {name direction global}
		set name [lindex $port 0]

		set dir_raw [lindex $port 1]
		switch -- $dir_raw {
			in    { set direction I }
			out   { set direction O }
			other { set direction IO }
			default {
				# Safety net in case Tanner adds something unexpected
				set direction $dir_raw
			}
		}

		# Output CSV row
		puts "$name,$direction"
	}
}

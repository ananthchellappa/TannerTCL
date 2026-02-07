# Print CSV header
puts "name,direction"

# Get all ports
set ports [database ports -all]

# Keep track of rows we've already output
array set seen {}

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
            set direction $dir_raw
        }
    }

    # Create a unique key per CSV row
    set key "$name,$direction"

    # Skip duplicates
    if {[info exists seen($key)]} {
        continue
    }
    set seen($key) 1

    # Output CSV row
    puts $key
}

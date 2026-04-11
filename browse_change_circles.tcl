# my best practice - make a change, put a *dashed* (yes, sadly not possible with Tanner S-Edit :) circle - stuff I learnt from Maxim
proc browse_change_circles {} {
    set rc [find circle -next -goto zoom]

    if {[string match -nocase *end* $rc]} {
		puts "Back to first circle.."
        set rc [find circle -first -goto zoom]
    }

    if {![string match -nocase *end* $rc]} {
        window zoom [expr {16/81.0}]
    }
}

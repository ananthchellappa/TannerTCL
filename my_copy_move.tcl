proc my_copy {} {
	copy
	paste
	mode place -forcemove on
}

proc my_move {} {
	copy
	delete
	paste
	mode place -forcemove on
}

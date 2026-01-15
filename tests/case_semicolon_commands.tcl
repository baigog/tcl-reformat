proc case_semicolon_commands {} {
set a 1; set b 2; set c 3
if {1} {puts ok}; set d 4
}

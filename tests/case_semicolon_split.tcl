proc xfail_semicolon_split {} {
set a 1; if {1} {puts "ok"}; set b 2 ;# multiple commands
set c 3;# comment after semicolon
}

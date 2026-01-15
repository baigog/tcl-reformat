proc case_command_boundaries {} {
set a 1; if {1} {puts ok} ; set b 2
set c 3;# comment after semicolon
set d 4; set e 5;#comment
}

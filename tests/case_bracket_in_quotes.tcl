proc case_bracket_in_quotes {} {
set a "[string map {[} {\[} {]} {\]}]" ;# brackets in map
set b "prefix [format {[%s]} [string length abc]] suffix"
}

proc case_brackets_quotes {} {
set a "[string toupper abc]" ;# command substitution in quotes
set b "prefix [format "%s" value] suffix" ;# nested quotes in []
set c [list [expr {1+2}] "[string length abc]"] ;# mix
}

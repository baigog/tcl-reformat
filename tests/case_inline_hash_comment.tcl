proc xfail_inline_hash_comment {} {
if {1} {# comment after open brace
puts "ok"
}
set a 1 ; # comment after semicolon
set b 2 # comment after command
}

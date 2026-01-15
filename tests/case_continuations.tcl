proc case_continuations {} {
set a 1 \
+ 2 \
+ 3 ;# math continuation
set b "x" \
+ "y" ;# string continuation with quotes
set c [list 1 \
+ 2 \
+ 3] ;# list continuation
}

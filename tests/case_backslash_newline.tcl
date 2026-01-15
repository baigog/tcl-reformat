proc case_backslash_newline {} {
set a 1 \
+ 2 \
+ 3
set b 1 \\
+ 2 ;# escaped backslash should not continue
set c {\
} ;# backslash in braces is literal newline
}

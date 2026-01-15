proc xfail_backslash_rules {} {
    set a "\\" ;# escaped backslash in quotes
    set b {\\} ;# backslash inside braces (literal)
    set c 1 \\
    + 2 ;# escaped backslash should not continue
}

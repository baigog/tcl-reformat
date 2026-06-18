set root [file normalize [file join [file dirname [info script]] ..]]
set reformat [file join $root reformat.tcl]
set work [file join $root tests error_tmp_[pid]]
file mkdir $work

proc write_file {path data} {
    set f [open $path w]
    try {
        puts -nonewline $f $data
    } finally {
        close $f
    }
}

try {
    set path [file join $work unbalanced_quotes.tcl]
    write_file $path [join [list {proc p {} \{} {set value "unterminated} ""] "\n"]

    if {![catch {
        exec [info nameofexecutable] $reformat --stdout $path
    } message]} {
        error "unbalanced quotes did not fail"
    }

    if {![string match "*unbalanced quotes at end of file (line 3); opened at line 2: set value \\\"unterminated*" $message]} {
        error "unbalanced quotes message lacked opening line context: $message"
    }
} finally {
    file delete -force $work
}

puts "ok: error messages include quote context"

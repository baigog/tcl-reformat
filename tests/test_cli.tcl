set root [file normalize [file join [file dirname [info script]] ..]]
set reformat [file join $root reformat.tcl]
set work [file join $root tests cli_tmp_[pid]]
file mkdir $work

proc write_file {path data} {
    set f [open $path w]
    try {
        puts -nonewline $f $data
    } finally {
        close $f
    }
}

proc read_file {path} {
    set f [open $path r]
    try {
        return [read $f]
    } finally {
        close $f
    }
}

try {
    set first [file join $work first.tcl]
    set second [file join $work second.tcl]
    write_file $first "if {\$a} {\nset x 1\n}\n"
    write_file $second "if {\$b} {\nset y 2\n}\n"

    exec [info nameofexecutable] $reformat $first $second
    if {[read_file $first] ne "if {\$a} {\n    set x 1\n}\n"} {
        error "multiple-file formatting failed for first.tcl"
    }
    if {[read_file $second] ne "if {\$b} {\n    set y 2\n}\n"} {
        error "multiple-file formatting failed for second.tcl"
    }

    write_file $first "if {\$a} {\nset x 1\n}\n"
    write_file $second "if {\$b} {\nset y 2\n}\n"
    exec [info nameofexecutable] $reformat [file join $work *.tcl]
    if {[read_file $first] ne "if {\$a} {\n    set x 1\n}\n"
            || [read_file $second] ne "if {\$b} {\n    set y 2\n}\n"} {
        error "glob formatting failed"
    }

    if {![catch {
        exec [info nameofexecutable] $reformat --stdout $first $second
    } message] || ![string match "*exactly one input file*" $message]} {
        error "--stdout accepted multiple files"
    }

    if {![catch {
        exec [info nameofexecutable] $reformat [file join $work missing*.tcl]
    } message] || ![string match "*no files matched*" $message]} {
        error "unmatched glob did not fail"
    }
} finally {
    file delete -force $work
}

puts "ok: CLI multiple files and globs"

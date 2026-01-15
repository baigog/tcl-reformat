#!/usr/bin/env tclsh
# Verify that inline comment blocks align at the same column.
source [file join [file dirname [info script]] .. reformat.tcl]

if {[llength $argv] != 1} {
    puts stderr "usage: check_alignment.tcl file"
    exit 2
}

set path [lindex $argv 0]
set f [open $path r]
set data [read $f]
close $f

set lines [split $data "\n"]
set base_ws -1
set base_col -1
set ok 1
set line_no 0

foreach line $lines {
    incr line_no
    set parts [_split_inline_comment $line]
    if {$parts eq {}} {
        set base_ws -1
        set base_col -1
        continue
    }

    set ws [_leading_ws_col $line 8]
    set col [lindex $parts 2]

    if {$base_ws < 0 || $ws != $base_ws} {
        set base_ws $ws
        set base_col $col
        continue
    }

    if {$col != $base_col} {
        puts stderr "alignment mismatch at $path:$line_no (col $col != $base_col)"
        set ok 0
        break
    }
}

if {!$ok} { exit 1 }

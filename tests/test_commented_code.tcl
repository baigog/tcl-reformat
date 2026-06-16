set path [file join [file dirname [info script]] case_commented_code_structures.tcl.out]
set f [open $path r]
try {
    set formatted [read $f]
} finally {
    close $f
}

set uncommented {}
foreach line [split $formatted "\n"] {
    regsub {^([ \t]*)#} $line {\1} line
    lappend uncommented $line
}

set expected_path [file join [file dirname [info script]] expected_commented_code_uncommented.txt]
set f [open $expected_path r]
try {
    set expected [read $f]
} finally {
    close $f
}

if {[join $uncommented "\n"] ne $expected} {
    error "removing '# ' did not preserve commented-code indentation"
}

puts "ok: commented code can be uncommented without reindentation"

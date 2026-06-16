#! /usr/bin/env tclsh
# reformat.tcl
# Reindent Tcl code and optionally align inline comments in blocks.

proc count {string char} {
    # Count occurrences of char in string, ignoring escaped ones.
    set count 0
    while {[set idx [string first $char $string]] >= 0} {
        set backslashes 0
        set nidx $idx
        while {$nidx > 0 && [string equal [string index $string [expr {$nidx-1}]] \\]} {
            incr backslashes
            incr nidx -1
        }
        if {($backslashes % 2) == 0} {
            incr count
        }
        set string [string range $string [expr {$idx+1}] end]
    }
    return $count
}

proc _is_escaped {s idx} {
    # Return 1 if character at idx is escaped by an odd number of backslashes.
    set count 0
    set i [expr {$idx - 1}]
    while {$i >= 0 && [string index $s $i] eq "\\"} {
        incr count
        incr i -1
    }
    return [expr {($count % 2) == 1}]
}

proc _tokenize_line {line {state {}}} {
    # Tokenize a line into {type start end} tokens with parsing state.
    array set s {in_quote 0 brace_depth 0 bracket_depth 0}
    if {$state ne {}} { array set s $state }

    set tokens {}
    set cur_type ""
    set cur_start 0
    set len [string length $line]
    set i 0

    set quote_count 0
    set net_braces 0
    set net_brackets 0
    set last_sep_idx -1
    set comment_start -1

    set command_start 1

    while {$i < $len} {
        set ch [string index $line $i]

        if {$command_start && !$s(in_quote) && $s(brace_depth) == 0 && $s(bracket_depth) == 0} {
            if {$ch eq "#"} {
                set comment_start $i
                if {$cur_type ne ""} {
                    lappend tokens [list $cur_type $cur_start $i]
                }
                lappend tokens [list comment $i $len]
                break
            }
        }

        if {!$s(in_quote) && $s(brace_depth) == 0 && $s(bracket_depth) == 0} {
            if {$ch eq ";"} {
                if {$cur_type ne ""} {
                    lappend tokens [list $cur_type $cur_start $i]
                    set cur_type ""
                }
                lappend tokens [list sep $i [expr {$i + 1}]]
                set last_sep_idx $i
                set command_start 1
                incr i
                continue
            }
        }

        if {$s(brace_depth) == 0 && $ch eq "\\"} {
            set next [expr {$i + 1}]
            set token_type word
            if {!$s(in_quote) && $s(brace_depth) == 0 && $s(bracket_depth) == 0} {
                set token_type word
            }
            if {$cur_type ne $token_type} {
                if {$cur_type ne ""} { lappend tokens [list $cur_type $cur_start $i] }
                set cur_type $token_type
                set cur_start $i
            }
            if {$next < $len} {
                incr i 2
            } else {
                incr i
            }
            set command_start 0
            continue
        }

        if {$s(brace_depth) == 0 && $ch eq "\""} {
            if {![_is_escaped $line $i]} {
                incr quote_count
                set s(in_quote) [expr {!$s(in_quote)}]
            }
        }

        if {!$s(in_quote)} {
            if {$ch eq "\x7b"} {
                if {![_is_escaped $line $i]} {
                    incr net_braces
                    incr s(brace_depth)
                }
            } elseif {$ch eq "\x7d"} {
                if {![_is_escaped $line $i]} {
                    incr net_braces -1
                    if {$s(brace_depth) > 0} { incr s(brace_depth) -1 }
                }
            }
        }

        if {$s(brace_depth) == 0} {
            if {$ch eq "\x5b"} {
                if {![_is_escaped $line $i]} {
                    incr net_brackets
                    incr s(bracket_depth)
                }
            } elseif {$ch eq "\x5d"} {
                if {![_is_escaped $line $i]} {
                    incr net_brackets -1
                    if {$s(bracket_depth) > 0} { incr s(bracket_depth) -1 }
                }
            }
        }

        set token_type word
        if {!$s(in_quote) && $s(brace_depth) == 0 && $s(bracket_depth) == 0} {
            if {$ch eq " " || $ch eq "\t"} {
                set token_type space
            } else {
                set command_start 0
            }
        }

        if {$cur_type ne $token_type} {
            if {$cur_type ne ""} { lappend tokens [list $cur_type $cur_start $i] }
            set cur_type $token_type
            set cur_start $i
        }

        incr i
    }

    if {$cur_type ne ""} {
        lappend tokens [list $cur_type $cur_start $i]
    }

    return [dict create \
        tokens $tokens \
        in_quote $s(in_quote) \
        brace_depth $s(brace_depth) \
        bracket_depth $s(bracket_depth) \
        quote_count $quote_count \
        net_braces $net_braces \
        net_brackets $net_brackets \
        last_sep_idx $last_sep_idx \
        comment_start $comment_start]
}

proc _scan_line {line} {
    set info [_tokenize_line $line]
    set last_sep [dict get $info last_sep_idx]
    set comment_start [dict get $info comment_start]

    set code_end $comment_start
    if {$code_end < 0} { set code_end [string length $line] }
    set code [string range $line 0 [expr {$code_end - 1}]]

    set comment_data {}
    if {$comment_start >= 0 && $last_sep >= 0} {
        set code_inline [string range $line 0 [expr {$last_sep - 1}]]
        set rest [string range $line [expr {$comment_start + 1}] end]
        set rest [string trimleft $rest " \t"]
        set comment_data [list $code_inline $rest $last_sep]
    }

    return [dict create \
        comment $comment_data \
        code $code \
        quote_count [dict get $info quote_count] \
        net_braces [dict get $info net_braces] \
        net_brackets [dict get $info net_brackets]]
}

proc _leading_ws_col {s {tabstop 8}} {
    # visual column count for leading whitespace
    set col 0
    regexp {^([ \t]*)} $s _ ws
    foreach ch [split $ws ""] {
        if {$ch eq "\t"} {
            set n [expr {$tabstop - ($col % $tabstop)}]
            incr col $n
        } else {
            incr col 1
        }
    }
    return $col
}


proc _split_inline_comment {line} {
    # Returns: code, comment_text, comment_start_col
    # Detects inline comments that start at a command boundary (after ';').
    set info [_scan_line $line]
    return [dict get $info comment]
}

proc _expand_tabs {s {tabstop 8}} {
    set out ""
    set col 0
    foreach ch [split $s ""] {
        if {$ch eq "\t"} {
            set n [expr {$tabstop - ($col % $tabstop)}]
            append out [string repeat " " $n]
            incr col $n
        } else {
            append out $ch
            incr col 1
        }
    }
    return $out
}

proc _net_braces {line} {
    # Net count of braces outside of quotes and inline comments.
    set info [_scan_line $line]
    return [dict get $info net_braces]
}

proc _count_quotes {line} {
    # Count quotes outside of braces and inline comments.
    set info [_scan_line $line]
    return [dict get $info quote_count]
}

proc _comment_payload_has_leading_space {text_after_hash} {
    return [regexp {^[ \t]+} $text_after_hash]
}

proc _comment_payload_is_strong_code {payload} {
    set text [string trimleft $payload " \t"]
    if {$text eq ""} { return 0 }
    if {[regexp {^[#]} $text]} { return 0 }
    if {[regexp {^[\}\]]} $text]} { return 1 }
    if {[regexp {^[+\-*/%]} $text]} { return 1 }
    if {[_line_continues_scan $text]} { return 1 }

    set commands {
        if for foreach proc while switch try catch return break continue
        set unset incr variable global namespace
    }

    if {[regexp {^([[:alpha:]_][[:alnum:]_:.-]*)($|[ \t\[\{])} $text _ command]} {
        if {[lsearch -exact $commands $command] >= 0} { return 1 }
        if {[regexp {[\[\]\{\}\\$;]} $text]} { return 1 }
    }

    return 0
}

proc _comment_payload_is_code {payload has_leading_space block_is_code} {
    if {$has_leading_space && !$block_is_code} { return 0 }
    if {[_comment_payload_is_strong_code $payload]} { return 1 }
    if {$block_is_code} {
        set text [string trimleft $payload " \t"]
        return [expr {$text ne "" && ![regexp {^[#]} $text]}]
    }
    return 0
}

proc _comment_payload_is_decoration {payload} {
    return [regexp {^#+$} [string trim $payload " \t"]]
}

proc _align_inline_comment_blocks {lines {min_gap 1} {tabstop 8} {max_align_col 0} {wrap_comment_col 0}} {
    set out {}
    set i 0
    set n [llength $lines]
    set max_target 0
    if {$max_align_col > 0} {
        set max_target [expr {$max_align_col - $min_gap}]
        if {$max_target < 1} { set max_target 0 }
    }

    while {$i < $n} {
        set line [lindex $lines $i]
        set parts [_split_inline_comment $line]
        if {$parts eq {}} {
            lappend out $line
            incr i
            continue
        }

        # Collect block: contiguous + same indent + has ;#
        set block_idx {}
        set block_parts {}
        regexp {^([ \t]*)} $line _ base_ws_str
        set base_ws [_leading_ws_col $line $tabstop]
        set j $i
        while {$j < $n} {
            set l [lindex $lines $j]
            if {[_leading_ws_col $l $tabstop] != $base_ws} break
            set p [_split_inline_comment $l]
            if {$p eq {}} break
            lassign $p code comment col
            regexp {^([ \t]*)} $l _ ws_str
            set code [string map [list \u00A0 " "] $code]
            set code_rt [string trimright $code " \t"]
            set clen [string length [_expand_tabs $code_rt $tabstop]]
            set comment [string trimleft $comment " \t"]
            set wrap 0
            if {$wrap_comment_col > 0 && $comment ne ""} {
                set inline_len [expr {$clen + $min_gap + 2 + 1 + [string length $comment]}]
                if {$inline_len > $wrap_comment_col} { set wrap 1 }
            }
            set eligible 1
            if {$wrap} { set eligible 0 }
            if {$max_target > 0 && $clen > $max_target} { set eligible 0 }
            lappend block_idx $j
            lappend block_parts [list $code_rt $comment $clen $wrap $eligible $ws_str $l]
            incr j
        }

        # Target column computed by VISUAL length (tabs expanded), but do not rewrite code
        set target 0
        foreach p $block_parts {
            lassign $p code_rt comment clen wrap eligible ws_str orig_line
            if {!$eligible} { continue }
            if {$clen > $target} { set target $clen }
        }
        if {$max_target > 0 && $target > $max_target} { set target $max_target }

        # Emit aligned lines (keep original code_rt, just pad with spaces)
        set k 0
        foreach idx $block_idx {
            lassign [lindex $block_parts $k] code_rt comment clen wrap eligible ws_str orig_line
            if {$wrap} {
                lappend out $code_rt
                lappend out "${ws_str}# $comment"
            } elseif {!$eligible} {
                lappend out $orig_line
            } else {
                set padlen [expr {($target - $clen) + $min_gap}]
                # Important: DON'T touch tabs inside code_rt. Only append spaces AFTER it.
                set aligned "${code_rt}[string repeat " " $padlen];#"
                set comment [string trimleft $comment " \t"]
                if {$comment ne ""} { append aligned " $comment" }
                lappend out $aligned
            }
            incr k
        }

        set i $j
    }

    return $out
}

proc _line_continues_scan {line} {
    # Continuation based on tokenizer analysis.
    set info [_scan_line $line]
    set code [dict get $info code]

    set trimmed [string trimright $code " \t"]
    if {$trimmed eq ""} { return 0 }
    if {[string length $trimmed] != [string length $code]} { return 0 }

    set i [expr {[string length $trimmed] - 1}]
    set bcount 0
    while {$i >= 0 && [string index $trimmed $i] eq "\\"} {
        incr bcount
        incr i -1
    }
    if {($bcount % 2) == 0} { return 0 }
    if {[_net_braces $trimmed] != 0} { return 0 }
    return 1
}

proc _line_has_trailing_continuation {line} {
    set info [_scan_line $line]
    set code [dict get $info code]

    set trimmed [string trimright $code " \t"]
    if {$trimmed eq ""} { return 0 }
    if {[string length $trimmed] != [string length $code]} { return 0 }

    set i [expr {[string length $trimmed] - 1}]
    set bcount 0
    while {$i >= 0 && [string index $trimmed $i] eq "\\"} {
        incr bcount
        incr i -1
    }
    return [expr {($bcount % 2) == 1}]
}

proc reformat {tclcode {pad 4} {align_inline_comments 1} {indent_multiline_strings 1} {indent_commented_code 0} {align_max_col 0} {wrap_comment_col 0} {indent_continuations 1}} {
    set lines [split $tclcode "\n"]
    set out_lines {}

    set continued 0
    set continuation_indent 0
    set braced_word_continued 0
    set braced_word_balance 0
    set bracket_balance 0
    set oddquotes 0
    set comment_active 0
    set comment_base_indent 0
    set comment_indent 0
    set comment_block_is_code 0
    set comment_continued 0
    set comment_continuation_indent 0

    # Para strings multilínea:
    set in_mls 0
    set mls_prefix ""

    # Determine initial indent from first non-blank, non-comment line
    set indent 0
    foreach l $lines {
        if {[string trim $l " \t"] eq ""} { continue }
        if {[regexp {^[ \t]*#} $l]} { continue }
        set leading [string length $l]
        set trimmed [string length [string trimleft $l " \t"]]
        set indent [expr {($leading - $trimmed) / $pad}]
        if {$indent < 0} { set indent 0 }
        break
    }

    set initial_indent $indent
    set padstr [string repeat " " $pad]
    set padlen [string length $padstr]

    set line_no 0
    foreach orig $lines {
        incr line_no
        # Blank lines
        if {[string trim $orig " \t"] eq ""} {
            set comment_active 0
            lappend out_lines ""
            continue
        }

        # --- Inside multiline string (quotes still open) ---
        if {$oddquotes} {
            set comment_active 0
            if {$indent_multiline_strings && $in_mls} {
                # Reindent string content lines: keep text, normalize leading ws
                set payload [string trimleft $orig " \t"]
                set line "${mls_prefix}${payload}"
                lappend out_lines $line
            } else {
                # Safe mode: preserve exactly
                lappend out_lines $orig
            }

            # Update quote state based on ORIGINAL line content
            set qcount [count $orig \"]
            set oddquotes [expr {($qcount + $oddquotes) % 2}]
            if {!$oddquotes} {
                # string closed
                set in_mls 0
                set mls_prefix ""
            }
            continue
        }

        # Normal formatting path
        set newline [string trim $orig " \t"]
        set line_continues [_line_continues_scan $orig]
        set has_trailing_continuation [_line_has_trailing_continuation $orig]
        set line "[string repeat $padstr $indent]$newline"

        # Full-line comment: reindent but don't affect state
        if {[regexp {^[ \t]*#} $line]} {
            if {$indent_commented_code} {
                if {!$comment_active} {
                    set comment_base_indent $indent
                    set comment_indent $indent
                    set comment_block_is_code 0
                    set comment_continued 0
                    set comment_continuation_indent 0
                    set comment_active 1
                }

                set raw_payload [string range $newline 1 end]
                set payload [string trimleft $raw_payload " \t"]
                set payload_has_leading_space [_comment_payload_has_leading_space $raw_payload]
                set payload_is_code [_comment_payload_is_code $payload $payload_has_leading_space $comment_block_is_code]
                if {$payload_is_code} { set comment_block_is_code 1 }
                set lead_brace_closes 0
                set lead_bracket_closes 0
                if {$payload ne "" && [regexp {^([\}\]]+)} $payload _ closes]} {
                    set lead_brace_closes [count $closes \}]
                    set lead_bracket_closes [count $closes \]]
                }

                set out_indent [expr {
                    $comment_indent - $lead_brace_closes - $lead_bracket_closes
                }]
                if {$out_indent < 0} { set out_indent 0 }

                set line "[string repeat $padstr $comment_base_indent]#"
                if {$payload ne ""} {
                    if {[_comment_payload_is_decoration $payload]} {
                        append line $payload
                    } elseif {$payload_is_code} {
                        set relative_indent [expr {$out_indent - $comment_base_indent}]
                        if {$relative_indent < 0} { set relative_indent 0 }
                        append line "[string repeat $padstr $relative_indent]$payload"
                    } else {
                        append line " $payload"
                    }
                }
                lappend out_lines $line

                if {$payload ne "" && $payload_is_code} {
                    set scan_info [_scan_line $payload]
                    set nbbraces [dict get $scan_info net_braces]
                    set nbbrackets [dict get $scan_info net_brackets]
                    set line_continues [_line_continues_scan $payload]

                    if {$indent_continuations} {
                        if {$line_continues} {
                            if {!$comment_continued} {
                                set comment_continued 1
                                if {$nbbrackets <= 0} {
                                    incr comment_indent
                                    set comment_continuation_indent 1
                                }
                            }
                        } elseif {$comment_continued} {
                            incr comment_indent -$comment_continuation_indent
                            set comment_continued 0
                            set comment_continuation_indent 0
                        }
                    }

                    incr comment_indent $nbbraces
                    incr comment_indent $nbbrackets
                    if {$comment_indent < 0} {
                        set comment_indent 0
                    }
                }
                continue
            }

            set comment_active 0
            lappend out_lines $line
            continue
        }
        set comment_active 0

        # Quote tracking
        set scan_info [_scan_line $line]
        set qcount [dict get $scan_info quote_count]
        set nbbraces [dict get $scan_info net_braces]
        set nbbrackets [dict get $scan_info net_brackets]
        incr bracket_balance $nbbrackets
        if {$bracket_balance < 0} {
            error "unbalanced brackets at line $line_no"
        }
        set oddquotes_after [expr {($qcount + $oddquotes) % 2}]

        # If this line OPENS a multiline string, arm MLS mode for next lines
        if {$oddquotes_after} {
            set in_mls 1
            set mls_indent [expr {$indent + 1}]
            #if {$mls_indent < 0} { set mls_indent 0 }
            set mls_prefix "[string repeat $padstr $mls_indent]"
        }


        # Only apply backslash-continuation indentation when NOT entering a quoted block
        if {$indent_continuations && !$oddquotes_after} {
            if {$line_continues && !$braced_word_continued} {
                if {!$continued} {
                    set continued 1
                    if {$nbbrackets <= 0} {
                        incr indent
                        set continuation_indent 1
                    }
                }
            } elseif {$continued} {
                incr indent -$continuation_indent
                set continued 0
                set continuation_indent 0
            }
        }

        # Brace logic only when quotes are balanced on this line
        if {!$oddquotes_after} {
            set brace [string equal [string index $newline end] \{]
            set lead_closes 0
            if {[regexp {^(\}+)} $newline _ closes]} {
                set lead_closes [string length $closes]
            }

            if {$nbbraces > 0 || $brace} {
                incr indent $nbbraces
            }

            if {$nbbraces < 0 || $lead_closes > 0} {
                incr indent $nbbraces
                if {$indent < 0} {
                    error "unbalanced braces at line $line_no"
                }

                if {$lead_closes > 0} {
                    set np [expr {$lead_closes * $padlen}]
                } else {
                    set np [expr {(-$nbbraces) * $padlen}]
                }
                if {$np > 0} {
                    set line [string range $line $np end]
                }
            }

            if {$braced_word_continued} {
                incr braced_word_balance $nbbraces
                if {$braced_word_balance <= 0} {
                    set braced_word_continued 0
                    set braced_word_balance 0
                }
            } elseif {$has_trailing_continuation && $nbbraces > 0} {
                set braced_word_continued 1
                set braced_word_balance $nbbraces
            }

            set lead_bracket_closes 0
            if {[regexp {^([\}\]]+)} $newline _ closes]} {
                set lead_bracket_closes [count $closes \]]
            }

            if {$nbbrackets > 0} {
                incr indent $nbbrackets
            }

            if {$nbbrackets < 0 || $lead_bracket_closes > 0} {
                incr indent $nbbrackets
                if {$indent < 0} {
                    error "unbalanced brackets at line $line_no"
                }

                if {$lead_bracket_closes > 0} {
                    set np [expr {$lead_bracket_closes * $padlen}]
                    set line [string range $line $np end]
                }
            }
        }

        set oddquotes $oddquotes_after
        lappend out_lines $line
    }

    if {$oddquotes} {
        error "unbalanced quotes at end of file (line $line_no)"
    }
    if {$bracket_balance != 0} {
        error "unbalanced brackets at end of file (line $line_no)"
    }
    if {$indent != $initial_indent} {
        error "unbalanced braces at end of file (line $line_no)"
    }

    if {$align_inline_comments} {
        set out_lines [_align_inline_comment_blocks $out_lines 1 8 $align_max_col $wrap_comment_col]
    }

    return [join $out_lines "\n"]
}



# --- CLI ---
proc _print_help {prog} {
    puts "Usage: $prog ?options? file ?file ...?"
    puts ""
    puts "Options:"
    puts "  -indent N, --indent N     Indent width in spaces (default: 4)"
    puts "  -noalign, --noalign       Disable inline ;# comment alignment"
    puts "  -align, --align           Enable inline ;# comment alignment"
    puts "  --align-max-col N         Cap ;# alignment column (optional)"
    puts "  --wrap-comment N          Wrap long inline comments to next line"
    puts "  --stdin                  Read Tcl from stdin (implies --stdout)"
    puts "  --stdout                 Write formatted Tcl to stdout"
    puts "  --indent-commented-code  Indent each comment marker like its code line"
    puts "  --no-indent-continuations"
    puts "                           Keep continuation lines at the normal block indent"
    puts "  -V, --version             Show version"
    puts "  -h, --help                Show this help message"
    puts ""
    puts "Examples:"
    puts "  $prog -indent 2 script.tcl"
    puts "  $prog --noalign script.tcl"
    puts "  $prog --align-max-col 80 script.tcl"
    puts "  $prog --wrap-comment 100 script.tcl"
    puts "  $prog --indent-commented-code script.tcl"
    puts "  $prog --no-indent-continuations script.tcl"
    puts "  $prog scripts/*.tcl tests/*.tcl"
    puts "  $prog \"scripts/*/*.tcl\""
    puts "  $prog --stdin < script.tcl"
    puts "  $prog --stdout script.tcl > formatted.tcl"
    puts ""
    puts "Before/after examples:"
    puts "  Default alignment"
    puts "    before:  set a 1 ;# short"
    puts "             set longer_name 2 ;# longer"
    puts "    after:   set a 1           ;# short"
    puts "             set longer_name 2 ;# longer"
    puts ""
    puts "  --align-max-col 24"
    puts "    before:  set a 1 ;# short"
    puts "             set very_long_variable_name 2 ;# long"
    puts "             set b 3 ;# short"
    puts "    after:   set a 1                 ;# short"
    puts "             set very_long_variable_name 2 ;# long"
    puts "             set b 3                 ;# short"
    puts ""
    puts "  --wrap-comment 50"
    puts "    before:  set x 1 ;# this comment is long and should wrap"
    puts "    after:   set x 1"
    puts "             # this comment is long and should wrap"
    puts ""
    puts "  --indent-commented-code"
    puts "    before:  if {\$a} {"
    puts "             # if {\$b} {"
    puts "             # set x 1"
    puts "             # }"
    puts "             }"
    puts "    after:   if {\$a} {"
    puts "                 # if {\$b} {"
    puts "                     # set x 1"
    puts "                 # }"
    puts "             }"
    puts ""
    puts "Completion scripts (optional):"
    puts "  bash: completions/reformat.bash"
    puts "  zsh:  completions/_reformat"
    puts "  csh:  completions/reformat.csh"
    puts "  tcsh: completions/reformat.tcsh"
}

proc _expand_paths {patterns} {
    set paths {}
    set seen {}

    foreach pattern $patterns {
        if {[file isfile $pattern]} {
            set matches [list $pattern]
        } else {
            set matches [glob -nocomplain -- $pattern]
        }

        if {[llength $matches] == 0} {
            error "no files matched: $pattern"
        }

        foreach path $matches {
            if {![file isfile $path]} { continue }
            set normalized [file normalize $path]
            if {[dict exists $seen $normalized]} { continue }
            dict set seen $normalized 1
            lappend paths $path
        }
    }

    if {[llength $paths] == 0} {
        error "no files matched"
    }
    return $paths
}

proc _format_data {data indent align indent_commented_code align_max_col wrap_comment_col indent_continuations} {
    set normalized [string map [list "\r\n" "\n" "\r" "\n"] $data]
    return [reformat $normalized $indent $align 1 $indent_commented_code $align_max_col $wrap_comment_col $indent_continuations]
}

proc _format_file {path indent align indent_commented_code align_max_col wrap_comment_col indent_continuations} {
    set f [open $path r]
    try {
        set data [read $f]
    } finally {
        close $f
    }

    set formatted [_format_data $data $indent $align $indent_commented_code $align_max_col $wrap_comment_col $indent_continuations]
    set tmp "${path}.tmp"
    set has_permissions [expr {![catch {file attributes $path -permissions} permissions]}]

    set f [open $tmp w]
    try {
        puts -nonewline $f $formatted
    } finally {
        close $f
    }

    file copy -force $tmp $path
    file delete -force $tmp
    if {$has_permissions} {
        file attributes $path -permissions $permissions
    }
}

set usage "reformat.tcl ?options? file ?file ...?"
set version "0.1.0"

if {[info exists argv] && [llength $argv] != 0 && [file normalize [info script]] eq [file normalize $::argv0]} {
    set indent 4
    set align 1
    set use_stdin 0
    set use_stdout 0
    set indent_commented_code 0
    set indent_continuations 1
    set align_max_col 0
    set wrap_comment_col 0
    set paths {}

    while {[llength $argv] > 0} {
        set a [lindex $argv 0]
        if {$a eq "-h" || $a eq "--help"} {
            _print_help [file tail [info script]]
            exit 0
        } elseif {$a eq "-V" || $a eq "--version"} {
            puts $version
            exit 0
        } elseif {$a eq "-indent" || $a eq "--indent"} {
            if {[llength $argv] < 2} { error $usage }
            set indent [lindex $argv 1]
            set argv [lrange $argv 2 end]
            continue
        } elseif {[string match "--indent=*" $a]} {
            set indent [string range $a 9 end]
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "-noalign" || $a eq "--noalign"} {
            set align 0
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "-align" || $a eq "--align"} {
            set align 1
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--stdin"} {
            set use_stdin 1
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--stdout"} {
            set use_stdout 1
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--align-max-col"} {
            if {[llength $argv] < 2} { error $usage }
            set align_max_col [lindex $argv 1]
            set argv [lrange $argv 2 end]
            continue
        } elseif {[string match "--align-max-col=*" $a]} {
            set align_max_col [string range $a 16 end]
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--wrap-comment"} {
            if {[llength $argv] < 2} { error $usage }
            set wrap_comment_col [lindex $argv 1]
            set argv [lrange $argv 2 end]
            continue
        } elseif {[string match "--wrap-comment=*" $a]} {
            set wrap_comment_col [string range $a 15 end]
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--indent-commented-code"} {
            set indent_commented_code 1
            set argv [lrange $argv 1 end]
            continue
        } elseif {$a eq "--no-indent-continuations"} {
            set indent_continuations 0
            set argv [lrange $argv 1 end]
            continue
        } elseif {[string match "-*" $a]} {
            error $usage
        }
        lappend paths $a
        set argv [lrange $argv 1 end]
    }

    if {$use_stdin} {
        if {[llength $paths] != 0} { error $usage }
        set use_stdout 1
    } elseif {[llength $paths] == 0} {
        error $usage
    } else {
        set paths [_expand_paths $paths]
        if {$use_stdout && [llength $paths] != 1} {
            error "--stdout requires exactly one input file"
        }
    }

    if {$use_stdin} {
        set data [read stdin]
        set formatted [_format_data $data $indent $align $indent_commented_code $align_max_col $wrap_comment_col $indent_continuations]
        puts -nonewline stdout $formatted
    } elseif {$use_stdout} {
        set path [lindex $paths 0]
        set f [open $path r]
        try {
            set data [read $f]
        } finally {
            close $f
        }
        set formatted [_format_data $data $indent $align $indent_commented_code $align_max_col $wrap_comment_col $indent_continuations]
        puts -nonewline stdout $formatted
    } else {
        foreach path $paths {
            _format_file $path $indent $align $indent_commented_code $align_max_col $wrap_comment_col $indent_continuations
        }
    }
}

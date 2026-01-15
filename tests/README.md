# Tcl reformat tests

These tests are grouped by edge case. All `case_*.tcl` files are expected to
format cleanly and load in `tclsh`.

Tokenizer model goals (to be implemented):
- Comment starts at command start or after `;` when not inside quotes/braces/brackets.
- `;#` inline comments are aligned and must ignore `;#` inside quotes/braces/brackets.
- Backslash escapes only apply in quotes and at top level; in braced words, only `\{` and `\}` should be treated as literal braces for counting.
- Bracket substitutions `[...]` are tracked even inside quotes; nested brackets should be balanced.
- Continuation is only when a line ends with an unescaped backslash outside braces.

Current tokenizer behavior:
- Tracks `in_quote`, `brace_depth`, and `bracket_depth` per line.
- Detects command-boundary comments only after `;` at top level.
- Inline `;#` alignment uses the same tokenizer rules to avoid false matches.
- Continuation checks ignore trailing inline comments and require an odd trailing backslash.

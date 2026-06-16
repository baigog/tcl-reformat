# reformat.tcl

Reindent Tcl code and optionally align inline `;#` comments in blocks.

## Usage

```sh
./reformat.tcl [options] file [file ...]
```

Options:
- `-indent N`, `--indent N`: Indent width in spaces (default: 4)
- `-noalign`, `--noalign`: Disable inline `;#` comment alignment
- `-align`, `--align`: Enable inline `;#` comment alignment
- `--align-max-col N`: Cap the `;#` alignment column (optional)
- `--wrap-comment N`: Move long inline `;#` comments to the next line
- `--stdin`: Read input from stdin (implies `--stdout`)
- `--stdout`: Write one formatted Tcl file to stdout instead of overwriting it
- `--indent-commented-code`: Indent commented Tcl code so block-deleting `#` restores code indentation; non-code comments keep a space after `#`
- `--no-indent-continuations`: Keep lines after a trailing `\` at the normal block indentation
- `-V`, `--version`: Show version
- `-h`, `--help`: Show help

Examples:
```sh
./reformat.tcl -indent 2 script.tcl
./reformat.tcl --noalign script.tcl
./reformat.tcl --align-max-col 80 script.tcl
./reformat.tcl --wrap-comment 100 script.tcl
./reformat.tcl --stdin < script.tcl
./reformat.tcl --stdout script.tcl > formatted.tcl
./reformat.tcl --indent-commented-code script.tcl
./reformat.tcl --no-indent-continuations script.tcl
./reformat.tcl src/*.tcl tests/*.tcl
./reformat.tcl "src/*/*.tcl"
```

## Before/after examples

Default alignment:
```tcl
# before
set a 1 ;# short
set longer_name 2 ;# longer

# after
set a 1           ;# short
set longer_name 2 ;# longer
```

`--align-max-col 24`:
```tcl
# before
set a 1 ;# short
set very_long_variable_name 2 ;# long
set b 3 ;# short

# after
set a 1                 ;# short
set very_long_variable_name 2 ;# long
set b 3                 ;# short
```

`--wrap-comment 50`:
```tcl
# before
set x 1 ;# this comment is long and should wrap

# after
set x 1
# this comment is long and should wrap
```

`--indent-commented-code`:
```tcl
# before
if {$a} {
# if {$b} {
# set x 1
# }
# This is a doc comment
}

# after
if {$a} {
    #if {$b} {
        #set x 1
    #}
    # This is a doc comment
}
```

## Behavior notes

- Multiline quoted strings are reindented one level deeper while quotes remain open.
- Line continuation only triggers with an odd trailing backslash and no trailing whitespace.
- Continuation lines are indented one extra level by default; `--no-indent-continuations` disables that extra indentation.
- Multiline command substitutions in `[...]` are indented as blocks, like brace-delimited blocks.
- When a continued line opens `[`, the bracket block supplies the extra level instead of adding a second continuation level.
- `--indent-commented-code` places `#` at the indentation a code line would use and omits the following space for detected Tcl code, so deleting only `#` restores valid indentation. Documentation-style comments keep `# `.
- Input line endings are normalized to LF on output (CRLF input is accepted).
- Multiple files and glob patterns are accepted. Quote a pattern to have `reformat.tcl` expand it instead of the shell.
- `--stdout` requires exactly one matched input file; multi-file commands overwrite files in place.
- `--align-max-col` ignores lines with code longer than the cap when aligning `;#` blocks.
- `--wrap-comment` writes long inline comments as a full-line `#` at the same indent.

## Shell completion

Completion scripts live in `completions/`:

- `completions/reformat.csh`
- `completions/reformat.tcsh`
- `completions/reformat.bash`
- `completions/_reformat`

Install by sourcing the file from your shell startup:

### csh
Add to `~/.cshrc`:
```csh
source /path/to/scripts/completions/reformat.csh
```

### tcsh
Add to `~/.tcshrc`:
```tcsh
source /path/to/scripts/completions/reformat.tcsh
```

### bash
Add to `~/.bashrc`:
```bash
source /path/to/scripts/completions/reformat.bash
```

### zsh
Add to `~/.zshrc` and ensure `fpath` includes the folder:
```zsh
fpath=(/path/to/scripts/completions $fpath)
autoload -Uz compinit && compinit
```
Then restart your shell.

## Tests

Run all tests:
```sh
tests/run_tests.sh
```

# bash completion for reformat.tcl
_reformat_tcl_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    -indent|--indent|--align-max-col|--wrap-comment)
      return 0
      ;;
  esac
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "-indent --indent --indent= -noalign --noalign -align --align --align-max-col --align-max-col= --wrap-comment --wrap-comment= --stdin --stdout --indent-commented-code --no-indent-continuations -V --version -h --help" -- "$cur") )
  else
    COMPREPLY=( $(compgen -f -- "$cur") )
    compopt -o filenames 2>/dev/null || true
  fi
}
complete -F _reformat_tcl_complete reformat.tcl

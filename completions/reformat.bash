# bash completion for reformat.tcl
_reformat_tcl_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    -indent|--indent)
      return 0
      ;;
  esac
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "-indent --indent --indent= -noalign --noalign -align --align -h --help" -- "$cur") )
  else
    COMPREPLY=( $(compgen -W "-indent --indent --indent= -noalign --noalign -align --align -h --help" -- "$cur") )
    COMPREPLY+=( $(compgen -f -- "$cur") )
  fi
}
complete -F _reformat_tcl_complete reformat.tcl

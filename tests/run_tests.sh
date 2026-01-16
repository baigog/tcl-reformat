#!/usr/bin/env bash
# Run formatter regression tests against golden outputs.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

reformat="$root_dir/reformat.tcl"

for f in tests/case_*.tcl; do
  base="${f%.tcl}"
  tmp="${base}.tmp"
  out="${base}.tcl.out"
  xfail=0
  extra_args=()
  if [[ "$f" == *xfail_* ]]; then
    xfail=1
  fi
  if [[ "$f" == *commented_code* || "$f" == *commented_docstring* ]]; then
    extra_args=(--indent-commented-code)
  fi
  if [[ "$f" == *align_max_col* ]]; then
    extra_args+=(--align-max-col 80)
  fi
  if [[ "$f" == *wrap_comment* ]]; then
    extra_args+=(--wrap-comment 100)
  fi
  if [[ "$f" == *wrap_comment_noalign* ]]; then
    extra_args+=(--noalign)
  fi

  cp "$f" "$tmp"
  if [[ "$f" == *unbalanced* ]]; then
    if "$reformat" "${extra_args[@]}" "$tmp" >/dev/null 2>&1; then
      echo "expected failure but succeeded: $f" >&2
      exit 1
    fi
    rm -f "$tmp"
    continue
  fi

  if ! "$reformat" "${extra_args[@]}" "$tmp" >/dev/null 2>&1; then
    if [[ $xfail -eq 1 ]]; then
      echo "xfail (reformat): $f"
      rm -f "$tmp"
      continue
    fi
    echo "reformat failed: $f" >&2
    exit 1
  fi

  if [[ $xfail -eq 0 ]]; then
    if [[ -f "$out" ]]; then
      if ! diff -u "$out" "$tmp" >/dev/null; then
        echo "golden output mismatch: $out" >&2
        diff -u "$out" "$tmp" || true
        exit 1
      fi
    else
      echo "missing golden file: $out" >&2
      exit 1
    fi
  fi

  if ! tclsh -c "source $tmp" >/dev/null 2>&1; then
    if [[ $xfail -eq 1 ]]; then
      echo "xfail (tclsh): $f"
      rm -f "$tmp"
      continue
    fi
    echo "tclsh failed: $f" >&2
    exit 1
  fi

  if [[ $xfail -eq 0 ]]; then
    if [[ "$f" != *align_max_col* && "$f" != *wrap_comment* ]]; then
      tclsh tests/check_alignment.tcl "$tmp"
    fi
  fi

  rm -f "$tmp"
  if [[ $xfail -eq 1 ]]; then
    echo "xpass: $f"
  else
    echo "ok: $f"
  fi
 done

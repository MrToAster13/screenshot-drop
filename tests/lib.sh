# Small assertion helpers shared by the test files. Source it, call the
# assertions, then call `finish` at the end of the file.
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "ok   $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && printf '     %s\n' "$2"; return 0; }

assert_eq() {  # name expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$2] got [$3]"; fi
}
assert_contains() {  # name needle haystack
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "[$2] not in [$3]" ;; esac
}
assert_not_contains() {  # name needle haystack
  case "$3" in *"$2"*) bad "$1" "[$2] found in [$3]" ;; *) ok "$1" ;; esac
}

exists() {  # path: prints yes or no
  if [ -e "$1" ] || [ -L "$1" ]; then echo yes; else echo no; fi
}

png() {  # size in bytes (default 12): PNG signature padded with zeros
  local n="${1:-12}"
  { printf '\x89PNG\r\n\x1a\n'; head -c $((n - 8)) /dev/zero; }
}

age_days() {  # days file...: set the mtime N*24 hours back, on BSD or GNU tools
  # Count in seconds: calendar days lose an hour across a DST change, and
  # find -mtime counts whole 24-hour days.
  local s stamp; s=$(( $(date +%s) - $1 * 86400 )); shift
  stamp=$(date -r "$s" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$s" +%Y%m%d%H%M.%S)
  touch -t "$stamp" "$@"
}

mtime() {  # path: mtime in epoch seconds, on BSD or GNU stat
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"
}

finish() {
  echo "passed $PASS, failed $FAIL"
  [ "$FAIL" -eq 0 ]
}

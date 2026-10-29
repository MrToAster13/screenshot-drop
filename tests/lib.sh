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

finish() {
  echo "passed $PASS, failed $FAIL"
  [ "$FAIL" -eq 0 ]
}

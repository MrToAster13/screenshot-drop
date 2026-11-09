#!/usr/bin/env bash
# linux/shot through its CLI: argument checks, the ssh exit code and output
# contract, and what it prints. Host resolution is in test_no_host_default.sh.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/bin"
png > "$T/img.png"
: > "$T/empty.png"
touch "$T/key"

# Fake ssh: saves stdin, prints FAKE_OUT, exits with FAKE_RC.
cat > "$T/bin/ssh" <<FAKE
#!/usr/bin/env bash
cat > "$T/uploaded"
printf '%b' "\${FAKE_OUT:-}"
exit "\${FAKE_RC:-0}"
FAKE
chmod +x "$T/bin/ssh"

GOOD=/Users/someone/screenshots/2026-01-01_000000-cachy.png

run_shot() {  # env assignments..., then -- and shot's arguments
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" SHOT_HOST=alice@box.example \
    SHOT_KEY="$T/key" "${envs[@]}" bash linux/shot "$@"
}

out=$(run_shot -- "$T/missing.png" 2>&1); rc=$?
assert_eq "missing file exits 1" "1" "$rc"
assert_contains "missing file message" "no such file" "$out"

out=$(run_shot -- "$T/empty.png" 2>&1); rc=$?
assert_eq "empty file exits 1" "1" "$rc"
assert_contains "empty file message" "image is empty" "$out"

out=$(run_shot SHOT_KEY="$T/nokey" -- "$T/img.png" 2>&1); rc=$?
assert_eq "missing key exits 1" "1" "$rc"
assert_contains "missing key message" "key missing" "$out"

rm -f "$T/uploaded"
out=$(run_shot "FAKE_OUT=$GOOD\n" -- "$T/img.png" 2>/dev/null); rc=$?
assert_eq "upload exits 0" "0" "$rc"
assert_eq "stdout is the remote path" "$GOOD" "$out"
assert_eq "ssh got the file bytes" "yes" "$(cmp -s "$T/img.png" "$T/uploaded" && echo yes || echo no)"

out=$(run_shot "FAKE_OUT=Pseudo-terminal will not be allocated\n$GOOD\n" -- "$T/img.png" 2>/dev/null); rc=$?
assert_eq "banner then path exits 0" "0" "$rc"
assert_eq "path found after an ssh banner" "$GOOD" "$out"

out=$(run_shot "FAKE_OUT=screenshot-receive: upload is not a PNG\nPseudo-terminal will not be allocated\n" FAKE_RC=1 -- "$T/img.png" 2>&1); rc=$?
assert_eq "receiver error exits 1" "1" "$rc"
assert_contains "receiver error is shown" "upload is not a PNG" "$out"

out=$(run_shot "FAKE_OUT=$GOOD\n" FAKE_RC=255 -- "$T/img.png" 2>/dev/null); rc=$?
assert_eq "ssh failure exits 1 even with a path" "1" "$rc"
assert_eq "ssh failure prints no path" "" "$out"

out=$(run_shot "FAKE_OUT=/tmp/x.png\n" -- "$T/img.png" 2>&1); rc=$?
assert_eq "output with no /Users path exits 1" "1" "$rc"
assert_contains "the unmatched output is shown" "/tmp/x.png" "$out"

finish

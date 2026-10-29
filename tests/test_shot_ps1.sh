#!/usr/bin/env bash
# ELI-751: windows/shot.ps1 refuses to upload without a host, and refuses a
# host ssh would read as an option. Runs the script for real when Windows
# PowerShell or pwsh is on PATH (Git Bash on Windows), and skips otherwise.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

PS=""
for c in powershell.exe pwsh; do
  if command -v "$c" >/dev/null 2>&1; then PS="$c"; break; fi
done
if [ -z "$PS" ] || ! command -v cygpath >/dev/null 2>&1; then
  echo "skip: no Windows PowerShell here"
  finish
  exit $?
fi

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/appdata"
printf '\x89PNG\r\n\x1a\nfake' > "$T/img.png"
APPDATA_W=$(cygpath -w "$T/appdata")
IMG_W=$(cygpath -w "$T/img.png")
KEY_W=$(cygpath -w "$T/key")
touch "$T/key"

run_ps() {  # extra env assignments as arguments
  env -u SHOT_HOST APPDATA="$APPDATA_W" SHOT_KEY="$KEY_W" "$@" \
    "$PS" -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w windows/shot.ps1)" "$IMG_W" 2>&1
}

out=$(run_ps); rc=$?
assert_eq "shot.ps1 exits 1 with no host" "1" "$rc"
assert_contains "shot.ps1 no-host message names SHOT_HOST" "no upload host: set SHOT_HOST" "$out"

mkdir -p "$T/appdata/screenshot-drop"
printf '# only a comment\n\n' > "$T/appdata/screenshot-drop/host"
out=$(run_ps); rc=$?
assert_eq "shot.ps1 exits 1 when the config has only comments" "1" "$rc"
assert_contains "comment-only config means no host" "no upload host" "$out"
rm -f "$T/appdata/screenshot-drop/host"

out=$(run_ps SHOT_HOST=-oProxyCommand=x); rc=$?
assert_eq "shot.ps1 rejects a host starting with -" "1" "$rc"
assert_contains "dash host message" "bad upload host" "$out"

out=$(run_ps "SHOT_HOST=a@b;calc"); rc=$?
assert_eq "shot.ps1 rejects a host with other characters" "1" "$rc"
assert_contains "odd host message" "bad upload host" "$out"

printf -- '-oProxyCommand=x\n' > "$T/appdata/screenshot-drop/host"
out=$(run_ps); rc=$?
assert_eq "shot.ps1 rejects a dash host from the config file" "1" "$rc"
assert_contains "config dash host message" "bad upload host" "$out"

finish

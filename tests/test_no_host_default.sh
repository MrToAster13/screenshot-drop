#!/usr/bin/env bash
# ELI-751: no real host or user in the repo, and the clients refuse to run
# without a configured upload host.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/bin"
printf '\x89PNG\r\n\x1a\nfake' > "$T/img.png"

# Fake ssh: records its arguments and prints a remote path like the receiver.
cat > "$T/bin/ssh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$T/ssh-args"
cat > /dev/null
echo /Users/someone/screenshots/2026-01-01_000000-cachy.png
EOF
chmod +x "$T/bin/ssh"
touch "$T/key"

run_shot() {  # extra env assignments as arguments
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" SHOT_KEY="$T/key" "$@" \
    bash linux/shot "$T/img.png" 2>&1
}

# Criterion 1: no tailnet host name anywhere in tracked files.
assert_eq "git grep for the tailnet suffix finds nothing" "" "$(git grep -n 'ts[.]net')"

# Criterion 1: linux/shot exits with a clear message when no host is set.
rm -f "$T/ssh-args"
out=$(run_shot); rc=$?
assert_eq "shot exits 1 with no host" "1" "$rc"
assert_contains "message names SHOT_HOST" "SHOT_HOST" "$out"
assert_contains "message names the config file" ".config/screenshot-drop/host" "$out"
assert_eq "ssh not called without a host" "no" "$([ -f "$T/ssh-args" ] && echo yes || echo no)"

# The config file supplies the host.
mkdir -p "$T/home/.config/screenshot-drop"
printf '# upload target\n\nalice@box.example\n' > "$T/home/.config/screenshot-drop/host"
out=$(run_shot); rc=$?
assert_eq "shot succeeds with config file" "0" "$rc"
assert_contains "config host passed to ssh" "alice@box.example" "$(cat "$T/ssh-args" 2>/dev/null)"

# SHOT_HOST overrides the config file.
out=$(run_shot SHOT_HOST=bob@other.example); rc=$?
assert_eq "shot succeeds with SHOT_HOST" "0" "$rc"
assert_contains "SHOT_HOST passed to ssh" "bob@other.example" "$(cat "$T/ssh-args" 2>/dev/null)"
assert_not_contains "config host ignored when SHOT_HOST set" "alice@box.example" "$(cat "$T/ssh-args" 2>/dev/null)"

# XDG_CONFIG_HOME moves the config file.
rm -rf "$T/home/.config"
mkdir -p "$T/xdg/screenshot-drop"
echo "carol@xdg.example" > "$T/xdg/screenshot-drop/host"
out=$(run_shot XDG_CONFIG_HOME="$T/xdg"); rc=$?
assert_eq "shot reads XDG_CONFIG_HOME" "0" "$rc"
assert_contains "XDG host passed to ssh" "carol@xdg.example" "$(cat "$T/ssh-args" 2>/dev/null)"

# A host that starts with '-' would be read by ssh as an option.
rm -f "$T/ssh-args"
out=$(run_shot SHOT_HOST=-oProxyCommand=x); rc=$?
assert_eq "shot rejects a host starting with -" "1" "$rc"
assert_eq "ssh not called for a dash host" "no" "$([ -f "$T/ssh-args" ] && echo yes || echo no)"

# windows/shot.ps1: no built-in host, reads the config file, clear message.
# pwsh is not installed on the test host, so these are static checks.
ps1=$(cat windows/shot.ps1)
# Any user@host in shot.ps1 must be the generic "user@host" text.
ps1_hosts=$(grep -oE '[A-Za-z0-9._<>-]+@[A-Za-z0-9._<>-]+' windows/shot.ps1 | grep -vx 'user@host')
assert_eq "shot.ps1 has no real user@host" "" "$ps1_hosts"
assert_contains "shot.ps1 reads its config file" 'screenshot-drop\host' "$ps1"
assert_contains "shot.ps1 fails naming SHOT_HOST" 'Fail "no upload host: set SHOT_HOST' "$ps1"

# Criterion 2: README uses placeholders for host and user.
readme=$(cat README.md)
# Every /Users/ path and user@host in README.md uses the placeholders.
readme_users=$(grep -oE '/Users/[^/[:space:]`)]*' README.md | grep -vx '/Users/<user>')
assert_eq "README has no /Users/ path but /Users/<user>" "" "$readme_users"
readme_hosts=$(grep -oE '[A-Za-z0-9._<>-]+@[A-Za-z0-9._<>-]+' README.md | grep -vx '<user>@<mac-host>')
assert_eq "README has no user@host but the placeholder" "" "$readme_hosts"
assert_contains "README shows a host placeholder" "<user>@<mac-host>" "$readme"

# Review finding SD-1: the real macOS user and host label appear nowhere in
# tracked files, this test included. The needles are built from parts so this
# file does not publish them either.
u=mi; u="${u}ni"
leak="${u}s-mac|${u}@|/Users/${u}"
assert_eq "git grep for the real user and host finds nothing" "" "$(git grep -nE "$leak")"

finish

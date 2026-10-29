#!/usr/bin/env bash
# ELI-752: mac/screenshot-receive stores one PNG of at most 50 MB and prunes
# PNGs older than 30 days. Runs in a temp HOME.
cd "$(dirname "$0")/.." || exit 1
. tests/lib.sh

RECV="$PWD/mac/screenshot-receive"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
H="$T/home"
D="$H/screenshots"
mkdir -p "$H" "$T/bin"

# Fake date so two uploads get the same timestamp.
cat > "$T/bin/date" <<'EOF'
#!/usr/bin/env bash
echo 2026-01-02_030405
EOF
chmod +x "$T/bin/date"

recv() {  # tag; stdin is the upload
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" bash "$RECV" "$@" 2>&1
}
count_files() { find "$D" -type f 2>/dev/null | wc -l | tr -d ' '; }

png() {  # size in bytes: PNG signature padded with zeros
  { printf '\x89PNG\r\n\x1a\n'; head -c $(($1 - 8)) /dev/zero; }
}

assert_eq "receiver is executable" "yes" "$([ -x "$RECV" ] && echo yes || echo no)"

# Criterion 2: a non-PNG is rejected and nothing is stored.
out=$(printf 'GIF89a not a png at all' | recv cachy); rc=$?
assert_eq "non-PNG exits 1" "1" "$rc"
assert_contains "non-PNG message" "not a PNG" "$out"
assert_eq "non-PNG stores nothing" "0" "$(count_files)"

out=$(printf '' | recv cachy); rc=$?
assert_eq "empty upload exits 1" "1" "$rc"
assert_eq "empty upload stores nothing" "0" "$(count_files)"

# Criterion 2: a file over 50 MB is rejected and nothing is left behind.
out=$(png 52428801 | recv cachy); rc=$?
assert_eq "over 50 MB exits 1" "1" "$rc"
assert_contains "over 50 MB message" "50 MB" "$out"
assert_eq "over 50 MB stores nothing" "0" "$(count_files)"

# Exactly 50 MB is allowed.
out=$(png 52428800 | recv win); rc=$?
assert_eq "exactly 50 MB exits 0" "0" "$rc"
assert_eq "exactly 50 MB stored" "$D/2026-01-02_030405-win.png" "$out"
rm -f "$D"/*.png

# A valid PNG is stored under the timestamp name and the path is printed.
png 100 > "$T/small.png"
out=$(recv cachy < "$T/small.png"); rc=$?
assert_eq "valid PNG exits 0" "0" "$rc"
assert_eq "valid PNG path printed" "$D/2026-01-02_030405-cachy.png" "$out"
assert_eq "stored bytes match" "yes" "$(cmp -s "$T/small.png" "$D/2026-01-02_030405-cachy.png" && echo yes || echo no)"

# A second upload in the same second gets -2, a third -3.
out=$(recv cachy < "$T/small.png")
assert_eq "collision gets -2" "$D/2026-01-02_030405-cachy-2.png" "$out"
out=$(recv cachy < "$T/small.png")
assert_eq "collision gets -3" "$D/2026-01-02_030405-cachy-3.png" "$out"
assert_eq "no temp files left" "3" "$(count_files)"

# The tag must be a plain word.
out=$(recv '../x' < "$T/small.png"); rc=$?
assert_eq "path tag rejected" "1" "$rc"
out=$(recv < "$T/small.png"); rc=$?
assert_eq "missing tag rejected" "1" "$rc"
assert_eq "bad tags store nothing" "3" "$(count_files)"

# Criterion 2: PNGs older than 30 days are removed on upload, newer ones and
# other files stay.
rm -f "$D"/*.png
png 100 > "$D/old.png";   touch -d '31 days ago' "$D/old.png"
png 100 > "$D/recent.png"; touch -d '29 days ago' "$D/recent.png"
echo keep > "$D/notes.txt"; touch -d '60 days ago' "$D/notes.txt"
recv cachy < "$T/small.png" > /dev/null
assert_eq "31-day-old PNG removed" "no" "$([ -e "$D/old.png" ] && echo yes || echo no)"
assert_eq "29-day-old PNG kept" "yes" "$([ -e "$D/recent.png" ] && echo yes || echo no)"
assert_eq "old non-PNG kept" "yes" "$([ -e "$D/notes.txt" ] && echo yes || echo no)"

# Criterion 3: README links the receiver script.
assert_contains "README links the receiver" "(mac/screenshot-receive)" "$(cat README.md)"

finish

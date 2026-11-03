#!/usr/bin/env bash
#
# hooks_test.sh — regression tests for the kit's hooks, their list reader, the tree scan and the history audit.
#
#   tests/hooks_test.sh [ROOT]    ROOT = a checkout of this kit, or of a project spawned from it
#                                 (default: the one holding this file)
#
# This suite ships in every install and tests what ships: the hooks, their list reader, the tree scan and the
# full-history identity check, bin/kit-history-audit (bin/kit-pin, the stub and the install are tests/install_test.sh's). Its fixtures are inline or synthetic,
# never the live CLAUDE.md, so it is green wherever it runs. The kit's own documents are tested by
# tests/kit_docs_test.sh, which stays in the kit (kit-manifest.txt).
#
# Plain bash on purpose. Needs bash, git, gitleaks and awk, plus the coreutils the hooks themselves
# use. Every case builds its own scratch repositories under a temp dir and uses a SYNTHETIC marker
# pattern -- never a real marker list, which is not in the repo and must never be.
#
# Hook LOGIC is tested from executable copies of ROOT's hooks, so a mode regression cannot mask a
# logic regression; tracked MODES are tested separately (M1).
#
# Exit 0 only when every case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
H="$ROOT/leak-detection"
command -v gitleaks >/dev/null 2>&1 || { echo "hooks_test: gitleaks is required" >&2; exit 1; }
BASH_BIN=$(command -v bash)
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

unset LEAK_PATTERN                          # a hook reads its list from the file at its place, never the environment
MARK='SYNTH-MARKER-7F3A'                    # synthetic identity marker for every case
Z=0000000000000000000000000000000000000000
PASS=0; FAIL=0; SKIP=0

# A counted skip, never a silent one: the summary line carries the number, and each skipped case
# says what would let it run. Skips do not fail the suite, and they do not count as passes.
skip() { SKIP=$((SKIP+1)); printf 'skip  %s  -- %s\n' "$1" "$2"; }
result() { if [[ $2 -eq 0 ]]; then PASS=$((PASS+1)); printf 'ok    %s\n' "$1"
           else FAIL=$((FAIL+1)); printf 'FAIL  %s  -- %s\n' "$1" "$3"; fi; }
# want_ok NAME RC OUTPUT [NEEDLE] / want_refused NAME RC OUTPUT NEEDLE: a refusal must be for the
# stated reason -- a red for the wrong reason reads exactly like a red for the right one.
want_ok() { if [[ $2 -eq 0 && ( -z "${4:-}" || "$3" == *"$4"* ) ]]; then result "$1" 0
            else result "$1" 1 "exit $2${4:+, want '$4'}: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-160)"; fi; }
want_refused() { if [[ $2 -ne 0 && "$3" == *"$4"* ]]; then result "$1" 0
                 else result "$1" 1 "exit $2, want refusal '$4': $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-160)"; fi; }
# want_says NAME RC OUTPUT LINE...: a refusal (RC non-zero) whose output holds each LINE: the lines a refusal adds after
# its first, each labelled for who acts on it ("You can:", "If IT manages this machine:", "The project's owner:"), in
# the do-not-publish wording.
want_says() { local n=$1 rc=$2 o=$3 l miss=""; shift 3
              for l in "$@"; do [[ "$o" == *"$l"* ]] || miss="$miss '$l'"; done
              if [[ $rc -ne 0 && -z "$miss" ]]; then result "$n" 0
              else result "$n" 1 "exit $rc, want a refusal saying$miss: $(printf '%s' "$o" | tr '\n' ' ' | cut -c1-160)"; fi; }
no_leak() { if [[ "$2" == *SYNTH-MARKER* ]]; then result "$1" 1 "output quotes the pattern"; else result "$1" 0; fi; }
# no_leak_at NAME STDOUT STDERR: no_leak over each stream apart; a red names the stream, the line number and the line,
# the marker shown as <M> and every byte outside printable ASCII as ?.
no_leak_at() {
    local s text line n where=""
    for s in stdout stderr; do
        if [[ $s == stdout ]]; then text=$2; else text=$3; fi
        n=0
        while IFS= read -r line; do
            n=$((n + 1))
            [[ "$line" == *SYNTH-MARKER* ]] || continue
            line=${line//$MARK/<M>}; line=${line//SYNTH-MARKER/<M>}
            where+="$s line $n: $(printf '%s' "$line" | LC_ALL=C tr -c '[:print:]' '?' | LC_ALL=C cut -c1-140); "
        done <<<"$text"
    done
    if [[ -n "$where" ]]; then result "$1" 1 "the marker is in $where"; else result "$1" 0; fi; }
# A refusal says what to fix, never "--no-verify": that flag skips every check, so a hook that
# offers it as the way on invites the one step that switches off the scans for the whole push.
no_bypass() { if [[ "$2" == *--no-verify* ]]; then result "$1" 1 "the refusal suggests --no-verify"; else result "$1" 0; fi; }
# want_split NAME RC OUTPUT: a sandbox refusal's two lines split who acts: "You can:" covers
# only a read block the person set themselves, adding the folder in their user settings; "If IT manages this
# machine:" says a sandbox read policy may block it, and to ask IT rather than change it in their own settings.
want_split() { local you="" it="" l
               while IFS= read -r l; do case "$l" in "  You can:"*) you+=$l ;; "  If IT manages this machine:"*) it+=$l ;; esac; done <<< "$3"
               if [[ $2 -ne 0 && "$you" == *"you set yourself"* && "$you" == *"sandbox.filesystem.allowRead in your user settings"* \
                     && "$you" != *"IT's settings allow"* && "$it" == *"sandbox read policy may block"* \
                     && "$it" == *"rather than changing it in your own settings"* ]]; then result "$1" 0
               else result "$1" 1 "exit $2: you [$(echo $you | cut -c1-140)] it [$(echo $it | cut -c1-140)]"; fi; }

# A project's list lives under the home folder the user database gives, never $HOME's (the gates skill, procedure 13).
# Every copy of the reader this suite runs is rswap's: kit_list_home's body alone swapped for this suite's scratch
# home, TH (MS41's after the shipped routine's python3 check), so no case reads or writes the real one; LH7 reads the shipped routine against the user database, read-only,
# and LH8 checks each copy differs from the shipped reader in that body only. A copy whose swap didn't take would send
# a case to the real home, so rswap stops the suite before it runs one.
TH="$TMP/home"; mkdir -p "$TH"
rswap() {  # SRC DST: SRC, kit_list_home's body swapped for printing TH; a SRC with no kit_list_home is copied as it is
    RS_BODY="    printf '%s\\n' '$TH'   # a suite's test copy: its scratch home" \
        awk '/^kit_list_home\(\) \{/ {print; print ENVIRON["RS_BODY"]; s=1; next} s && /^\}/ {s=0} !s {print}' "$1" > "$2" || exit 1
    chmod 0644 "$2"
    "$BASH_BIN" --norc --noprofile -c '. "$1" && declare -F kit_list_home' _ "$1" >/dev/null 2>&1 || return 0
    [[ "$("$BASH_BIN" --norc --noprofile -c '. "$1" && kit_list_home' _ "$2" 2>/dev/null)" == "$TH" ]] \
        || { echo "hooks_test: the reader copy $2 doesn't find its home in the scratch home; stopping before any case" >&2; exit 1; }
}

# Executable copies of the hooks under test, plus a variant with a malformed allowlist.
HK="$TMP/hooks"; HKB="$TMP/hooks-badallow"; mkdir -p "$HK" "$HKB"
for h in pre-commit pre-push; do
    [[ -f "$H/$h" ]] && install -m 0755 "$H/$h" "$HK/$h"
    [[ -f "$H/$h" ]] && sed "s/^ALLOW=.*/ALLOW='(unclosed'/" "$H/$h" > "$HKB/$h" && chmod 0755 "$HKB/$h"
done
for d in "$HK" "$HKB"; do   # pre-push finds both beside itself
    [[ -f "$H/scan-binaries.py" ]] && cp "$H/scan-binaries.py" "$d/"
    # The scan's own rules sit beside it, as in an install (BC1 to BC4).
    [[ -f "$H/spawn.gitleaks.toml" ]] && cp "$H/spawn.gitleaks.toml" "$d/"
    # Writable whatever the source's mode, so EG6 can plant into a copy of it under a read-only install.
    [[ -f "$H/read-leak-pattern.sh" ]] && rswap "$H/read-leak-pattern.sh" "$d/read-leak-pattern.sh"
done
# MS41's hooks: kit_list_home keeps the shipped routine's first line, so with no python3 the place fails as the shipped
# one does, and with python3 it gives TH; no case reaches the real home either way. LH8 checks it with the others.
HKP="$TMP/hooks-pycheck"; mkdir -p "$HKP"; [[ -f "$H/pre-push" ]] && install -m 0755 "$H/pre-push" "$HKP/pre-push"
for f in scan-binaries.py spawn.gitleaks.toml; do [[ -f "$H/$f" ]] && cp "$H/$f" "$HKP/"; done
if [[ -f "$H/read-leak-pattern.sh" ]]; then
    RS_BODY="    command -v python3 >/dev/null 2>&1 || return 1
    printf '%s\\n' '$TH'   # a suite's test copy: the shipped routine's python3 check, then its scratch home" \
        awk '/^kit_list_home\(\) \{/ {print; print ENVIRON["RS_BODY"]; s=1; next} s && /^\}/ {s=0} !s {print}' \
        "$H/read-leak-pattern.sh" > "$HKP/read-leak-pattern.sh" || exit 1
    ! command -v python3 >/dev/null 2>&1 \
        || [[ "$("$BASH_BIN" --norc --noprofile -c '. "$1" && kit_list_home' _ "$HKP/read-leak-pattern.sh" 2>/dev/null)" == "$TH" ]] \
        || { echo "hooks_test: the reader copy $HKP doesn't find its home in the scratch home; stopping before any case" >&2; exit 1; }
fi
# MS43's hooks: kit_list_home keeps the shipped routine's python3 check, then fails as the shipped routine does where
# python3 runs but the user database gives no usable home (LH11 shows it does); no case reaches any home. LH8 checks it.
HKU="$TMP/hooks-nohome"; mkdir -p "$HKU"; [[ -f "$H/pre-push" ]] && install -m 0755 "$H/pre-push" "$HKU/pre-push"
for f in scan-binaries.py spawn.gitleaks.toml; do [[ -f "$H/$f" ]] && cp "$H/$f" "$HKU/"; done
if [[ -f "$H/read-leak-pattern.sh" ]]; then
    RS_BODY="    command -v python3 >/dev/null 2>&1 || return 1
    return 1   # a suite's test copy: python3 is there, and the user database gives no usable home" \
        awk '/^kit_list_home\(\) \{/ {print; print ENVIRON["RS_BODY"]; s=1; next} s && /^\}/ {s=0} !s {print}' \
        "$H/read-leak-pattern.sh" > "$HKU/read-leak-pattern.sh" || exit 1
    [[ -z "$("$BASH_BIN" --norc --noprofile -c '. "$1" && kit_list_home' _ "$HKU/read-leak-pattern.sh" 2>/dev/null)" ]] \
        || { echo "hooks_test: the reader copy $HKU gives a home; stopping before any case" >&2; exit 1; }
fi

# PATHs without git (symlinks to the few tools the hooks need before they look for git), and without gitleaks or
# python3: a link to the first command of each name on PATH but the ones left out. Git Bash runs name.exe as name, so
# a name is left out with its .exe; and on Windows git started from a folder of a few links exits 127 without a word,
# so those two folders hold every command. One ln per folder of PATH: on Windows each process
# start costs, and a link per command took about 3 minutes a folder.
mkbin() { mkdir -p "$1"; shift; local t p; for t in "$@"; do p=$(command -v "$t") && ln -sf "$p" "$BIN/$t"; done; }
pathless() {   # DIR NAME...: links in DIR to the first command of each name on PATH, except each NAME and NAME.exe
    local dir=$1 d f n i; local -a dirs add; shift; mkdir -p "$dir"
    IFS=: read -ra dirs <<< "$PATH"
    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] || continue
        add=()
        for f in "$d"/*; do
            n=${f##*/}
            [[ -f "$f" && -x "$f" && ! -e "$dir/$n" && ! -L "$dir/$n" ]] || continue
            [[ " $* " == *" ${n%.exe} "* ]] || add+=("$f")
        done
        for (( i = 0; i < ${#add[@]}; i += 500 )); do ln -s "${add[@]:i:500}" "$dir/"; done
    done
}
BIN="$TMP/nogit";  mkbin "$BIN" bash grep head awk sort sed tr cut cat wc env
pathless "$TMP/nogl" gitleaks
pathless "$TMP/nopy" python3

# A list's pin: its rows and the SHA-256 of its value. The suite writes its own pins, with a
# row count it knows, so a counting fault in the hooks can't agree with itself.
tsum() { local s; if command -v sha256sum >/dev/null 2>&1; then s=$(sha256sum); else s=$(shasum -a 256); fi; printf '%s' "${s%% *}"; }
tpin() { mkdir -p "${1%/*}"; printf '# a test pin\nrows=%s\nsha256=%s\n' "$3" "$(printf '%s' "$2" | tsum)" > "$1"; }   # PINFILE VALUE ROWS
# A project's list is one file in TH's lists folder, named by the project's kit.list-id (the LH cases); its pin stays in
# .git. mk_repo gives every repository an id of its own, so lp names where its list goes.
LHL="$TH/.config/morrowcairn/lists"; mkdir -p "$LHL"; chmod 700 "$TH/.config/morrowcairn" "$LHL"
lid() { od -An -tx1 -N16 /dev/urandom | tr -d ' \n'; }                     # a fresh list id: 32 hex digits
lp() { printf '%s/%s' "$LHL" "$(cat "$1/kit.list-id")"; }                   # DIR: where DIR's list lives in TH
mk_repo() {  # DIR [HOOKSDIR]: with a list id, the suite's one-row list at its place, and its pin in .git
    git init -q "$1"
    git -C "$1" config user.name hooks-test; git -C "$1" config user.email hooks-test@invalid.local
    git -C "$1" config core.hooksPath "${2:-$HK}"
    [[ -f "$ROOT/.gitleaks.toml" ]] && cp "$ROOT/.gitleaks.toml" "$1/"
    printf '%s\n' "$(lid)" > "$1/kit.list-id"
    tlist "$1" "$MARK"
}
tlist() {  # DIR VALUE [ROWS]: DIR's list at its place set to VALUE, and its pin to match
    (umask 077 && printf "LEAK_PATTERN='%s'\n" "$2" > "$(lp "$1")"); tpin "$1/.git/leak-pattern.pin" "$2" "${3:-1}"; }
commit() { git -C "$1" add -A && git -C "$1" commit -q --no-verify -m "$2"; }
chk() {  # DIR NAME EXIT [BODY]  -- write an executable check that runs BODY, then exits EXIT
    mkdir -p "$1"; printf '#!/usr/bin/env bash\n%s\nexit %s\n' "${4:-:}" "$3" > "$1/$2"; chmod +x "$1/$2"; }
# FILE: an entry that would pass if run (exit 0), not executable: 0 when the file system says so. Git Bash reads a
# file's execute bit from a #! first line, whatever chmod says, so the entry has none.
nonexec() { mkdir -p "${1%/*}"; printf 'exit 0\n' > "$1"; chmod a-x "$1"; [[ ! -x "$1" ]]; }

# Synthetic images, written byte for byte at run time: nothing binary is committed to the kit.
# Payloads are printf %b strings, or files (the *f forms). PNG CRCs are placeholders: the binary
# scan reads chunk types and lengths, never CRCs or pixels.
be32() { printf '\\x%02x\\x%02x\\x%02x\\x%02x' $(($1>>24&255)) $(($1>>16&255)) $(($1>>8&255)) $(($1&255)); }
le32() { printf '\\x%02x\\x%02x\\x%02x\\x%02x' $(($1&255)) $(($1>>8&255)) $(($1>>16&255)) $(($1>>24&255)); }
pngcf() { printf '%b' "$(be32 $(($(wc -c < "$3"))))$2" >> "$1"; cat "$3" >> "$1"; printf '\0\0\0\0' >> "$1"; }  # FILE TYPE PAYLOAD-FILE
pngc()  { printf '%b' "$3" > "$TMP/chunk.payload"; pngcf "$1" "$2" "$TMP/chunk.payload"; }                      # FILE TYPE PAYLOAD
mkpng() {  # FILE [IDAT-PAYLOAD] [EXTRA-TYPE EXTRA-PAYLOAD]: IHDR, the extra chunk if any, IDAT, IEND
    printf '%b' '\x89PNG\r\n\x1a\n' > "$1"; pngc "$1" IHDR '\x00\x00\x00\x02\x00\x00\x00\x02\x08\x02\x00\x00\x00'
    if [[ -n "${3:-}" ]]; then pngc "$1" "$3" "$4"; fi
    pngc "$1" IDAT "${2:-\x78\x9c\x63\x60}"; pngc "$1" IEND ''; }
mkpngf() { printf '%b' '\x89PNG\r\n\x1a\n' > "$1"; pngc "$1" IHDR '\x00\x00\x00\x02\x00\x00\x00\x02\x08\x02\x00\x00\x00'
           pngcf "$1" IDAT "$2"; pngc "$1" IEND ''; }                                  # FILE IDAT-PAYLOAD-FILE
mkjpg() {  # FILE [EXTRA-SEGMENT] [SOF-BYTE] [SCAN-DATA]: SOI, 16-byte JFIF APP0, the extra, DQT, SOFn (default
           # SOF2), DHT, SOS, the scan data, EOI. Segments and data are printf %b strings, markers included.
    printf '%b' '\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00' > "$1"
    if [[ -n "${2:-}" ]]; then printf '%b' "$2" >> "$1"; fi
    printf '%b' "\\xff\\xdb\\x00\\x05\\x00\\x01\\x02\\xff\\x${3:-c2}\\x00\\x0b\\x08\\x00\\x02\\x00\\x02\\x01\\x01\\x11\\x00" >> "$1"
    printf '%b' '\xff\xc4\x00\x05\x00\x01\x02\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00' >> "$1"
    printf '%b' "${4:-\\x12\\x34\\x56}" '\xff\xd9' >> "$1"; }
mkwebp() {  # FILE [EXTRA-CHUNK, header included]: RIFF/WEBP with VP8X and VP8, the extra after them
    printf '%b' 'WEBPVP8X\x0a\x00\x00\x00\x10\x00\x00\x00\x01\x00\x00\x01\x00\x00VP8 \x04\x00\x00\x00\x9d\x01\x2a\x00' > "$TMP/webp.body"
    if [[ -n "${2:-}" ]]; then printf '%b' "$2" >> "$TMP/webp.body"; fi
    { printf 'RIFF'; printf '%b' "$(le32 $(($(wc -c < "$TMP/webp.body"))))"; cat "$TMP/webp.body"; } > "$1"; }
# Synthetic video, the same way. Boxes and elements are printf %b strings, nested by composition:
# mbox TYPE PAYLOAD prints an MP4 box, eel ID PAYLOAD a WebM element (ID as %b bytes, the size as a
# 1-byte vint below 127 and an 8-byte one above, so both forms are read). z N prints N zero bytes.
blen() { printf '%b' "$1" | wc -c; }
z() { local i s=; for ((i = 0; i < $1; i++)); do s+='\x00'; done; printf '%s' "$s"; }
mbox() { printf '%s%s%s' "$(be32 $(( $(blen "$2") + 8 )))" "$1" "$2"; }
eel() { local n; n=$(blen "$2")
        if (( n < 127 )); then printf '%s\\x%02x%s' "$1" $((0x80 | n)) "$2"; else printf '%s\\x01\\x00\\x00\\x00%s%s' "$1" "$(be32 "$n")" "$2"; fi; }
mkmp4() {  # FILE: ftyp; moov (mvhd, one video trak, udta/meta with an empty ilst); free; mdat. A caller varies
           # one part for one call by setting M_FTYP, M_MVHD, M_HDLR (the handler name), M_URL, M_CNAME (the
           # 32-byte compressor-name field), M_COLR, M_TRAKX (appended in the trak), M_TRAK (appended in moov),
           # M_ILST, M_FREE, M_MDAT or M_TOP (appended after mdat).
    local avc1 stbl trak meta moov
    avc1="$(z 6)\x00\x01$(z 16)\x00\x10\x00\x10\x00\x48\x00\x00\x00\x48\x00\x00$(z 4)\x00\x01"
    avc1+="${M_CNAME:-\x0cLavc libx264$(z 19)}\x00\x18\xff\xff"
    avc1+="$(mbox avcC '\x01\x64\x00\x1f\xff\xe1\x00\x04\x67\x64\x00\x1f\x01\x00\x04\x68\xeb\xe3\xcb')"
    avc1+="${M_COLR:-$(mbox colr 'nclx\x00\x01\x00\x01\x00\x01\x00')}$(mbox btrt "$(z 12)")"
    stbl="$(mbox stsd "$(z 4)\x00\x00\x00\x01$(mbox avc1 "$avc1")")"
    stbl+="$(mbox stts "$(z 4)\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x02\x00")$(mbox stss "$(z 4)\x00\x00\x00\x01\x00\x00\x00\x01")"
    stbl+="$(mbox ctts "$(z 4)\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x04\x00")"
    stbl+="$(mbox stsc "$(z 4)\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01")"
    stbl+="$(mbox stsz "$(z 8)\x00\x00\x00\x01\x00\x00\x00\x08")$(mbox stco "$(z 4)\x00\x00\x00\x01\x00\x00\x00\x30")"
    trak="$(mbox tkhd "\x00\x00\x00\x03$(z 80)")"
    trak+="$(mbox edts "$(mbox elst "$(z 4)\x00\x00\x00\x01\x00\x00\x07\xfa\x00\x00\x04\x00\x00\x01\x00\x00")")"
    trak+="$(mbox mdia "$(mbox mdhd "$(z 12)\x00\x00\x30\x00\x00\x00\x62\x00\x55\xc4\x00\x00")$(mbox hdlr "$(z 8)vide$(z 12)${M_HDLR-VideoHandler\x00}")$(
             mbox minf "$(mbox vmhd "\x00\x00\x00\x01$(z 8)")$(mbox dinf "$(mbox dref "$(z 4)\x00\x00\x00\x01$(mbox 'url ' "${M_URL:-\x00\x00\x00\x01}")")")$(mbox stbl "$stbl")")")"
    meta="$(mbox meta "$(z 4)$(mbox hdlr "$(z 8)mdirappl$(z 9)")$(mbox ilst "${M_ILST:-}")")"
    moov="$(mbox mvhd "${M_MVHD:-$(z 12)\x00\x00\x03\xe8$(z 84)}")$(mbox trak "$trak${M_TRAKX:-}")${M_TRAK:-}$(mbox udta "$meta")"
    printf '%b' "${M_FTYP:-$(mbox ftyp 'isom\x00\x00\x02\x00isomiso2avc1mp41')}$(mbox moov "$moov")${M_FREE-$(mbox free '')}$(
        mbox mdat "${M_MDAT:-\x00\x00\x00\x04\x65\x88\x84\x00}")${M_TOP:-}" > "$1"; }
mkwebm() {  # FILE: the EBML header; a Segment of SeekHead, Void, Info, Tracks (one video track), Tags (one Tag:
            # ENCODER and DURATION), a Cluster and Cues. A caller varies one part for one call by setting W_DOCTYPE,
            # W_VOID, W_MUX, W_WRITE, W_INFO (appended in Info), W_TRACK (appended in the TrackEntry), W_TRACKS
            # (appended in Tracks, after the TrackEntry), W_ENC (the
            # ENCODER value), W_TAG (appended in the Tag), W_BLOCK, W_CLUSTER (appended in the Segment after the
            # Cluster, e.g. a second one) or W_SEG (appended in the Segment, last).
    local head seg track tag
    head="$(eel '\x42\x86' '\x01')$(eel '\x42\xf7' '\x01')$(eel '\x42\xf2' '\x04')$(eel '\x42\xf3' '\x08')"
    head+="$(eel '\x42\x82' "${W_DOCTYPE:-webm}")$(eel '\x42\x87' '\x02')$(eel '\x42\x85' '\x02')"
    seg="$(eel '\x11\x4d\x9b\x74' "$(eel '\x4d\xbb' "$(eel '\x53\xab' '\x15\x49\xa9\x66')$(eel '\x53\xac' '\xa1')")")"
    seg+="$(eel '\xec' "${W_VOID:-$(z 12)}")"
    seg+="$(eel '\x15\x49\xa9\x66' "$(eel '\x2a\xd7\xb1' '\x0f\x42\x40')$(eel '\x4d\x80' "${W_MUX:-Lavf}")$(eel '\x57\x41' "${W_WRITE:-Lavf}")$(
             eel '\x44\x89' '\x40\x9f\xe8\x00\x00\x00\x00\x00')${W_INFO:-}")"
    track="$(eel '\xd7' '\x01')$(eel '\x73\xc5' "$(z 7)\x01")$(eel '\x9c' '\x00')$(eel '\x22\xb5\x9c' 'und')$(eel '\x86' 'V_VP9')"
    track+="$(eel '\x83' '\x01')$(eel '\x23\xe3\x83' '\x02\x7b\xc8\x6a')$(eel '\xe0' "$(eel '\xb0' '\x01\x50')$(eel '\xba' '\x01\xa4')$(
             eel '\x9a' '\x02')$(eel '\x55\xb0' "$(eel '\x55\xba' '\x01')$(eel '\x55\xb1' '\x01')$(eel '\x55\xbb' '\x01')$(
             eel '\x55\xb9' '\x01')$(eel '\x55\xb7' '\x01')$(eel '\x55\xb8' '\x02')")")${W_TRACK:-}"
    seg+="$(eel '\x16\x54\xae\x6b' "$(eel '\xae' "$track")${W_TRACKS:-}")"
    tag="$(eel '\x63\xc0' "$(eel '\x63\xc5' "$(z 7)\x01")")$(eel '\x67\xc8' "$(eel '\x45\xa3' 'ENCODER')$(eel '\x44\x87' "${W_ENC:-Lavc libvpx-vp9}")")"
    tag+="$(eel '\x67\xc8' "$(eel '\x45\xa3' 'DURATION')$(eel '\x44\x87' '00:00:02.042000000\x00')")${W_TAG:-}"
    seg+="$(eel '\x12\x54\xc3\x67' "$(eel '\x73\x73' "$tag")")"
    seg+="$(eel '\x1f\x43\xb6\x75' "$(eel '\xe7' '\x00')$(eel '\xa3' "${W_BLOCK:-\x81\x00\x00\x80\x82\x49\x83\x42\x00}")")${W_CLUSTER:-}"
    seg+="$(eel '\x1c\x53\xbb\x6b' "$(eel '\xbb' "$(eel '\xb3' '\x00')$(eel '\xb7' "$(eel '\xf7' '\x01')$(eel '\xf1' '\x01\x7f')$(eel '\xf0' '\x03')")")")"
    printf '%b' "$(eel '\x1a\x45\xdf\xa3' "$head")$(eel '\x18\x53\x80\x67' "$seg${W_SEG:-}")" > "$1"; }
LIST=records/reviewed_binaries.txt
review() {  # PATH...: add each file's blob id to the reviewed list in the working tree of $C
    local p; mkdir -p "$C/records"
    for p in "$@"; do printf '%s  %s  2026-09-26  hooks-test  synthetic fixture\n' "$(git -C "$C" hash-object "$C/$p")" "$p" >> "$C/$LIST"; done; }
FIXTURE="$ROOT/leak-detection/fixtures/synthetic_config.txt"

# ============================== pre-push, identity layer ========================================
R="$TMP/l1"; mk_repo "$R"; echo "plain text" > "$R/a.txt"; commit "$R" base
git init -q --bare "$TMP/l1.git"; git -C "$R" push -q --no-verify "$TMP/l1.git" HEAD:refs/heads/main
SHA=$(git -C "$R" rev-parse HEAD)
# The stdin protocol's ref lines go to a file first and reach the hook by redirection, here and in every helper below,
# never through a pipe: a hook that refuses before reading them can't cut a producer off, so no case's status races.
direct() {  # HOOK SHA [PATTERN] [PATH]  -- the pre-push stdin protocol, no push; the pattern the list at its place
    tlist "$R" "${3:-$MARK}"
    (cd "$R" && printf 'refs/heads/main %s refs/heads/main %s\n' "$2" "$Z" > "$TMP/pp.in" \
        && env PATH="${4:-$PATH}" "$BASH_BIN" "$1" r "$TMP/l1.git" 2>&1 < "$TMP/pp.in"); }
out=$(direct "$HK/pre-push" "$SHA");                    want_ok      "L1 identity: clean tree passes" $? "$out"
echo "has $MARK here" > "$R/m.txt"; commit "$R" marker; MSHA=$(git -C "$R" rev-parse HEAD)
out=$(direct "$HK/pre-push" "$MSHA");                   want_refused "L2 identity: marker in tree is blocked" $? "$out" "listed terms"
out=$(direct "$HK/pre-push" 1111111111111111111111111111111111111111)
                                                        want_refused "L3 identity: unreadable commit refuses" $? "$out" "could not be read"
out=$(direct "$HK/pre-push" "$SHA" "$MARK(");  rc=$?;   want_refused "L4 identity: malformed pattern refuses" $rc "$out" "did not compile"
                                                        no_leak      "L4b identity: refusal does not quote the pattern" "$out"
out=$(direct "$HK/pre-push" "$SHA" "$MARK" "$TMP/nogit"); want_refused "L5 identity: git off PATH refuses" $? "$out" "git was not found"
out=$(direct "$HKB/pre-push" "$MSHA");                  want_refused "L6 identity: malformed ALLOW with a marker refuses" $? "$out" "allowlist filter did not run"
# A block's output reaches the terminal and an agent's transcript, so it names each hit's file and line and never the
# matched text; a file whose own name matches the list is named only as such.
out=$(direct "$HK/pre-push" "$MSHA"); rc=$?;            want_refused "L7 identity: a block still refuses, and names the file and line" $rc "$out" "m.txt:1"
                                                        no_leak      "L7b identity: a block does not print the matched text" "$out"
echo "also $MARK here" > "$R/$MARK-named.txt"; commit "$R" named; NSHA=$(git -C "$R" rev-parse HEAD)
out=$(direct "$HK/pre-push" "$NSHA"); rc=$?;            want_refused "L8 identity: a hit in a file whose name matches the list still refuses" $rc "$out" "listed terms"
                                                        no_leak      "L8b identity: a block does not print a file name that matches the list" "$out"
# The same with invalid UTF-8 beside the marker in the name, which git prints raw with core.quotePath off: BSD grep in
# a UTF-8 locale missed the marker on such a line, so pre-push matches a name in two passes.
# The file goes into git's index only, never onto disk: a Mac's file system refuses such a name.
LI="$TMP/l9.index"; GIT_INDEX_FILE="$LI" git -C "$R" read-tree "$SHA"
blob=$(printf 'x %s\n' "$MARK" | git -C "$R" hash-object -w --stdin)
GIT_INDEX_FILE="$LI" git -C "$R" update-index --add --cacheinfo "100644,$blob,bad$(printf '\377\376')$MARK.txt"
BSHA=$(git -C "$R" commit-tree "$(GIT_INDEX_FILE="$LI" git -C "$R" write-tree)" -p "$SHA" -m badname)
git -C "$R" config core.quotePath false
# Its two streams apart, so a red names where the marker came from: the stream, the line and the line itself, the
# marker shown as <M> and every byte outside printable ASCII as ?.
tlist "$R" "$MARK"
l9o=$(cd "$R" && printf 'refs/heads/main %s refs/heads/main %s\n' "$BSHA" "$Z" > "$TMP/pp.in" \
      && "$BASH_BIN" "$HK/pre-push" r "$TMP/l1.git" 2>"$TMP/l9.err" < "$TMP/pp.in"); rc=$?; l9e=$(cat "$TMP/l9.err")
                                                        want_refused "L9 identity: a hit in a file whose name holds invalid UTF-8 beside the marker refuses" $rc "$l9o$l9e" "listed terms"
                                                        no_leak_at   "L9b identity: a block does not print that file name, printed raw (core.quotePath off)" "$l9o" "$l9e"
git -C "$R" config --unset core.quotePath
# A block names at most 40 hits and counts the rest, so a tree full of hits can't flood the terminal; it still refuses.
: > "$R/m41.txt"; for ((i = 1; i <= 41; i++)); do echo "line $i $MARK" >> "$R/m41.txt"; done; commit "$R" m41
M41=$(git -C "$R" rev-parse HEAD)
out=$(direct "$HK/pre-push" "$M41"); rc=$?; n=$(printf '%s\n' "$out" | awk '/^  .+:([0-9]+|binary)$/ { c++ } END { print c + 0 }')
[[ $rc -ne 0 && "$n" == 40 && "$out" == *"more matching lines"* ]]
                                                        want_ok      "L10 identity: a block with more than 40 hits refuses, names 40 and counts the rest" $? "exit $rc, $n named"
                                                        no_leak      "L10b identity: that block does not print the matched text" "$out"
git -C "$R" rm -q m41.txt; commit "$R" m41-gone

# ============================== pre-push, a bounded row's sides =================================
# A list row bounded on a side keeps a letter there from joining the term into another word, and lets anything
# else separate it: a digit, an underscore, punctuation, a line's start or end. The bound is (^|[^[:alpha:]]) on the
# left and ([^[:alpha:]]|$) on the right; the \b and [^[:alnum:]...] bounds it replaced let an ad hoc tag (a term run
# into a digit) and a snake_case name through. Stand-in rows for the sides the kit's list
# bounds a name on: both, left only, and right only after a path.
LB='(^|[^[:alpha:]])zqone([^[:alpha:]]|$)|(^|[^[:alpha:]])zqtwo([^[:alpha:]]|$)|(^|[^[:alpha:]])zqthree|/zqfour([^[:alpha:]]|$)'
LBR="$TMP/lb"; mk_repo "$LBR"; echo "plain text" > "$LBR/a.txt"; commit "$LBR" base; tlist "$LBR" "$LB" 4
git init -q --bare "$TMP/lb.git"; git -C "$LBR" push -q --no-verify "$TMP/lb.git" HEAD:refs/heads/main
lbeach() {  # WANT LINE...: each LINE alone in the tip's tree, pushed with the stand-in list; prints those not WANT
    local want=$1 l sha out rc bad=(); shift
    for l in "$@"; do
        printf '%s\n' "$l" > "$LBR/f.txt"; commit "$LBR" lb; sha=$(git -C "$LBR" rev-parse HEAD)
        out=$(cd "$LBR" && printf 'refs/heads/main %s refs/heads/main %s\n' "$sha" "$Z" > "$TMP/pp.in" \
              && "$BASH_BIN" "$HK/pre-push" r "$TMP/lb.git" 2>&1 < "$TMP/pp.in"); rc=$?
        if [[ $want == refused ]]; then [[ $rc -ne 0 && "$out" == *"listed terms in the tree"* ]] || bad+=("$l")
        else [[ $rc -eq 0 ]] || bad+=("$l"); fi
    done
    printf '%s' "${bad[*]}"; }
bad=$(lbeach refused zqone7 7zqone zqtwo7 7zqtwo 7zqthree /zqfour7)
[[ -z "$bad" ]];                                        want_ok      "LB1 bounded row: the term joined to a digit on a bounded side is blocked" $? "passed: $bad"
bad=$(lbeach refused zqone_x x_zqone zqtwo_x x_zqtwo x_zqthree /zqfour_x)
[[ -z "$bad" ]];                                        want_ok      "LB2 bounded row: the term joined to an underscore on a bounded side is blocked" $? "passed: $bad"
bad=$(lbeach passes zqonex xzqone zqtwox xzqtwo xzqthree /zqfourx)
[[ -z "$bad" ]];                                        want_ok      "LB3 bounded row: the term joined to a letter on a bounded side passes" $? "blocked: $bad"
bad=$(lbeach refused "a zqone here" zqone "a zqtwo here" zqtwo "a zqthree here" zqthree "at /zqfour/ here" /zqfour)
[[ -z "$bad" ]];                                        want_ok      "LB4 bounded row: the bare term is blocked" $? "passed: $bad"

# ============================== pre-push, an address row's sides ================================
# A number row is bounded by digits only: a digit beside the number joins it into a longer one, and anything else
# separates it, a full stop, a letter, an underscore, a line's start or end. The kit's
# address row once kept a full stop out of its bounds too, `[^0-9.]`, so an address ending a sentence or before a file
# extension passed (LA1 and LA2 red on that form). The stand-in is the row's form now. Every address is built at
# run time from RFC 5737's TEST-NET-1, so this file holds none.
LA='(^|[^0-9])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9]|$)'
LAD=$(printf '%s.%s.%s.%s' 192 0 2 $((100 + 23)))
LAR="$TMP/la"; mk_repo "$LAR"; echo "plain text" > "$LAR/a.txt"; commit "$LAR" base; tlist "$LAR" "$LA"
git init -q --bare "$TMP/la.git"; git -C "$LAR" push -q --no-verify "$TMP/la.git" HEAD:refs/heads/main
LABASE=$(git -C "$LAR" rev-parse HEAD)
laeach() {  # WANT LINE...: each LINE alone in the tip's tree, pushed with the address stand-in; prints those not WANT,
    local want=$1 l sha out rc bad=(); shift    # the address shown as <addr>, so a red quotes no address
    for l in "$@"; do
        printf '%s\n' "$l" > "$LAR/f.txt"; commit "$LAR" la; sha=$(git -C "$LAR" rev-parse HEAD)
        out=$(cd "$LAR" && printf 'refs/heads/main %s refs/heads/main %s\n' "$sha" "$Z" > "$TMP/pp.in" \
              && "$BASH_BIN" "$HK/pre-push" r "$TMP/la.git" 2>&1 < "$TMP/pp.in"); rc=$?
        if [[ $want == refused ]]; then [[ $rc -ne 0 && "$out" == *"listed terms in the tree"* ]] || bad+=("${l//$LAD/<addr>}")
        else [[ $rc -eq 0 ]] || bad+=("${l//$LAD/<addr>}"); fi
    done
    printf '%s' "${bad[*]}"; }
bad=$(laeach refused "reach it at $LAD.")
[[ -z "$bad" ]];                                        want_ok      "LA1 address row: an address ending a sentence is blocked" $? "passed: $bad"
bad=$(laeach refused "see $LAD.txt")
[[ -z "$bad" ]];                                        want_ok      "LA2 address row: an address before a file extension is blocked" $? "passed: $bad"
bad=$(laeach refused "$LAD is the host")
[[ -z "$bad" ]];                                        want_ok      "LA3 address row: an address at a line's start is blocked" $? "passed: $bad"
bad=$(laeach refused "the host is $LAD")
[[ -z "$bad" ]];                                        want_ok      "LA4 address row: an address at a line's end is blocked" $? "passed: $bad"
bad=$(laeach refused "$LAD")
[[ -z "$bad" ]];                                        want_ok      "LA5 address row: an address alone on a line is blocked" $? "passed: $bad"
bad=$(laeach refused "host$LAD" "${LAD}x")
[[ -z "$bad" ]];                                        want_ok      "LA6 address row: an address joined to a letter is blocked" $? "passed: $bad"
bad=$(laeach refused "host_$LAD" "${LAD}_a")
[[ -z "$bad" ]];                                        want_ok      "LA7 address row: an address joined to an underscore is blocked" $? "passed: $bad"
bad=$(laeach passes "${LAD}45" "45$LAD")
[[ -z "$bad" ]];                                        want_ok      "LA8 address row: a longer digit run passes" $? "blocked: $bad"
bad=$(laeach passes "$(printf '%s.%s.%s.%s' 192 1000 2 123)")
[[ -z "$bad" ]];                                        want_ok      "LA9 address row: a part with four digits passes" $? "blocked: $bad"
# A file of its own: a branch from the base holding PATH with TEXT, a final newline left off with nonl, pushed with the
# stand-in. pre-push reads no file name in its identity scan (its header); it reads one only to name a blocked file, and
# withholds a name the list matches, so a name holding an address is tested there. Prints the exit, whether the
# address shows in the output (named) or not (withheld), then the output with the address as <addr>.
lafile() {  # PATH TEXT [nonl]
    local sha out rc
    git -C "$LAR" checkout -q -B la-file "$LABASE"
    if [[ ${3:-} == nonl ]]; then printf '%s' "$2" > "$LAR/$1"; else printf '%s\n' "$2" > "$LAR/$1"; fi
    commit "$LAR" la-file; sha=$(git -C "$LAR" rev-parse HEAD)
    out=$(cd "$LAR" && printf 'refs/heads/main %s refs/heads/main %s\n' "$sha" "$Z" > "$TMP/pp.in" \
          && "$BASH_BIN" "$HK/pre-push" r "$TMP/la.git" 2>&1 < "$TMP/pp.in"); rc=$?
    git -C "$LAR" checkout -q -
    if [[ "$out" == *"$LAD"* ]]; then printf '%s named\n' "$rc"; else printf '%s withheld\n' "$rc"; fi
    printf '%s' "${out//$LAD/<addr>}"; }
la_blocked() { [[ "${1%% *}" != 0 && "$1" == *"listed terms in the tree"* ]]; }    # LAFILE-OUTPUT
out=$(lafile f.txt "host$LAD.");                        la_blocked "$out"
                                                        want_ok      "LA10 address row: an address with a letter before it and a full stop after it is blocked" $? "$out"
out=$(lafile f.txt "the host is $LAD" nonl);            la_blocked "$out"
                                                        want_ok      "LA11 address row: an address ending a file with no final newline is blocked" $? "$out"
out=$(lafile "$LAD.log" "see $LAD here");               la_blocked "$out" && [[ "$out" == *" withheld"$'\n'* && "$out" == *"file name withheld"* ]]
                                                        want_ok      "LA12 address row: a file whose name starts with an address is blocked, and its name withheld from the report" $? "$out"
out=$(lafile "$LAD" "see $LAD here");                   la_blocked "$out" && [[ "$out" == *" withheld"$'\n'* && "$out" == *"file name withheld"* ]]
                                                        want_ok      "LA13 address row: a file whose name is an address is blocked, and its name withheld from the report" $? "$out"

# ============================== pre-push, the list file read as data ============================
# pre-push reads its list from the file at the list's place, never from the environment. v0.6.0 ran that file as
# shell: an apostrophe in a term ended its quoting, and the rest ran as a command or quietly changed
# the list, and a second LEAK_PATTERN line silently dropped every term of the first. It is read as
# data now: blank lines, full-line comments, and one assignment in a shape the kit documents (the
# setup line's, or the export form in pre-push's header), with nothing after the closing quote.
# The reader is one file, leak-detection/read-leak-pattern.sh, which pre-push sources from beside itself and
# bin/kit-pin from the install it checks; v0.7.0 kept a copy in pre-push and in its installer, and LP0 compared the
# two. kit-pin is read where it ships beside the hooks (the kit, an install).
own='^[[:space:]]*(function[[:space:]]+)?read_leak_pattern[[:space:]]*\(\)'
! grep -qE "$own" "$H/pre-push" "$ROOT/bin/kit-pin" && grep -q 'read-leak-pattern\.sh' "$H/pre-push" \
    && grep -q 'read-leak-pattern\.sh' "$ROOT/bin/kit-pin"
                                                        want_ok      "LP0 pre-push and kit-pin hold no list reader of their own; both name the reader file" $? ""
LF="$TMP/lf"; mk_repo "$LF"; echo "plain text" > "$LF/a.txt"; commit "$LF" base
git init -q --bare "$TMP/lf.git"; git -C "$LF" push -q --no-verify "$TMP/lf.git" HEAD:refs/heads/main
LFBASE=$(git -C "$LF" rev-parse HEAD)
lfc() { git -C "$LF" checkout -q -B "$1" "$LFBASE"; printf '%s\n' "$2" > "$LF/f.txt"; commit "$LF" "$1"; git -C "$LF" rev-parse HEAD; }
LF_CLEAN=$(lfc clean "nothing listed here"); LF_MARK=$(lfc mark "has $MARK here"); LF_TWOQ=$(lfc twoq "has zq'ab'cterm here")
# A command named from list text: if the file is ever run as shell, this runs and leaves a trace.
FBIN="$TMP/listbin"; RAN="$TMP/list-text-ran"; mkdir -p "$FBIN"
printf '#!/bin/sh\ntouch "%s"\n' "$RAN" > "$FBIN/zqcmdz"; chmod +x "$FBIN/zqcmdz"
lfile() { if (( $# )); then printf '%s\n' "$@"; fi > "$(lp "$LF")"; }   # LINE...: the list file
fpush() {  # SHA  -- the pre-push stdin protocol, with the pattern from the list at its place only
    (cd "$LF" && printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$Z" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN PATH="$FBIN:$PATH" "$BASH_BIN" "$HK/pre-push" r "$TMP/lf.git" 2>&1 < "$TMP/pp.in"); }
SETUP="LEAK_PATTERN='$MARK'"; EXPORT="export LEAK_PATTERN='$MARK'"
NOTES=("# a note" "   # an indented note" "	# a tabbed note" "" " 	 ")
lfile "$SETUP"
out=$(fpush "$LF_MARK");                                want_refused "LP1 list file, setup form: a marker is blocked" $? "$out" "listed terms"
out=$(fpush "$LF_CLEAN");                               want_ok      "LP2 list file, setup form: a clean tree passes" $? "$out"
lfile "$EXPORT"
out=$(fpush "$LF_MARK");                                want_refused "LP3 list file, export form: a marker is blocked" $? "$out" "listed terms"
out=$(fpush "$LF_CLEAN");                               want_ok      "LP4 list file, export form: a clean tree passes" $? "$out"
lfile "${NOTES[@]}" "$SETUP	 " "${NOTES[@]}"
out=$(fpush "$LF_MARK");                                want_refused "LP5 list file, setup form among comments and blank lines: a marker is blocked" $? "$out" "listed terms"
out=$(fpush "$LF_CLEAN");                               want_ok      "LP6 list file, setup form among comments and blank lines: a clean tree passes" $? "$out"
lfile "${NOTES[@]}" "$EXPORT 	" "${NOTES[@]}"
out=$(fpush "$LF_MARK");                                want_refused "LP7 list file, export form among comments and blank lines: a marker is blocked" $? "$out" "listed terms"
out=$(fpush "$LF_CLEAN");                               want_ok      "LP8 list file, export form among comments and blank lines: a clean tree passes" $? "$out"
lfile
out=$(fpush "$LF_CLEAN");                               want_refused "LP9 list file: an empty file refuses" $? "$out" "not configured"
lfile "LEAK_PATTERN=''"
out=$(fpush "$LF_CLEAN");                               want_refused "LP10 list file: an empty assignment refuses" $? "$out" "not configured"
lfile "# only a note" ""
out=$(fpush "$LF_CLEAN");                               want_refused "LP11 list file: comments with no assignment refuse" $? "$out" "not configured"
lfile "LEAK_PATTERN='$MARK|zq'one'"
out=$(fpush "$LF_CLEAN");                               want_refused "LP12 list file: a term with one apostrophe refuses" $? "$out" "not a blank line"
rm -f "$RAN"; lfile "LEAK_PATTERN='$MARK|zq'w|zqcmd'z'"
out=$(fpush "$LF_CLEAN"); rc=$?;                        want_refused "LP13 list file: two terms with an apostrophe each refuse" $rc "$out" "not a blank line"
[[ ! -e "$RAN" ]];                                      want_ok      "LP13b list file: no list text runs as a command" $? "a command named from the list ran"
                                                        no_leak      "LP13c list file: the refusal does not quote the pattern" "$out"
                                                        no_bypass    "LP13d list file: the refusal does not offer --no-verify" "$out"
lfile "LEAK_PATTERN='$MARK|zq'ab'cterm'"
out=$(fpush "$LF_TWOQ");                                want_refused "LP14 list file: a term with two apostrophes refuses, not loads changed" $? "$out" "not a blank line"
lfile "LEAK_PATTERN='$MARK'" "LEAK_PATTERN='zqotherterm'"
out=$(fpush "$LF_MARK");                                want_refused "LP15 list file: a second assignment refuses, not drops the first's terms" $? "$out" "more than once"
lfile "$SETUP  # a trailing note"
out=$(fpush "$LF_CLEAN");                               want_refused "LP16 list file: a comment after the assignment refuses" $? "$out" "not a blank line"
lfile "  $SETUP"
out=$(fpush "$LF_CLEAN");                               want_refused "LP17 list file: an assignment not at the line's start refuses" $? "$out" "not a blank line"
rm -f "$(lp "$LF")"

# ============================== the list reader file ============================================
# leak-detection/read-leak-pattern.sh defines read_leak_pattern and read_leak_pattern_selftest and nothing
# else. A reader the hooks can't trust stops them before they read a list or scan anything: missing, not
# loading, short of a function, or failing its selftest: a reader in that state was cut or edited, and a
# scan run on a list read wrong would let through what the list exists to stop.
RD="$H/read-leak-pattern.sh"; RQ="$TMP/rdq"; RV="$TMP/readers"; mkdir -p "$RQ" "$RV"
# What sourcing leaves, measured against a bare shell that sourced an empty file the same way (the shell's
# own variables, PIPESTATUS among them, appear in both).
sourced() {  # FILE DIR
    mkdir -p "$2"; "$BASH_BIN" --norc --noprofile -c '. "$1" > "$2/out" 2>&1 || : > "$2/failed"
        compgen -v | sort > "$2/vars"; declare -F | sort > "$2/fns"' _ "$1" "$2" 2>/dev/null; }
: > "$RQ/empty.sh"; sourced "$RQ/empty.sh" "$RQ/e"; sourced "$RD" "$RQ/r"
[[ ! -e "$RQ/r/failed" && ! -s "$RQ/r/out" \
   && "$(cat "$RQ/r/fns")" == $'declare -f kit_list_file\ndeclare -f kit_list_home\ndeclare -f read_leak_pattern\ndeclare -f read_leak_pattern_selftest' ]] \
    && cmp -s "$RQ/e/vars" "$RQ/r/vars"
                                                        want_ok      "RF1 reader file: sourcing prints nothing, sets no variable and defines exactly its four functions" $? "$(cat "$RQ/r/out" "$RQ/r/fns" 2>/dev/null)"
out=$("$BASH_BIN" --norc --noprofile -c '. "$1" && read_leak_pattern_selftest' _ "$RD" 2>&1)
                                                        want_ok      "RF2 reader file: the selftest passes on the reader as shipped" $? "$out"
# The suite's own copy of the must-refuse set, so an edit to the reader file can't weaken its selftest and
# this test at once.
out=$("$BASH_BIN" --norc --noprofile -c '. "$1" || exit 2; shift
    for t in "$@"; do read_leak_pattern <(printf "%s\n" "$t") && { echo "accepted: list $((++n))"; exit 1; }; n=$((n + 1)); done' \
    _ "$RD" "LEAK_PATTERN='$MARK|zq'one'" "LEAK_PATTERN='$MARK|zq'w|zqcmd'z'" "LEAK_PATTERN='$MARK|zq'ab'cterm'" \
    "LEAK_PATTERN='$MARK'"$'\n'"LEAK_PATTERN='zqotherterm'" "$SETUP  # a trailing note" "  $SETUP" 2>&1)
                                                        want_ok      "RF3 reader file: the suite's own must-refuse set refuses" $? "$out"
                                                        no_leak      "RF3b reader file: that run does not print the pattern" "$out"
# Planted reshapes: the selftest must go red on each, and the reshaped file must still be a reader.
sed 's/(( at != 0 ))/(( 0 ))/' "$RD" > "$RV/twice.sh" 2>/dev/null                                   # a second assignment passes
sed 's/if \[\[ ! "\$line" =~ \$re \]\]; then/if false; then/' "$RD" > "$RV/shape.sh" 2>/dev/null    # no line refused for its shape
selftest_red() {  # FILE: 0 only if FILE differs from the reader, defines both functions, and its selftest fails
    [[ -f "$RD" ]] && ! cmp -s "$RD" "$1" || return 1
    "$BASH_BIN" --norc --noprofile -c '. "$1" 2>/dev/null && declare -F read_leak_pattern_selftest >/dev/null || exit 3
        read_leak_pattern_selftest && exit 0; exit 1' _ "$1"; (( $? == 1 )); }
selftest_red "$RV/twice.sh";                            want_ok      "RF4 reader file: the selftest goes red when a second assignment no longer refuses" $? ""
selftest_red "$RV/shape.sh";                            want_ok      "RF5 reader file: the selftest goes red when no line is refused for its shape" $? ""
# pre-push beside a reader it can't use: a clean tree, the list at its place, still refused, and refused
# for that reason. A hook that lost its exit on a reader fault can still refuse for another reason further on (a
# list it then can't read), and a test that accepted any refusal would stay green with the protection gone. So the
# fault, with its stated reason, must be the only refusal and the last thing printed.
reader_stop() {  # NAME RC OUTPUT REASON
    local n last
    n=$(printf '%s\n' "$3" | grep -c 'REFUSING'); last=$(printf '%s\n' "$3" | tail -n 2 | head -n 1)
    if [[ $2 -ne 0 && $n -eq 1 && "$last" == *"list reader leak-detection/read-leak-pattern.sh can't be used: $4."* ]]; then
        result "$1" 0
    else result "$1" 1 "exit $2, $n refusal(s), want only the reader fault '$4', last: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-160)"; fi; }
rdir() { mkdir -p "$1"; install -m 0755 "$H/pre-push" "$1/pre-push"; [[ -f "$H/scan-binaries.py" ]] && cp "$H/scan-binaries.py" "$1/"; }
rdir "$TMP/hk-noreader"
rdir "$TMP/hk-cut";      awk '{print} /while IFS= read -r line/ {exit}' "$RD" > "$TMP/hk-cut/read-leak-pattern.sh" 2>/dev/null
rdir "$TMP/hk-nohelper"; awk '/^read_leak_pattern_selftest\(\) \{/ {s=1} !s {print} s && /^\}/ {s=0}' "$RD" > "$TMP/hk-nohelper/read-leak-pattern.sh" 2>/dev/null
rdir "$TMP/hk-twice";    cp "$RV/twice.sh" "$TMP/hk-twice/read-leak-pattern.sh"
out=$(direct "$TMP/hk-noreader/pre-push" "$SHA"); rc=$?; reader_stop  "RC1 pre-push: no reader file beside it refuses, even a clean push with the pattern set" $rc "$out" "it is missing"
                                                        no_bypass    "RC1b pre-push: that refusal does not offer --no-verify" "$out"
out=$(direct "$TMP/hk-cut/pre-push" "$SHA");            reader_stop  "RC2 pre-push: a reader file cut short refuses" $? "$out" "it did not load"
out=$(direct "$TMP/hk-nohelper/pre-push" "$SHA");       reader_stop  "RC3 pre-push: a reader file without its selftest refuses" $? "$out" "it does not define both read_leak_pattern and read_leak_pattern_selftest"
out=$(direct "$TMP/hk-twice/pre-push" "$SHA");          reader_stop  "RC4 pre-push: a reader file failing its selftest refuses" $? "$out" "it failed its selftest"
lfile "$SETUP"
out=$(cd "$LF" && printf 'refs/heads/main %s refs/heads/main %s\n' "$LF_CLEAN" "$Z" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN "$BASH_BIN" "$TMP/hk-noreader/pre-push" r "$TMP/lf.git" 2>&1 < "$TMP/pp.in")
                                                        reader_stop  "RC5 pre-push: no reader file, the list in its file: refuses" $? "$out" "it is missing"
rm -f "$(lp "$LF")"

# ============================== pre-push, credential layer ======================================
C="$TMP/push"; mk_repo "$C"
mkdir -p "$C/leak-detection/fixtures"; cp "$FIXTURE" "$C/leak-detection/fixtures/"   # allowlisted path
# The binary scan runs only where a project switches it on (below), so this repository does, at its base: every
# B, BC, V, PY and MG case that branches from BASE runs with the scan on.
printf 'readme\n' > "$C/README.md"; printf 'scan=on\n' > "$C/kit.binaries"; commit "$C" c1
printf 'doomed\n' > "$C/doomed.txt"; commit "$C" c2
git -C "$C" rm -q doomed.txt; commit "$C" "c3 deletion only"
BASE=$(git -C "$C" rev-parse HEAD)
git init -q --bare "$TMP/push.git"; git -C "$C" remote add r "$TMP/push.git"
push() { (cd "$C" && env PATH="${2:-$PATH}" git push "${3:-r}" $1 2>&1); }
on_remote() { git -C "$TMP/${2:-push}.git" rev-parse --verify -q "$1" >/dev/null; }
from_base() { git -C "$C" checkout -q -B "$1" "$BASE"; }

out=$(push "HEAD:refs/heads/main");            want_ok "P0  first push to an empty remote scans history" $? "$out" "2 of 2 commit(s) adding text scanned, clean"
from_base u1; out=$(push "u1:refs/heads/u1");  want_ok "P1a new branch with no new commits passes" $? "$out" "no new commits"
echo more >> "$C/README.md"; commit "$C" upd
out=$(push "u1:refs/heads/u1");                want_ok "P1b update of an existing branch is scanned" $? "$out" "1 of 1 commit(s) adding text scanned, clean"
from_base nb; echo x > "$C/new.txt"; commit "$C" nb
out=$(push "nb:refs/heads/nb");                want_ok "P2  new branch with a commit is scanned" $? "$out" "1 of 1"
git -C "$C" tag lt "$BASE"; git -C "$C" tag -a at -m annotated "$BASE"
out=$(push "refs/tags/*:refs/tags/*");         rc=$?; on_remote refs/tags/at; want_ok "P3  tags on an already-pushed commit pass" $((rc + $?)) "$out"
out=$(push ":refs/heads/nb");                  rc=$?; ! on_remote refs/heads/nb; want_ok "P4  branch delete passes" $((rc + $?)) "$out"
from_base side; echo s > "$C/side.txt"; commit "$C" side
from_base mg; echo m > "$C/mg.txt"; commit "$C" mg; git -C "$C" merge -q --no-ff --no-edit side
out=$(push "mg:refs/heads/mg"); rc=$?; on_remote refs/heads/mg || rc=1
                                               want_ok      "MG0 a clean merge is scanned, against its first parent, and goes through" $rc "$out" "3 of 3 commit(s) adding text scanned, clean"
# A merge's own changes go through every layer an ordinary commit's do. Its own changes are read as its diff against
# its first parent, which holds everything it adds in neither parent and more (the stricter of the readings). Each
# case below was refused before as a merge, and must stay refused now for what it carries: MGn checks
# the refusal, MGnb its reason. mpush BRANCH: push it; rc 0 only if it reached the remote.
mpush() { out=$(push "$1:refs/heads/$1"); rc=$?; on_remote "refs/heads/$1" && rc=0; }
mconflict() {  # BRANCH: a branch that conflicts with a side branch on mg-conf.txt, mid-merge, MERGE_HEAD set
    from_base "$1-base"; printf 'value=1\n' > "$C/mg-conf.txt"; commit "$C" "$1 base"
    git -C "$C" checkout -q -B "$1-side"; printf 'value=2\n' > "$C/mg-conf.txt"; commit "$C" "$1 side"
    git -C "$C" checkout -q -B "$1" "$1-base"; printf 'value=3\n' > "$C/mg-conf.txt"; commit "$C" "$1 main"
    git -C "$C" merge -q --no-edit "$1-side" >/dev/null 2>&1; }
mcommit() { git -C "$C" add -A && git -C "$C" commit -q --no-verify --no-edit; }
mconflict mg1; cp "$FIXTURE" "$C/mg-conf.txt"; mcommit; mpush mg1
                                               want_refused "MG1 a merge whose conflict resolution adds a credential, in neither parent, is refused" $rc "$out" "pre-push: "
                                               want_refused "MG1b ... by the credential scan" $rc "$out" "gitleaks found credential shapes"
                                               no_bypass    "N1  that refusal does not suggest --no-verify" "$out"
mconflict mg2; printf 'owner=%s\n' "$MARK" > "$C/mg-conf.txt"; mcommit; mpush mg2
                                               want_refused "MG2 a merge whose conflict resolution adds an identity term is refused" $rc "$out" "pre-push: "
                                               want_refused "MG2b ... by the identity layer" $rc "$out" "listed terms in the tree"
from_base mg3-side; cp "$FIXTURE" "$C/mg3.cfg"; commit "$C" "mg3 side"
from_base mg3; echo m3 > "$C/mg3.txt"; commit "$C" "mg3 main"; git -C "$C" merge -q --no-ff --no-edit mg3-side; mpush mg3
                                               want_refused "MG3 a merge bringing in a branch whose commit carries a credential is refused" $rc "$out" "pre-push: "
                                               want_refused "MG3b ... by the credential scan" $rc "$out" "gitleaks found credential shapes"
from_base mg4-a; echo a > "$C/mg4a.txt"; commit "$C" "mg4 a"; from_base mg4-b; echo b > "$C/mg4b.txt"; commit "$C" "mg4 b"
from_base mg4; echo m4 > "$C/mg4.txt"; commit "$C" "mg4 main"
git -C "$C" merge -q --no-ff --no-commit mg4-a mg4-b >/dev/null 2>&1; cp "$FIXTURE" "$C/mg4.cfg"; mcommit; mpush mg4
[[ $(git -C "$C" rev-list --count --min-parents=3 mg4 -1) -eq 1 ]] || rc=0
                                               want_refused "MG4 an octopus merge whose own changes add a credential is refused" $rc "$out" "pre-push: "
                                               want_refused "MG4b ... by the credential scan" $rc "$out" "gitleaks found credential shapes"
from_base mg5-side; echo s5 > "$C/mg5s.txt"; commit "$C" "mg5 side"
from_base mg5; echo m5 > "$C/mg5.txt"; commit "$C" "mg5 main"
git -C "$C" merge -q --no-ff --no-commit mg5-side >/dev/null 2>&1; mkpng "$C/mg5.png" '\x55'; mcommit; mpush mg5
                                               want_refused "MG5 a merge whose own changes add an unreviewed binary is refused" $rc "$out" "pre-push: "
                                               want_refused "MG5b ... by the binary scan, which reads the merge" $rc "$out" "is not on the reviewed list"
from_base gp; echo g > "$C/gp.txt"; commit "$C" gp
out=$(push "gp:refs/heads/gp" "$TMP/nogl"); p6rc=$?; want_refused "P6  gitleaks off PATH is refused" $p6rc "$out" "gitleaks was not found"
want_says "MS5 pre-push: gitleaks missing says what you can do and what to ask IT for" $p6rc "$out" \
    "You can: install gitleaks 8.30.1" "If IT manages this machine: ask IT to install or allow gitleaks 8.30.1"
# No refusal points a commit or a push outside the sandbox: IT may forbid it, and a block goes to IT, not around it.
[[ "$out" != *"outside the sandbox"* ]];        want_ok "MS33 pre-push: that refusal points nothing outside the sandbox" $? "$out"
                                               no_bypass    "N2  pre-push's gitleaks refusal does not suggest --no-verify" "$out"
# Under Claude Code's sandbox read block a gitleaks in a hidden folder looks missing, as the install does to the stub,
# so the refusal names both causes and what to let sandboxed commands read.
rc=1; [[ "$out" == *"missing, or hidden"* && "$out" == *"sandbox.filesystem.allowRead"* ]] || rc=0
                                               want_refused "P6b pre-push: that refusal names both causes, missing or hidden, and what to allow" $rc "$out" "gitleaks was not found"
want_split "MS37 pre-push: that refusal's sandbox lines split, your own block in your user settings, IT's through IT" $p6rc "$out"
from_base del; git -C "$C" rm -q README.md; commit "$C" "deletion only"
out=$(push "del:refs/heads/del");              want_ok "P7  deletion-only commit passes unscanned" $? "$out" "none adding text"
from_base cred; cp "$FIXTURE" "$C/config.local.txt"; commit "$C" creds
out=$(push "cred:refs/heads/cred");            rc=$?; on_remote refs/heads/cred && rc=0; want_refused "P8  fake-credential commit is blocked" $rc "$out" "gitleaks found credential shapes"
from_base bin; printf 'bin\000ary\000%.0s' 1 2 3 4 5 6 7 8 > "$C/blob.bin"; commit "$C" binary
out=$(push "bin:refs/heads/bin");              want_refused "P10 binary file in range is refused" $? "$out" "binary file"
from_base idt; echo "names $MARK" > "$C/idt.txt"; commit "$C" idt
out=$(push "idt:refs/heads/idt");              want_refused "P11 identity marker is blocked at push" $? "$out" "listed terms"
from_base rn; git -C "$C" mv README.md READ.md; commit "$C" rename
out=$(push "rn:refs/heads/rn");                want_ok "P12 rename-only commit passes unscanned" $? "$out" "none adding text"
# The credential scan's count: pre-push reads the first "N commits scanned" gitleaks prints and refuses any count but
# the one it expects, since a partial scan is not a clean one. Stand-in gitleaks binaries first on PATH, never a switch
# in the hook, each printing its counts and no leaks.
gsstand() { local d=$1 n; shift; mkdir -p "$d"
            { printf '#!/bin/sh\n'; for n in "$@"; do printf 'echo "INF %s commits scanned." >&2\n' "$n"; done
              printf 'echo "INF no leaks found" >&2\nexit 0\n'; } > "$d/gitleaks"; chmod 0755 "$d/gitleaks"; }
gsstand "$TMP/gl-gs0" 0; gsstand "$TMP/gl-gs01" 0 1; gsstand "$TMP/gl-gs10" 1 0
from_base gs; echo one > "$C/gs.txt"; commit "$C" gs
out=$(push "gs:refs/heads/gs" "$TMP/gl-gs0:$PATH"); rc=$?; on_remote refs/heads/gs && rc=0
                                               want_refused "GS1 pre-push: a credential scan that reports 0 commits where 1 adds text is refused, a partial scan" $rc "$out" "a partial scan is not a clean one"
out=$(push "gs:refs/heads/gs" "$TMP/gl-gs01:$PATH"); rc=$?; on_remote refs/heads/gs && rc=0
                                               want_refused "GS1b ... the first count printed decides: 0, then 1, is refused" $rc "$out" "a partial scan is not a clean one"
out=$(push "gs:refs/heads/gs" "$TMP/gl-gs10:$PATH")
                                               want_ok      "GS1c control: 1, then 0, goes through, the first count read" $? "$out" "1 of 1 commit(s) adding text scanned, clean"
# P9: a remote-tracking ref left pointing at a commit the remote no longer has.
git init -q --bare "$TMP/stale.git"; git -C "$C" remote add s "$TMP/stale.git"
from_base stale; cp "$FIXTURE" "$C/settings.local.txt"; commit "$C" "stale creds"; CRED=$(git -C "$C" rev-parse HEAD)
git -C "$C" push -q --no-verify s "$CRED:refs/heads/main" 2>/dev/null; git -C "$C" fetch -q s
git clone -q "$TMP/stale.git" "$TMP/other" 2>/dev/null
git -C "$TMP/other" push -q --no-verify --force origin "$BASE:refs/heads/main" 2>/dev/null
out=$(push "stale:refs/heads/feat" "" s);      rc=$?; on_remote refs/heads/feat stale && rc=0
                                               want_refused "P9  stale tracking ref: the commit is still scanned and blocked" $rc "$out" "gitleaks found credential shapes"
out=$( (cd "$C" && printf 'refs/heads/x %s refs/heads/x %s\n' "$BASE" "$Z" > "$TMP/pp.in" && "$BASH_BIN" "$HK/pre-push" r "$TMP/no-such.git" 2>&1 < "$TMP/pp.in") )
                                               want_refused "P13 remote refs cannot be listed: refused" $? "$out" "could not list the remote"
# The project's own pre-push checks (hook-checks/pre-push/), made after each commit so `commit`'s
# `add -A` never tracks them. They get the hook's arguments and the same ref lines git sent.
XP="$C/hook-checks/pre-push"
from_base xp1; echo x > "$C/xp1.txt"; commit "$C" xp1; chk "$XP" 10-refuse 4
out=$(push "xp1:refs/heads/xp1");              rc=$?; on_remote refs/heads/xp1 && rc=0
                                               want_refused "X7 pre-push: a failing project check refuses the push" $rc "$out" "10-refuse exited 4"
rm -rf "$C/hook-checks"; from_base xp2; echo y > "$C/xp2.txt"; commit "$C" xp2; XSHA=$(git -C "$C" rev-parse HEAD)
chk "$XP" 20-record 0 "{ echo \"args: \$1 \$2\"; cat; } > '$TMP/x8.out'"
out=$(push "xp2:refs/heads/xp2");              rc=$?
# The URL as git holds it: Git for Windows stores the remote's path in Windows form.
printf 'args: r %s\nrefs/heads/xp2 %s refs/heads/xp2 %s\n' "$(git -C "$C" remote get-url r)" "$XSHA" "$Z" | cmp -s - "$TMP/x8.out" || rc=$((rc + 1))
                                               want_ok      "X8 pre-push: a project check gets the hook's arguments and ref lines, and the push goes through" $rc "$out"
rm -rf "$C/hook-checks"; from_base xp3; echo z > "$C/xp3.txt"; commit "$C" xp3
if nonexec "$XP/30-plain"; then
    out=$(push "xp3:refs/heads/xp3");          rc=$?; on_remote refs/heads/xp3 && rc=0
                                               want_refused "X9 pre-push: a non-executable entry refuses, never skips" $rc "$out" "not an executable file"
else skip "X9 pre-push: a non-executable entry refuses, never skips" "chmod -x left a file without #! executable here"; fi
rm -rf "$C/hook-checks"; from_base xp4; echo "names $MARK" > "$C/xp4.txt"; commit "$C" xp4
chk "$XP" 40-pass 0 "touch '$TMP/x10-ran'"
out=$(push "xp4:refs/heads/xp4");              rc=$?; [[ -f "$TMP/x10-ran" ]] && rc=0
                                               want_refused "X10 pre-push: the kit's refusal stands, and no project check runs" $rc "$out" "listed terms"
rm -rf "$C/hook-checks"

# Binaries: cleared only when reviewed by blob id on the list at the pushed tip, structurally plain,
# and with no match in their strings -- and the text layers keep running over the same push.
bcase() { from_base "$1"; git -C "$C" clean -qfd; }
bpush() { out=$(push "$1:refs/heads/$1" "${2:-}"); rc=$?; on_remote "refs/heads/$1" && rc=0; }   # rc 0 if it reached the remote
bcase b1; mkpng "$C/i.png"; mkjpg "$C/i.jpg"; mkwebp "$C/i.webp"; echo "text beside them" > "$C/b1.txt"
review i.png i.jpg i.webp; commit "$C" b1
out=$(push "b1:refs/heads/b1"); rc=$?; [[ "$out" == *"1 of 1 commit(s) adding text scanned, clean"* ]] || rc=$((rc + 1))
                                               want_ok      "B1  reviewed plain PNG, JPEG and WebP pass, and the push's text is still scanned" $rc "$out" "3 of 3 binary file(s) cleared"
bcase b2; mkpng "$C/u.png" '\x01\x02'; commit "$C" b2; bpush b2
                                               want_refused "B2  a binary not on the reviewed list is refused" $rc "$out" "is not on the reviewed list"
bcase b3; mkpng "$C/t.png" '\x03' tEXt 'Comment\x00made by hand'; review t.png; commit "$C" b3; bpush b3
                                               want_refused "B3  a reviewed PNG with a text chunk is refused" $rc "$out" "'tEXt' chunk"
bcase b4; mkpng "$C/e.png" '\x04'; printf 'tail' >> "$C/e.png"; review e.png; commit "$C" b4; bpush b4
                                               want_refused "B4  a reviewed PNG with bytes after its end is refused" $rc "$out" "after its end"
bcase b5; mkjpg "$C/x.jpg" '\xff\xe1\x00\x0cExif\x00\x00abcd'; review x.jpg; commit "$C" b5; bpush b5
                                               want_refused "B5  a reviewed JPEG with an EXIF segment (APP1) is refused" $rc "$out" "'APP1' segment"
bcase b6; mkwebp "$C/x.webp" 'EXIF\x04\x00\x00\x00abcd'; review x.webp; commit "$C" b6; bpush b6
                                               want_refused "B6  a reviewed WebP with an EXIF chunk is refused" $rc "$out" "'EXIF' chunk"
bcase b7; mkpngf "$C/c.png" "$FIXTURE"; review c.png; commit "$C" b7; bpush b7
                                               want_refused "B7  a reviewed PNG with credential shapes in its bytes is refused" $rc "$out" "credential shapes in its strings"
# UTF-16 text: the identity layer's raw-bytes grep cannot see it (measured), so this is the scan's.
bcase b8; for ((i = 0; i < ${#MARK}; i++)); do printf '%s\0' "${MARK:i:1}"; done > "$TMP/utf16.payload"
mkpngf "$C/m.png" "$TMP/utf16.payload"; review m.png; commit "$C" b8; bpush b8
[[ "$out" != *"listed terms in the tree"* ]] || rc=0
                                               want_refused "B8  a reviewed PNG with LEAK_PATTERN in UTF-16 text is refused by the binary scan" $rc "$out" "matches LEAK_PATTERN"
                                               no_leak      "B8b binary refusal does not quote the pattern" "$out"
# The scan's credential rules are the project's .gitleaks.toml, or else the kit's spawn rules beside the scanner:
# never a config the caller's environment names. Given no --config, gitleaks 8.30.1 takes one from GITLEAKS_CONFIG
# or GITLEAKS_CONFIG_TOML (its help), so a clone without a .gitleaks.toml let the environment choose the rules
# (gates procedure 13, item 1). BC0 shows the planted config allows everything, so BC1 and BC2 can't pass
# for want of a working plant; BC4 shows a clean binary still clears there.
printf 'title = "allows everything"\n[extend]\nuseDefault = true\n[allowlist]\nregexes = [%s.*%s]\n' "'''" "'''" > "$TMP/allow-all.toml"
glin() { (cd "$TMP" && env "$@" gitleaks stdin --no-banner --no-color --redact --exit-code 3 < "$FIXTURE" >/dev/null 2>&1); }
bc0=0; glin; [[ $? -eq 3 ]] || bc0=1
glin GITLEAKS_CONFIG="$TMP/allow-all.toml"; [[ $? -eq 0 ]] || bc0=$((bc0 + 2))
glin GITLEAKS_CONFIG_TOML="$(cat "$TMP/allow-all.toml")"; [[ $? -eq 0 ]] || bc0=$((bc0 + 4))
                                               want_ok      "BC0 control: gitleaks finds the fixture's shapes, and either variable's planted config lets them all through" $bc0 "(1: no shapes found; 2, 4: a variable not taken)"
bcase bc1; git -C "$C" rm -q .gitleaks.toml; mkpngf "$C/bc1.png" "$FIXTURE"; review bc1.png; commit "$C" bc1
export GITLEAKS_CONFIG="$TMP/allow-all.toml"; bpush bc1; unset GITLEAKS_CONFIG
                                               want_refused "BC1 no .gitleaks.toml: GITLEAKS_CONFIG naming a config that allows everything doesn't clear a reviewed PNG with credential shapes" $rc "$out" "credential shapes in its strings"
bcase bc2; git -C "$C" rm -q .gitleaks.toml; mkpngf "$C/bc2.png" "$FIXTURE"; review bc2.png; commit "$C" bc2
export GITLEAKS_CONFIG_TOML="$(cat "$TMP/allow-all.toml")"; bpush bc2; unset GITLEAKS_CONFIG_TOML
                                               want_refused "BC2 no .gitleaks.toml: GITLEAKS_CONFIG_TOML holding that config doesn't clear it either" $rc "$out" "credential shapes in its strings"
# No .gitleaks.toml and no spawn rules beside the scanner: the rules can't load, so the scan refuses (gates item 4),
# even for a binary that gitleaks' defaults would clear.
HKN="$TMP/hk-norules"; mkdir -p "$HKN"; install -m 0755 "$H/pre-push" "$HKN/pre-push"
cp "$H/scan-binaries.py" "$HKN/"; rswap "$H/read-leak-pattern.sh" "$HKN/read-leak-pattern.sh"
bcase bc3; git -C "$C" rm -q .gitleaks.toml; mkpng "$C/bc3.png" '\x33'; review bc3.png; commit "$C" bc3
git -C "$C" config core.hooksPath "$HKN"; bpush bc3; git -C "$C" config core.hooksPath "$HK"
                                               want_refused "BC3 no .gitleaks.toml and no spawn rules beside the scanner: refused, the scan did not run" $rc "$out" "the scan did not run"
bcase bc4; git -C "$C" rm -q .gitleaks.toml; mkpng "$C/bc4.png" '\x34'; review bc4.png; commit "$C" bc4
out=$(push "bc4:refs/heads/bc4")
                                               want_ok      "BC4 control: no .gitleaks.toml, the spawn rules beside the scanner: a clean reviewed PNG is cleared" $? "$out" "1 of 1 binary file(s) cleared"
# pre-push's own credential scan, run without the stub (no KIT_INSTALL) in a clone with no .gitleaks.toml: the spawn
# rules beside the hook, never a config the environment names, and a refusal when there are none (gates procedure 13,
# items 1 and 4). fpush BRANCH [VAR=VALUE]: push it so; rc 0 only if it reached the remote.
fpush() { out=$( (cd "$C" && env -u KIT_INSTALL ${2:+"$2"} git push r "$1:refs/heads/$1") 2>&1 ); rc=$?; on_remote "refs/heads/$1" && rc=0; }
fcase() { from_base "$1"; git -C "$C" rm -q .gitleaks.toml; cp "$FIXTURE" "$C/$1.cfg"; commit "$C" "$1"; }
fcase fp1; fpush fp1 GITLEAKS_CONFIG="$TMP/allow-all.toml"
                                               want_refused "FP1 pre-push, no stub, no .gitleaks.toml: GITLEAKS_CONFIG allowing everything doesn't clear a credential" $rc "$out" "gitleaks found credential shapes"
fcase fp2; fpush fp2 GITLEAKS_CONFIG_TOML="$(cat "$TMP/allow-all.toml")"
                                               want_refused "FP2 the same through GITLEAKS_CONFIG_TOML" $rc "$out" "gitleaks found credential shapes"
fcase fp3; git -C "$C" config core.hooksPath "$HKN"; fpush fp3 GITLEAKS_CONFIG="$TMP/allow-all.toml"; git -C "$C" config core.hooksPath "$HK"
                                               want_refused "FP3 the same with no spawn rules beside the hook: refused, the rules missing" $rc "$out" "no credential rules"
                                               no_bypass    "N5  that refusal does not suggest --no-verify" "$out"
from_base fp0; git -C "$C" rm -q .gitleaks.toml; echo clean > "$C/fp0.txt"; commit "$C" fp0; fpush fp0 GITLEAKS_CONFIG="$TMP/allow-all.toml"
                                               want_ok      "FP0 control: no stub, no .gitleaks.toml, the spawn rules beside the hook: a clean push goes through" $rc "$out" "1 of 1 commit(s) adding text scanned, clean"
bcase b9; mkpng "$C/mid.png" '\x09'; commit "$C" "b9 unreviewed"; MID=$(git -C "$C" rev-parse HEAD:mid.png)
mkpng "$C/mid.png" '\x0a'; review mid.png; commit "$C" "b9 reviewed at the tip"; bpush b9
                                               want_refused "B9  an unreviewed binary in a commit before the tip is refused" $rc "$out" "${MID:0:12}  mid.png: is not on the reviewed list"
bcase b10; mkpng "$C/w.png" '\x10'; commit "$C" b10; review w.png; bpush b10
                                               want_refused "B10 a reviewed-list entry in the working tree only does not clear" $rc "$out" "is not on the reviewed list"
bcase b11; mkpng "$C/p.png" '\x11'; review p.png; commit "$C" b11; bpush b11 "$TMP/nopy"
                                               want_refused "B11 python3 absent: a push with a binary is refused" $rc "$out" "python3 is not installed"
want_says "MS42 pre-push: a binary push with no python3 says what you can do" $rc "$out" "  You can: install python3 where you may, then push again."
bcase b11b; echo "text only" > "$C/b11b.txt"; commit "$C" b11b; out=$(push "b11b:refs/heads/b11b" "$TMP/nopy")
                                               want_ok      "B11b python3 absent: a push with no binary is unaffected" $? "$out" "1 of 1 commit(s) adding text scanned, clean"
bcase b12; printf '%b' 'GIF89a\x02\x00\x02\x00\x00\x00\x00;' > "$C/g.gif"; review g.gif; commit "$C" b12; bpush b12
                                               want_refused "B12 a reviewed file in a format the scan cannot read is refused" $rc "$out" "not a format this scan can read"
bcase b13; mkpng "$C/l.png" '\x13'; mkdir -p "$C/records"; printf '%s  l.png  abbreviated\n' "$(git -C "$C" hash-object "$C/l.png" | cut -c1-12)" > "$C/$LIST"
commit "$C" b13; bpush b13
                                               want_refused "B13 a reviewed-list line without a full blob id refuses" $rc "$out" "is not '<full"
bcase b14; mkpng "$C/k.png" '\x14'; review k.png; cp "$FIXTURE" "$C/b14.local.txt"; commit "$C" b14; bpush b14
                                               want_refused "B14 a push with a cleared binary still has its text scanned for credentials" $rc "$out" "gitleaks found credential shapes"
# A binary at a path holding invalid UTF-8: the scan names the path and must still refuse for its reason, not stop
# with "did not run", in the caller's locale or under LC_ALL=C. The file goes into git's index
# only: a Mac's file system refuses such a name.
bcase b15; mkpng "$TMP/b15.png" '\x15'; blob=$(git -C "$C" hash-object -w "$TMP/b15.png")
git -C "$C" update-index --add --cacheinfo "100644,$blob,u$(printf '\377\376').png"; git -C "$C" commit -q --no-verify -m b15; bpush b15
                                               want_refused "B15 a binary at a path holding invalid UTF-8 is refused for its reason, and the scan runs" $rc "$out" "is not on the reviewed list"
# A binary whose path holds the marker: the binary scan names each binary it refuses or clears, and must withhold a
# name that matches the list, as pre-push's own naming does (L8, L9). Both streams apart.
bcase b16; mkpng "$C/p-$MARK.png" '\x16'; commit "$C" b16
b16o=$(cd "$C" && git push r b16:refs/heads/b16 2>"$TMP/b16.err"); rc=$?; on_remote refs/heads/b16 && rc=0; b16e=$(cat "$TMP/b16.err")
                                               want_refused "B16 a binary whose path holds the marker is refused for its reason" $rc "$b16o$b16e" "is not on the reviewed list"
                                               no_leak_at   "B16b the binary scan doesn't print that path, refusing it" "$b16o" "$b16e"
bcase b17; mkpng "$C/q-$MARK.png" '\x17'; review "q-$MARK.png"; commit "$C" b17
b17o=$(cd "$C" && git push r b17:refs/heads/b17 2>"$TMP/b17.err"); b17e=$(cat "$TMP/b17.err")
[[ "$b17o$b17e" == *"1 of 1 binary file(s) cleared"* ]]; want_ok "B17 a reviewed binary whose path holds the marker is cleared" $? "$(printf '%s' "$b17o$b17e" | tr '\n' ' ' | cut -c1-160)"
                                               no_leak_at   "B17b the binary scan doesn't print that path, clearing it" "$b17o" "$b17e"
# The same with colour forced in the user's config: the scan's git grep, whose output decides which names to withhold,
# must ask for no colour itself, or a coloured line misses the parse and the path is printed.
CH="$TMP/colour-home"; mkdir -p "$CH"; git config -f "$CH/.gitconfig" color.ui always; git config -f "$CH/.gitconfig" color.diff always
bcase bw1; mkpng "$C/w-$MARK.png" '\x1a'; commit "$C" bw1
bw1o=$(cd "$C" && env HOME="$CH" git push r bw1:refs/heads/bw1 2>"$TMP/bw1.err"); rc=$?; on_remote refs/heads/bw1 && rc=0; bw1e=$(cat "$TMP/bw1.err")
                                               want_refused "BW1 with colour forced, a binary whose path holds the marker is refused for its reason" $rc "$bw1o$bw1e" "is not on the reviewed list"
                                               no_leak_at   "BW1b the binary scan doesn't print that path, with colour forced" "$bw1o" "$bw1e"
# The scan runs isolated (python3 -I: no PYTHON* variable, no user site-packages, no script folder on its path), so a
# module the caller's environment plants can't clear a binary. PY1 shadows re, which
# the scan imports, from PYTHONPATH; PY2 plants usercustomize, which the user site runs at start, under PYTHONUSERBASE.
# Each plant exits 0 at once, so a scan that ran it reports clean. PY2 needs the python3 this hook resolves to have its
# user site on: it asks that interpreter, run as v0.9.0's hook ran it, and fails naming the precondition if not, never
# passing by default (a venv's python3 has the user site off).
mkdir -p "$TMP/plant-path"; printf 'import os\nos._exit(0)\n' > "$TMP/plant-path/re.py"
bcase py1; mkpng "$C/py1.png" '\x31'; commit "$C" py1
out=$( (cd "$C" && env PYTHONPATH="$TMP/plant-path" git push r py1:refs/heads/py1) 2>&1 ); rc=$?; on_remote refs/heads/py1 && rc=0
                                               want_refused "PY1 a module planted on PYTHONPATH doesn't clear an unreviewed binary" $rc "$out" "is not on the reviewed list"
PY2="PY2 a usercustomize planted in the user site under PYTHONUSERBASE doesn't clear an unreviewed binary"
UB="$TMP/plant-userbase"
usite=$( (cd "$C" && PYTHONUSERBASE="$UB" python3 -c 'import site, sys; print(site.getusersitepackages()); sys.exit(0 if site.ENABLE_USER_SITE else 3)') 2>/dev/null ); urc=$?
if [[ $urc -eq 0 && -n "$usite" ]]; then
    mkdir -p "$usite"; printf 'import os\nos._exit(0)\n' > "$usite/usercustomize.py"
    bcase py2; mkpng "$C/py2.png" '\x32'; commit "$C" py2
    out=$( (cd "$C" && env PYTHONUSERBASE="$UB" git push r py2:refs/heads/py2) 2>&1 ); rc=$?; on_remote refs/heads/py2 && rc=0
                                               want_refused "$PY2" $rc "$out" "is not on the reviewed list"
elif [[ -n "${KIT_INSTALL_CHECK:-}" ]]; then
    # Run as part of an install (tools/install-release.sh sets this when it runs the staged suite). The
    # isolation itself is python3 -I, which PY1 shows without the user site; PY2 only adds the user-site
    # variant, and it can't be exercised when this machine's python3 has its user site off. Report it
    # loudly, but do not fail the install over a machine setting the gate does not depend on. In CI and a
    # direct run the marker is unset, so the branch below fails instead: a gate check is never silently
    # skipped there.
    skip "$PY2" "precondition unmet at install time: this machine's python3 has its user site off (exit $urc); the isolation is the interpreter's -I flag, shown by PY1. Set it on to exercise the user-site variant"
else
    result "$PY2" 1 "precondition unmet: the python3 first on PATH, which this hook runs, has its user site off (exit $urc), so the plant can't be shown refused; run the suite with a python3 whose user site is on (not a venv's), or let tools/install-release.sh run it, which reports this as a skip rather than a failure"
fi

# Structure, type by type. Cleared: every chunk type that carries no metadata field. Refused by name:
# every metadata type and anything unknown. One push each way; each type gets its own result.
bcase w; W=()
for t in PLTE tRNS gAMA cHRM sBIT bKGD hIST pHYs sRGB; do mkpng "$C/w-$t.png" '\x77' "$t" '\x00\x01\x02'; W+=("w-$t.png"); done
for f in c0 c1 c3 c5 c6 c7 c9 ca cb cd ce cf; do mkjpg "$C/w-sof-$f.jpg" '' "$f"; W+=("w-sof-$f.jpg"); done
mkjpg "$C/w-dri-rst.jpg" '\xff\xdd\x00\x04\x00\x01' c0 '\x12\xff\xd0\x34\xff\xd1\x56'; W+=(w-dri-rst.jpg)
review "${W[@]}"; commit "$C" w; out=$(push "w:refs/heads/w"); rc=$?
want_ok "W0  every structural chunk type below is cleared, and the push goes through" $rc "$out" "${#W[@]} of ${#W[@]} binary file(s) cleared"
# Each file's line ends at its name. A Windows Python ends its lines with CRLF, so the CRs go first.
out=${out//$'\r'/}
for f in "${W[@]}"; do [[ "$out" == *"  $f"$'\n'* && "$out" != *"  $f: "* ]]
    want_ok "W   $f is cleared" $? "$out"; done
bcase q; Q=()
qpng() { mkpng "$C/q-$1.png" '\x71' "$1" "${2:-\x00\x01\x02}"; Q+=("q-$1.png|carries a '$1' chunk"); }
qpng zTXt; qpng iTXt; qpng eXIf; qpng iCCP; qpng tIME; qpng sPLT 'name\x00\x08'; qpng prVt
qjpg() { mkjpg "$C/q-$1.jpg" "$2"; Q+=("q-$1.jpg|$3"); }
qjpg app2  '\xff\xe2\x00\x06ICC\x00'           "carries a 'APP2' segment"
qjpg app13 '\xff\xed\x00\x06IPTC'              "carries a 'APP13' segment"
qjpg app14 '\xff\xee\x00\x07Adobe'             "carries a 'APP14' segment"
qjpg com   '\xff\xfe\x00\x06note'              "carries a 'COM' segment"
qjpg dac   '\xff\xcc\x00\x04\x00\x00'          "carries a 'DAC' segment"
qjpg app0t '\xff\xe0\x00\x13JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x01\x01\x00\x00\x00' "carries an APP0 segment other than"
mkjpg "$C/q-tail.jpg"; printf 'tail' >> "$C/q-tail.jpg"; Q+=("q-tail.jpg|has 4 byte(s) after its end")
mkwebp "$C/q-xmp.webp"  'XMP \x04\x00\x00\x00abcd'; Q+=("q-xmp.webp|carries a 'XMP ' chunk")
mkwebp "$C/q-iccp.webp" 'ICCP\x04\x00\x00\x00abcd'; Q+=("q-iccp.webp|carries a 'ICCP' chunk")
mkwebp "$C/q-abcd.webp" 'ABCD\x04\x00\x00\x00abcd'; Q+=("q-abcd.webp|carries a 'ABCD' chunk")
mkwebp "$C/q-tail.webp"; printf 'tail' >> "$C/q-tail.webp"; Q+=("q-tail.webp|has 4 byte(s) after its end")
# A structural chunk holds bytes too (PLTE up to 768): text put there is the strings pass's to catch.
mkpng "$C/q-plte-mark.png" '\x72' PLTE "$MARK"; Q+=("q-plte-mark.png|matches LEAK_PATTERN")
review "${Q[@]%%|*}"; commit "$C" q; bpush q
for e in "${Q[@]}"; do f=${e%%|*}; want_refused "Q   $f is refused: ${e#*|}" $rc "$out" "$f: ${e#*|}"; done
git -C "$C" clean -qfd

# Video, MP4 and WebM: cleared only as the structure the spawns' clean encodes were measured to use, with
# only the encoder's own fields, by exact value. The V0 set is those encodes rebuilt box for box, plus the
# admitted empty forms and a second cluster. Every VQ file is one of them with one thing changed, and each
# must be refused for that thing, by name: these are the controls that show the allowlist is not lenient.
bcase v; V=(v.mp4 v.webm v-empty.mp4 v-2cl.webm)
mkmp4 "$C/v.mp4"; mkwebm "$C/v.webm"; M_HDLR='' M_CNAME="$(z 32)" mkmp4 "$C/v-empty.mp4"
W_CLUSTER="$(eel '\x1f\x43\xb6\x75' "$(eel '\xe7' '\x10')$(eel '\xa3' '\x81\x00\x00\x80\x00')")" mkwebm "$C/v-2cl.webm"
review "${V[@]}"; commit "$C" v; out=$(push "v:refs/heads/v"); rc=$?
want_ok "V0  reviewed clean MP4 and WebM are cleared, and the push goes through" $rc "$out" "${#V[@]} of ${#V[@]} binary file(s) cleared"
out=${out//$'\r'/}                             # as W's
for f in "${V[@]}"; do [[ "$out" == *"  $f"$'\n'* && "$out" != *"  $f: "* ]]
    want_ok "V   $f is cleared" $? "$out"; done
bcase vu; mkmp4 "$C/vu.mp4"; commit "$C" vu; bpush vu
                                               want_refused "V1  a clean MP4 not on the reviewed list is refused" $rc "$out" "vu.mp4: is not on the reviewed list"
bcase vq; VQ=()
vq() { VQ+=("$1|$2"); }
M_TOP="$(mbox uuid "$(z 16)provenance manifest")" mkmp4 "$C/vq-uuid.mp4";      vq vq-uuid.mp4 "carries a 'uuid' box"
M_ILST="$(mbox '\xa9too' "$(mbox data "$(z 8)Lavf62.18.100")")" mkmp4 "$C/vq-too.mp4"; vq vq-too.mp4 "carries a '\\xa9too' box in 'ilst'"
M_ILST="$(mbox covr "$(mbox data "$(z 8)\xff\xd8\xff\xd9")")" mkmp4 "$C/vq-covr.mp4"; vq vq-covr.mp4 "carries a 'covr' box in 'ilst'"
M_TRAK="$(mbox trak "$(mbox mdia "$(mbox hdlr "$(z 8)soun$(z 12)SoundHandler\x00")$(mbox minf "$(mbox smhd "$(z 8)")")")")" \
    mkmp4 "$C/vq-audio.mp4";                                                  vq vq-audio.mp4 "carries a 'smhd' box in 'minf'"
M_TRAKX="$(mbox udta "$(mbox meta "$(z 4)")")" mkmp4 "$C/vq-nest.mp4";         vq vq-nest.mp4 "carries a 'udta' box in 'trak'"
# A second video track is shown by no player, so the person reviewing the clip never sees it.
M_TRAK="$(mbox trak "$(mbox tkhd "\x00\x00\x00\x03$(z 80)")")" mkmp4 "$C/vq-2trak.mp4"; vq vq-2trak.mp4 "has more than one 'trak' box in 'moov'"
M_HDLR="$MARK handler\x00" mkmp4 "$C/vq-hname.mp4";                           vq vq-hname.mp4 "has a handler name that is not on the allowed list"
M_CNAME="\x15Lavc62.34.102 libx264$(z 10)" mkmp4 "$C/vq-cname.mp4";           vq vq-cname.mp4 "has a compressor name that is not on the allowed list"
M_CNAME="\x0cLavc libx264hidden$(z 13)" mkmp4 "$C/vq-ctail.mp4";              vq vq-ctail.mp4 "has bytes after its compressor name"
M_FTYP="$(mbox ftyp 'qt  \x00\x00\x02\x00qt  ')" mkmp4 "$C/vq-brand.mp4";       vq vq-brand.mp4 "has a file-type brand that is not on the allowed list"
M_MVHD="$(z 4)\xe1\x23\x45\x67$(z 4)\x00\x00\x03\xe8$(z 84)" mkmp4 "$C/vq-time.mp4"; vq vq-time.mp4 "has a creation or modification time in its 'mvhd' box"
M_URL='\x00\x00\x00\x00elsewhere/clip.mov\x00' mkmp4 "$C/vq-url.mp4";     vq vq-url.mp4 "has a data reference to a location outside the file"
M_COLR="$(mbox colr 'profICC profile bytes')" mkmp4 "$C/vq-colr.mp4";          vq vq-colr.mp4 "has a 'colr' box other than the plain 'nclx' colour type"
M_FREE="$(mbox free 'padding with text')" mkmp4 "$C/vq-free.mp4";              vq vq-free.mp4 "has a 'free' box that is not all zero bytes"
M_TOP="$(be32 1000)skip" mkmp4 "$C/vq-trunc.mp4";                             vq vq-trunc.mp4 "could not be parsed"
mkmp4 "$C/vq-tail.mp4"; printf 'tail' >> "$C/vq-tail.mp4";                     vq vq-tail.mp4 "has 4 byte(s) after its last box"
M_MDAT="$MARK" mkmp4 "$C/vq-mark.mp4";                                        vq vq-mark.mp4 "matches LEAK_PATTERN"
W_INFO="$(eel '\x7b\xa9' 'My clip')" mkwebm "$C/vq-title.webm";                vq vq-title.webm "carries a 'Title' element in 'Info'"
W_INFO="$(eel '\x44\x61' "$(z 7)\x01")" mkwebm "$C/vq-date.webm";              vq vq-date.webm "carries a 'DateUTC' element in 'Info'"
W_MUX='Lavf62.18.100' mkwebm "$C/vq-mux.webm";                                vq vq-mux.webm "has a 'MuxingApp' value that is not on the allowed list"
W_WRITE="$MARK" mkwebm "$C/vq-write.webm";                                    vq vq-write.webm "has a 'WritingApp' value that is not on the allowed list"
W_DOCTYPE=matroska mkwebm "$C/vq-doctype.webm";                               vq vq-doctype.webm "has a 'DocType' value that is not on the allowed list"
W_SEG="$(eel '\x19\x41\xa4\x69' "$(eel '\x61\xa7' "$(eel '\x46\x6e' 'cover.jpg')")")" mkwebm "$C/vq-attach.webm"
                                                                              vq vq-attach.webm "carries an 'Attachments' element in 'Segment'"
W_SEG="$(eel '\x10\x43\xa7\x70' "$(eel '\x45\xb9' "$(eel '\xb6' "$(eel '\x73\xc4' '\x01')")")")" mkwebm "$C/vq-chap.webm"
                                                                              vq vq-chap.webm "carries a 'Chapters' element in 'Segment'"
W_SEG="$(eel '\x5f\xff' 'x')" mkwebm "$C/vq-unknown.webm";                     vq vq-unknown.webm "carries an element with ID 0x5FFF in 'Segment'"
W_TAG="$(eel '\x67\xc8' "$(eel '\x45\xa3' 'ARTIST')$(eel '\x44\x87' 'someone')")" mkwebm "$C/vq-tag.webm"
                                                                              vq vq-tag.webm "has a tag that is not on the allowed list"
W_ENC='Lavc62.34.102 libvpx-vp9' mkwebm "$C/vq-enc.webm";                      vq vq-enc.webm "has a tag that is not on the allowed list"
W_TAG="$(eel '\x67\xc8' "$(eel '\x45\xa3' 'ENCODER')$(eel '\x44\x87' 'a second value')$(eel '\x44\x87' 'Lavc libvpx-vp9')")" \
    mkwebm "$C/vq-dup.webm";                                                  vq vq-dup.webm "has a tag that is not on the allowed list"
W_TAG="$(eel '\x67\xc8' "$(eel '\x45\xa3' 'ENCODER')$(eel '\x44\x87' 'Lavc libvpx-vp9')$(eel '\x44\x7a' 'eng')")" \
    mkwebm "$C/vq-tlang.webm";                                                vq vq-tlang.webm "carries a 'TagLanguage' element in 'SimpleTag'"
W_TRACK="$(eel '\xe1' "$(eel '\xb5' '\x47\x3b\x80\x00')")" mkwebm "$C/vq-audio.webm"; vq vq-audio.webm "carries an 'Audio' element in 'TrackEntry'"
W_SEG="$(eel '\x16\x54\xae\x6b' "$(eel '\xae' "$(eel '\xd7' '\x02')$(eel '\x86' 'V_VP9')")")" mkwebm "$C/vq-2track.webm"
                                                                              vq vq-2track.webm "has more than one 'Tracks' element in 'Segment'"
W_TRACKS="$(eel '\xae' "$(eel '\xd7' '\x02')$(eel '\x86' 'V_VP9')")" mkwebm "$C/vq-2entry.webm"
                                                                              vq vq-2entry.webm "has more than one 'TrackEntry' element in 'Tracks'"
W_TRACK="$(eel '\x73\xc5' 'sixteen-byte uid')" mkwebm "$C/vq-long.webm";        vq vq-long.webm "has a 'TrackUID' element longer than a number"
W_VOID='hidden text here' mkwebm "$C/vq-void.webm";                           vq vq-void.webm "has a 'Void' element that is not all zero bytes"
W_SEG='\x1f\x43\xb6\x75\x01\xff\xff\xff\xff\xff\xff\xff\xe7\x81\x00' mkwebm "$C/vq-live.webm"
                                                                              vq vq-live.webm "an element of unknown size"
mkwebm "$C/vq-tail.webm"; printf 'tail' >> "$C/vq-tail.webm";                  vq vq-tail.webm "has 4 byte(s) after its end (the Segment size)"
W_BLOCK="\x81\x00\x00\x80$MARK" mkwebm "$C/vq-mark.webm";                     vq vq-mark.webm "matches LEAK_PATTERN"
review "${VQ[@]%%|*}"; commit "$C" vq; bpush vq
# A file can be refused for more than one thing (vq-audio's handler and its smhd): the reason must be on
# that file's own line, wherever in it.
for e in "${VQ[@]}"; do f=${e%%|*}; line=$(printf '%s\n' "$out" | grep -F -- "  $f: ")
    want_refused "VQ  $f is refused: ${e#*|}" $rc "$line" "${e#*|}"; done
[[ "$out" != *SYNTH-MARKER* && "$out" != *clip.mov* && "$out" != *Lavf62* && "$out" != *ARTIST* && "$out" != *"My clip"* ]]
                                               want_ok      "VQb video refusals quote no refused field and not the pattern" $? "$out"
git -C "$C" clean -qfd

# ============================== pre-push, the binary scan's switch ==============================
# The binary scan runs only where a project turns it on: a tracked kit.binaries
# at the pushed tip holding the one line scan=on, or a tracked records/reviewed_binaries.txt there, even an empty one,
# so a project that relies on the scan keeps it at its move onto v0.11.0. Anything else in kit.binaries refuses a push
# that carries a binary. Off, such a push says so on one line, and the identity and credential layers still run (the
# identity layer reads the tip's raw bytes, binaries included). The switch is read at the tip, as the list is.
SW="$TMP/sw"; mk_repo "$SW"; echo "plain" > "$SW/a.txt"; commit "$SW" base
git init -q --bare "$TMP/sw.git"; git -C "$SW" push -q --no-verify "$TMP/sw.git" HEAD:refs/heads/main
SWB=$(git -C "$SW" rev-parse HEAD)
mkpdf() { printf '%%PDF-1.4\n%b\n%%%%EOF\n' '\x00\x01\x02 a stand-in PDF \xe2\xe3' > "$1"; }   # FILE: git takes it as binary
swcase() { git -C "$SW" checkout -q -B "$1" "$SWB"; git -C "$SW" clean -qfd; }
swpush() { (cd "$SW" && git push "$TMP/sw.git" "$1:refs/heads/$1" 2>&1); }
swon() { printf 'scan=on\n' > "$SW/kit.binaries"; }
swreview() { mkdir -p "$SW/records"; printf '%s  %s  2026-10-25  hooks-test  synthetic fixture\n' "$(git -C "$SW" hash-object "$SW/$1")" "$1" >> "$SW/$LIST"; }
swcase bs0; mkpng "$SW/r.png" '\x60'; swreview r.png; swon; commit "$SW" bs0
out=$(swpush bs0);                             want_ok      "BS0 switch on: a reviewed plain PNG passes (control)" $? "$out" "1 of 1 binary file(s) cleared"
swcase bs1; mkpdf "$SW/u.pdf"; swon; commit "$SW" bs1
out=$(swpush bs1); rc=$?;                      want_refused "BS1 switch on: an unreviewed PDF is refused" $rc "$out" "not cleared"
want_says "MS14 pre-push: that refusal says what you can do and what to ask the project's owner" $rc "$out" \
    "You can: review each binary named above" "The project's owner: whether this project scans binaries"
swcase bs2; mkpdf "$SW/l.pdf"; mkdir -p "$SW/records"; printf '%s  other.png  2026-10-25  hooks-test  another file\n' "$Z" > "$SW/$LIST"
commit "$SW" bs2
out=$(swpush bs2);                             want_refused "BS2 no kit.binaries but a tracked reviewed list: the scan runs, and an unreviewed PDF is refused" $? "$out" "not cleared"
swcase bs3; mkdir -p "$SW/records"; : > "$SW/$LIST"; mkpdf "$SW/e.pdf"; commit "$SW" bs3
out=$(swpush bs3);                             want_refused "BS3 an empty tracked reviewed list counts as on too" $? "$out" "not cleared"
swcase bs4; mkpng "$SW/g.png" '\x61'; swreview g.png; printf 'scan=yes\n' > "$SW/kit.binaries"; commit "$SW" bs4
out=$(swpush bs4); rc=$?;                      want_refused "BS4 a kit.binaries that isn't the one line scan=on refuses a push carrying a binary, naming it" $rc "$out" "kit.binaries"
want_says "MS15 pre-push: that refusal says what you can do and what to ask the project's owner" $rc "$out" \
    "You can: make kit.binaries the one line scan=on" "The project's owner: whether this project scans binaries"
swcase bs5; mkpdf "$SW/o.pdf"; commit "$SW" bs5
out=$(swpush bs5);                             want_ok      "BS5 switch off, no list: a PDF push passes, saying the binary scan is off" $? "$out" "binary scan off for this project"
swcase bs6; mkpng "$SW/m.png" "$MARK"; commit "$SW" bs6
out=$(swpush bs6);                             want_refused "BS6 switch off: a binary whose raw bytes hold a listed term is still refused, by the identity layer" $? "$out" "listed terms"
swcase bs7; mkpdf "$SW/c.pdf"; cp "$FIXTURE" "$SW/cred.local.txt"; commit "$SW" bs7
out=$(swpush bs7);                             want_refused "BS7 switch off: the credential layer still scans the same push" $? "$out" "credential shapes"
swcase bs8; mkpdf "$SW/w.pdf"; swon; commit "$SW" bs8; rm -f "$SW/kit.binaries"
out=$(swpush bs8);                             want_refused "BS8 the switch is read at the pushed tip: removed from the working tree only, the scan still runs" $? "$out" "not cleared"
git -C "$SW" checkout -q -- . 2>/dev/null

# ============================== pre-push, metadata layer ========================================
# Identity markers in what a push adds besides the files at its tip: the author and committer of every
# new commit (tip or not), every new commit's message, every new tag object (tagger, name, message), and
# the names of the refs pushed. What the remote already has is not read again.
M="$TMP/md"; mk_repo "$M"; echo base > "$M/base.txt"; commit "$M" base
git init -q --bare "$TMP/md.git"; git -C "$M" remote add r "$TMP/md.git"
git -C "$M" push -q --no-verify r HEAD:refs/heads/main
MBASE=$(git -C "$M" rev-parse HEAD)
mpush() { (cd "$M" && git push r "$@" 2>&1); }
mfrom() { git -C "$M" checkout -q -B "$1" "$MBASE"; }
mc() {  # FILE MESSAGE [VAR=VALUE...]: a commit adding FILE, with any identity variables given
    echo "$1" > "$M/$1"; git -C "$M" add -A; env "${@:3}" git -C "$M" commit -q --no-verify -m "$2"; }
mfrom md0; mc md0.txt "clean change"
out=$(mpush md0:refs/heads/md0);               want_ok      "MD0 metadata: a clean new commit passes, and the layer says what it read" $? "$out" "metadata scan"
mfrom md1; mc md1.txt "c" GIT_AUTHOR_NAME="Dev $MARK"
out=$(mpush md1:refs/heads/md1);               want_refused "MD1 metadata: a marker in the author name is blocked" $? "$out" "listed terms in the metadata"
                                               no_bypass    "N4  the metadata refusal does not suggest --no-verify" "$out"
mfrom md2; mc md2.txt "c" GIT_AUTHOR_EMAIL="dev@$MARK.invalid"
out=$(mpush md2:refs/heads/md2);               want_refused "MD2 metadata: a marker in the author email is blocked" $? "$out" "author of"
mfrom md3; mc md3.txt "c" GIT_COMMITTER_NAME="Dev $MARK"
out=$(mpush md3:refs/heads/md3);               want_refused "MD3 metadata: a marker in the committer name is blocked" $? "$out" "committer of"
mfrom md4; mc md4.txt "c" GIT_COMMITTER_EMAIL="dev@$MARK.invalid"
out=$(mpush md4:refs/heads/md4);               want_refused "MD4 metadata: a marker in the committer email is blocked" $? "$out" "committer of"
mfrom md5; mc md5.txt "fix for $MARK"
out=$(mpush md5:refs/heads/md5);               want_refused "MD5 metadata: a marker in a commit message is blocked" $? "$out" "message of"
                                               no_leak      "MD5b metadata: the refusal does not quote the marker" "$out"
mfrom md6; mc md6a.txt "body line one
names $MARK in the body"; mc md6b.txt "clean tip"
out=$(mpush md6:refs/heads/md6);               want_refused "MD6 metadata: a marker in a commit below the tip is blocked" $? "$out" "message of"
git -C "$M" tag -a md7 -m "release notes name $MARK" "$MBASE"
out=$(mpush refs/tags/md7);                    want_refused "MD7 metadata: a marker in a tag message is blocked" $? "$out" "tag object"
env GIT_COMMITTER_NAME="Rel $MARK" git -C "$M" tag -a md8 -m "clean" "$MBASE"
out=$(mpush refs/tags/md8);                    want_refused "MD8 metadata: a marker in a tagger is blocked" $? "$out" "tag object"
mfrom md9; mc md9.txt "clean"
out=$(mpush "md9:refs/heads/feature-$MARK");   want_refused "MD9 metadata: a marker in a pushed branch name is blocked" $? "$out" "ref name"
git -C "$M" tag "lt-$MARK" "$MBASE"
out=$(mpush "refs/tags/lt-$MARK");             want_refused "MD10 metadata: a marker in a lightweight tag's name is blocked" $? "$out" "ref name"
mfrom md13; mc md13.txt "names $MARK"; git -C "$M" tag -a md13t -m "clean" md13
out=$(mpush refs/tags/md13t);                  want_refused "MD13 metadata: a new commit pushed by its tag alone is read" $? "$out" "message of"
# A marker beside invalid UTF-8, in a pushed ref's name and on a tag message's line: BSD grep in a UTF-8 locale missed
# such a line, so pre-push matches ref names and tag objects in two passes.
mfrom md14; mc md14.txt "clean"
out=$(mpush "md14:refs/heads/feature-$(printf '\377\376')$MARK"); want_refused "MD14 metadata: a marker beside invalid UTF-8 in a pushed branch name is blocked" $? "$out" "ref name"
printf 'release notes\nbad \377\376 %s here\n' "$MARK" > "$TMP/md15.msg"; git -C "$M" tag -a md15 -F "$TMP/md15.msg" "$MBASE"
out=$(mpush refs/tags/md15);                   want_refused "MD15 metadata: a marker on a tag message's line holding invalid UTF-8 is blocked" $? "$out" "tag object"
# And in an author name and on a commit message's line: git's own matcher, run in the caller's locale, which a
# Mac's run measures on Apple's git.
mfrom md16; mc md16.txt "c" GIT_AUTHOR_NAME="Dev $(printf '\377\376')$MARK"
out=$(mpush md16:refs/heads/md16);             want_refused "MD16 metadata: a marker beside invalid UTF-8 in an author name is blocked" $? "$out" "author of"
mfrom md17; mc md17.txt "line one
bad $(printf '\377\376') $MARK here"
out=$(mpush md17:refs/heads/md17);             want_refused "MD17 metadata: a marker on a commit message's line holding invalid UTF-8 is blocked" $? "$out" "message of"
# Only what the push adds: a marker already on the remote does not block a clean commit on top of it.
mfrom md11; mc md11a.txt "old $MARK"; git -C "$M" push -q --no-verify r md11:refs/heads/md11
mc md11b.txt "clean on top"
out=$(mpush md11:refs/heads/md11);             want_ok      "MD11 metadata: a marker the remote already has is not read again" $? "$out" "metadata scan"
mfrom md12; mc md12.txt "clean"; tlist "$M" "$MARK("
out=$( (cd "$M" && git push r md12:refs/heads/md12 2>&1) ); rc=$?; tlist "$M" "$MARK"
                                               want_refused "MD12 metadata: a pattern that does not compile refuses the metadata scan" $rc "$out" "metadata scan did not run"
want_says "MS13 pre-push: the tree's scan of that pattern refuses too, naming the do-not-publish scan" $rc "$out" "REFUSING -- the do-not-publish scan did not run"
                                               no_leak      "MD12b metadata: that refusal does not quote the pattern" "$out"
git -C "$M" checkout -q main 2>/dev/null || git -C "$M" checkout -q -B main "$MBASE"

# ============================== tree scan run by CI =============================================
T="$TMP/scan"; mk_repo "$T"; echo "plain" > "$T/a.txt"; commit "$T" base
SCAN="$H/scan-tree.sh"
scan() { [[ -z "${2:-}" ]] || tpin "$T/.github/leak-pattern.pin" "$2" 1     # CI's pin, for the pattern given
         if [[ -f "$1" ]]; then (cd "$T" && env ${2:+LEAK_PATTERN="$2"} ${3:+-u LEAK_PATTERN} "$BASH_BIN" "$1" 2>&1)
         else echo "scan-tree.sh missing"; return 99; fi; }
out=$(scan "$SCAN" "$MARK");                   want_ok      "S1 tree scan: clean passes" $? "$out" "clean:"
# The verdict lines say what was matched and how much was examined, never a category of term: the
# same script runs against a CI secret with no identity term and against a full local list.
n=$(git -C "$T" ls-files | wc -l)
[[ "$out" == *"clean: $n tracked files scanned, none matches LEAK_PATTERN"* && "$out" != *identity* ]]
                                               want_ok      "S6 tree scan: clean line counts the files and names LEAK_PATTERN, not a category" $? "$out"
echo "has $MARK" > "$T/marker.txt"; commit "$T" marker
out=$(scan "$SCAN" "$MARK"); rc=$?;            want_refused "S2 tree scan: marker fails with file:line" $rc "$out" "marker.txt:1"
                                               no_leak      "S2b tree scan: hit output omits the matched text" "$out"
n=$(git -C "$T" ls-files | wc -l)
[[ "$out" == *"1 of $n tracked files match LEAK_PATTERN"* && "$out" != *identity* ]]
                                               want_ok      "S7 tree scan: hit line counts matching files of the total, not a category" $? "$out"
out=$(scan "$SCAN" "" unset);                  want_refused "S3 tree scan: unset pattern fails closed" $? "$out" "unset"
out=$(scan "$SCAN" "$MARK("); rc=$?;           want_refused "S4 tree scan: malformed pattern fails closed" $rc "$out" "did not run"
                                               no_leak      "S4b tree scan: refusal does not quote the pattern" "$out"
[[ -f "$SCAN" ]] && sed "s/^ALLOW=.*/ALLOW='(unclosed'/" "$SCAN" > "$TMP/scan-badallow.sh"
out=$(scan "$TMP/scan-badallow.sh" "$MARK");   want_refused "S5 tree scan: malformed ALLOW with a marker fails" $? "$out" "allowlist filter did not run"

# ============================== the list's pin: pre-push and the tree scan ======================
# Each reads its list against a pin: pre-push the local list against .git/leak-pattern.pin
# beside it, the tree scan CI's list against the tracked .github/leak-pattern.pin. A list cut to one row (the row a
# canary would keep), the full count with one row changed, and a missing pin each refuse, in rows, never printing a
# term or a hash; the list its pin names passes. A row is a top-level alternative: groups, bracket expressions and
# escapes don't split one.
PL="ZQCANARYROW|$MARK|zqthirdrow"
PL3='zq(ab|cd)e|zq[[:digit:]|]f|zq\.g'
PR="$TMP/pin"; mk_repo "$PR"; echo "plain text" > "$PR/a.txt"; commit "$PR" base
git init -q --bare "$TMP/pin.git"; PSHA=$(git -C "$PR" rev-parse HEAD)
ppin() { [[ -z "$1" ]] || (umask 077 && printf "LEAK_PATTERN='%s'\n" "$1" > "$(lp "$PR")")   # LIST [PATH]: LIST at its place
          (cd "$PR" && printf 'refs/heads/main %s refs/heads/main %s\n' "$PSHA" "$Z" > "$TMP/pp.in" \
          && env PATH="${2:-$PATH}" "${@:3}" "$BASH_BIN" "$HK/pre-push" r "$TMP/pin.git" 2>&1 < "$TMP/pp.in"); }    # [VAR=VALUE...]
nohash() { [[ "$1" != *SYNTH-MARKER* && "$1" != *ZQCANARYROW* && "$1" != *zqthirdrow* && ! "$1" =~ [0-9a-f]{64} ]]; }
tpin "$PR/.git/leak-pattern.pin" "$PL" 3
out=$(ppin "$PL");                             want_ok      "PN1 pre-push: the list its pin names passes" $? "$out"
out=$(ppin "ZQCANARYROW"); rc=$?;              want_refused "PN2 pre-push: a list cut to one row refuses, giving the rows" $rc "$out" "holds 1 row(s) where its pin expects 3"
want_says "MS11 pre-push: that refusal names the do-not-publish list, what you can do and what to ask the project's owner" $rc "$out" \
    "the do-not-publish list (from" "You can: if the list changed on purpose" "The project's owner: whether the change to the list was meant"
nohash "$out";                                 want_ok      "PN2b that refusal prints no term and no hash" $? "$out"
out=$(ppin "ZQCANARYROW|$MARK|zqchanged");     want_refused "PN3 pre-push: the full count with one row changed refuses" $? "$out" "but not the same ones"
rm -f "$PR/.git/leak-pattern.pin"
out=$(ppin "$PL");                             want_refused "PN4 pre-push: no pin beside the list refuses" $? "$out" "it has no pin"
tpin "$PR/.git/leak-pattern.pin" "$PL3" 3
out=$(ppin "$PL3");                            want_ok      "PN5 pre-push: groups, bracket expressions and escapes don't split a row (3 rows)" $? "$out"
pathless "$TMP/nohash" sha256sum shasum; tpin "$PR/.git/leak-pattern.pin" "$PL" 3
out=$(ppin "$PL" "$TMP/nohash"); rc=$?;        want_refused "PN6 pre-push: with neither hashing tool it refuses, naming both" $rc "$out" "neither sha256sum (GNU coreutils) nor shasum (Perl) is installed"
want_says "MS12 pre-push: that refusal names the do-not-publish list" $rc "$out" "so the do-not-publish list can't be checked against its pin"
# A list in the environment never stands in for the file's: pre-push reads no list from the environment,
# so with the full list at its place and its pin beside it, a cut list there changes nothing.
out=$(ppin "$PL");                             want_ok      "PN7b pre-push: the full list at its place, its pin beside it, passes" $? "$out"
out=$(ppin "" "" LEAK_PATTERN=ZQCANARYROW);    want_ok      "PN7 pre-push: a cut list in the environment beside that file is ignored, and the file's list passes" $? "$out"
rm -f "$(lp "$PR")"
TS="$TMP/pinscan"; mk_repo "$TS"; echo "plain" > "$TS/a.txt"; commit "$TS" base
tscan() { (cd "$TS" && env LEAK_PATTERN="$1" "$BASH_BIN" "$SCAN" 2>&1); }                                       # LIST
tpin "$TS/.github/leak-pattern.pin" "$PL" 3
out=$(tscan "$PL");                            want_ok      "SN1 tree scan: CI's list its pin names passes" $? "$out" "clean:"
out=$(tscan "ZQCANARYROW"); rc=$?;             want_refused "SN2 tree scan: a list cut to one row refuses, giving the rows" $rc "$out" "holds 1 row(s) where its pin expects 3"
nohash "$out";                                 want_ok      "SN2b that refusal prints no term and no hash" $? "$out"
out=$(tscan "ZQCANARYROW|$MARK|zqchanged");    want_refused "SN3 tree scan: the full count with one row changed refuses" $? "$out" "but not the same ones"
rm -f "$TS/.github/leak-pattern.pin"
out=$(tscan "$PL");                            want_refused "SN4 tree scan: no pin refuses" $? "$out" "it has no pin"
out=$( (cd "$TS" && env -u LEAK_PATTERN "$BASH_BIN" "$SCAN" 2>&1) )
                                               want_refused "SN5 tree scan: LEAK_PATTERN unset in CI refuses, naming it" $? "$out" "LEAK_PATTERN secret is unset"

# ============================== a hit on a line that isn't plain text ===========================
# Both gates pass git grep's hits through the allowlist filter, then name them. Without -a, grep in a UTF-8 locale takes
# a line holding invalid UTF-8 as binary and prints nothing for it, so v0.9.0 let such a hit through in both. Its NUL
# forms were caught only because bash drops NUL bytes from a command substitution; a direct
# pipe from git grep would hide every hit beside one. ML1 to ML4: a hit on a line holding invalid UTF-8, in a UTF-8
# locale and with no LANG. NB: a NUL past git's 8,000-byte look, on the hit's line; NC: the same with the allowlist's
# string on that line too; ND: a NUL inside it, where git grep names the file as binary and prints no NUL (so a direct
# pipe hides nothing there, measured; ND guards that report, which a git grep -I would drop). Each sits beside a plain
# hit in a second file, which must be named.
# The UTF-8 locale is the first of C.UTF-8 and en_US.UTF-8 that locale -a lists; with neither, those cases fail.
U8=$(locale -a 2>/dev/null | grep -a -i -x -E 'C\.utf-?8' | head -n 1)
[[ -n "$U8" ]] || U8=$(locale -a 2>/dev/null | grep -a -i -x -E 'en_US\.utf-?8' | head -n 1)
NT="$TMP/nt"; mk_repo "$NT"; echo "plain text" > "$NT/base.txt"; tpin "$NT/.github/leak-pattern.pin" "$MARK" 1; commit "$NT" base
git init -q --bare "$TMP/nt.git"; git -C "$NT" push -q --no-verify "$TMP/nt.git" HEAD:refs/heads/nt; NTB=$(git -C "$NT" rev-parse HEAD)
ntcase() { git -C "$NT" checkout -q -B nt "$NTB"; git -C "$NT" clean -qfd; }                    # the base alone, then the caller's files
ntpad() { awk 'BEGIN { s = ""; for (j = 0; j < 99; j++) s = s "y"; for (i = 0; i < 90; i++) print s }' > "$1"; }   # FILE: 9,000 bytes, no NUL
ntenv() { if [[ $1 == u8 ]]; then printf '%s\n' "LC_ALL=$U8" "LANG=$U8"; else printf '%s\n' -u LANG -u LC_ALL -u LC_CTYPE -u LANGUAGE; fi; }
ntrun() {  # MODE GATE: pre-push on the tip by the stdin protocol, or the tree scan over the checkout; MODE u8 or none
    local -a e; local l; e=(); while IFS= read -r l; do e+=("$l"); done < <(ntenv "$1")
    if [[ $2 == pre-push ]]; then
        (cd "$NT" && printf 'refs/heads/nt %s refs/heads/nt %s\n' "$(git rev-parse HEAD)" "$Z" > "$TMP/pp.in" \
            && env "${e[@]}" "$BASH_BIN" "$HK/pre-push" r "$TMP/nt.git" 2>&1 < "$TMP/pp.in")
    else (cd "$NT" && env "${e[@]}" LEAK_PATTERN="$MARK" "$BASH_BIN" "$SCAN" 2>&1); fi; }
nt_named() {  # NAME RC OUTPUT BLOCK NEEDLE...: refused, saying BLOCK, naming each NEEDLE; a NEEDLE written !X must not appear
    local name=$1 rc=$2 out=$3 blk=$4 n miss=""; shift 4
    [[ "$out" == *"$blk"* ]] || miss+=" '$blk'"
    for n in "$@"; do
        if [[ $n == '!'* ]]; then [[ "$out" != *"${n#!}"* ]] || miss+=" (names ${n#!})"; else [[ "$out" == *"$n"* ]] || miss+=" $n"; fi
    done
    if [[ $rc -ne 0 && -z "$miss" ]]; then result "$name" 0
    else result "$name" 1 "exit $rc, missing:$miss: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"; fi; }
PPB="listed terms in the tree"; STB="match LEAK_PATTERN"; NOU8="no UTF-8 locale: locale -a lists neither C.UTF-8 nor en_US.UTF-8"
ntcase; printf 'plain\nx \377\376 %s\n' "$MARK" > "$NT/a.txt"; commit "$NT" ml
if [[ -n "$U8" ]]; then
    out=$(ntrun u8 pre-push); rc=$?;           nt_named     "ML1 pre-push: a hit on a line holding invalid UTF-8, in a UTF-8 locale, is blocked and named" $rc "$out" "$PPB" a.txt:2
    out=$(ntrun u8 scan); rc=$?;               nt_named     "ML2 tree scan: a hit on a line holding invalid UTF-8, in a UTF-8 locale, fails and is named" $rc "$out" "$STB" a.txt:2
else for c in "ML1 pre-push" "ML2 tree scan"; do result "$c: a hit on a line holding invalid UTF-8, in a UTF-8 locale" 1 "$NOU8"; done; fi
out=$(ntrun none pre-push); rc=$?;             nt_named     "ML3 pre-push: the same hit with no LANG is blocked and named" $rc "$out" "$PPB" a.txt:2
out=$(ntrun none scan); rc=$?;                 nt_named     "ML4 tree scan: the same hit with no LANG fails and is named" $rc "$out" "$STB" a.txt:2
ntcase; ntpad "$NT/b1.txt"; printf '\000 %s\n' "$MARK" >> "$NT/b1.txt"; printf '%s\n' "$MARK" > "$NT/b2.txt"; commit "$NT" nb; NBS=$(git -C "$NT" rev-parse HEAD)
ntcase; ntpad "$NT/c1.txt"; printf '\000 %s __NEVER_MATCHES_BY_DEFAULT__\n' "$MARK" >> "$NT/c1.txt"; printf '%s\n' "$MARK" > "$NT/c2.txt"; commit "$NT" nc; NCS=$(git -C "$NT" rev-parse HEAD)
ntcase; printf 'x\000 %s\n' "$MARK" > "$NT/d1.txt"; printf '%s\n' "$MARK" > "$NT/d2.txt"; commit "$NT" nd; NDS=$(git -C "$NT" rev-parse HEAD)
if [[ -n "$U8" ]]; then
    git -C "$NT" checkout -q "$NBS"
    out=$(ntrun u8 pre-push); rc=$?;           nt_named     "NB1 pre-push: a NUL past git's 8,000-byte look, on a hit's line, hides neither that hit nor one in another file" $rc "$out" "$PPB" b1.txt:91 b2.txt:1
    out=$(ntrun u8 scan); rc=$?;               nt_named     "NB2 tree scan: the same NUL hides neither hit" $rc "$out" "$STB" b1.txt:91 b2.txt:1
    git -C "$NT" checkout -q "$NCS"
    out=$(ntrun u8 pre-push); rc=$?;           nt_named     "NC1 pre-push: with the allowlist's string on the NUL line, that line is allowed and the other file's hit is still named" $rc "$out" "$PPB" c2.txt:1 '!c1.txt'
    out=$(ntrun u8 scan); rc=$?;               nt_named     "NC2 tree scan: the same, the other file's hit still named" $rc "$out" "$STB" c2.txt:1 '!c1.txt'
    git -C "$NT" checkout -q "$NDS"
    out=$(ntrun u8 pre-push); rc=$?;           nt_named     "ND1 pre-push: a NUL inside git's 8,000-byte look names that file as binary and still names the other file's hit" $rc "$out" "$PPB" d1.txt:binary d2.txt:1
    out=$(ntrun u8 scan); rc=$?;               nt_named     "ND2 tree scan: the same, both files named" $rc "$out" "$STB" "Binary file d1.txt matches" d2.txt:1
else for c in NB1 NB2 NC1 NC2 ND1 ND2; do result "$c a NUL beside a hit in another file, in a UTF-8 locale" 1 "$NOU8"; done; fi
git -C "$NT" checkout -q nt

# ============================== pre-commit ======================================================
P="$TMP/pc"; mk_repo "$P"; echo "plain" > "$P/a.txt"; commit "$P" base
pc() { (cd "$P" && env PATH="${1:-$PATH}" git commit -q -m "${2:-test}" 2>&1); }
cp "$FIXTURE" "$P/config.local.txt"; git -C "$P" add config.local.txt
out=$(pc);                                     want_refused "C1 pre-commit: staged credential shapes are blocked" $? "$out" "credential shapes"
git -C "$P" reset -q; rm -f "$P/config.local.txt"
echo ok > "$P/b.txt"; git -C "$P" add b.txt
out=$(pc);                                     want_ok      "C2 pre-commit: clean content commits" $? "$out"
echo more > "$P/c.txt"; git -C "$P" add c.txt
out=$(pc "$TMP/nogl"); c3rc=$?;                want_refused "C3 pre-commit: gitleaks missing is refused" $c3rc "$out" "gitleaks was not found"
want_says "MS6 pre-commit: gitleaks missing says what you can do and what to ask IT for" $c3rc "$out" \
    "You can: install gitleaks 8.30.1" "If IT manages this machine: ask IT to install or allow gitleaks 8.30.1"
[[ "$out" != *"outside the sandbox"* ]];        want_ok "MS34 pre-commit: that refusal points nothing outside the sandbox" $? "$out"
                                               no_bypass    "N3  pre-commit's gitleaks refusal does not suggest --no-verify" "$out"
rc=1; [[ "$out" == *"missing, or hidden"* && "$out" == *"sandbox.filesystem.allowRead"* ]] || rc=0
                                               want_refused "C3b pre-commit: that refusal names both causes, missing or hidden, and what to allow" $rc "$out" "gitleaks was not found"
want_split "MS38 pre-commit: that refusal's sandbox lines split, your own block in your user settings, IT's through IT" $c3rc "$out"
git -C "$P" reset -q; rm -f "$P/c.txt"
mkdir -p "$P/.local"; echo "notes" > "$P/.local/operator-notes.md"; git -C "$P" add -f .local/operator-notes.md
out=$(pc);                                     want_refused "C4 pre-commit: anything staged under .local/ is refused" $? "$out" ".local/"
git -C "$P" reset -q; rm -rf "$P/.local"
# The same with a staged path holding invalid UTF-8, which pre-commit lists through its text tools: refused for the same
# reason, whatever the locale. Put into git's index only: a Mac's file system refuses the name.
blob=$(printf 'notes\n' | git -C "$P" hash-object -w --stdin)
git -C "$P" update-index --add --cacheinfo "100644,$blob,.local/n$(printf '\377\376').md"
out=$(pc);                                     want_refused "C4b pre-commit: a staged .local/ path holding invalid UTF-8 is refused for the same reason" $? "$out" "staged paths under .local/"
git -C "$P" reset -q
# A staged .local/ path holding the marker: still refused, and the refusal lists it only if the list, read from
# .git/leak-pattern, doesn't match it; with no list to check against, it lists no name. Both
# streams apart, as L9.
mkdir -p "$P/.local"; echo "notes" > "$P/.local/n-$MARK.md"; git -C "$P" add -f ".local/n-$MARK.md"
printf "LEAK_PATTERN='%s'\n" "$MARK" > "$(lp "$P")"
c4o=$(cd "$P" && git commit -q -m test 2>"$TMP/c4.err"); rc=$?; c4e=$(cat "$TMP/c4.err")
                                               want_refused "C4c pre-commit: a staged .local/ path holding the marker is refused" $rc "$c4o$c4e" "staged paths under .local/"
want_says "MS16 pre-commit: that refusal withholds the name, naming the do-not-publish list" $rc "$c4o$c4e" "it matches the do-not-publish list"
                                               no_leak_at   "C4d pre-commit: that refusal doesn't print the path, the list matching it" "$c4o" "$c4e"
rm -f "$(lp "$P")"
c4o=$(cd "$P" && git commit -q -m test 2>"$TMP/c4.err"); rc=$?; c4e=$(cat "$TMP/c4.err")
                                               want_refused "C4e pre-commit: with no list, the same path is refused" $rc "$c4o$c4e" "staged paths under .local/"
want_says "MS17 pre-commit: and says no do-not-publish list was there to check names against" $rc "$c4o$c4e" "no do-not-publish list in its place"
                                               no_leak_at   "C4f pre-commit: and the refusal prints no staged name, none checkable" "$c4o" "$c4e"
# A list it can't use to check a name: one that doesn't compile, and one that sets LEAK_PATTERN twice, the
# second assignment the one holding the marker. Either way the path is refused, and its name withheld.
printf "LEAK_PATTERN='%s('\n" "$MARK" > "$(lp "$P")"
c4o=$(cd "$P" && git commit -q -m test 2>"$TMP/c4.err"); rc=$?; c4e=$(cat "$TMP/c4.err")
                                               want_refused "C4g pre-commit: with a list that doesn't compile, the path is refused" $rc "$c4o$c4e" "staged paths under .local/"
                                               no_leak_at   "C4h pre-commit: and its name withheld, since it can't be checked" "$c4o" "$c4e"
printf '%s\n' "LEAK_PATTERN='zqone'" "LEAK_PATTERN='$MARK'" > "$(lp "$P")"
c4o=$(cd "$P" && git commit -q -m test 2>"$TMP/c4.err"); rc=$?; c4e=$(cat "$TMP/c4.err")
                                               want_refused "C4i pre-commit: with a list that sets LEAK_PATTERN twice, the path is refused" $rc "$c4o$c4e" "staged paths under .local/"
                                               no_leak_at   "C4j pre-commit: and its name withheld, never checked against the first assignment alone" "$c4o" "$c4e"
rm -f "$(lp "$P")"
git -C "$P" reset -q; rm -rf "$P/.local"
# pre-commit run without the stub (no KIT_INSTALL), in a clone with no .gitleaks.toml: the spawn rules beside the hook,
# never a config the environment names, and a refusal when there are none (gates procedure 13, items 1 and 4).
# fstage NAME: back to the clone's base, then the fixture staged as NAME.cfg; fc VAR=VALUE: commit what's staged so.
# FC0 is the control.
FC="$TMP/fc"; mk_repo "$FC"; echo plain > "$FC/a.txt"; commit "$FC" base; git -C "$FC" rm -q .gitleaks.toml; commit "$FC" "no config"
FCB=$(git -C "$FC" rev-parse HEAD)
fstage() { git -C "$FC" reset -q --hard "$FCB"; cp "$FIXTURE" "$FC/$1.cfg"; git -C "$FC" add "$1.cfg"; }
fc() { (cd "$FC" && env -u KIT_INSTALL "$1" git commit -q -m test 2>&1); }
HKC="$TMP/hk-norules-pc"; mkdir -p "$HKC"; install -m 0755 "$H/pre-commit" "$HKC/pre-commit"; rswap "$H/read-leak-pattern.sh" "$HKC/read-leak-pattern.sh"
fstage fc1; out=$(fc GITLEAKS_CONFIG="$TMP/allow-all.toml")
                                               want_refused "FC1 pre-commit, no stub, no .gitleaks.toml: GITLEAKS_CONFIG allowing everything doesn't clear a credential" $? "$out" "credential shapes"
fstage fc2; out=$(fc GITLEAKS_CONFIG_TOML="$(cat "$TMP/allow-all.toml")")
                                               want_refused "FC2 the same through GITLEAKS_CONFIG_TOML" $? "$out" "credential shapes"
fstage fc3; git -C "$FC" config core.hooksPath "$HKC"; out=$(fc GITLEAKS_CONFIG="$TMP/allow-all.toml"); rc=$?; git -C "$FC" config core.hooksPath "$HK"
                                               want_refused "FC3 the same with no spawn rules beside the hook: refused, the rules missing" $rc "$out" "no credential rules"
                                               no_bypass    "N6  that refusal does not suggest --no-verify" "$out"
git -C "$FC" reset -q --hard "$FCB"; echo clean > "$FC/fc0.txt"; git -C "$FC" add fc0.txt
out=$(fc GITLEAKS_CONFIG="$TMP/allow-all.toml");  want_ok      "FC0 control: no stub, no .gitleaks.toml, the spawn rules beside the hook: a clean commit goes through" $? "$out"
# A scan that read nothing is not a clean one: when the staged diff adds text and gitleaks reports ~0 bytes scanned, or
# no count, pre-commit refuses. The blind scans come from stand-in gitleaks binaries first
# on PATH, never from a switch in the hook; with the real gitleaks, commits that add no text (a deletion, a binary, a
# rename) still go through, reading nothing being right for them.
glstand() { mkdir -p "$1"; { printf '#!/bin/sh\n'; printf '%s\n' "${@:2}"; printf 'exit 0\n'; } > "$1/gitleaks"; chmod 0755 "$1/gitleaks"; }
glstand "$TMP/gl-blind" 'echo "INF 0 commits scanned." >&2' 'echo "INF scanned ~0 bytes (0 bytes) in 1ms" >&2' 'echo "INF no leaks found" >&2'
glstand "$TMP/gl-mute" 'echo "INF no leaks found" >&2'
TW="$TMP/tw"; mk_repo "$TW"; printf 'one\ntwo\n' > "$TW/a.txt"; printf '\000\001\002' > "$TW/b.bin"; echo keep > "$TW/r.txt"
commit "$TW" base; TWB=$(git -C "$TW" rev-parse HEAD)
tw() { (cd "$TW" && env PATH="${1:-$PATH}" git commit -q -m "${2:-tw}" 2>&1); }
twreset() { git -C "$TW" reset -q --hard "$TWB"; git -C "$TW" clean -qfd; }
echo three >> "$TW/a.txt"; git -C "$TW" add a.txt
out=$(tw "$TMP/gl-blind:$PATH");               want_refused "TW1 pre-commit: a scan that reads ~0 bytes while the commit adds text is refused" $? "$out" "read nothing"
                                               no_bypass    "N7  that refusal does not suggest --no-verify" "$out"
twreset; echo three >> "$TW/a.txt"; git -C "$TW" add a.txt
out=$(tw "$TMP/gl-mute:$PATH");                want_refused "TW2 pre-commit: a scan that reports no count while the commit adds text is refused" $? "$out" "read nothing"
twreset; git -C "$TW" rm -q a.txt
out=$(tw);                                     want_ok      "TW3 control: a deletion-only commit goes through, the scan reading nothing" $? "$out"
twreset; printf '\000\003' >> "$TW/b.bin"; git -C "$TW" add b.bin
out=$(tw);                                     want_ok      "TW4 control: a binary-only commit goes through" $? "$out"
twreset; git -C "$TW" mv r.txt r2.txt
out=$(tw);                                     want_ok      "TW5 control: a rename-only commit goes through" $? "$out"
twreset; git -C "$TW" rm -q a.txt
out=$(tw "$TMP/gl-blind:$PATH");               want_ok      "TW6 control: the blind stand-in with a deletion only goes through, nothing to read" $? "$out"
twreset; echo three >> "$TW/a.txt"; git -C "$TW" add a.txt
out=$(tw);                                     want_ok      "TW7 control: an ordinary commit goes through, the scan reading its bytes" $? "$out"
twreset

# ============================== the credential rules, one by one ================================
# The whole-fixture cases (P8, C1 and the rest) pass on any refusal, and gitleaks's default rules refuse the
# fixture with no custom rule at all. So each custom rule in ROOT's .gitleaks.toml has a case of its own: its
# block of the fixture (the lines under "# <rule id>"), scanned alone from a copy at a path no allowlist entry
# exempts, must be reported under that rule's id in gitleaks's JSON report. The copy's name holds "config",
# the paths the 40-character rule reads. The ids are written out here, never read from the config, so a rule
# deleted from the config fails its case instead of taking the case with it. A further shape for a rule has its
# own block, under "# <rule id>, <note>", and its own case (GR10 on).
RULES=(GR1:generic-api-key-40char-in-config GR2:generic-secret-assignment GR3:kit-jwt GR4:bearer-header
       GR5:db-url-with-password GR6:private-key-pem GR7:aws-named-access-key-id GR8:aws-named-secret-access-key
       GR9:monitoring-ping-url-uuid "GR10:bearer-header:an = inside the token"
       "GR11:generic-api-key-40char-in-config:its key name on another line"
       "GR12:private-key-pem:a tab after BEGIN" "GR13:private-key-pem:two spaces inside PRIVATE KEY")
rule_fires() {  # CASE ID [NOTE]: 0 only when the block under "# ID" (or "# ID, NOTE"), scanned alone, has a finding whose RuleID is ID
    local d="$TMP/rules/$1" rep="$TMP/rules/$1.json" h="# $2${3:+, $3}"; mkdir -p "$d"
    awk -v h="$h" '$0 == h {on = 1; next} on && !NF {exit} on' "$FIXTURE" > "$d/config.local.txt" 2>/dev/null
    [[ -s "$d/config.local.txt" ]] || { echo "the fixture has no '$h' block"; return 1; }
    gitleaks dir "$d" --config "$ROOT/.gitleaks.toml" --no-banner --log-level error \
        --report-format json --report-path "$rep" --exit-code 0 2>&1 || { echo "gitleaks did not run"; return 1; }
    grep -qE "\"RuleID\": *\"$2\"" "$rep" && return 0
    # Name the rules that did fire, never the matched text.
    echo "reported only: $(grep -oE '"RuleID": *"[^"]*"' "$rep" | sed -E 's/.*"([^"]*)"$/\1/' | sort -u | tr '\n' ' ')"
    return 1; }
for r in "${RULES[@]}"; do
    IFS=: read -r c id note <<< "$r"
    out=$(rule_fires "$c" "$id" "$note");      want_ok      "$c credential rule $id catches its own fixture block${note:+ ($note)}, under its own id" $? "$out"
done

# ============================== the project's own checks: hook-checks/ ==========================
# A spawn's extra checks live in hook-checks/<hook>/ and run inside the kit's hooks, after the kit's
# own checks pass. Each check below is a tiny script; a "ran" file proves it ran, or that it did not.
XC="$P/hook-checks/pre-commit"
chk "$XC" 10-refuse 3; echo e1 > "$P/e1.txt"; git -C "$P" add e1.txt
out=$(pc);                                     want_refused "X1 pre-commit: a failing project check refuses the commit" $? "$out" "10-refuse exited 3"
echo e2 > "$P/e2.txt"; git -C "$P" add e2.txt
if nonexec "$XC/10-refuse"; then
    out=$(pc);                                 want_refused "X2 pre-commit: a non-executable entry refuses, never skips" $? "$out" "not an executable file"
else skip "X2 pre-commit: a non-executable entry refuses, never skips" "chmod -x left a file without #! executable here"; fi
rm -rf "$XC"; chk "$XC" 20-restage 0 'echo sneaked > sneak.txt; git add sneak.txt'; echo e3 > "$P/e3.txt"; git -C "$P" add e3.txt
out=$(pc); rc=$?; git -C "$P" rm -q --cached --ignore-unmatch sneak.txt; rm -f "$P/sneak.txt"
                                               want_refused "X3 pre-commit: a check that changes what is staged refuses" $rc "$out" "changed what is staged"
rm -rf "$XC"; chk "$XC" 30-pass 0 "touch '$TMP/x4-ran'"; echo e4 > "$P/e4.txt"; git -C "$P" add e4.txt
out=$(pc); rc=$?; [[ -f "$TMP/x4-ran" ]] || rc=$((rc + 1))
                                               want_ok      "X4 pre-commit: a passing project check runs, and the commit goes through" $rc "$out"
rm -f "$TMP/x4-ran"; cp "$FIXTURE" "$P/config.local.txt"; git -C "$P" add config.local.txt
out=$(pc); rc=$?; [[ -f "$TMP/x4-ran" ]] && rc=0
                                               want_refused "X5 pre-commit: the kit's refusal stands, and no project check runs" $rc "$out" "credential shapes"
git -C "$P" reset -q; rm -f "$P/config.local.txt"; rm -rf "$P/hook-checks"
mkdir -p "$P/hook-checks"; : > "$XC"; echo e6 > "$P/e6.txt"; git -C "$P" add e6.txt
out=$(pc);                                     want_refused "X6 pre-commit: hook-checks/pre-commit that is not a folder refuses" $? "$out" "not a folder"
git -C "$P" reset -q; rm -rf "$P/hook-checks" "$P/e6.txt"
# Read in a scratch repository holding ROOT's .gitignore, so the case runs where ROOT is no repository
# (an install, where install-release runs this suite).
CI="$TMP/ignore"; git init -q "$CI"; cp "$ROOT/.gitignore" "$CI/" 2>/dev/null
git -C "$CI" check-ignore -q --no-index .local/operator-notes.md
                                               want_ok      "C5 .gitignore ignores .local/" $? ""

# ============================== a pass only from the pass point =================================
# pre-commit and pre-push report success only from the pass point at their end: an EXIT trap turns any other exit 0
# into a refusal, whether an early exit, a sourced file's exit, or a stop on an unset variable that a shell reports
# as 0, as bash 3.2 can. Copies with one line put right after their first check must
# refuse, and so must pre-push beside a list reader that exits 0 while sourced; the hooks' legitimate passes must
# still pass. KIT_TEST_BASH3 names a bash 3 to run them under too (a test tool, never a kit dependency); without it
# those runs are skipped, counted.
B3=${KIT_TEST_BASH3:-}; b3why=""
if [[ -z "$B3" ]]; then b3why="KIT_TEST_BASH3 is not set"
elif [[ "$("$B3" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)" != 3 ]]; then b3why="KIT_TEST_BASH3 is not a bash 3"; fi
early() {  # NAME FILE ANCHOR LINE: prints $TMP/early-NAME, a copy of the hooks' folder whose FILE has LINE put before
           # its first line starting ANCHOR; returns 0 only when exactly one line went in
    local d="$TMP/early-$1"; rm -rf "$d"; mkdir -p "$d"; cp -p "$HK"/* "$d/"
    awk -v a="$3" -v l="$4" '!done && index($0, a) == 1 {print l; done = 1} {print}' "$HK/$2" > "$d/$2"; chmod +x "$d/$2"
    echo "$d"; [[ $(( $(wc -l < "$d/$2") - $(wc -l < "$HK/$2") )) -eq 1 ]]; }
egc() { (cd "$P" && "$1" "$2" 2>&1); }                                                                  # BASH HOOK
egp() { tlist "$R" "$MARK"                                                                              # BASH HOOK [REF-LINES]
        (cd "$R" && printf '%s' "${3:-}" > "$TMP/pp.in" && "$1" "$2" r "$TMP/l1.git" 2>&1 < "$TMP/pp.in"); }
STOPPED="stopped before it finished"
PC_X=$(early pc-exit pre-commit '# ---- 0b.' 'exit 0'); pcx=$?
PC_U=$(early pc-unset pre-commit '# ---- 0b.' ': "$zq_unset_probe"'); pcu=$?
PP_X=$(early pp-exit pre-push 'GITDIR=' 'exit 0'); ppx=$?
PP_U=$(early pp-unset pre-push 'GITDIR=' ': "$zq_unset_probe"'); ppu=$?
PP_R=$(early pp-reader read-leak-pattern.sh 'read_leak_pattern() {' 'exit 0'); ppr=$?
eg_run() {  # SUFFIX BASH
    local s=$1 b=$2 out rc
    echo eg > "$P/eg.txt"; git -C "$P" add eg.txt
    out=$(egc "$b" "$PC_X/pre-commit"); rc=$?; (( pcx == 0 )) || rc=0
    want_refused "EG1$s pre-commit: an exit 0 right after its first check refuses" $rc "$out" "$STOPPED"
    out=$(egc "$b" "$PC_U/pre-commit"); rc=$?; (( pcu == 0 )) || rc=0
    want_refused "EG2$s pre-commit: an unset variable right after its first check refuses" $rc "$out" "zq_unset_probe"
    out=$(egc "$b" "$HK/pre-commit")
    want_ok "EG3$s pre-commit: a clean commit still passes" $? "$out"
    git -C "$P" reset -q; rm -f "$P/eg.txt"
    out=$(egp "$b" "$PP_X/pre-push" "refs/heads/main $SHA refs/heads/main $Z"$'\n'); rc=$?; (( ppx == 0 )) || rc=0
    want_refused "EG4$s pre-push: an exit 0 right after its first check refuses" $rc "$out" "$STOPPED"
    out=$(egp "$b" "$PP_U/pre-push" "refs/heads/main $SHA refs/heads/main $Z"$'\n'); rc=$?; (( ppu == 0 )) || rc=0
    want_refused "EG5$s pre-push: an unset variable right after its first check refuses" $rc "$out" "zq_unset_probe"
    # A plant that didn't go in fails the case by name: the copy it ran would be the unaltered reader.
    if (( ppr == 0 )); then
        out=$(egp "$b" "$PP_R/pre-push" "refs/heads/main $SHA refs/heads/main $Z"$'\n'); rc=$?
        want_refused "EG6$s pre-push: a list reader that exits 0 while sourced refuses" $rc "$out" "$STOPPED"
    else result "EG6$s pre-push: a list reader that exits 0 while sourced refuses" 1 "the planted exit 0 didn't go into the reader's copy, so the case would test the unaltered reader"; fi
    out=$(egp "$b" "$HK/pre-push" "")
    want_ok "EG7$s pre-push: nothing pushed still passes" $? "$out"
    out=$(egp "$b" "$HK/pre-push" "(delete) $Z refs/heads/gone $SHA"$'\n')
    want_ok "EG8$s pre-push: a branch deletion still passes" $? "$out"
    out=$(egp "$b" "$HK/pre-push" "refs/heads/main $SHA refs/heads/main $SHA"$'\n')
    want_ok "EG9$s pre-push: a push of no new commits still passes" $? "$out" "no new commits"
}
eg_run "" "$BASH_BIN"
if [[ -z "$b3why" ]]; then eg_run " (bash 3)" "$B3"
else for c in EG1 EG2 EG3 EG4 EG5 EG6 EG7 EG8 EG9; do skip "$c (bash 3)" "$b3why"; done; fi

# ============================== tracked modes ===================================================
# The hooks, the tree scan and this suite must be tracked executable: git skips a hook it can't execute with
# only a hint. A clone of no commits tracks nothing yet, so there M1 skips, counted, rather than fail: a red for
# the wrong reason teaches that red can be ignored. (The installer and its I-cases are gone: a pinned spawn gets
# its hooks from bin/kit-pin, whose cases, the installer's among them, are in tests/install_test.sh.)
if git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null 2>&1; then
modes=$(git -C "$ROOT" ls-files -s -- leak-detection/pre-commit leak-detection/pre-push \
            leak-detection/scan-tree.sh tests/hooks_test.sh)
bad=$(printf '%s\n' "$modes" | awk 'NF && $1 != "100755" {print $4}'); n=$(printf '%s\n' "$modes" | awk 'NF' | wc -l)
if [[ "$n" -eq 4 && -z "$bad" ]]; then result "M1 hooks, scan and tests are tracked executable" 0
else result "M1 hooks, scan and tests are tracked executable" 1 "tracked $n of 4; not 100755: $(echo $bad)"; fi
elif [[ -n "${KIT_INSTALL_CHECK:-}" ]]; then
    # Run as part of an install (tools/install-release.sh sets the marker): an install is the release's files with no
    # git history, so the modes are checked in the kit's repository, where the release was tagged.
    skip "M1 hooks, scan and tests are tracked executable" "this install has no git history of its own: M1 runs in the kit's repository"
else
    skip "M1 hooks, scan and tests are tracked executable" "no commits yet in $ROOT: rerun after commit one"
fi

# ============================== pre-commit: genesis gates =======================================
G="$TMP/gen"; mk_repo "$G"
gc() { (cd "$G" && git commit -q -m "${1:-x}") 2>&1; }
# The refuse-me fixture is inline: a template still carrying the TODO the hook looks for. It is not
# the checkout's CLAUDE.md, which in a spawn has its frame written and would make F2 red for the
# wrong reason. kit_docs_test.sh checks that this TODO and the kit template's are the hook's.
todo_template() { cat > "$G/CLAUDE.md" <<'TPL'
# Project conventions

## Stakes frame

<!-- TODO: write this project's stakes frame fresh, in one or two sentences. -->
TPL
}
echo a > "$G/a.txt"; git -C "$G" add a.txt
out=$(gc);                                     want_refused "F1 first commit without CLAUDE.md is refused" $? "$out" "stages no CLAUDE.md"
todo_template; git -C "$G" add CLAUDE.md
out=$(gc);                                     want_refused "F2 first commit with the frame TODO still in CLAUDE.md is refused" $? "$out" "stakes-frame TODO"
printf '# Conventions\n\n## Stakes frame\n\nOne sentence, written for this project.\n' > "$G/CLAUDE.md"; git -C "$G" add CLAUDE.md
out=$(gc);                                     want_ok      "F3 first commit with the frame written commits" $? "$out"
todo_template; git -C "$G" add CLAUDE.md
out=$(gc);                                     want_ok      "F4 later commits are not gated by the frame check" $? "$out"
git -C "$G" config user.name UNSET-SEE-REPO-GENESIS; git -C "$G" config user.email unset@invalid.local
echo b > "$G/b.txt"; git -C "$G" add b.txt
out=$(gc);                                     want_refused "ID1 the genesis sentinel identity is refused" $? "$out" "genesis sentinel"
git -C "$G" config user.name hooks-test; git -C "$G" config user.email hooks-test@invalid.local
out=$(gc);                                     want_ok      "ID2 a real identity commits" $? "$out"
# E5: the sentinel email repo-genesis sets, unset@invalid.local, is refused as the
# sentinel name is, and read the same way: from the identity git will record (git var), so a config entry, an
# environment override and --author all count. A real address on the same reserved domain is no sentinel.
# Each case stages a change of its own, so a commit the old hook let through can't leave the next case nothing to commit.
gstage() { echo "$1" > "$G/$1.txt"; git -C "$G" add "$1.txt"; }
gstage e3; git -C "$G" config user.email unset@invalid.local
out=$(gc); id3rc=$?;                           want_refused "ID3 the sentinel email with a real name is refused" $id3rc "$out" "genesis sentinel"
want_says "MS7 pre-commit: the sentinel's refusal says what you can do" $id3rc "$out" "You can: if the environment or --author sets it, drop that"
git -C "$G" config user.email hooks-test@invalid.local
gstage e4; out=$( (cd "$G" && GIT_AUTHOR_EMAIL=unset@invalid.local git commit -q -m x) 2>&1 )
                                               want_refused "ID4 the sentinel email as the author, from the environment, is refused" $? "$out" "genesis sentinel"
gstage e5; out=$( (cd "$G" && GIT_COMMITTER_EMAIL=unset@invalid.local git commit -q -m x) 2>&1 )
                                               want_refused "ID5 the sentinel email as the committer, from the environment, is refused" $? "$out" "genesis sentinel"
gstage e6; out=$( (cd "$G" && git commit -q -m x --author='Real Name <unset@invalid.local>') 2>&1 )
                                               want_refused "ID6 the sentinel email given with --author is refused" $? "$out" "genesis sentinel"
gstage e7; out=$(gc);                          want_ok      "ID7 a real name with a real address on the same domain commits" $? "$out"

# ============================== gates item 3: replace refs, grafts, inherited git settings =====
# A content gate reads what git will send or record, never what a replace ref or a graft makes git show, and a scan run
# outside a hook follows no git setting it inherits (the gates skill's procedure 13, item 3). A hook
# keeps what git sets for it: in a linked worktree git gives it GIT_DIR, and the hooks must still work there.
X="$TMP/rc"; mk_repo "$X"; echo "plain" > "$X/a.txt"; commit "$X" base; XB=$(git -C "$X" rev-parse HEAD)
git init -q --bare "$TMP/rc.git"; git -C "$X" remote add r "$TMP/rc.git"
xdirect() { (cd "$X" && printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "${2:-$Z}" > "$TMP/pp.in" \
              && "$BASH_BIN" "$HK/pre-push" r "$TMP/rc.git" 2>&1 < "$TMP/pp.in"); }   # SHA [REMOTE-SHA]
echo "has $MARK" > "$X/m.txt"; commit "$X" marker; XM=$(git -C "$X" rev-parse HEAD)
git -C "$X" rm -q --cached m.txt; XC=$(git -C "$X" commit-tree "$(git -C "$X" write-tree)" -p "$XB" -m marker)
git -C "$X" reset -q --hard "$XM"; git -C "$X" replace "$XM" "$XC"
out=$(xdirect "$XM");                          want_refused "RG1 pre-push: a replace ref pointing the pushed commit at a clean one hides no marker" $? "$out" "listed terms"
git -C "$X" replace -d "$XM" >/dev/null
git -C "$X" checkout -q -B g "$XB"; git -C "$X" commit -q --allow-empty --no-verify -m "names $MARK"
git -C "$X" commit -q --allow-empty --no-verify -m clean; XG=$(git -C "$X" rev-parse HEAD)
printf '%s %s\n' "$XG" "$XB" > "$X/.git/info/grafts"
# The remote already holds the base, so the two new commits add no text and only the metadata layer reads them.
git -C "$X" push -q --no-verify r "$XB:refs/heads/main"
out=$(xdirect "$XG" "$XB");                    want_refused "RG2 pre-push: a graft hiding a commit whose message holds a marker refuses" $? "$out" "grafts"
rm -f "$X/.git/info/grafts"
out=$(xdirect "$XG" "$XB");                    want_refused "RG2b and without the graft, the same push is blocked for the marker" $? "$out" "listed terms"
git -C "$X" checkout -q main
# pre-commit reads one staged blob through git, the first commit's CLAUDE.md: a replace ref there must not hide the
# frame's TODO. gitleaks reads the staged content its own way, so a replace ref over a staged credential hid nothing
# even before (RG3b, which passed on the hook before replace refs were turned off); it stays as a control.
YF="$TMP/rcf"; mk_repo "$YF"
printf '# Project conventions\n\n## Stakes frame\n\n<!-- TODO: write this project'"'"'s stakes frame fresh, in one or two sentences. -->\n' > "$YF/CLAUDE.md"
git -C "$YF" add CLAUDE.md; YT=$(git -C "$YF" rev-parse :CLAUDE.md)
git -C "$YF" replace "$YT" "$(printf '# Conventions\n\n## Stakes frame\n\nWritten.\n' | git -C "$YF" hash-object -w --stdin)"
out=$( (cd "$YF" && git commit -q -m one) 2>&1 ); want_refused "RG3 pre-commit: a replace ref over the staged CLAUDE.md hides no frame TODO" $? "$out" "stakes-frame TODO"
Y="$TMP/rcc"; mk_repo "$Y"; echo "plain" > "$Y/a.txt"; commit "$Y" base
cp "$FIXTURE" "$Y/cred.txt"; git -C "$Y" add cred.txt
YB=$(git -C "$Y" rev-parse :cred.txt); git -C "$Y" replace "$YB" "$(echo "nothing here" | git -C "$Y" hash-object -w --stdin)"
out=$( (cd "$Y" && git commit -q -m x) 2>&1 ); want_refused "RG3b pre-commit: a replace ref over a staged credential hides nothing from gitleaks" $? "$out" "credential shapes"
git -C "$Y" replace -d "$YB" >/dev/null; git -C "$Y" reset -q; rm -f "$Y/cred.txt"
echo ok > "$Y/b.txt"; git -C "$Y" add b.txt; git -C "$Y" rev-parse HEAD > "$Y/.git/info/grafts"
out=$( (cd "$Y" && git commit -q -m x) 2>&1 ); want_refused "RG4 pre-commit: a repository with grafts refuses" $? "$out" "grafts"
rm -f "$Y/.git/info/grafts"; git -C "$Y" reset -q; rm -f "$Y/b.txt"
SD="$TMP/rcsd"; mk_repo "$SD"; echo "has $MARK" > "$SD/m.txt"; tpin "$SD/.github/leak-pattern.pin" "$MARK" 1; commit "$SD" d
SC="$TMP/rcsc"; mk_repo "$SC"; echo "plain" > "$SC/a.txt"; tpin "$SC/.github/leak-pattern.pin" "$MARK" 1; commit "$SC" c
out=$( (cd "$SD" && env GIT_DIR="$SC/.git" GIT_WORK_TREE="$SC" LEAK_PATTERN="$MARK" "$BASH_BIN" "$SCAN" 2>&1) )
                                               want_refused "RG5 tree scan: an inherited GIT_DIR naming another checkout doesn't move the scan" $? "$out" "m.txt:1"
git -C "$SC" rev-parse HEAD > "$SC/.git/info/grafts"
out=$( (cd "$SC" && env LEAK_PATTERN="$MARK" "$BASH_BIN" "$SCAN" 2>&1) ); want_refused "RG6 tree scan: a repository with grafts refuses" $? "$out" "grafts"
rm -f "$SC/.git/info/grafts"
out=$( (cd "$SC" && env LEAK_PATTERN="$MARK" "$BASH_BIN" "$SCAN" 2>&1) ); want_ok "RG6b tree scan: the same checkout without them is clean" $? "$out" "clean:"
# A linked worktree: git sets GIT_DIR for its hooks, which names the worktree's own git folder; pre-push reads the
# list's pin from the repository's shared git folder, which every worktree of it shares (as kit-history-audit reads
# it), and never from the worktree's own, so a worktree needs no pin of its own (queue 452).
WT="$TMP/rcwt"; git -C "$X" worktree add -q -b wt "$WT" "$XB" 2>/dev/null; WTG=$(git -C "$WT" rev-parse --absolute-git-dir)
echo "w" > "$WT/w.txt"; git -C "$WT" add w.txt
out=$( (cd "$WT" && git commit -q -m w) 2>&1 ); want_ok "WT1 pre-commit in a linked worktree: a clean commit passes" $? "$out"
out=$( (cd "$WT" && git push -q r wt 2>&1) ); want_ok "WT2 pre-push in a linked worktree with no pin of its own: a clean push passes, on the shared pin" $? "$out"
echo "has $MARK" > "$WT/m2.txt"; git -C "$WT" add m2.txt; git -C "$WT" commit -q --no-verify -m m2
out=$( (cd "$WT" && git push -q r wt 2>&1) ); want_refused "WT3 pre-push in a linked worktree: a marker is still blocked" $? "$out" "listed terms"
# The worktree's own folder never stands in for the shared one: a pin there that names the list doesn't let a push
# through when the shared pin doesn't, and a stale one there doesn't refuse a push the shared pin allows. Each push is a
# clean commit on a branch of its own, so only the pin decides.
wtpush() { (cd "$WT" && git checkout -q -b "$1" "$XB" && echo "$1" > "$WT/$1.txt" && git add "$1.txt" \
              && git commit -q --no-verify -m "$1" && git push -q r "$1") 2>&1; }   # BRANCH: a clean commit, pushed
tpin "$X/.git/leak-pattern.pin" "zqother-$MARK" 1; tpin "$WTG/leak-pattern.pin" "$MARK" 1
out=$(wtpush wt4); want_refused "WT4 pre-push in a linked worktree: a shared pin that doesn't name the list refuses, a matching pin in the worktree's own folder never read" $? "$out" "doesn't match its pin"
tpin "$X/.git/leak-pattern.pin" "$MARK" 1; tpin "$WTG/leak-pattern.pin" "zqstale-$MARK" 1
out=$(wtpush wt5); want_ok "WT5 pre-push in a linked worktree: a stale pin left in the worktree's own folder is never read in the shared pin's place" $? "$out"
rm -f "$WTG/leak-pattern.pin"
# Grafts sit in the shared git folder (info/grafts), and each gate finds them from a linked worktree too, through
# --git-path, never the worktree's own folder (purple's §602, F1): a commit and a push from the worktree both refuse.
git -C "$X" rev-parse HEAD > "$X/.git/info/grafts"
(cd "$WT" && git checkout -q -b wt6 "$XB" && echo wt6 > "$WT/wt6.txt" && git add wt6.txt) >/dev/null 2>&1
out=$( (cd "$WT" && git commit -q -m wt6) 2>&1 ); want_refused "WT6 pre-commit in a linked worktree: grafts in the shared git folder refuse" $? "$out" "grafts"
(cd "$WT" && git commit -q --no-verify -m wt6) >/dev/null 2>&1
out=$( (cd "$WT" && git push -q r wt6) 2>&1 ); want_refused "WT7 pre-push in a linked worktree: grafts in the shared git folder refuse" $? "$out" "grafts"
rm -f "$X/.git/info/grafts"

# ============================== git config a gate's git calls read ==============================
# A mailmap maps a commit's author to another name; git log --author matches the mapped name, so
# pre-push's metadata scan missed a marker author until it read the identity git recorded
# (--no-use-mailmap). Forced colour (color.ui or color.diff = always, in any config file) colourises
# the diff gitleaks parses, so gitleaks found nothing until the gates forced colour off in the
# environment of their git calls. Routes: the work tree, HOME's config, the XDG config, the repo's
# .git/config. The attribute routes measured there (a *.png diff passing a
# binary, a -diff line passing a credential) are left for a later release: their fix is not
# a few lines in a gate -- an attribute from .git/info/attributes reaches no config
# override. pushes and commits run under empty scratch HOME/XDG, so the real user's config never bleeds in.
GM="$TMP/gm"; mk_repo "$GM"; echo plain > "$GM/base.txt"; commit "$GM" base
git init -q --bare "$TMP/gm.git"; git -C "$GM" remote add r "$TMP/gm.git"
git -C "$GM" push -q --no-verify r HEAD:refs/heads/main >/dev/null 2>&1
GMB=$(git -C "$GM" rev-parse HEAD)
MM="Clean Name <c@invalid.local> $MARK a <c@invalid.local>"        # maps the marker author to a clean name
gc_home="$TMP/gm-home"; gc_xdg="$TMP/gm-xdg"
gc_clear() { git -C "$GM" config --local --unset mailmap.file 2>/dev/null; git -C "$GM" config --local --unset color.ui 2>/dev/null
             git -C "$GM" config --local --unset color.diff 2>/dev/null; rm -f "$GM/.mailmap"; : > "$GM/.git/info/exclude"
             rm -rf "$gc_home" "$gc_xdg"; mkdir -p "$gc_home" "$gc_xdg/git"; }
gc_mailmap() { case $1 in                                          # ROUTE: place the mailmap by that route
    tree) printf '%s\n' "$MM" > "$GM/.mailmap"; echo .mailmap > "$GM/.git/info/exclude" ;;
    home) printf '%s\n' "$MM" > "$gc_home/mm"; git config -f "$gc_home/.gitconfig" mailmap.file "$gc_home/mm" ;;
    xdg)  printf '%s\n' "$MM" > "$gc_xdg/mm"; git config -f "$gc_xdg/git/config" mailmap.file "$gc_xdg/mm" ;;
    repo) printf '%s\n' "$MM" > "$GM/.git/mm"; git -C "$GM" config --local mailmap.file "$GM/.git/mm" ;; esac; }
gc_colour() { case $1 in                                           # ROUTE: force colour on by that route
    home) git config -f "$gc_home/.gitconfig" color.ui always; git config -f "$gc_home/.gitconfig" color.diff always ;;
    xdg)  git config -f "$gc_xdg/git/config" color.ui always; git config -f "$gc_xdg/git/config" color.diff always ;;
    repo) git -C "$GM" config --local color.ui always; git -C "$GM" config --local color.diff always ;; esac; }
gcpush() { (cd "$GM" && env HOME="$gc_home" XDG_CONFIG_HOME="$gc_xdg" git push r "$@" 2>&1); }
gccommit() { (cd "$GM" && env HOME="$gc_home" XDG_CONFIG_HOME="$gc_xdg" git commit "$@" 2>&1); }
for route in tree home xdg repo; do
    gc_clear
    git -C "$GM" checkout -q -B "mm-$route" "$GMB"; git -C "$GM" clean -qfd
    gc_mailmap "$route"
    echo x > "$GM/mm.txt"; git -C "$GM" add mm.txt
    git -C "$GM" -c user.name="$MARK a" -c user.email=c@invalid.local commit -q --no-verify -m "mm $route"
    out=$(gcpush "mm-$route:refs/heads/mm-$route"); rc=$?; on_remote "refs/heads/mm-$route" gm && rc=0
    want_refused "MP-$route pre-push: a marker author mapped by a mailmap ($route) is still blocked" $rc "$out" "listed terms in the metadata"
done
for route in home xdg repo; do
    gc_clear
    git -C "$GM" checkout -q -B "col-$route" "$GMB"; git -C "$GM" clean -qfd
    gc_colour "$route"
    cp "$FIXTURE" "$GM/cred.txt"; git -C "$GM" add cred.txt
    out=$(gccommit -q -m "cl $route"); rc=$?
    want_refused "CL-$route pre-commit: a staged credential is caught with colour forced ($route)" $rc "$out" "credential shapes"
    git -C "$GM" reset -q; rm -f "$GM/cred.txt"
    echo clean > "$GM/cl.txt"; git -C "$GM" add cl.txt; git -C "$GM" commit -q --no-verify -m "clean $route"
    out=$(gcpush "col-$route:refs/heads/col-$route"); rc=$?; on_remote "refs/heads/col-$route" gm && rc=0
    want_ok "CP-$route pre-push: a clean push goes through with colour forced ($route)" $rc "$out" "adding text scanned, clean"
done
gc_clear
# The same routes under a git that drops the config the environment gives it (GIT_CONFIG_COUNT and its pairs), as a
# git older than 2.31 ignores it: the gates must ask for uncoloured output on the command line too, not only through
# the environment. The hooks run directly here, so the wrapper first on PATH is the git they
# and gitleaks find: a hook that git runs finds git's own exec-path first.
GW="$TMP/git-noenv"; mkdir -p "$GW"
{ cat <<'W'
#!/bin/sh
# git, without the config the environment gives it (GIT_CONFIG_COUNT and its pairs), as a git older than 2.31 ignores it
n=${GIT_CONFIG_COUNT:-0}; i=0
while [ "$i" -lt "$n" ]; do unset "GIT_CONFIG_KEY_$i" "GIT_CONFIG_VALUE_$i"; i=$((i + 1)); done
unset GIT_CONFIG_COUNT
W
printf 'exec "%s" "$@"\n' "$(command -v git)"; } > "$GW/git"; chmod 0755 "$GW/git"
gcdirect() { (cd "$GM" && env HOME="$gc_home" XDG_CONFIG_HOME="$gc_xdg" PATH="$1:$PATH" "$BASH_BIN" "$HK/pre-commit") 2>&1; }
gpdirect() {  # GITDIR BRANCH: pre-push by the stdin protocol, that git first on PATH
    (cd "$GM" && printf 'refs/heads/%s %s refs/heads/%s %s\n' "$2" "$(git rev-parse "$2")" "$2" "$Z" > "$TMP/pp.in" \
        && env HOME="$gc_home" XDG_CONFIG_HOME="$gc_xdg" PATH="$1:$PATH" "$BASH_BIN" "$HK/pre-push" r "$TMP/gm.git" < "$TMP/pp.in") 2>&1; }
for route in home xdg repo; do
    gc_clear
    git -C "$GM" checkout -q -B "cw-$route" "$GMB"; git -C "$GM" clean -qfd
    gc_colour "$route"
    cp "$FIXTURE" "$GM/cred.txt"; git -C "$GM" add cred.txt
    out=$(gcdirect "$GW"); rc=$?
    want_refused "CLW-$route pre-commit, a git ignoring the environment's config: a staged credential is caught with colour forced ($route)" $rc "$out" "credential shapes"
    git -C "$GM" commit -q --no-verify -m "cred $route"
    out=$(gpdirect "$GW" "cw-$route"); rc=$?
    want_refused "CPC-$route pre-push, the same git: a pushed credential is caught by the scan itself with colour forced ($route)" $rc "$out" "gitleaks found credential shapes"
    git -C "$GM" checkout -q -B "cwc-$route" "$GMB"; git -C "$GM" clean -qfd
    echo clean > "$GM/cw.txt"; git -C "$GM" add cw.txt; git -C "$GM" commit -q --no-verify -m "clean $route"
    out=$(gpdirect "$GW" "cwc-$route"); rc=$?
    want_ok "CPW-$route pre-push, the same git: a clean push goes through with colour forced ($route)" $rc "$out" "adding text scanned, clean"
done
gc_clear
# A git older than 2.31, or one whose version can't be read, is refused by name in both hooks, before anything is
# scanned. gitver DIR VERSION: a git that reports VERSION and is otherwise the real one.
gitver() { mkdir -p "$1"; { printf '#!/bin/sh\ncase "$1" in --version|version) echo "git version %s"; exit 0 ;; esac\n' "$2"
                            printf 'exec "%s" "$@"\n' "$(command -v git)"; } > "$1/git"; chmod 0755 "$1/git"; }
gitver "$TMP/git-old" 2.30.2; gitver "$TMP/git-odd" banana
git -C "$GM" checkout -q -B og "$GMB"; git -C "$GM" clean -qfd
echo og > "$GM/og.txt"; git -C "$GM" add og.txt
out=$(gcdirect "$TMP/git-old"); rc=$?
want_refused "OG1 pre-commit: a git older than 2.31 is refused, naming both versions" $rc "$out" "git 2.30.2 is older than 2.31"
GITSAYS=("You can: install git 2.31 or later" "If IT manages this machine: ask IT for git 2.31 or later")
want_says "MS1 pre-commit: that refusal says what you can do and what to ask IT for" $rc "$out" "${GITSAYS[@]}"
out=$(gcdirect "$TMP/git-odd"); rc=$?
want_refused "OG3 pre-commit: a git whose version can't be read is refused" $rc "$out" "could not read git's version"
want_says "MS2 pre-commit: so does that one" $rc "$out" "${GITSAYS[@]}"
git -C "$GM" commit -q --no-verify -m og
out=$(gpdirect "$TMP/git-old" og); rc=$?
want_refused "OG2 pre-push: a git older than 2.31 is refused, naming both versions" $rc "$out" "git 2.30.2 is older than 2.31"
want_says "MS3 pre-push: that refusal says what you can do and what to ask IT for" $rc "$out" "${GITSAYS[@]}"
out=$(gpdirect "$TMP/git-odd" og); rc=$?
want_refused "OG4 pre-push: a git whose version can't be read is refused" $rc "$out" "could not read git's version"
want_says "MS4 pre-push: so does that one" $rc "$out" "${GITSAYS[@]}"
gc_clear

# ============================== locale: text byte-wise, matching in the caller's ==============================
# Each gate runs its text tools under LC_ALL=C and its matchers in the locale its caller set, so a list row written
# with a non-ASCII letter still blocks that letter's other case in a UTF-8 locale: in pre-push's tree scan, its
# metadata scan and a ref name, and in the tree scan CI runs. A forced C locale folds only ASCII.
NA_LO=$(printf 'synth-mark\303\251r-7f3a'); NA_UP=$(printf 'SYNTH-MARK\303\211R-7F3A')   # the stand-in with an e acute
if [[ -n "$U8" ]]; then
    NA="$TMP/na"; mk_repo "$NA"; tlist "$NA" "$NA_LO"; echo base > "$NA/base.txt"; commit "$NA" base
    git init -q --bare "$TMP/na.git"; git -C "$NA" push -q --no-verify "$TMP/na.git" HEAD:refs/heads/main; NAB=$(git -C "$NA" rev-parse HEAD)
    napush() {  # LOCALREF REMOTEREF: pre-push by the stdin protocol, in the UTF-8 locale, the list that one row
        (cd "$NA" && printf '%s %s %s %s\n' "$1" "$(git rev-parse "$1")" "$2" "$Z" > "$TMP/pp.in" \
            && env LC_ALL="$U8" LANG="$U8" "$BASH_BIN" "$HK/pre-push" r "$TMP/na.git" 2>&1 < "$TMP/pp.in"); }
    git -C "$NA" checkout -q -B na1 "$NAB"; printf 'has %s here\n' "$NA_UP" > "$NA/na1.txt"; commit "$NA" na1
    out=$(napush refs/heads/na1 refs/heads/na1)
                                               want_refused "ML5 pre-push: a row with a non-ASCII letter blocks its other case in the tree, UTF-8 locale" $? "$out" "listed terms in the tree"
    git -C "$NA" checkout -q -B na2 "$NAB"; echo x > "$NA/na2.txt"; git -C "$NA" add -A
    git -C "$NA" -c user.name="Dev $NA_UP" commit -q --no-verify -m na2
    out=$(napush refs/heads/na2 refs/heads/na2)
                                               want_refused "MD18 pre-push: that row blocks its other case in an author name, UTF-8 locale" $? "$out" "author of"
    git -C "$NA" checkout -q -B na3 "$NAB"; echo y > "$NA/na3.txt"; commit "$NA" na3
    out=$(napush refs/heads/na3 "refs/heads/f-$NA_UP")
                                               want_refused "MD19 pre-push: that row blocks its other case in a pushed ref's name, UTF-8 locale" $? "$out" "ref name"
    NTS="$TMP/na-scan"; mk_repo "$NTS"; printf 'has %s here\n' "$NA_UP" > "$NTS/a.txt"; commit "$NTS" base; tpin "$NTS/.github/leak-pattern.pin" "$NA_LO" 1
    out=$( (cd "$NTS" && env LC_ALL="$U8" LANG="$U8" LEAK_PATTERN="$NA_LO" "$BASH_BIN" "$SCAN" 2>&1) ); rc=$?
                                               want_refused "ML6 tree scan: that row blocks its other case in a tracked file, UTF-8 locale" $rc "$out" "match LEAK_PATTERN"
else
    for c in ML5 MD18 MD19 ML6; do skip "$c" "locale -a lists no UTF-8 locale"; done
fi

# ============================== grep forms over files a search may skip (procedure 11) ================
# procedure 11 tells a reader which search forms see a NUL file, a non-UTF-8 file and an unreadable file, and
# runs its grep forms under LC_ALL=C on every platform. This runs those forms on the stock /usr/bin/grep: GNU
# grep on Linux, BSD grep in the macOS install smoke; a difference there is a red to report, not to paper over.
# Expected set, measured on GNU grep 3.11 under LC_ALL=C and C.utf8
# alike: -l and -a -l name every readable file; -I drops the NUL file; -q exits 0 on each non-UTF-8 file
# alone, the invalid bytes on the marker's line (bad) or on the line before it (bad2); a count sees every
# readable file; an unreadable file in range exits 2. GF8 records the same -rl in a UTF-8 locale without
# LC_ALL=C: on BSD grep it missed the ASCII marker on a line holding invalid UTF-8. That miss is why
# procedure 11 sets LC_ALL=C, so GF8 is printed as a note and counted nowhere, never as coverage.
GF="$TMP/grepforms"; rm -rf "$GF"; mkdir -p "$GF"
printf 'plain %s here\n' "$MARK" > "$GF/plain.txt"
printf 'nul\000 %s here\n' "$MARK" > "$GF/nul.txt"
printf 'bad \377\376 %s here\n' "$MARK" > "$GF/bad.txt"
printf 'bad \377\376 line\nnext %s here\n' "$MARK" > "$GF/bad2.txt"
printf 'noread %s here\n' "$MARK" > "$GF/noread.txt"; chmod 000 "$GF/noread.txt"
SG=/usr/bin/grep; [[ -x "$SG" ]] || SG=$(command -v grep)
gfset() { (cd "$GF" && LC_ALL=C "$SG" "$@" -e "$MARK" . 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ,); }
GFALL="bad.txt,bad2.txt,nul.txt,plain.txt,"
s=$(gfset -rl);   [[ "$s" == "$GFALL" ]];        result "GF1 LC_ALL=C /usr/bin/grep -rl names the NUL and non-UTF-8 files" $? "names [$s] want [$GFALL]"
s=$(gfset -a -rl);[[ "$s" == "$GFALL" ]];        result "GF2 LC_ALL=C /usr/bin/grep -a -rl names the same set" $? "names [$s] want [$GFALL]"
s=$(gfset -rlI);  [[ "$s" == "bad.txt,bad2.txt,plain.txt," ]]; result "GF3 LC_ALL=C /usr/bin/grep -rlI drops the NUL file" $? "names [$s] want [bad.txt,bad2.txt,plain.txt,]"
q1=0; q2=0; (cd "$GF" && LC_ALL=C "$SG" -q -e "$MARK" bad.txt 2>/dev/null) || q1=$?; (cd "$GF" && LC_ALL=C "$SG" -q -e "$MARK" bad2.txt 2>/dev/null) || q2=$?
[[ $q1 -eq 0 && $q2 -eq 0 ]];                    result "GF4 LC_ALL=C /usr/bin/grep -q exits 0 on each non-UTF-8 file alone" $? "exit $q1 (bad), $q2 (bad2), want 0 and 0"
(cd "$GF" && LC_ALL=C "$SG" -rl -e "$MARK" . >/dev/null 2>&1); grc=$?; [[ $grc -eq 2 ]]; result "GF5 LC_ALL=C /usr/bin/grep -rl exits 2 when a file can't be read" $? "exit $grc, want 2"
n=$( (cd "$GF" && LC_ALL=C "$SG" -r -c -e "$MARK" . 2>/dev/null) | awk -F: '{s+=$NF} END{print s+0}'); [[ "$n" -eq 4 ]]; result "GF6 LC_ALL=C /usr/bin/grep -r -c counts the match in every readable file" $? "count $n, want 4"
if command -v rg >/dev/null 2>&1; then
    r=$( (cd "$GF" && rg --text --hidden --no-ignore -l -e "$MARK" . 2>/dev/null) | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ,)
    [[ "$r" == "$GFALL" ]];                      result "GF7 ripgrep --text --hidden --no-ignore -l agrees with grep -a -l" $? "rg [$r] grep [$GFALL]"
else skip "GF7 ripgrep --text --hidden --no-ignore -l agrees with grep -a -l" "no ripgrep on PATH"; fi
if [[ -n "$U8" ]]; then
    s=$( (cd "$GF" && LC_ALL=$U8 "$SG" -rl -e "$MARK" . 2>/dev/null) | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ,)
    printf 'note  %s\n' "GF8 /usr/bin/grep -rl in $U8, without LC_ALL=C, names [$s] (recorded, not counted; [$GFALL] is every readable file)"
else printf 'note  %s\n' "GF8 not recorded: locale -a lists no UTF-8 locale"; fi
chmod 0644 "$GF/noread.txt"

# ============================== a project with no do-not-publish list: the reserved line =================
# A project with no do-not-publish list says so with one deliberate line in .git/leak-pattern, a reserved value pinned
# like any list. A missing list still refuses, naming that line; a list file that exists but can't be read refuses with
# a message of its own; with the line, pre-push turns its identity layers off, says so on every push, and still runs the
# credential scan. The pin guards the line: written over a real list, it doesn't match that list's pin. CI's scan reads
# the same value from its secret, against its tracked pin. This line is the suites' one definition of the value:
# install_test reads it from here (its NV0), so each of the four readers' cases (NL4, NS2 and HA30 here, KL10 there)
# is fed the same value, and a change to any one reader's copy fails its case.
NOLIST='kit:no-identity-list'
NL="$TMP/nl"; mk_repo "$NL"; echo "plain text" > "$NL/a.txt"; commit "$NL" base
git init -q --bare "$TMP/nl.git"; git -C "$NL" push -q --no-verify "$TMP/nl.git" HEAD:refs/heads/main
NLB=$(git -C "$NL" rev-parse HEAD)
nlc() { git -C "$NL" checkout -q -B "$1" "$NLB"; printf '%s\n' "$2" > "$NL/f.txt"; commit "$NL" "$1"; git -C "$NL" rev-parse HEAD; }
NL_CLEAN=$(nlc nlclean "nothing listed here"); NL_MARK=$(nlc nlmark "has $MARK here")
git -C "$NL" checkout -q -B nlcred "$NLB"; cp "$FIXTURE" "$NL/cred.txt"; commit "$NL" nlcred; NL_CRED=$(git -C "$NL" rev-parse HEAD)
nlpush() {  # SHA: pre-push by the stdin protocol over the remote's main, the list at its place only
    (cd "$NL" && printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$NLB" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN "$BASH_BIN" "$HK/pre-push" r "$TMP/nl.git" 2>&1 < "$TMP/pp.in"); }
nllist() { printf "LEAK_PATTERN='%s'\n" "$1" > "$(lp "$NL")"; tpin "$NL/.git/leak-pattern.pin" "$1" "${2:-1}"; }   # VALUE [ROWS]
rm -f "$(lp "$NL")"
out=$(nlpush "$NL_CLEAN"); rc=$?;              want_refused "NL1 pre-push: no list file refuses, naming the reserved line and where it goes" $rc "$out" "LEAK_PATTERN='$NOLIST'"
want_says "MS8 pre-push: no list says what you can do and what to ask the project's owner" $rc "$out" \
    "You can: if this project has a do-not-publish list, put it in" "The project's owner: whether this project keeps a do-not-publish list"
# A sandbox read policy over the list's folder hides the file, as an absent one (measured with bubblewrap's tmpfs, the
# Linux sandbox's tool): so the refusals for a list absent or unreadable say IT's policy may be the cause, naming the folder.
LISTSAYS="If IT manages this machine: a sandbox read policy may block the do-not-publish list's folder, ~/.config/morrowcairn/lists/"
want_says "MS30 pre-push: no list says a sandbox read policy may hide the list's folder, naming it" $rc "$out" "$LISTSAYS"
[[ "$out" != *"outside the sandbox"* ]];        want_ok "MS35 pre-push: that refusal points nothing outside the sandbox" $? "$out"
want_split "MS39 pre-push: the no-list refusal's sandbox lines split, your own block in your user settings, IT's through IT" $rc "$out"
# A printed step never writes over a list that is there (one a sandbox hides is still there): each line of the no-list
# steps that writes the list, run with the suite's home against a stand-in list at its place, refuses and leaves it as
# it was.
printf '%s\n' "LEAK_PATTERN='zqkeepterm'" > "$(lp "$NL")"; nlsum=$(tsum < "$(lp "$NL")"); nw=0; nbad=""
while IFS= read -r l; do
    [[ "$l" == *"echo \"LEAK_PATTERN="*">"* ]] || continue
    nw=$((nw + 1))
    printf '%s\n' "$l" | (cd "$NL" && HOME="$TH" "$BASH_BIN") >/dev/null 2>&1 && nbad+=" a write exited 0"
done <<< "$out"
[[ $nw -ge 1 && -z "$nbad" && "$(tsum < "$(lp "$NL")")" == "$nlsum" ]]
want_ok "MS32 pre-push: each no-list step that writes the list refuses a list already there, leaving it unchanged" $? "writes $nw;$nbad"
rm -f "$(lp "$NL")"
nllist "$MARK"; chmod 000 "$(lp "$NL")"
if [[ -r "$(lp "$NL")" ]]; then skip "NL2 pre-push: a list file it can't read refuses with its own message" "the file stays readable at mode 000 (root)"
     skip "MS9 pre-push: that refusal names the do-not-publish list and says what you can do" "the file stays readable at mode 000 (root)"
     skip "MS31 pre-push: and says a sandbox read policy may block the list's folder" "the file stays readable at mode 000 (root)"
     skip "MS36 pre-push: that refusal points nothing outside the sandbox" "the file stays readable at mode 000 (root)"
     skip "MS40 pre-push: and its sandbox lines split, your own block in your user settings, IT's through IT" "the file stays readable at mode 000 (root)"
else out=$(nlpush "$NL_CLEAN"); rc=$?;         want_refused "NL2 pre-push: a list file it can't read refuses with its own message, not the missing list's" $rc "$out" "exists but can't be read"
     want_says "MS9 pre-push: that refusal names the do-not-publish list and says what you can do" $rc "$out" \
         "so the do-not-publish list can't be checked" "You can: make it a file this user can read"
     want_says "MS31 pre-push: and says a sandbox read policy may block the list's folder" $rc "$out" "$LISTSAYS"
     [[ "$out" != *"outside the sandbox"* ]];   want_ok "MS36 pre-push: that refusal points nothing outside the sandbox" $? "$out"
     want_split "MS40 pre-push: and its sandbox lines split, your own block in your user settings, IT's through IT" $rc "$out"; fi
chmod 600 "$(lp "$NL")"
printf '%s\n' "LEAK_PATTERN='$MARK'" "LEAK_PATTERN='zqother'" > "$(lp "$NL")"
out=$(nlpush "$NL_CLEAN"); rc=$?;              want_refused "NL3 pre-push: a list it can't parse refuses" $rc "$out" "not in a shape"
want_says "MS10 pre-push: that refusal says what you can do" $rc "$out" "You can: give it the shape this hook reads"
nllist "$NOLIST"
out=$(nlpush "$NL_CLEAN");                     want_ok      "NL4 pre-push: the pinned reserved line passes a clean push and says the do-not-publish check is off" $? "$out" "the do-not-publish check is off for this project"
out=$(nlpush "$NL_MARK");                      want_ok      "NL5 pre-push: with the reserved line the do-not-publish check doesn't run, and the push says so" $? "$out" "the do-not-publish check is off for this project"
out=$(nlpush "$NL_CRED");                      want_refused "NL6 pre-push: with the reserved line, a planted credential is still refused" $? "$out" "credential shapes"
tpin "$NL/.git/leak-pattern.pin" "$MARK" 1
out=$(nlpush "$NL_CLEAN");                     want_refused "NL7 pre-push: the reserved line written over a pinned real list is refused by the pin" $? "$out" "doesn't match its pin"
nllist "$MARK"
out=$(nlpush "$NL_MARK");                      want_refused "NL8 pre-push: a real list still catches a planted term (control)" $? "$out" "listed terms"
NS="$TMP/ns"; mk_repo "$NS"; echo "plain" > "$NS/a.txt"; tpin "$NS/.github/leak-pattern.pin" "$NOLIST" 1; commit "$NS" base
out=$( (cd "$NS" && env -u LEAK_PATTERN "$BASH_BIN" "$SCAN" 2>&1) )
                                               want_refused "NS1 tree scan: no secret refuses, naming the reserved value" $? "$out" "$NOLIST"
[[ "$out" == *"If this project has no do-not-publish list, set the secret"* ]]
                                               want_ok      "MS18 tree scan: that refusal names the do-not-publish list" $? "$out"
out=$( (cd "$NS" && env LEAK_PATTERN="$NOLIST" "$BASH_BIN" "$SCAN" 2>&1) )
                                               want_ok      "NS2 tree scan: the pinned reserved value passes and says the do-not-publish check is off" $? "$out" "the do-not-publish check is off"
tpin "$NS/.github/leak-pattern.pin" "$MARK" 1
out=$( (cd "$NS" && env LEAK_PATTERN="$NOLIST" "$BASH_BIN" "$SCAN" 2>&1) )
                                               want_refused "NS3 tree scan: the reserved value against a real list's pin refuses" $? "$out" "doesn't match its pin"
# A list that doesn't compile, pinned: the scan refuses, never prints the list, and never reports clean.
tpin "$NS/.github/leak-pattern.pin" "$MARK(" 1
out=$( (cd "$NS" && env LEAK_PATTERN="$MARK(" "$BASH_BIN" "$SCAN" 2>&1) ); rc=$?
                                               want_refused "NS4 tree scan: a pinned list that doesn't compile refuses" $rc "$out" "may not compile"
                                               no_leak      "NS4b tree scan: and that refusal doesn't print the list" "$out"

# ============================== the full-history identity check: bin/kit-history-audit ====================
# Before a repository goes public, every commit reachable from any ref, and every one only its reflog still holds, is
# read against the project's own list: each commit's author and committer (names and emails), its message, the paths
# it touches and the content it adds (a merge's against its first parent), every tag object's tagger and message, and
# every ref name (the kit's own .local audit, shipped). A hit is named by its
# commit, or tag object, and its field, never by the matched text or a path; a content line passes only when the
# project's allow file pins it. Each history below plants the suite's marker in one field of an older commit, under a
# clean tip. The control, --control, plants a term made from the project's own list in all ten fields of a throwaway
# repository and passes only when the audit refuses all ten.
# The audit runs from a copy beside an rswap'd reader, as it sits beside the install's, so it finds lists in TH.
HAK="$TMP/ha-kit"; mkdir -p "$HAK/bin" "$HAK/leak-detection"; HA="$HAK/bin/kit-history-audit"
[[ -f "$ROOT/bin/kit-history-audit" ]] && install -m 0755 "$ROOT/bin/kit-history-audit" "$HA"
rswap "$H/read-leak-pattern.sh" "$HAK/leak-detection/read-leak-pattern.sh"
har() { "$BASH_BIN" "$HA" "$@" 2>&1; }                                     # ARGS...: the audit, both streams
ha_repo() {  # DIR: the suite's one-row list in .git/leak-pattern, its pin beside it, one clean commit
    mk_repo "$1"; printf '%s\n' "$SETUP" > "$(lp "$1")"; echo base > "$1/base.txt"; commit "$1" base; }
ha_tip() { echo "${2:-tip}" > "$1/tip.txt"; commit "$1" tip; }            # DIR [WORD]: a clean commit on top
ha_named() {  # OUTPUT ID FIELD: 0 when one refusal line names that commit or tag object (its first 12) and that field
    printf '%s\n' "$1" | awk -v h="${2:0:12}" -v f=" $3 " 'index($0, "REFUSED") && index($0, h) && index($0, f) {ok = 1} END {exit !ok}'; }
ha_case() {  # NAME DIR ID FIELD: the audit exits 3 naming ID and FIELD, and prints no marker
    local out rc; out=$(har "$2" --remote none); rc=$?
    if [[ $rc -eq 3 ]] && ha_named "$out" "$3" "$4"; then result "$1" 0
    else result "$1" 1 "exit $rc, want 3 naming ${3:0:12} $4: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-220)"; fi
    no_leak_at "${1%% *}b and it prints no marker" "$out" ""; HA_OUT=$out; }

d="$TMP/ha-clean"; ha_repo "$d"; ha_tip "$d"
out=$(har "$d" --remote none);                 want_ok      "HA0 history audit: a clean history passes" $? "$out" "clean:"
d="$TMP/ha-msg"; ha_repo "$d"; echo m > "$d/m.txt"; git -C "$d" add -A; git -C "$d" commit -q --no-verify -m "names $MARK"
p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"; ha_case "HA1 history audit: a marker in an old commit's message refuses, naming commit and field" "$d" "$p" message
d="$TMP/ha-an"; ha_repo "$d"; echo a > "$d/a.txt"; git -C "$d" add -A
GIT_AUTHOR_NAME="Dev $MARK" git -C "$d" commit -q --no-verify -m a; p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"
ha_case "HA2 history audit: a marker in an old commit's author name refuses, naming commit and field" "$d" "$p" author_name
d="$TMP/ha-ae"; ha_repo "$d"; echo a > "$d/a.txt"; git -C "$d" add -A
GIT_AUTHOR_EMAIL="dev@$MARK.invalid" git -C "$d" commit -q --no-verify -m a; p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"
ha_case "HA3 history audit: a marker in an old commit's author email refuses, naming commit and field" "$d" "$p" author_email
d="$TMP/ha-cn"; ha_repo "$d"; echo c > "$d/c.txt"; git -C "$d" add -A
GIT_COMMITTER_NAME="Ops $MARK" git -C "$d" commit -q --no-verify -m c; p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"
ha_case "HA4 history audit: a marker in an old commit's committer name refuses, naming commit and field" "$d" "$p" committer_name
d="$TMP/ha-ce"; ha_repo "$d"; echo c > "$d/c.txt"; git -C "$d" add -A
GIT_COMMITTER_EMAIL="ops@$MARK.invalid" git -C "$d" commit -q --no-verify -m c; p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"
ha_case "HA5 history audit: a marker in an old commit's committer email refuses, naming commit and field" "$d" "$p" committer_email
d="$TMP/ha-path"; ha_repo "$d"; echo plain > "$d/f-$MARK.txt"; commit "$d" path; p=$(git -C "$d" rev-parse HEAD)
git -C "$d" rm -q "f-$MARK.txt"; ha_tip "$d"
ha_case "HA6 history audit: a marker in a path an old commit added refuses, naming commit and field" "$d" "$p" path
d="$TMP/ha-content"; ha_repo "$d"; printf 'one\nhas %s here\n' "$MARK" > "$d/carrier.txt"; commit "$d" content; p=$(git -C "$d" rev-parse HEAD)
git -C "$d" rm -q carrier.txt; ha_tip "$d"
ha_case "HA7 history audit: a marker in content an old commit added, gone at the tip, refuses, naming commit and field" "$d" "$p" content
[[ "$HA_OUT" != *carrier* ]];                  result       "HA7c and it prints no path, even one that holds no marker" $? "the output names the carrier file"
HAC="$d"; HACP="$p"                            # kept for the allow-file cases
d="$TMP/ha-tagmsg"; ha_repo "$d"; git -C "$d" tag -a t1 -m "names $MARK"; t=$(git -C "$d" rev-parse t1); ha_tip "$d"
ha_case "HA8 history audit: a marker in a tag object's message refuses, naming the tag object and field" "$d" "$t" tag_message
d="$TMP/ha-tagger"; ha_repo "$d"; GIT_COMMITTER_NAME="Rel $MARK" git -C "$d" tag -a t1 -m release; t=$(git -C "$d" rev-parse t1); ha_tip "$d"
ha_case "HA9 history audit: a marker in a tag object's tagger refuses, naming the tag object and field" "$d" "$t" tag_tagger
d="$TMP/ha-ref"; ha_repo "$d"; git -C "$d" branch "ref-$MARK"; ha_tip "$d"
ha_case "HA10 history audit: a marker in a ref's name refuses, naming the field" "$d" refs ref_name
d="$TMP/ha-reflog"; ha_repo "$d"; printf 'has %s\n' "$MARK" > "$d/gone.txt"; commit "$d" gone; p=$(git -C "$d" rev-parse HEAD)
git -C "$d" reset -q --hard HEAD~1
ha_case "HA11 history audit: a commit only the reflog holds is read too, and its marker refuses" "$d" "$p" content
# The allow file: a content line, pinned by its commit, the SHA-256 of the line and its path, passes; nothing else does.
lsum=$(printf 'has %s here' "$MARK" | tsum)
printf '# a note\n%s §1 %s carrier.txt\n' "$HACP" "$lsum" > "$TMP/ha-allow"
out=$(har "$HAC" --remote none --allow "$TMP/ha-allow"); want_ok "HA12 history audit: a content line the allow file pins passes" $? "$out" "allowed:"
d="$TMP/ha-two"; ha_repo "$d"; printf 'has %s here\nand %s again\n' "$MARK" "$MARK" > "$d/carrier.txt"; commit "$d" two
p=$(git -C "$d" rev-parse HEAD); git -C "$d" rm -q carrier.txt; ha_tip "$d"
printf '%s §1 %s carrier.txt\n' "$p" "$lsum" > "$TMP/ha-allow2"
out=$(har "$d" --remote none --allow "$TMP/ha-allow2"); rc=$?
[[ $rc -eq 3 ]] && ha_named "$out" "$p" content; result "HA13 history audit: a second line on a pinned commit and path refuses" $? "exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
d="$TMP/ha-msgpin"; ha_repo "$d"; printf 'has %s here\n' "$MARK" > "$d/carrier.txt"; git -C "$d" add -A
git -C "$d" commit -q --no-verify -m "names $MARK"; p=$(git -C "$d" rev-parse HEAD); ha_tip "$d"
printf '%s §1 %s carrier.txt\n' "$p" "$lsum" > "$TMP/ha-allow3"
out=$(har "$d" --remote none --allow "$TMP/ha-allow3"); rc=$?
[[ $rc -eq 3 ]] && ha_named "$out" "$p" message; result "HA14 history audit: the allow file pins content only; a message hit on that commit still refuses" $? "exit $rc"
printf 'not a pin line\n' > "$TMP/ha-allow4"
out=$(har "$HAC" --remote none --allow "$TMP/ha-allow4"); want_refused "HA15 history audit: an allow file line it can't read refuses" $? "$out" "allow file"
# The list: read as data from the repository's own list at its place, checked against its pin, never from the caller's
# environment (the gates skill's procedure 13, items 1 and 4).
d="$TMP/ha-shell"; ha_repo "$d"; rm -f "$TMP/ha-ran"
printf '%s\n' "LEAK_PATTERN='$MARK'" "\$(touch \"$TMP/ha-ran\")" > "$(lp "$d")"
out=$(har "$d" --remote none); rc=$?
[[ $rc -ne 0 && ! -e "$TMP/ha-ran" ]];         result       "HA16 history audit: a list holding shell code is read without running it, and refuses" $? "exit $rc, the command $([[ -e "$TMP/ha-ran" ]] && echo ran || echo did not run)"
out=$(LEAK_PATTERN='zq-cut-list' "$BASH_BIN" "$HA" "$HAC" --remote none 2>&1); rc=$?
[[ $rc -eq 3 ]] && ha_named "$out" "$HACP" content; result "HA17 history audit: a cut list in the environment is ignored; the repository's list finds the hit" $? "exit $rc"
d="$TMP/ha-nolist"; ha_repo "$d"; rm -f "$(lp "$d")"
out=$(har "$d" --remote none); rc=$?;          want_refused "HA18 history audit: no list refuses, naming it" $rc "$out" "no do-not-publish list"
want_says "MS19 history audit: that refusal says what you can do and what to ask the project's owner" $rc "$out" \
    "You can: put the project's list there" "The project's owner: whether this project keeps a do-not-publish list"
d="$TMP/ha-pinoff"; ha_repo "$d"; printf '%s\n' "LEAK_PATTERN='$MARK|zq-added-row'" > "$(lp "$d")"
out=$(har "$d" --remote none); rc=$?;          want_refused "HA19 history audit: a list that doesn't match its pin refuses" $rc "$out" "doesn't match its pin"
want_says "MS20 history audit: that refusal names the do-not-publish list, what you can do and what to ask the project's owner" $rc "$out" \
    "the do-not-publish list in" "You can: if the list changed on purpose" "The project's owner: whether the change to the list was meant"
rm -f "$d/.git/leak-pattern.pin"; printf '%s\n' "$SETUP" > "$(lp "$d")"
out=$(har "$d" --remote none);                 want_refused "HA19b history audit: a list with no pin refuses" $? "$out" "has no pin"
# What git shows must be what history holds (the gates skill's procedure 13, item 3).
d="$TMP/ha-replace"; ha_repo "$d"; b=$(git -C "$d" rev-parse HEAD); printf 'has %s\n' "$MARK" > "$d/r.txt"; commit "$d" planted
p=$(git -C "$d" rev-parse HEAD); s=$(git -C "$d" commit-tree "$(git -C "$d" rev-parse "$b^{tree}")" -p "$b" -m planted)
git -C "$d" replace "$p" "$s"
ha_case "HA20 history audit: a replace ref standing a clean commit in for a planted one isn't followed" "$d" "$p" content
d="$TMP/ha-graft"; ha_repo "$d"; git -C "$d" rev-parse HEAD > "$d/.git/info/grafts"
out=$(har "$d" --remote none);                 want_refused "HA21 history audit: a repository with grafts refuses" $? "$out" "grafts"
out=$(GIT_DIR="$TMP/ha-clean/.git" "$BASH_BIN" "$HA" "$HAC" --remote none 2>&1); rc=$?
[[ $rc -eq 3 ]] && ha_named "$out" "$HACP" content; result "HA22 history audit: an inherited GIT_DIR naming another repository isn't followed" $? "exit $rc"
# Content that isn't plain text: the .local audit passed each of these.
d="$TMP/ha-bad"; ha_repo "$d"; printf 'bad \377\376 %s here\n' "$MARK" > "$d/bad.txt"; commit "$d" bad; p=$(git -C "$d" rev-parse HEAD)
git -C "$d" rm -q bad.txt; ha_tip "$d"
if [[ -n "$U8" ]]; then
    out=$(LC_ALL="$U8" LANG="$U8" "$BASH_BIN" "$HA" "$d" --remote none 2>&1); rc=$?
    [[ $rc -eq 3 ]] && ha_named "$out" "$p" content; result "HA23 history audit: a marker on a line holding invalid UTF-8 refuses, in a UTF-8 locale" $? "exit $rc"
else skip "HA23 history audit: a marker on a line holding invalid UTF-8 refuses, in a UTF-8 locale" "locale -a lists no UTF-8 locale"; fi
out=$(env -u LANG -u LC_ALL -u LC_CTYPE "$BASH_BIN" "$HA" "$d" --remote none 2>&1); rc=$?
[[ $rc -eq 3 ]] && ha_named "$out" "$p" content; result "HA23b history audit: the same, with no locale set" $? "exit $rc"
d="$TMP/ha-nul"; ha_repo "$d"; printf 'nul\000 %s here\n' "$MARK" > "$d/nul.txt"; printf 'plain %s here\n' "$MARK" > "$d/plain.txt"
commit "$d" nul; p=$(git -C "$d" rev-parse HEAD); git -C "$d" rm -q nul.txt plain.txt; ha_tip "$d"
out=$(har "$d" --remote none); rc=$?
n=$(printf '%s\n' "$out" | awk -v h="${p:0:12}" 'index($0, "REFUSED") && index($0, h) && index($0, " content ") {n++} END {print n + 0}')
[[ $rc -eq 3 && $n -eq 2 ]];                   result       "HA24 history audit: a marker after a NUL on its line refuses, and a plain hit beside it in a second file is named too" $? "exit $rc, $n content refusal(s) for the commit, want 2"
d="$TMP/ha-bin"; ha_repo "$d"; printf '\000\001\002 %s \003\000' "$MARK" > "$d/blob.bin"; commit "$d" bin; p=$(git -C "$d" rev-parse HEAD)
git -C "$d" rm -q blob.bin; ha_tip "$d"
ha_case "HA25 history audit: a marker in a binary file's content refuses" "$d" "$p" content
# A merge's own content, which neither parent holds (a conflict's resolution), read against its first parent.
d="$TMP/ha-merge"; ha_repo "$d"; b=$(git -C "$d" rev-parse HEAD)
git -C "$d" checkout -q -b side; echo s > "$d/s.txt"; commit "$d" side
git -C "$d" checkout -q -B trunk "$b"; echo t > "$d/t.txt"; commit "$d" trunk
git -C "$d" merge -q --no-ff --no-commit side >/dev/null 2>&1; printf 'has %s\n' "$MARK" > "$d/evil.txt"; git -C "$d" add evil.txt
git -C "$d" commit -q --no-verify -m merge; p=$(git -C "$d" rev-parse HEAD); git -C "$d" rm -q evil.txt; ha_tip "$d"
ha_case "HA26 history audit: a marker that only a merge adds refuses, naming the merge" "$d" "$p" content
# Whatever the audit can't see is a refusal, not a pass: a remote's ref whose commit isn't here, a shallow clone.
d="$TMP/ha-rem"; ha_repo "$d"; git init -q --bare "$TMP/ha-rem.git"; git -C "$d" remote add origin "$TMP/ha-rem.git"
git -C "$d" push -q --no-verify origin HEAD:refs/heads/main
git clone -q "$TMP/ha-rem.git" "$TMP/ha-rem2" 2>/dev/null; echo x > "$TMP/ha-rem2/x.txt"; git -C "$TMP/ha-rem2" add -A
git -C "$TMP/ha-rem2" -c user.name=hooks-test -c user.email=hooks-test@invalid.local commit -q --no-verify -m x
git -C "$TMP/ha-rem2" push -q --no-verify origin HEAD:refs/heads/elsewhere
out=$(har "$d" --remote origin);               want_refused "HA27 history audit: a remote ref whose commit isn't here refuses" $? "$out" "not here"
out=$(har "$d");                               want_refused "HA27b history audit: origin, when there is one, is checked by default" $? "$out" "not here"
git clone -q --depth 1 "file://$TMP/ha-clean" "$TMP/ha-shallow" 2>/dev/null
cp "$TMP/ha-clean/.git/leak-pattern.pin" "$TMP/ha-shallow/.git/"   # the clone carries the id
out=$(har "$TMP/ha-shallow" --remote none);    want_refused "HA28 history audit: a shallow clone refuses" $? "$out" "shallow"
out=$(PATH="$TMP/git-old:$PATH" "$BASH_BIN" "$HA" "$TMP/ha-clean" --remote none 2>&1)
ha29rc=$?;                                     want_refused "HA29 history audit: a git older than 2.31 is refused, naming both versions" $ha29rc "$out" "git 2.30.2 is older than 2.31"
want_says "MS21 history audit: that refusal says what you can do and what to ask IT for" $ha29rc "$out" "${GITSAYS[@]}"
d="$TMP/ha-nolist-line"; ha_repo "$d"; printf "LEAK_PATTERN='%s'\n" "$NOLIST" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$NOLIST" 1
out=$(har "$d" --remote none); rc=$?;          want_refused "HA30 history audit: the reserved line refuses: a project going public needs a real list" $rc "$out" "needs a real list"
want_says "MS22 history audit: that refusal names the do-not-publish list" $rc "$out" "the line saying it has no do-not-publish list"
# The audit's other refusals over the list, each naming the do-not-publish list: no place for it, a list only at the old
# place, one that sets no pattern, no hashing tool, a list that doesn't compile; and a git whose version can't be read.
md="$TMP/ha-noid"; ha_repo "$md"; rm -f "$md/kit.list-id"; out=$(har "$md" --remote none); rc=$?
want_says "MS23 history audit: no place for the list names it and says what you can do" $rc "$out" \
    "the do-not-publish list's place can't be found" "You can: give the project its place"
md="$TMP/ha-oldplace"; ha_repo "$md"; mv "$(lp "$md")" "$md/.git/leak-pattern"; out=$(har "$md" --remote none); rc=$?
want_says "MS24 history audit: a list only at the old place names the do-not-publish list and says what you can do" $rc "$out" \
    "no do-not-publish list at" "You can: move it ("
md="$TMP/ha-empty"; ha_repo "$md"; printf "LEAK_PATTERN=''\n" > "$(lp "$md")"; out=$(har "$md" --remote none); rc=$?
want_says "MS25 history audit: a list that sets no pattern names the do-not-publish list" $rc "$out" "the do-not-publish list in"
md="$TMP/ha-nohash"; ha_repo "$md"; out=$(PATH="$TMP/nohash" "$BASH_BIN" "$HA" "$md" --remote none 2>&1); rc=$?
want_says "MS26 history audit: with no hashing tool it names the do-not-publish list" $rc "$out" "so the do-not-publish list can't be checked against its pin"
md="$TMP/ha-badre"; ha_repo "$md"; printf "LEAK_PATTERN='%s('\n" "$MARK" > "$(lp "$md")"; tpin "$md/.git/leak-pattern.pin" "$MARK(" 1
out=$(har "$md" --remote none); rc=$?
want_says "MS29 history audit: a list that doesn't compile names the do-not-publish list" $rc "$out" "the do-not-publish list doesn't compile"
out=$(PATH="$TMP/git-odd:$PATH" "$BASH_BIN" "$HA" "$TMP/ha-clean" --remote none 2>&1); rc=$?
want_says "MS28 history audit: a git whose version can't be read says what you can do and what to ask IT for" $rc "$out" \
    "could not read git's version" "${GITSAYS[@]}"
out=$(har --control "$d");                     want_refused "HC9 history control: the reserved line refuses too" $? "$out" "needs a real list"
# A list it can't search with: one that doesn't compile, pinned, and one that sets LEAK_PATTERN twice.
d="$TMP/ha-nocompile"; ha_repo "$d"; printf "LEAK_PATTERN='%s('\n" "$MARK" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$MARK(" 1
out=$(har "$d" --remote none);                 want_refused "HA31 history audit: a pinned list that doesn't compile refuses" $? "$out" "doesn't compile"
                                               no_leak      "HA31b history audit: and that refusal doesn't print the list" "$out"
d="$TMP/ha-twice"; ha_repo "$d"; printf '%s\n' "LEAK_PATTERN='zqone'" "LEAK_PATTERN='$MARK'" > "$(lp "$d")"
out=$(har "$d" --remote none);                 want_refused "HA32 history audit: a list that sets LEAK_PATTERN twice refuses" $? "$out" "not in a shape"
# The control: a term made from the project's own list, never printed, in all ten fields of a throwaway repository.
out=$(har --control "$TMP/ha-clean");          want_ok      "HC1 history control: the project's own list goes red on 10 of 10 fields" $? "$out" "control: 10 of 10 fields red"
                                               no_leak_at   "HC1b and it prints no term" "$out" ""
hm="$TMP/ha-mut"; mkdir -p "$hm/bin" "$hm/leak-detection"; rswap "$H/read-leak-pattern.sh" "$hm/leak-detection/read-leak-pattern.sh"
awk '/^    exit 3   # the refusal$/ {print "    exit 0"; next} {print}' "$HA" > "$hm/bin/kit-history-audit" 2>/dev/null
if [[ -s "$HA" ]] && ! cmp -s "$HA" "$hm/bin/kit-history-audit"; then
    out=$("$BASH_BIN" "$hm/bin/kit-history-audit" --control "$TMP/ha-clean" 2>&1)
                                               want_refused "HC2 history control: an audit that never refuses fails the control" $? "$out" "must refuse"
else result "HC2 history control: an audit that never refuses fails the control" 1 "no refusal line to mutate in the audit"; fi
e="$TMP/ha-else"; git init -q "$e"; git -C "$e" -c user.name=hooks-test -c user.email=hooks-test@invalid.local commit -q --allow-empty -m e
before=$(git -C "$e" for-each-ref --format='%(objectname) %(refname)'; git -C "$e" rev-parse HEAD)
out=$(GIT_DIR="$e/.git" "$BASH_BIN" "$HA" --control "$TMP/ha-clean" 2>&1); rc=$?
after=$(git -C "$e" for-each-ref --format='%(objectname) %(refname)'; git -C "$e" rev-parse HEAD)
[[ $rc -eq 0 && "$out" == *"control: 10 of 10 fields red"* && "$before" == "$after" ]]
                                               result       "HC3 history control: it follows no inherited GIT_DIR, and leaves that repository as it was" $? "exit $rc, the other repository $([[ "$before" == "$after" ]] && echo unchanged || echo CHANGED)"
d="$TMP/ha-rows"; ha_repo "$d"; v='^zq-anchored|\bzq-[a-c]{3}[[:digit:]]+x\b'
printf '%s\n' "LEAK_PATTERN='$v'" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$v" 2
out=$(har --control "$d");                     want_ok      "HC4 history control: a term is made from a row of classes and counts, past one it can't plant" $? "$out" "control: 10 of 10 fields red"
d="$TMP/ha-norow"; ha_repo "$d"; v='^zq-anchored|zq@mail\.invalid'
printf '%s\n' "LEAK_PATTERN='$v'" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$v" 2
out=$(har --control "$d");                     want_refused "HC5 history control: a list with no row it can plant in every field refuses, saying so" $? "$out" "no row of the list"
# The control proves every row: it makes a term from each, a branch at a time where a row alternates, plants
# each row's term in a commit of its own and passes only when the audit refuses them all. A list made only of rows
# bounded by an anchor or a non-letter, the form most lists use, goes red on all of them (HC7); a row it can't make a
# term from fails the control, named by number (HC8).
d="$TMP/ha-anch"; ha_repo "$d"; v='(^|[^a-z0-9])zq-alpha([^a-z0-9]|$)|(^|[^a-z0-9])zq-beta([^a-z0-9]|$)'
printf '%s\n' "LEAK_PATTERN='$v'" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$v" 2
out=$(har --control "$d"); rc=$?
[[ $rc -eq 0 && "$out" == *"terms made from 2 of the list's 2 rows"* && "$out" == *"control: 10 of 10 fields red"* \
   && "$out" == *"2 of 2 rows' terms refused"* ]]
                                               result       "HC7 history control: rows bounded by an anchor give terms, and the audit refuses each row's term" $? "exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-260)"
[[ "$out" != *zq-alpha* && "$out" != *zq-beta* ]]; result "HC7b and it prints no term" $? "the output holds a planted term"
d="$TMP/ha-backref"; ha_repo "$d"; v="$MARK|zq-(ab)\\1"
printf '%s\n' "LEAK_PATTERN='$v'" > "$(lp "$d")"; tpin "$d/.git/leak-pattern.pin" "$v" 2
out=$(har --control "$d");                     want_refused "HC8 history control: a row it can't make a term from fails the control, named by number" $? "$out" "row 2"
d="$TMP/ha-cshell"; ha_repo "$d"; rm -f "$TMP/ha-ran"
printf '%s\n' "LEAK_PATTERN='$MARK'" "\$(touch \"$TMP/ha-ran\")" > "$(lp "$d")"
out=$(har --control "$d"); rc=$?
[[ $rc -ne 0 && ! -e "$TMP/ha-ran" ]];         result       "HC6 history control: a list holding shell code is read without running it, and refuses" $? "exit $rc"
if [[ -z "$b3why" ]]; then
    out=$("$B3" "$HA" "$TMP/ha-clean" --remote none 2>&1); want_ok "HA0 (bash 3) history audit: a clean history passes" $? "$out" "clean:"
    out=$("$B3" "$HA" "$HAC" --remote none 2>&1); rc=$?
    [[ $rc -eq 3 ]] && ha_named "$out" "$HACP" content; result "HA7 (bash 3) history audit: a marker in old content refuses" $? "exit $rc"
    out=$("$B3" "$HA" --control "$TMP/ha-clean" 2>&1); want_ok "HC1 (bash 3) history control: 10 of 10 fields red" $? "$out" "control: 10 of 10 fields red"
else for c in "HA0 (bash 3)" "HA7 (bash 3)" "HC1 (bash 3)"; do skip "$c" "$b3why"; done; fi

# ============================== the list's place: one file per project, outside every repository =========
# A project's do-not-publish list is one file under the home folder's .config/morrowcairn/lists/, named by the
# project's own random id, the one line of its tracked kit.list-id: every clone of the project reads the same file, and
# no repository holds the list. The home folder comes from the user database by user id, never from HOME or
# XDG_CONFIG_HOME. The list's pin stays in .git. Each case runs the suite's copies, so TH stands for the home.
LH="$TMP/lh"; mk_repo "$LH"; echo "plain text" > "$LH/a.txt"; commit "$LH" base
git init -q --bare "$TMP/lh.git"; git -C "$LH" push -q --no-verify "$TMP/lh.git" HEAD:refs/heads/main
LHB=$(git -C "$LH" rev-parse HEAD)
lhc() { git -C "$1" checkout -q -B "$2" "$LHB"; printf '%s\n' "$3" > "$1/f.txt"; commit "$1" "$2"; git -C "$1" rev-parse HEAD; }  # DIR BRANCH TEXT
lhpush() {  # DIR SHA [VAR=VALUE...]: pre-push by the stdin protocol over the remote's main, no list in the environment
    local d=$1 s=$2; shift 2
    (cd "$d" && printf 'refs/heads/main %s refs/heads/main %s\n' "$s" "$LHB" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN "$@" "$BASH_BIN" "$HK/pre-push" r "$TMP/lh.git" 2>&1 < "$TMP/pp.in"); }
LH_CLEAN=$(lhc "$LH" lhclean "nothing listed here"); LH_MARK=$(lhc "$LH" lhmark "has $MARK here")
out=$(lhpush "$LH" "$LH_MARK");                want_refused "LH1 pre-push: a listed term is refused, the list in its place under the home folder" $? "$out" "listed terms in the tree"
out=$(lhpush "$LH" "$LH_CLEAN");               want_ok      "LH1b pre-push: and a clean push passes, reading that list" $? "$out"
mv "$(lp "$LH")" "$TMP/lh-list.aside"
out=$(lhpush "$LH" "$LH_CLEAN");               want_refused "LH2 pre-push: no list in its place refuses, naming the place by the project's id" $? "$out" "~/.config/morrowcairn/lists/$(cat "$LH/kit.list-id")"
printf "LEAK_PATTERN='%s'\n" "$MARK" > "$LH/.git/leak-pattern"
out=$(lhpush "$LH" "$LH_CLEAN");               want_refused "LH2b pre-push: a list left only in .git/leak-pattern isn't read, and the refusal names the move" $? "$out" "move-list"
mv "$LH/kit.list-id" "$TMP/lh-id.aside"; out=$(lhpush "$LH" "$LH_CLEAN"); rc=$?; mv "$TMP/lh-id.aside" "$LH/kit.list-id"
want_says "MS27 pre-push: no place for the list names the do-not-publish list and says what you can do" $rc "$out" \
    "the do-not-publish list's place can't be found" "You can: give the project its place"
rm -f "$LH/.git/leak-pattern"; mv "$TMP/lh-list.aside" "$(lp "$LH")"
mv "$LH/kit.list-id" "$TMP/lh-id.aside"
out=$(lhpush "$LH" "$LH_CLEAN");               want_refused "LH2c pre-push: a project with no kit.list-id refuses, naming it" $? "$out" "kit.list-id"
printf '%s\n' "../../../$(lid)" > "$LH/kit.list-id"
out=$(lhpush "$LH" "$LH_CLEAN");               want_refused "LH2d pre-push: a kit.list-id that isn't 32 hex digits refuses, so it can name no other path" $? "$out" "kit.list-id isn't"
mv "$TMP/lh-id.aside" "$LH/kit.list-id"
mkdir -p "$TMP/elsewhere/.config/morrowcairn/lists"; printf "LEAK_PATTERN='zqdecoy'\n" > "$TMP/elsewhere/.config/morrowcairn/lists/$(cat "$LH/kit.list-id")"
out=$(lhpush "$LH" "$LH_MARK" HOME="$TMP/elsewhere" XDG_CONFIG_HOME="$TMP/elsewhere/.config")
                                               want_refused "LH3 pre-push: HOME and XDG_CONFIG_HOME pointed at a folder holding a decoy list change nothing it reads" $? "$out" "listed terms in the tree"
LC2="$TMP/lh-second"; git clone -q -b main "$TMP/lh.git" "$LC2" 2>/dev/null; git -C "$LC2" config user.name hooks-test
git -C "$LC2" config user.email hooks-test@invalid.local; git -C "$LC2" config core.hooksPath "$HK"; cp "$LH/.git/leak-pattern.pin" "$LC2/.git/"
printf '%s\n' "has $MARK here" > "$LC2/f.txt"; commit "$LC2" second; LC2_MARK=$(git -C "$LC2" rev-parse HEAD)
out=$(lhpush "$LC2" "$LC2_MARK");              want_refused "LH4 pre-push: a second clone of the project reads the same list, by the id it cloned" $? "$out" "listed terms in the tree"
mkdir -p "$TMP/lh-moved"; mv "$LC2" "$TMP/lh-moved/renamed"
out=$(lhpush "$TMP/lh-moved/renamed" "$LC2_MARK"); want_refused "LH5 pre-push: the project's folder renamed and moved keeps its list" $? "$out" "listed terms in the tree"
mkdir -p "$LH/.local"; echo x > "$LH/.local/has-$MARK.txt"; echo x > "$LH/.local/plain-notes.txt"; git -C "$LH" add -f .local
out=$( (cd "$LH" && env -u LEAK_PATTERN "$BASH_BIN" "$HK/pre-commit") 2>&1 ); rc=$?
[[ $rc -ne 0 && "$out" == *"plain-notes.txt"* && "$out" == *"a path withheld"* && "$out" != *SYNTH-MARKER* ]]
                                               result       "LH6 pre-commit: a staged .local/ name the list in its place matches is withheld, a clean one named" $? "exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
git -C "$LH" reset -q; rm -rf "$LH/.local"
# The shipped routine, read-only: the user database's home, whatever HOME and XDG_CONFIG_HOME say. It opens nothing
# under the home; a failure names no folder. The database is read here by getent where there is one, else by python3.
if command -v getent >/dev/null 2>&1; then want_home=$(getent passwd "$(id -u)" | awk -F: '{print $6}')
else want_home=$(python3 -I - <<'PY'
import os, pwd
print(pwd.getpwuid(os.getuid()).pw_dir)
PY
); fi
got=$(env HOME="$TMP/elsewhere" XDG_CONFIG_HOME="$TMP/elsewhere/.config" "$BASH_BIN" --norc --noprofile \
      -c '. "$1" && kit_list_home' _ "$H/read-leak-pattern.sh" 2>/dev/null); rc=$?
[[ $rc -eq 0 && -n "$want_home" && "$got" == "$want_home" ]]
                                               result       "LH7 the shipped kit_list_home gives the user database's home, with HOME and XDG_CONFIG_HOME pointed elsewhere" $? "exit $rc; the two $([[ "$got" == "$want_home" ]] && echo agree || echo differ)"
lhstrip() { awk '/^kit_list_home\(\) \{/ {print; s=1; next} s && /^\}/ {s=0} !s {print}' "$1" 2>/dev/null; }   # FILE: without that body
a=$(lhstrip "$H/read-leak-pattern.sh"); bad=""
for c in "$HK" "$HKB" "$HKN" "$HKC" "$HKP" "$HKU" "$HAK/leak-detection" "$hm/leak-detection"; do
    [[ "$(lhstrip "$c/read-leak-pattern.sh")" == "$a" ]] && ! cmp -s "$H/read-leak-pattern.sh" "$c/read-leak-pattern.sh" || bad+=" ${c#"$TMP"/}"
done
[[ "$a" == *"kit_list_home() {"* && -z "$bad" ]]
                                               result       "LH8 each reader copy the suite runs differs from the shipped reader in kit_list_home's body alone" $? "differing elsewhere, or not swapped:${bad:- none}; the routine $([[ "$a" == *"kit_list_home() {"* ]] && echo is || echo isn\'t) there"
d="$TMP/lh-ha"; mk_repo "$d"; echo base > "$d/base.txt"; commit "$d" base
rm -f "$(lp "$d")"; printf "LEAK_PATTERN='%s'\n" "$MARK" > "$d/.git/leak-pattern"
out=$(har "$d" --remote none);                 want_refused "LH9 history audit: a list left only in .git/leak-pattern isn't read; the refusal names the place by the id" $? "$out" "~/.config/morrowcairn/lists/$(cat "$d/kit.list-id")"
rm -f "$d/.git/leak-pattern"; printf "LEAK_PATTERN='%s'\n" "$MARK" > "$(lp "$d")"
out=$(har "$d" --remote none);                 want_ok      "LH9b history audit: the list in its place reads, and a clean history passes" $? "$out" "clean:"
# With no python3 the shipped routine can't read the user database, so the place fails closed, naming python3, and
# never falls back to HOME. Read-only: it reads kit.list-id and nothing under any home.
out=$( (cd "$LH" && env HOME="$TMP/elsewhere" PATH="$TMP/nopy" "$BASH_BIN" --norc --noprofile \
        -c '. "$1" || exit 9; kit_list_file; printf "rc=%s file=[%s] %s" "$?" "$KL_FILE" "$LP_ERROR"' _ "$H/read-leak-pattern.sh") 2>&1 )
[[ "$out" == "rc=1 file=[] "*python3* ]]
                                               result       "LH10 the shipped kit_list_file with no python3 fails, naming it, and names no file" $? "$(printf '%s' "$out" | cut -c1-160)"
# Where python3 runs but the user database gives this user no usable home, the shipped routine fails closed the same
# way: a python3 that runs the real one with pwd.getpwuid finding no entry for any id (LH11), or giving a relative home
# (LH11b), and nothing else changed. Read-only, as LH10; a red names no path.
REALPY=$(command -v python3 2>/dev/null)
if [[ -n "$REALPY" ]] && "$REALPY" -I -c pass >/dev/null 2>&1; then
    for v in noentry relhome; do
        if [[ $v == noentry ]]; then pre='import pwd\ndef _g(uid): raise KeyError(uid)\npwd.getpwuid = _g\n'; n=LH11
                                    w="python3 runs and the user database has no entry for this user's id"
        else pre='import pwd\nclass _E: pw_dir = "relative/home"\npwd.getpwuid = lambda uid: _E()\n'; n=LH11b
             w="python3 runs and the user database gives a home that isn't an absolute path"; fi
        mkdir -p "$TMP/py-$v"
        cat > "$TMP/py-$v/python3" <<EOF
#!/bin/sh
# $n's stand-in: the real interpreter, its user database lookup changed as the case says, for the reader's program alone
if [ "\$1" = -I ] && [ "\$2" = - ]; then
    { printf '$pre'; cat; } | "$REALPY" -I -
    exit \$?
fi
exec "$REALPY" "\$@"
EOF
        chmod 0755 "$TMP/py-$v/python3"
        out=$( (cd "$LH" && env HOME="$TMP/elsewhere" PATH="$TMP/py-$v:$TMP/nopy" "$BASH_BIN" --norc --noprofile \
                -c '. "$1" || exit 9; kit_list_file; printf "rc=%s file=[%s] %s" "$?" "$KL_FILE" "$LP_ERROR"' _ "$H/read-leak-pattern.sh") 2>&1 )
        [[ "$out" == "rc=1 file=[] the home folder can't be read from the user database"* ]]
                                               result       "$n the shipped kit_list_file where $w fails, and names no file" $? "rc ${out:3:1}, a file $([[ "$out" == *"file=[]"* ]] && echo not named || echo named)"
    done
else
    skip "LH11 the shipped kit_list_file where python3 runs and the user database has no entry for this user's id fails" "python3 is not installed here, or doesn't run"
    skip "LH11b the shipped kit_list_file where the user database gives a home that isn't an absolute path fails" "python3 is not installed here, or doesn't run"
fi
# pre-push with no python3: every push reads the list's home from the user database with python3, so it refuses with
# that cause and says to install python3, or ask IT, never move-list, which reads the same place.
out=$( (cd "$LH" && printf 'refs/heads/main %s refs/heads/main %s\n' "$LH_CLEAN" "$LHB" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN PATH="$TMP/nopy" "$BASH_BIN" "$HKP/pre-push" r "$TMP/lh.git" < "$TMP/pp.in") 2>&1 ); rc=$?
want_says "MS41 pre-push with no python3: the list's place can't be found, the home unread; install python3, or ask IT" $rc "$out" \
    "pre-push: REFUSING -- the do-not-publish list's place can't be found: the home folder can't be read from the user database (python3 reads it)." \
    "  You can: install python3 where you may, then push again." "  If IT manages this machine: ask IT for python3."
[[ $rc -ne 0 && "$out" != *move-list* ]]
                                               result       "MS41b and it sends no one to move-list" $? "exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
# python3 on PATH that doesn't run (a stand-in that only offers to install the tools, as a Mac's does without them) is
# python3 missing: the same refusal as MS41's.
mkdir -p "$TMP/stubpy"; printf '#!/bin/sh\necho "a stand-in python3 that only offers to install the tools" >&2\nexit 1\n' > "$TMP/stubpy/python3"
chmod 0755 "$TMP/stubpy/python3"
out=$( (cd "$LH" && printf 'refs/heads/main %s refs/heads/main %s\n' "$LH_CLEAN" "$LHB" > "$TMP/pp.in" \
        && env -u LEAK_PATTERN PATH="$TMP/stubpy:$TMP/nopy" "$BASH_BIN" "$HKU/pre-push" r "$TMP/lh.git" < "$TMP/pp.in") 2>&1 ); rc=$?
want_says "MS44 pre-push where python3 is on PATH but doesn't run: install python3, or ask IT, as with none" $rc "$out" \
    "pre-push: REFUSING -- the do-not-publish list's place can't be found: the home folder can't be read from the user database (python3 reads it)." \
    "  You can: install python3 where you may, then push again." "  If IT manages this machine: ask IT for python3."
# Where python3 runs but the user database gives this user no usable home (no entry for the user's id, or a home that
# isn't an absolute path on one line: kit_list_home's checks), installing python3 wouldn't help: a refusal of its own
# names that cause, with no python3 advice and no move-list, which reads the same place.
if command -v python3 >/dev/null 2>&1 && python3 -I -c pass >/dev/null 2>&1; then
    out=$( (cd "$LH" && printf 'refs/heads/main %s refs/heads/main %s\n' "$LH_CLEAN" "$LHB" > "$TMP/pp.in" \
            && env -u LEAK_PATTERN "$BASH_BIN" "$HKU/pre-push" r "$TMP/lh.git" < "$TMP/pp.in") 2>&1 ); rc=$?
    want_says "MS43 pre-push where python3 runs but the user database gives no usable home: a refusal naming that cause" $rc "$out" \
        "pre-push: REFUSING -- the do-not-publish list's place can't be found: python3 runs, but the user database gives this user no home folder the kit can use (no entry for this user's id, or a home that isn't an absolute path on one line)." \
        "  You can: push from an account the user database lists, with an absolute home folder (in a container, give its user a line in /etc/passwd); the kit takes the home only from there, never from HOME." \
        "  If IT manages this machine: ask IT to give your account an entry in the user database with an absolute home folder."
    [[ $rc -ne 0 && "$out" != *"install python3"* && "$out" != *"ask IT for python3"* && "$out" != *move-list* ]]
                                               result       "MS43b and it gives no python3 advice and sends no one to move-list" $? "exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
else
    skip "MS43 pre-push where python3 runs but the user database gives no usable home: a refusal naming that cause" "python3 is not installed here, or doesn't run"
    skip "MS43b and it gives no python3 advice and sends no one to move-list" "python3 is not installed here, or doesn't run"
fi
# No list from the caller's environment: a list in LEAK_PATTERN, harmless or the real one, changes nothing pre-push
# reads; the list is the file at its place, or there is none. CI's tree scan keeps its own named secret (the NS cases).
out=$(lhpush "$LH" "$LH_MARK" LEAK_PATTERN=zqharmless)
                                               want_refused "LE1 pre-push: a harmless list in LEAK_PATTERN is ignored, and the term in the list at its place is refused" $? "$out" "listed terms in the tree"
mv "$(lp "$LH")" "$TMP/lh-list.aside2"
out=$(lhpush "$LH" "$LH_CLEAN" LEAK_PATTERN="$MARK")
                                               want_refused "LE2 pre-push: with LEAK_PATTERN set and no list at its place, it refuses, naming the place" $? "$out" "~/.config/morrowcairn/lists/$(cat "$LH/kit.list-id")"
mv "$TMP/lh-list.aside2" "$(lp "$LH")"

echo
echo "hooks_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

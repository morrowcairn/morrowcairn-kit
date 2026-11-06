#!/usr/bin/env bash
#
# upgrade_test.sh — a project carried across the kit's real releases by kit-pin to, the way a project takes them: every
# release from v0.11.0 on, read from this repository's own tags, then the candidate, ROOT's staged tree.
#
#   tests/upgrade_test.sh [ROOT]    ROOT = a clone of this kit holding its release tags (default: the one holding this file)
#
# Each release's install is built here by that release's own tools/install-release.sh, from its tag's tree with two
# files swapped, as the install suite's stand-in releases are: the list reader's kit_list_home, so every list this run
# reads or writes is under its scratch home, never the real one; and tests/hooks_test.sh, a stand-in, so an install takes
# seconds (each release's own suite ran when it was released). Everything else is the release's own: kit-pin, the stubs,
# the hooks and the reader's other routines.
#
# No network. A release tag missing here, as in a shallow clone, fails the run (UT0) and nothing else runs: it never
# skips. CI runs this suite in a job of its own, checked out with every tag (.github/workflows/upgrade.yml).
#
# The project carries a check of its own that reads the list (own-check.sh), at first where the kit's hooks read it
# before v0.12.0, .git/leak-pattern, and runs it from kit-pin.tests. Each move is made with the candidate's kit-pin, as
# patterns/local-upgrade.md says to run the newer release's, and is checked the way a project relies on it: the move
# kept, committed through the new stubs, check passing, a clean push accepted and a push carrying a listed term refused.
#
# A refusal must be for its stated reason (install_test's rule): each refused case names the words it expects.
# Exit 0 only when every case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
TMP=$(mktemp -d) || exit 1
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT     # installs are read-only
PASS=0; FAIL=0; SKIP=0
result() { if [[ $2 -eq 0 ]]; then PASS=$((PASS+1)); printf 'ok    %s\n' "$1"
           else FAIL=$((FAIL+1)); printf 'FAIL  %s  -- %s\n' "$1" "$3"; fi; }
squash() { printf '%s' "$1" | tr '\n' ' ' | cut -c1-300; }
summary() { echo; echo "upgrade_test: $PASS passed, $FAIL failed, $SKIP skipped"; }

# Every release from v0.11.0 on, oldest first. A release made later is added here when it is tagged.
RELEASES=(v0.11.0 v0.11.1 v0.12.0 v0.12.1 v0.13.0 v0.13.1 v0.14.0)
CAND=v0.99.0                                   # the candidate's tag in this run's scratch kit: ROOT's staged tree

# ============================== the release tags, from this repository alone ======================
mkdir -p "$TMP/tags"; miss=""
for t in "${RELEASES[@]}"; do
    [[ "$(git -C "$ROOT" cat-file -t "refs/tags/$t" 2>/dev/null)" == tag ]] \
        && git -C "$ROOT" archive --format=tar -o "$TMP/tags/$t.tar" "refs/tags/$t" 2>/dev/null || miss+=" $t"
done
if [[ -n "$miss" ]]; then
    result "UT0 every release from v0.11.0 on is an annotated tag here, its tree readable" 1 \
        "missing or unreadable:$miss; a shallow clone holds no older tag: clone with every tag (CI: fetch-depth: 0)"
    summary; exit 1
fi
result "UT0 every release from v0.11.0 on is an annotated tag here, its tree readable" 0 ""

command -v gitleaks >/dev/null 2>&1 || { echo "upgrade_test: gitleaks is required: the hooks run it on every push" >&2; exit 1; }
export KIT_INSTALL_ROOT="$TMP/releases"; mkdir -p "$KIT_INSTALL_ROOT"
export GIT_CONFIG_GLOBAL="$TMP/global.gitconfig" GIT_CONFIG_NOSYSTEM=1; : > "$GIT_CONFIG_GLOBAL"
unset LEAK_PATTERN KIT_INSTALL                 # the hooks and kit-pin read a project's list from its file, never the environment
MARK='SYNTH-MARKER-7F3A'
ident() { git -C "$1" config user.name upgrade-test; git -C "$1" config user.email upgrade-test@invalid.local; }

# A project's list lives under the home folder the user database gives, never $HOME's. Every reader a release ships from
# v0.12.0 on is rswap's copy here, kit_list_home's body alone swapped for this run's scratch home, TH. A copy whose swap
# didn't take would send a case to the real home, so rswap stops the run before any case.
TH="$TMP/home"; LML="$TH/.config/morrowcairn/lists"; mkdir -p "$LML"; chmod 700 "$TH/.config/morrowcairn" "$LML"
rswap() {  # FILE: kit_list_home's body swapped in place for printing TH; a FILE with no kit_list_home stays as it is
    RS_BODY="    printf '%s\\n' '$TH'   # upgrade_test's copy: its scratch home" \
        awk '/^kit_list_home\(\) \{/ {print; print ENVIRON["RS_BODY"]; s=1; next} s && /^\}/ {s=0} !s {print}' "$1" > "$1.rswap" || exit 1
    bash --norc --noprofile -c '. "$1" && declare -F kit_list_home' _ "$1" >/dev/null 2>&1 || { rm -f "$1.rswap"; return 0; }
    mv -f "$1.rswap" "$1" || exit 1
    [[ "$(bash --norc --noprofile -c '. "$1" && kit_list_home' _ "$1" 2>/dev/null)" == "$TH" ]] \
        || { echo "upgrade_test: the reader copy $1 doesn't find its home in the scratch home; stopping before any case" >&2; exit 1; }
}
lmid() { cat "$1/kit.list-id" 2>/dev/null; }                                 # DIR: its id, or nothing
lmf() { printf '%s/%s' "$LML" "$(lmid "$1")"; }                              # DIR: where its list lives in TH
lmstrip() { awk '/^kit_list_home\(\) \{/ {print; s=1; next} s && /^\}/ {s=0} !s {print}'; }    # stdin: without that body

# ============================== each release's install, by its own install-release.sh ============
K="$TMP/kit"; git init -q -b main "$K"; ident "$K"
git init -q --bare "$TMP/kit-remote.git"; git -C "$K" remote add origin "$TMP/kit-remote.git"
inbad=""
mkrel() {  # TAG: K's work tree holds the release's tree; swap the two files, commit, tag, push the tag, install it
    local t=$1 out
    printf '#!/usr/bin/env bash\necho "hooks_test: a stand-in suite (upgrade_test)"\nexit 0\n' > "$K/tests/hooks_test.sh"
    chmod 755 "$K/tests/hooks_test.sh"
    rswap "$K/leak-detection/read-leak-pattern.sh"
    git -C "$K" add -A && git -C "$K" -c core.hooksPath=/dev/null commit -q --allow-empty -m "$t, two files swapped" \
        && git -C "$K" tag -a "$t" -m "$t" && git -C "$K" push -q --no-verify origin "refs/tags/$t" 2>/dev/null \
        || { inbad+=" [$t: not tagged and pushed]"; return 1; }
    out=$( (cd "$K" && tools/install-release.sh "$t") 2>&1 ) || { inbad+=" [$t: $(squash "$out")]"; return 1; }
}
emptyk() { git -C "$K" rm -rqf --ignore-unmatch -- . >/dev/null 2>&1; git -C "$K" clean -fdxq; }
for t in "${RELEASES[@]}"; do
    emptyk; tar -x -C "$K" -f "$TMP/tags/$t.tar" && mkrel "$t"
    # The install's reader is the tag's, kit_list_home's body alone aside, and finds TH where it has that routine.
    r="$KIT_INSTALL_ROOT/$t/leak-detection/read-leak-pattern.sh"
    [[ "$(lmstrip < "$r" 2>/dev/null)" == "$(tar -x -O -f "$TMP/tags/$t.tar" leak-detection/read-leak-pattern.sh | lmstrip)" ]] \
        || inbad+=" [$t: its reader differs from the tag's beyond kit_list_home]"
done
emptyk; git -C "$ROOT" checkout-index -a --prefix="$K/"
git -C "$ROOT" ls-files -s | awk -F '\t' '$1 ~ /^100755 / {print $2}' | while IFS= read -r f; do chmod 755 "$K/$f"; done
mkrel "$CAND"
[[ -z "$inbad" ]]
result "UT1 every release from v0.11.0 on and the candidate install from their own trees by their own install-release.sh, each reader the tag's but for kit_list_home" $? "$inbad"
KPC="$KIT_INSTALL_ROOT/$CAND/bin/kit-pin"
[[ -x "$KPC" ]] || { echo "upgrade_test: the candidate didn't install, so no move can be made" >&2; summary; exit 1; }

# ============================== the project ======================================================
kpc() { local d=$1; shift; (cd "$d" && env -u LEAK_PATTERN "$KPC" "$@") 2>&1; }               # DIR ARGS: the candidate's kit-pin
kpr() { local d=$1 r=$2; shift 2; (cd "$d" && env -u LEAK_PATTERN "$KIT_INSTALL_ROOT/$r/bin/kit-pin" "$@") 2>&1; }   # a release's own
# kit-pin.tests' own-check line: the check passes a clean file and refuses one holding a listed term, written inside .git
# (never tracked, never pushed), its term built at run time so the tracked line holds none.
OWNLINE='printf "notes SYNTH-%s-7F3A\n" MARKER > .git/planted.txt && ./own-check.sh clean.txt && ! ./own-check.sh .git/planted.txt'
own1() {  # DIR: own-check.sh reading the list where the kit's hooks read it before v0.12.0
    cat > "$1/own-check.sh" <<'EOF'
#!/usr/bin/env bash
# This project's own check that FILE holds no do-not-publish term, reading the list at .git/leak-pattern.
lp="$(git rev-parse --git-dir)/leak-pattern"
v=$(sed -n "s/^LEAK_PATTERN='\(.*\)'\$/\1/p" "$lp" 2>/dev/null | head -n 1)
[ -n "$v" ] || { echo "own-check: no list at $lp" >&2; exit 2; }
if grep -qiE -e "$v" -- "$1"; then echo "own-check: $1 holds a listed term" >&2; exit 1; fi
exit 0
EOF
    chmod 755 "$1/own-check.sh"; }
own2() {  # DIR: own-check.sh reading the list at its place, through the pinned release's own reader
    cat > "$1/own-check.sh" <<'EOF'
#!/usr/bin/env bash
# This project's own check that FILE holds no do-not-publish term, reading the list where the pinned release's hooks
# read it: that install's reader, at the place it names.
rel=$(sed -n 's/^release=//p' kit.pin)
r="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/$rel/leak-detection/read-leak-pattern.sh"
v=$(bash -c '. "$1" && kit_list_file && read_leak_pattern "$KL_FILE" && printf "%s" "$LP_VALUE"' _ "$r" 2>/dev/null)
[ -n "$v" ] || { echo "own-check: no list at its place" >&2; exit 2; }
if grep -qiE -e "$v" -- "$1"; then echo "own-check: $1 holds a listed term" >&2; exit 1; fi
exit 0
EOF
    chmod 755 "$1/own-check.sh"; }
WHY=""
mkproj() {  # DIR [TESTS-LINE...]: a project pinned at v0.11.0 by v0.11.0's own kit-pin, its list at .git/leak-pattern,
            # pinned, a bare remote holding its first push; kit-pin.tests the lines given, else the own-check line alone;
            # WHY says what failed
    local d=$1 out; shift; WHY=""
    git init -q -b main "$d"; ident "$d"; own1 "$d"; echo clean > "$d/clean.txt"
    if (( $# )); then printf '%s\n' "$@" > "$d/kit-pin.tests"; else printf '%s\n' "$OWNLINE" > "$d/kit-pin.tests"; fi
    git -C "$d" add -A && git -C "$d" commit -q --no-verify -m one || { WHY="commit one"; return 1; }
    (umask 077 && printf "LEAK_PATTERN='%s'\n" "$MARK" > "$d/.git/leak-pattern")
    git init -q --bare "$d.remote.git"; git -C "$d" remote add origin "$d.remote.git"
    out=$(kpr "$d" v0.11.0 repin local --first) || { WHY="v0.11.0's repin --first: $(squash "$out")"; return 1; }
    out=$(kpr "$d" v0.11.0 to v0.11.0) || { WHY="v0.11.0's to v0.11.0: $(squash "$out")"; return 1; }
    git -C "$d" add kit.pin && out=$(git -C "$d" commit -q -m "onto v0.11.0" 2>&1) || { WHY="its commit through v0.11.0's stubs: $(squash "$out")"; return 1; }
    out=$(git -C "$d" push -q origin HEAD:refs/heads/main 2>&1) || { WHY="its first push through v0.11.0's stubs: $(squash "$out")"; return 1; }
}
planted() {  # DIR: a commit carrying a listed term is refused at push, then taken back
    local d=$1 out rc
    printf 'notes %s\n' "$MARK" > "$d/notes.txt"; git -C "$d" add notes.txt; git -C "$d" commit -q --no-verify -m planted
    out=$(git -C "$d" push origin HEAD:refs/heads/main 2>&1); rc=$?
    git -C "$d" reset -q --hard HEAD~1
    (( rc != 0 )) || { WHY="a push carrying a listed term went through"; return 1; }
    [[ "$out" == *notes.txt* ]] || { WHY="a push carrying a listed term refused, but not naming the file: $(squash "$out")"; return 1; }
}
TO_OUT=""; CHECK_OUT=""
moved() {  # DIR RELEASE: to RELEASE with the candidate's kit-pin, kept, committed through the new stubs, check exit 0,
           # a clean push accepted and one carrying a listed term refused; WHY says what failed
    local d=$1 t=$2 out rc
    WHY=""
    TO_OUT=$(kpc "$d" to "$t"); rc=$?
    (( rc == 0 )) || { WHY="to $t exit $rc: $(squash "$TO_OUT")"; return 1; }
    git -C "$d" add kit.pin; [[ ! -f "$d/kit.list-id" ]] || git -C "$d" add kit.list-id
    out=$(git -C "$d" commit -q -m "onto $t" 2>&1) || { WHY="the commit through $t's stubs: $(squash "$out")"; return 1; }
    CHECK_OUT=$(kpc "$d" check); rc=$?
    (( rc == 0 )) || { WHY="check exit $rc: $(squash "$CHECK_OUT")"; return 1; }
    out=$(git -C "$d" push -q origin HEAD:refs/heads/main 2>&1) || { WHY="a clean push refused: $(squash "$out")"; return 1; }
    planted "$d"
}
snap() { (cd "$1" && cat kit.pin .git/hooks/pre-commit .git/hooks/pre-push 2>/dev/null | sha256sum; git status --porcelain); }

# ============================== release by release, v0.11.0 to the candidate =====================
P="$TMP/p"; mkproj "$P"
result "UW0 a project pinned at v0.11.0 by v0.11.0's own kit-pin, its list at .git/leak-pattern and its own check reading it there" $? "$WHY"
prev=v0.11.0
for t in "${RELEASES[@]:1}" "$CAND"; do
    moved "$P" "$t"
    result "UW $prev to $t with the candidate's kit-pin: kept, committed through the new stubs, check passes, a clean push accepted, a listed term refused" $? "$WHY"
    if [[ $t == v0.12.0 ]]; then
        # RL1: the move that takes the list to its place leaves .git/leak-pattern, which this project's own check still
        # reads; check must not tell the project to delete it while such a check reads it.
        [[ "$CHECK_OUT" == *"a check of the project's own"* && "$CHECK_OUT" != *"Delete it once nothing else does"* ]]
        result "U1 after the list's move, check's note on .git/leak-pattern says a check of the project's own may still read it, not to delete it" $? \
            "check said: $(squash "$(printf '%s\n' "$CHECK_OUT" | grep -F '.git/leak-pattern')")"
    fi
    prev=$t
done
# The route the note gives: the project's own check moved onto the list at its place, through the pinned release's reader;
# then .git/leak-pattern goes, the check still refuses a listed term, and check has nothing more to say of the old place.
own2 "$P"; git -C "$P" add own-check.sh; out=$(git -C "$P" commit -q -m "own check at the list's place" 2>&1); rc=$?
rm -f "$P/.git/leak-pattern"
(( rc == 0 )) && (cd "$P" && bash -c "$OWNLINE") && out=$(kpc "$P" check) && [[ "$out" != *".git/leak-pattern"* ]] && planted "$P"
result "U1b the project's own check, moved onto the list at its place through the pinned release's reader, still refuses a listed term with .git/leak-pattern gone" $? "${WHY:-$(squash "$out")}"

# ============================== straight from v0.11.0 to the candidate ===========================
B="$TMP/b"; mkproj "$B" && moved "$B" "$CAND"
result "U9 v0.11.0 straight to the candidate: kept, check passes, a clean push accepted, a listed term refused" $? "$WHY"

# ============================== going back to v0.11.0 ============================================
# RL5: v0.11.0's hooks read the list at .git/leak-pattern, so going back to it must find there the list the project holds
# now, at its place, byte for byte; otherwise to refuses and changes nothing.
moved "$B" v0.11.0 && moved "$B" "$CAND"
result "U5 back to v0.11.0 with .git/leak-pattern the list at its place: kept, its hooks refuse a listed term, and forward again" $? "$WHY"
(umask 077 && printf "LEAK_PATTERN='%s|zqappended'\n" "$MARK" > "$(lmf "$B")"); out=$(kpc "$B" repin local); rc=$?
if (( rc == 0 )) && [[ "$out" == *"an append"* ]]; then
    before=$(snap "$B"); out=$(kpc "$B" to v0.11.0); rc=$?
    if (( rc == 0 )); then
        push=$(git -C "$B" push -q origin HEAD:refs/heads/main 2>&1); prc=$?
        result "U5b back to v0.11.0 refuses while .git/leak-pattern differs from the list at its place, changing nothing" 1 \
            "to v0.11.0 was kept (exit 0) with .git/leak-pattern the list before its append; then a clean push exited $prc: $(squash "$push")"
    else
        [[ "$out" == *"hooks read the list at .git/leak-pattern"* && "$(snap "$B")" == "$before" ]]
        result "U5b back to v0.11.0 refuses while .git/leak-pattern differs from the list at its place, changing nothing" $? "exit $rc: $(squash "$out")"
    fi
else result "U5b back to v0.11.0 refuses while .git/leak-pattern differs from the list at its place, changing nothing" 1 "the append's repin: exit $rc: $(squash "$out")"; fi
# This project runs no check of its own, so what to does here is kit-pin's alone.
C="$TMP/c"; mkproj "$C" '# no tests of its own' && moved "$C" "$CAND"; rc=$?
if (( rc == 0 )); then
    rm -f "$C/.git/leak-pattern"; before=$(snap "$C"); out=$(kpc "$C" to v0.11.0); rc=$?
    if (( rc == 0 )); then
        push=$(git -C "$C" push -q origin HEAD:refs/heads/main 2>&1); prc=$?
        result "U5c back to v0.11.0 refuses with no list at .git/leak-pattern, changing nothing" 1 \
            "to v0.11.0 was kept (exit 0) with no .git/leak-pattern for v0.11.0's hooks to read; then a clean push exited $prc: $(squash "$push")"
    else
        [[ "$out" == *"hooks read the list at .git/leak-pattern"* && "$(snap "$C")" == "$before" ]]
        result "U5c back to v0.11.0 refuses with no list at .git/leak-pattern, changing nothing" $? "exit $rc: $(squash "$out")"
    fi
else result "U5c back to v0.11.0 refuses with no list at .git/leak-pattern, changing nothing" 1 "its project: $WHY"; fi

# ============================== kit-pin.tests and the move's files ===============================
# RL3: to runs kit-pin.tests before anything is committed, so a test sees the move in the work tree and the index alone.
# A test that checks the index holds what the work tree does (kit.list-id, once the move makes it) must pass, and a red
# test after the move must leave neither kit.list-id nor anything else staged.
Q="$TMP/q"; mkproj "$Q" "$OWNLINE" '[ ! -e kit.list-id ] || git cat-file -e :kit.list-id'; rc=$?
if (( rc == 0 )); then
    out=$(kpc "$Q" to v0.12.0); rc=$?
    [[ $rc -eq 0 && "$(git -C "$Q" diff --cached --name-only)" == *kit.list-id* && "$out" == *"ran on the work tree and the index"* ]]
    result "U3 a test reading the move from the index passes: to stages kit.list-id and says its tests ran on the work tree and the index" $? "exit $rc: $(squash "$out")"
else result "U3 a test reading the move from the index passes: to stages kit.list-id and says its tests ran on the work tree and the index" 1 "its project: $WHY"; fi
Q2="$TMP/q2"; mkproj "$Q2" "$OWNLINE" '[ ! -e kit.list-id ] || exit 1'; rc=$?
if (( rc == 0 )); then
    before=$(snap "$Q2"); out=$(kpc "$Q2" to v0.12.0); rc=$?
    [[ $rc -ne 0 && "$out" == *"kit-pin.tests line 2 failed"* && "$(snap "$Q2")" == "$before" && ! -e "$Q2/kit.list-id" ]] \
        && ! git -C "$Q2" ls-files --error-unmatch kit.list-id >/dev/null 2>&1
    result "U3b a red test after the move puts everything back: kit.list-id in neither the work tree nor the index" $? "exit $rc: $(squash "$out")"
else result "U3b a red test after the move puts everything back: kit.list-id in neither the work tree nor the index" 1 "its project: $WHY"; fi

summary
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

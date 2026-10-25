#!/usr/bin/env bash
#
# install_test.sh — tests for delivery by install and pin: tools/install-release.sh, the stub hook
# (leak-detection/stub-hook), the checked-copies layer (leak-detection/check-copies.sh, which the hooks run
# under the stub) and bin/kit-pin.
#
#   tests/install_test.sh [ROOT]    ROOT = a checkout of this kit (default: the one holding this file)
#
# Every case works under a temp dir: a clone of ROOT's staged tree with release tags and a bare remote,
# installs under KIT_INSTALL_ROOT, scratch spawns and their remotes. A private global git config keeps
# the user's own (a global core.hooksPath, say) out of every case. Tags here are the clone's, never ROOT's.
#
# A refusal must be for its stated reason, and the only refusal: a check that lost its exit can still
# refuse further on for another reason, and a test that accepted any refusal would stay green with the
# protection gone (hooks_test RC1 to RC5). Exit 0 only when every case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
command -v gitleaks >/dev/null 2>&1 || { echo "install_test: gitleaks is required" >&2; exit 1; }
TMP=$(mktemp -d) || exit 1
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT     # installs are read-only

export KIT_INSTALL_ROOT="$TMP/releases"; mkdir -p "$KIT_INSTALL_ROOT"
export GIT_CONFIG_GLOBAL="$TMP/global.gitconfig" GIT_CONFIG_NOSYSTEM=1; : > "$GIT_CONFIG_GLOBAL"
export LEAK_PATTERN='SYNTH-MARKER-7F3A'
MARK='SYNTH-MARKER-7F3A'
PASS=0; FAIL=0; SKIP=0

skip() { SKIP=$((SKIP+1)); printf 'skip  %s  -- %s\n' "$1" "$2"; }
result() { if [[ $2 -eq 0 ]]; then PASS=$((PASS+1)); printf 'ok    %s\n' "$1"
           else FAIL=$((FAIL+1)); printf 'FAIL  %s  -- %s\n' "$1" "$3"; fi; }
want_ok() { if [[ $2 -eq 0 && ( -z "${4:-}" || "$3" == *"$4"* ) ]]; then result "$1" 0
            else result "$1" 1 "exit $2${4:+, want '$4'}: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-200)"; fi; }
want_refused() { if [[ $2 -ne 0 && "$3" == *"$4"* ]]; then result "$1" 0
                 else result "$1" 1 "exit $2, want refusal '$4': $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-200)"; fi; }
# NAME RC OUTPUT REASON: refused, with exactly one REFUSING line, for REASON.
refused_for() { local n; n=$(printf '%s\n' "$3" | grep -c 'REFUSING')
    if [[ $2 -ne 0 && $n -eq 1 && "$3" == *"$4"* ]]; then result "$1" 0
    else result "$1" 1 "exit $2, $n refusal(s), want '$4': $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-200)"; fi; }
sha() { local s; s=$(sha256sum < "$1") && printf '%s' "${s%% *}"; }
# A list's pin (decisions log §108, §112): its rows and the SHA-256 of its value, written here with a row count the
# suite knows, so a counting fault in kit-pin can't agree with itself.
tsum() { local s; if command -v sha256sum >/dev/null 2>&1; then s=$(sha256sum); else s=$(shasum -a 256); fi; printf '%s' "${s%% *}"; }
tpin() { mkdir -p "${1%/*}"; printf '# a test pin\nrows=%s\nsha256=%s\n' "$3" "$(printf '%s' "$2" | tsum)" > "$1"; }   # PINFILE VALUE ROWS
mhash() { local s; s=$(sha "$1/MANIFEST.sha256") && printf 'sha256:%s' "$s"; }
ident() { git -C "$1" config user.name install-test; git -C "$1" config user.email install-test@invalid.local; }

CASES=(MX1 VT1 HS1 HS2 IR0 IR1 IR1b IR1c IR1d IR1e IR2 IR3 IR4 IR5 IR6 IR7 IR8 IR8b IR9 IR15 IR16
       ST0 ST0b ST1 ST2 ST2b ST3 ST3b ST3c ST4 ST5 ST6 ST6b ST7 ST8 ST9 ST10 ST10b ST11 ST12
       CC7 CC1 CC2 CC3 CC4 CC5 CC6 CI1 CI2 CI3 CI4 GL1 CF1 CF2 CF3 CF4 CF5
       KV0 KV1 KV2 KV3 KV4 KC0 KC1 KC1b KC2 KC3 KC4 KC5 KP1
       KL1 KL2 KL2b KL3 KL4 KL5 KL6 KL7 KL8 KL9 NV0 KL10 KL11 KL12 KL13 KL14 KL15 KL16 KB1 KB2 KB3
       KT1 KT2 KT3 KT4 KT5 KT6 KT6b KT7 KT0 KT0b KT8 KT9
       KM2 KM3 KM1 KM1b KM0 KM0b
       HO1 HO1b HO2 HO3 HO4 HO5 HO6 HG1 HG2 HG3 HP1 HP2 HP3 HP4 HN1 HN2 HX1 KX1 HX2 KX2 HX3 HX4
       KR2 KR1 KR0
       HP0 NT1 NT1b NT2 NT2b NT3 NT3b NT4 NT4b NT5 NT5b SH1 SH2 SH3 SH4 SH5 KG0 KG1 KG2 KG3
       CC9 EX2 EX1 V31 V32 V33 V34 CC8 V35 HB1 HB2 HB3 HB4 HB5 HB6
       IR10 IR11 IR13 IR14 PL0 PL1 GP0 GP0b LG0 LG0b GP1 LG1 V36 V37 V38 LE1 LE2
       EG10 EG11 EG12 EG13 EG14 EG15 IR12 EG16 EG17 EG18 EG19 EG20 EG21 EG22 EG23 EG24
       EG28 EG29 EG30 EG31 EG32 EG33 EG34 EG35 PN0 CP1 CP2 KR3 CP3 KM4
       RP1 RP2 RP3 RP4 RP5 RP6 RP7 RP8 RP9 RP10 RP11 RP12 RP13
       PC0 PC1 PC2 PC3 PC4 PC5 PC6 PC7 PC8 PC9 PC10 PC11 PC12 PC13 PC14 PC15 PC16 PC17 PC18 PC19 PC20 PC21 PC22 PC23 PC24 PC25)
if ! git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    for c in "${CASES[@]}"; do skip "$c" "no commits yet in $ROOT: rerun after commit one"; done
    echo; echo "install_test: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi

# ============================== tracked modes, and one verifier text ============================
modes=$(git -C "$ROOT" ls-files -s -- leak-detection/stub-hook leak-detection/check-copies.sh bin/kit-pin \
            tools/install-release.sh tests/install_test.sh bin/kit-history-audit)
bad=$(printf '%s\n' "$modes" | awk 'NF && $1 != "100755" {print $4}'); n=$(printf '%s\n' "$modes" | awk 'NF' | wc -l)
[[ "$n" -eq 6 && -z "$bad" ]];                 want_ok "MX1 stub, copies layer, kit-pin, install-release, the history audit and this suite are tracked executable" $? "tracked $n of 6; not 100755: $(echo $bad)"
# The stub and kit-pin each carry the install verifier in their own code (a verifier read from the install
# would be checking itself); one text, so the two can't drift apart.
vf() { awk '/^kit_verify_install\(\) \{/ {p=1} p {print} p && /^\}/ {exit}' "$1" 2>/dev/null; }
a=$(vf "$ROOT/leak-detection/stub-hook"); b=$(vf "$ROOT/bin/kit-pin")
[[ -n "$a" && "$a" == "$b" ]];                 want_ok "VT1 the stub and kit-pin carry the same install verifier" $? ""
# One SHA-256 routine, the same text in each script that hashes: sha256sum, else shasum -a 256 (a stock Mac has only
# that), else a refusal naming both (decisions log §88). Outside it, no line of their code names either tool.
HASHERS=(leak-detection/stub-hook bin/kit-pin bin/kit-load-check-stub leak-detection/check-copies.sh tools/install-release.sh
         leak-detection/pre-push leak-detection/scan-tree.sh bin/kit-history-audit)
hs() { awk '/^kit_(no_)?sha256\(\) \{/ {p=1} p {print} p && /^\}/ {p=0}' "$1" 2>/dev/null; }
a=$(hs "$ROOT/${HASHERS[0]}"); n=0
for f in "${HASHERS[@]:1}"; do [[ "$(hs "$ROOT/$f")" == "$a" ]] && n=$((n+1)); done
[[ "$a" == *"kit_sha256() {"* && "$a" == *"kit_no_sha256() {"* && $n -eq 7 ]]
                                               want_ok "HS1 the eight scripts that hash carry one SHA-256 routine, the same text" $? "${#a} bytes in the stub's; $n of 7 others match it"
# One pin routine, the same text in each script that reads a list's pin (decisions log §112): how many rows a list
# holds, its first N rows, and whether it is the list its pin names.
pn() { awk '/^kit_list_split=/ {p=1} /^kit_pin_check\(\)/ {q=1} p {print} q && /^\}/ {exit}' "$1" 2>/dev/null; }
a=$(pn "$ROOT/leak-detection/pre-push")
[[ "$a" == *"kit_pin_check() {"* && "$(pn "$ROOT/leak-detection/scan-tree.sh")" == "$a" && "$(pn "$ROOT/bin/kit-pin")" == "$a" \
   && "$(pn "$ROOT/bin/kit-history-audit")" == "$a" ]]
                                               want_ok "PN0 pre-push, scan-tree.sh, kit-pin and the history audit carry one pin routine, the same text" $? "${#a} bytes in pre-push's"
bad=""
for f in "${HASHERS[@]}"; do
    awk '/^kit_(no_)?sha256\(\) \{/ {p=1} !p && !/^[[:space:]]*#/ {print} p && /^\}/ {p=0}' "$ROOT/$f" 2>/dev/null \
        | grep -qE 'sha256sum|shasum' && bad+=" $f"
done
[[ -z "$bad" ]];                               want_ok "HS2 outside that routine, none of the seven names sha256sum or shasum in its code" $? "named in:$bad"

# ============================== a kit clone with release tags, and its remote ===================
# The kit here holds ROOT's STAGED tree, so these cases test what is about to be committed. It is a new
# repository, not a clone: a clone of a shallow ROOT (CI's checkout is depth 1) inherits the shallow
# boundary, and its tags can't then be pushed to an empty remote. v2.0.0 is that tree with the real hook
# suite; v1.0.0 and the rest replace the suite with a stand-in so the many installs below stay fast;
# v2.0.0 alone runs the real one (IR9).
K="$TMP/kit"; git init -q -b main "$K"; ident "$K"
git -C "$ROOT" checkout-index -a --prefix="$K/"
kc() { git -C "$K" add -A && git -C "$K" -c core.hooksPath=/dev/null commit -q --allow-empty -m "$1"; }
# Git for Windows' git init sets core.fileMode false, and git add then records every new file 100644, so the execute
# bits come from ROOT's index (decisions log §102).
git -C "$K" add -A && git -C "$ROOT" ls-files -s | awk -F '\t' '$1 ~ /^100755 / {print $2}' | git -C "$K" update-index --chmod=+x --stdin
kc "ROOT's staged tree"
[[ "$(git -C "$K" ls-files -s)" == "$(git -C "$ROOT" ls-files -s)" ]]
                                               want_ok "IR0 the install cases run on ROOT's staged tree" $? "the kit here and ROOT's index differ, first at: $(diff <(git -C "$K" ls-files -s) <(git -C "$ROOT" ls-files -s) | grep -m 1 '^[<>]')"
git -C "$K" tag -a v2.0.0 -m "the real suite"
git -C "$K" tag -a v9.0.0 -m "the real suite, for the install-time PY2 case"   # same tree as v2.0.0
printf '#!/usr/bin/env bash\necho "hooks_test: stand-in suite"\nexit 0\n' > "$K/tests/hooks_test.sh"; chmod +x "$K/tests/hooks_test.sh"
kc "stand-in suite"; git -C "$K" tag -a v1.0.0 -m v1.0.0; B=$(git -C "$K" rev-parse HEAD)
git -C "$K" tag -a v6.0.0 -m "pushed here, moved later"
git -C "$K" checkout -q -b bad
printf '#!/usr/bin/env bash\necho "FAIL  ZZ1 a stand-in case  -- planted"\necho "hooks_test: 0 passed, 1 failed"\nexit 1\n' > "$K/tests/hooks_test.sh"
kc "a failing suite"
git -C "$K" tag -a v3.0.0 -m "a failing suite"; git -C "$K" checkout -q -
echo "a later line" >> "$K/patterns/local-upgrade.md"; kc "a later release"; git -C "$K" tag -a v1.0.1 -m v1.0.1
git -C "$K" tag v4.0.0                                         # lightweight
git -C "$K" tag -a v5.0.0 -m "never pushed"
# v1.0.2: a release whose list reader fails its own selftest (a second assignment no longer refuses).
git -C "$K" checkout -q -b badreader
sed -i 's/(( at != 0 ))/(( 0 ))/' "$K/leak-detection/read-leak-pattern.sh"; kc "a reader that fails its selftest"
git -C "$K" tag -a v1.0.2 -m "a failing reader"; git -C "$K" checkout -q main
# v8.0.0: a release whose stand-in suite makes something at the target while the install is staged, as another
# process could between install-release's check and its rename.
git -C "$K" checkout -q -b appear
printf '#!/usr/bin/env bash\nt="$(dirname "$1")/v8.0.0"; mkdir -p "$t" && echo x > "$t/appeared"\necho "hooks_test: a stand-in that made the target"\nexit 0\n' \
    > "$K/tests/hooks_test.sh"; kc "a suite that makes the target"
git -C "$K" tag -a v8.0.0 -m "the target appears"; git -C "$K" checkout -q main
git init -q --bare "$TMP/kit-remote.git"; git -C "$K" remote add origin "$TMP/kit-remote.git"
git -C "$K" push -q --no-verify origin HEAD:refs/heads/main v1.0.0 v1.0.1 v1.0.2 v2.0.0 v3.0.0 v6.0.0 v8.0.0 v9.0.0 2>/dev/null
git -C "$K" tag -f -a v6.0.0 -m "moved" HEAD >/dev/null        # the remote's v6.0.0 still names B
IRK="$K/tools/install-release.sh"
irun() { (cd "$K" && "$IRK" "$@") 2>&1; }

# ============================== install-release =================================================
I1="$KIT_INSTALL_ROOT/v1.0.0"; I2="$KIT_INSTALL_ROOT/v1.0.1"
out=$(irun v1.0.0); rc=$?
[[ $rc -eq 0 && -f "$I1/RELEASE" && -f "$I1/MANIFEST.sha256" && -f "$I1/CLASSES" ]]
                                               want_ok "IR1 install-release installs a tag with RELEASE, MANIFEST.sha256 and CLASSES" $? "$out"
[[ "$(sed -n 's/^tag=//p' "$I1/RELEASE" 2>/dev/null)" == v1.0.0 && "$(sed -n 's/^commit=//p' "$I1/RELEASE" 2>/dev/null)" == "$B" ]]
                                               want_ok "IR1b RELEASE names the tag and its commit" $? ""
nf=$(cd "$I1" 2>/dev/null && find . -type f ! -name MANIFEST.sha256 | wc -l); nm=$(wc -l < "$I1/MANIFEST.sha256" 2>/dev/null)
(cd "$I1" 2>/dev/null && sha256sum --quiet --strict -c MANIFEST.sha256 >/dev/null 2>&1) && [[ -n "$nm" && "$nf" -eq "$nm" ]]
                                               want_ok "IR1c MANIFEST.sha256 lists every other file of the install, each with its hash" $? "files $nf, lines ${nm:-none}"
[[ -f "$I1/leak-detection/pre-push" && ! -e "$I1/README.md" && ! -e "$I1/kit-manifest.txt" && ! -e "$I1/tests/kit_docs_test.sh" \
   && ! -e "$I1/CLAUDE.md" ]] \
    && grep -q '^owned  leak-detection/pre-push$' "$I1/CLASSES" && grep -q '^spawn  templates/CLAUDE.md$' "$I1/CLASSES"
                                               want_ok "IR1d the install holds the tag's tree minus files classed kit, and CLASSES names the rest" $? ""
[[ -d "$I1" && -z "$(find "$I1" -perm /222 2>/dev/null)" ]]
                                               want_ok "IR1e the install is read-only" $? "writable: $(find "$I1" -perm /222 2>/dev/null | sed "s|^$I1|.|" | head -n 3 | tr '\n' ' ')"
echo "PLANTED working-tree edit" >> "$K/patterns/local-upgrade.md"
out=$(irun v1.0.1); rc=$?
[[ $rc -eq 0 && -f "$I2/patterns/local-upgrade.md" ]] && ! grep -q PLANTED "$I2/patterns/local-upgrade.md"
                                               want_ok "IR2 an edit in the clone's working tree never reaches the install" $? "$out"
git -C "$K" checkout -q -- patterns/local-upgrade.md
out=$(irun v1.0.0); rc=$?;                     refused_for "IR3 install-release refuses a target that exists" $rc "$out" "already exists"
out=$(irun v4.0.0); rc=$?;                     refused_for "IR4 install-release refuses a lightweight tag" $rc "$out" "lightweight tag"
out=$(irun v5.0.0); rc=$?;                     refused_for "IR5 install-release refuses a tag that isn't on the remote" $rc "$out" "is not on the remote"
out=$(irun v6.0.0); rc=$?;                     refused_for "IR6 install-release refuses a tag the remote has on another commit" $rc "$out" "points at another commit"
out=$(irun v3.0.0); rc=$?
left=$(find "$KIT_INSTALL_ROOT" -mindepth 1 -maxdepth 1 \( -name 'v3.0.0' -o -name '.staging*' \) | wc -l)
(( left == 0 )) || rc=0;                       refused_for "IR7 install-release refuses when the release's suite fails on the staged install, and leaves nothing" $rc "$out" "hook suite failed"
[[ "$out" == *"FAIL  ZZ1 a stand-in case"* ]]; want_ok "IR12 and that refusal names the suite's failing cases" $? "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
out=$(irun main); rc=$?;                       refused_for "IR8 install-release refuses a name that isn't a release tag" $rc "$out" "not a release tag name"
out=$(irun v7.0.0); rc=$?;                     refused_for "IR8b install-release refuses a release name with no tag" $rc "$out" "is not a tag in this clone"
out=$(irun v2.0.0); rc=$?;                     want_ok "IR9 the whole current hook suite passes from an install (the real suite, run on the staged install)" $rc "$out" "installed v2.0.0"
# PY2 at install time (decisions log §152). PY2 can only exercise its user-site plant where this machine's python3 has
# its user site on; otherwise the plant is inert even without python3 -I, and PY2 has nothing to refute. The isolation
# itself is python3 -I, which PY1 shows. So the suite must not block an install over a machine setting the gate doesn't
# depend on -- yet CI must never skip the check silently. tools/install-release.sh sets KIT_INSTALL_CHECK when it runs
# the staged suite; with it, a precondition-unmet PY2 is a loud skip; without it (CI, a direct run), a failure.
# PYTHONNOUSERSITE=1 turns this machine's user site off, so PY2's probe reports the precondition unmet.
I9="$KIT_INSTALL_ROOT/v9.0.0"
out=$( (cd "$K" && PYTHONNOUSERSITE=1 "$IRK" v9.0.0) 2>&1 ); rc=$?
                                               want_ok "IR15 install-release installs though this machine's python3 has its user site off (PY2's precondition unmet), not blocking on it" $rc "$out" "installed v9.0.0"
if [[ -d "$I9" ]]; then
    out=$( (cd "$I9" && PYTHONNOUSERSITE=1 "$I9/tests/hooks_test.sh" "$I9") 2>&1 ); rc=$?
    [[ $rc -ne 0 && "$out" == *"PY2"* && "$out" == *"precondition unmet"* ]]
                                               want_ok "IR16 the same suite without the install marker fails PY2, so CI never skips the isolation check" $? "exit $rc: $(printf '%s' "$out" | grep -a PY2 | head -1 | cut -c1-120)"
else skip "IR16 the same suite without the install marker fails PY2" "v9.0.0 did not install (IR15), so its suite can't be rerun"; fi
H1=$(mhash "$I1"); H2=$(mhash "$I2")
PRISTINE="$TMP/pristine-v1.0.0"; cp -a "$I1" "$PRISTINE" 2>/dev/null
reset_i1() { chmod -R u+w "$I1" 2>/dev/null; rm -rf "${I1:?}"; cp -a "$PRISTINE" "$I1" 2>/dev/null; }

# ============================== a spawn pinned by hand: the stub ================================
SP="$TMP/spawn"; git init -q -b main "$SP"; ident "$SP"; tpin "$SP/.git/leak-pattern.pin" "$MARK" 1   # the list's pin, for pushes
# Files copied out of an install keep its read-only mode; install -m 0644 gives the spawn writable copies. The spawn
# starts with no .gitleaks.toml of its own; the copies cases below give it one.
printf '# a spawn\n' > "$SP/CLAUDE.md"; printf 'true\n' > "$SP/kit-pin.tests"
printf 'release=v1.0.0\nmanifest=%s\n' "$H1" > "$SP/kit.pin"
git -C "$SP" add -A; git -C "$SP" commit -q --no-verify -m one
git init -q --bare "$TMP/spawn-remote.git"; git -C "$SP" remote add origin "$TMP/spawn-remote.git"
git -C "$SP" push -q --no-verify origin main 2>/dev/null
stubs() { local h; for h in pre-commit pre-push; do install -m 0755 "$1/leak-detection/stub-hook" "$SP/.git/hooks/$h" 2>/dev/null; done; }
stubs "$I1"
pin() { printf 'release=%s\nmanifest=%s\n' "$1" "$2" > "$SP/kit.pin"; }
note() { echo "$1" >> "$SP/notes.txt"; git -C "$SP" add notes.txt; }
sc() { (cd "$SP" && git commit -q -m "${1:-x}") 2>&1; }                 # a commit, through the stub
sp() { (cd "$SP" && git push -q origin "${1:-main}") 2>&1; }             # a push, through the stub
unstage() { git -C "$SP" reset -q; git -C "$SP" checkout -q -- . 2>/dev/null; git -C "$SP" clean -qfd -e kit.pin 2>/dev/null; }

isstub() { cmp -s "$SP/.git/hooks/pre-commit" "$1/leak-detection/stub-hook" && cmp -s "$SP/.git/hooks/pre-push" "$1/leak-detection/stub-hook"; }
note a; out=$(sc); rc=$?; isstub "$I1" || rc=1
                                               want_ok "ST0 a clean commit passes through the stub and the release's pre-commit" $rc "$out"
install -m 0644 "$I1/leak-detection/fixtures/synthetic_config.txt" "$SP/config.local.txt" 2>/dev/null; git -C "$SP" add config.local.txt 2>/dev/null
out=$(sc);                                     want_refused "ST0b the release's pre-commit runs: a credential shape is blocked" $? "$out" "credential shapes"
unstage
mv "$SP/kit.pin" "$TMP/kit.pin.aside"; note b; out=$(sc); rc=$?; mv "$TMP/kit.pin.aside" "$SP/kit.pin"
                                               refused_for "ST1 the stub refuses with no kit.pin" $rc "$out" "no kit.pin"
printf 'release=v1.0.0\n' > "$SP/kit.pin"; out=$(sc); refused_for "ST2 the stub refuses a malformed kit.pin" $? "$out" "kit.pin is malformed"
pin ../v1.0.0 "$H1"; out=$(sc);                refused_for "ST2b the stub refuses a release name that isn't vX.Y.Z" $? "$out" "kit.pin is malformed"
pin v9.9.9 "$H1"; out=$(sc);                   refused_for "ST3 the stub refuses a pin whose install is missing" $? "$out" "no install for v9.9.9"
# Under Claude Code's sandbox read block a sandboxed command sees the install, and every folder up to ~/.local, as "No
# such file or directory", the error a missing install gives (measured, decisions log §292), so the stub can't tell
# hidden from missing: its refusal names both and the folder to let sandboxed commands read, and offers kit-pin restore
# only for the missing case. ST3c makes the install root unreadable, the nearest this suite gets to hidden.
pin v9.9.9 "$H1"; out=$(sc); rc=$?
[[ "$out" == *"sandbox.filesystem.allowRead"* ]] || rc=0
                                               refused_for "ST3b a missing install's refusal names both causes, missing or hidden, and what to allow" $rc "$out" "missing, or hidden"
pin v1.0.0 "$H1"; chmod 000 "$KIT_INSTALL_ROOT"; out=$(sc); rc=$?; chmod 755 "$KIT_INSTALL_ROOT"
                                               refused_for "ST3c an install the stub can't read is refused the same way" $rc "$out" "missing, or hidden"
cp -a "$PRISTINE" "$KIT_INSTALL_ROOT/v1.0.9" 2>/dev/null; pin v1.0.9 "$H1"; out=$(sc)
                                               refused_for "ST4 the stub refuses an install whose RELEASE names another tag" $? "$out" "RELEASE names v1.0.0, not v1.0.9"
pin v1.0.0 "sha256:$(printf '0%.0s' {1..64})"; out=$(sc)
                                               refused_for "ST5 the stub refuses a manifest that doesn't match the pin" $? "$out" "manifest doesn't match the pin"
git -C "$SP" checkout -q -- kit.pin; unstage
# The gap stage 2 left (decisions log §47): a reader edited to exit 0 while sourced ends pre-push with a pass.
RDI="$I1/leak-detection/read-leak-pattern.sh"
chmod -R u+w "$I1" 2>/dev/null; { echo 'exit 0'; cat "$PRISTINE/leak-detection/read-leak-pattern.sh"; } > "$RDI" 2>/dev/null
echo "has $MARK here" > "$SP/m.txt"; git -C "$SP" add m.txt; git -C "$SP" commit -q --no-verify -m marker
out=$(sp); rc=$?;                              refused_for "ST6 the stub refuses a push when the install's reader was edited to exit 0 when sourced" $rc "$out" "leak-detection/read-leak-pattern.sh in the install doesn't match its manifest line"
[[ $rc -ne 0 && "$out" != *SYNTH-MARKER* ]];   want_ok "ST6b that refusal does not print the pattern" $? "exit $rc"
git -C "$SP" reset -q --hard HEAD~1
note c; out=$(sc);                             refused_for "ST7 the stub refuses a commit while an install file doesn't match its manifest line" $? "$out" "doesn't match its manifest line"
unstage
# A file and its manifest line edited together: the manifest no longer matches the pin.
sum=$(sha "$RDI"); sed -i "s|^[0-9a-f]*  leak-detection/read-leak-pattern.sh\$|$sum  leak-detection/read-leak-pattern.sh|" "$I1/MANIFEST.sha256" 2>/dev/null
note d; out=$(sc);                             refused_for "ST8 the stub refuses a file and its manifest line edited together" $? "$out" "manifest doesn't match the pin"
unstage; reset_i1
chmod u+w "$I1/leak-detection" 2>/dev/null; echo 'exit 0' > "$I1/leak-detection/extra.sh"
note e; out=$(sc);                             refused_for "ST9 the stub refuses a file in the install that its manifest doesn't list" $? "$out" "leak-detection/extra.sh is in the install but not in its manifest"
unstage; reset_i1
echo '# drift' >> "$SP/.git/hooks/pre-commit"; note f; out=$(sc)
                                               refused_for "ST10 the stub refuses when it differs from the release's copy" $? "$out" "this stub differs from release v1.0.0's copy"
unstage; stubs "$I1"
echo "has $MARK here" > "$SP/m.txt"; git -C "$SP" add m.txt; git -C "$SP" commit -q --no-verify -m marker
out=$(sp);                                     want_refused "ST10b through the stub, the release's pre-push blocks an identity marker" $? "$out" "identity markers"
git -C "$SP" reset -q --hard HEAD~1
mkdir -p "$SP/hook-checks/pre-commit"; printf '#!/usr/bin/env bash\nprintf "%%s" "$KIT_INSTALL" > "%s/seen"\n' "$TMP" > "$SP/hook-checks/pre-commit/a-seen"
chmod +x "$SP/hook-checks/pre-commit/a-seen"; git -C "$SP" add hook-checks; out=$(sc); rc=$?
# The same folder, however it is spelled: on Windows a hook gets the path in Windows form (decisions log §102).
[[ "$(cat "$TMP/seen" 2>/dev/null)" -ef "$I1" ]] || rc=1
                                               want_ok "ST11 the stub exports KIT_INSTALL, which a project's own check sees" $rc "$out"
git -C "$SP" rm -q -r hook-checks; git -C "$SP" commit -q --no-verify -m "no checks"
# The installer's I3, here: git skips a hook it can't execute with only a hint, so the stub refuses rather than hand
# a commit to a release hook that can't run. The manifest holds contents, not modes, so this is its own check.
# Git Bash reads a file's execute bit from its #! line, so there the release's hook stays executable whatever chmod says,
# and the case can't be built (decisions log §102).
chmod u+w "$I1/leak-detection" "$I1/leak-detection/pre-commit" 2>/dev/null; chmod a-x "$I1/leak-detection/pre-commit" 2>/dev/null
if [[ -x "$I1/leak-detection/pre-commit" ]]; then skip ST12 "chmod a-x left the release's pre-commit executable here"
else note j; out=$(sc);                        refused_for "ST12 the stub refuses when the release's hook isn't executable" $? "$out" "release v1.0.0's pre-commit is not executable"; fi
unstage; reset_i1

# ============================== the checked-copies layer, under the stub ========================
# A project with a remote keeps a .gitleaks.toml for its CI. Its checked copy is the release's spawn config, not
# the kit's own file, which allowlists the kit's fixture by path (decisions log §51, §54).
install -m 0644 "$I1/leak-detection/spawn.gitleaks.toml" "$SP/.gitleaks.toml" 2>/dev/null; git -C "$SP" add .gitleaks.toml; out=$(sc); rc=$?
isstub "$I1" || rc=1;                          want_ok "CC7 a project's .gitleaks.toml equal to the release's spawn config commits" $rc "$out"
echo "# a local edit" >> "$SP/.gitleaks.toml"; git -C "$SP" add .gitleaks.toml; out=$(sc)
                                               refused_for "CC1 a kit-owned file that differs from the release refuses" $? "$out" ".gitleaks.toml: differs from release v1.0.0, and kit.forks doesn't declare it"
FS=$(sha "$SP/.gitleaks.toml")
printf '.gitleaks.toml  sha256:%s  §7\n' "$(printf '0%.0s' {1..64})" > "$SP/kit.forks"; git -C "$SP" add kit.forks; out=$(sc)
                                               refused_for "CC2 a declared fork whose hash differs refuses" $? "$out" ".gitleaks.toml: declared in kit.forks with another hash"
printf '.gitleaks.toml  sha256:%s\n' "$FS" > "$SP/kit.forks"; git -C "$SP" add kit.forks; out=$(sc)
                                               refused_for "CC3 a declared fork with no decisions-log section refuses" $? "$out" ".gitleaks.toml: declared in kit.forks without a decisions-log §"
printf '# forks\n.gitleaks.toml  sha256:%s  §7  a local rule\n' "$FS" > "$SP/kit.forks"; git -C "$SP" add kit.forks; out=$(sc); rc=$?
isstub "$I1" || rc=1;                          want_ok "CC4 a declared fork with its hash and its section commits" $rc "$out"
git -C "$SP" rm -q kit.forks; git -C "$SP" commit -q --no-verify -m "fork undeclared"
out=$(sp); rc=$?;                              refused_for "CC5 pre-push refuses a pushed tip holding an undeclared kit-owned difference" $rc "$out" ".gitleaks.toml: differs from release v1.0.0"
git -C "$SP" reset -q --hard HEAD~2
install -m 0644 "$I1/.gitleaks.toml" "$SP/.gitleaks.toml" 2>/dev/null; git -C "$SP" add .gitleaks.toml; out=$(sc)
                                               refused_for "CC6 a project's .gitleaks.toml that is the kit's own config, its fixture exemption with it, refuses for that" $? "$out" ".gitleaks.toml: is the kit's own config, with its kit-only fixture exemption"
git -C "$SP" reset -q; git -C "$SP" checkout -q -- .gitleaks.toml 2>/dev/null
# A project with CI holds the release's ci/ variants as its workflows and the release's scan-tree.sh (ci/copies.txt).
# A refusal names the release file the copy is held to.
mkdir -p "$SP/.github/workflows" "$SP/leak-detection"
install -m 0644 "$I1/ci/gitleaks.yml" "$SP/.github/workflows/gitleaks.yml" 2>/dev/null
install -m 0644 "$I1/ci/leak-scan.yml" "$SP/.github/workflows/leak-scan.yml" 2>/dev/null
install -m 0755 "$I1/leak-detection/scan-tree.sh" "$SP/leak-detection/scan-tree.sh" 2>/dev/null
git -C "$SP" add -A .github leak-detection 2>/dev/null; out=$(sc); rc=$?; isstub "$I1" || rc=1
[[ -f "$SP/.github/workflows/gitleaks.yml" && -f "$SP/.github/workflows/leak-scan.yml" ]] || rc=1
                                               want_ok "CI1 a project's workflows equal to the release's ci/ variants, and its scan-tree.sh, commit" $rc "$out"
install -m 0644 "$I1/.github/workflows/gitleaks.yml" "$SP/.github/workflows/gitleaks.yml" 2>/dev/null; git -C "$SP" add .github; out=$(sc)
                                               refused_for "CI2 the kit's own gitleaks.yml in a project refuses, naming the variant it is held to" $? "$out" ".github/workflows/gitleaks.yml: is the kit's own file; a project's copy is ci/gitleaks.yml"
{ cat "$I1/ci/gitleaks.yml" 2>/dev/null; echo "# a step of the project's own"; } > "$SP/.github/workflows/gitleaks.yml"; git -C "$SP" add .github; out=$(sc)
                                               refused_for "CI3 a workflow matching neither the release's variant nor a declared fork refuses, naming the variant" $? "$out" ".github/workflows/gitleaks.yml: differs from release v1.0.0, and kit.forks doesn't declare it (a project's copy is ci/gitleaks.yml)"
printf '.github/workflows/gitleaks.yml  sha256:%s  §9  a step of its own\n' "$(sha "$SP/.github/workflows/gitleaks.yml")" > "$SP/kit.forks"
git -C "$SP" add kit.forks .github; out=$(sc); rc=$?; isstub "$I1" || rc=1
                                               want_ok "CI4 a declared fork of a workflow is the project's own, and commits" $rc "$out"
# gitleaks' config: the spawn's own .gitleaks.toml when it has one, else the install's.
GLW="$TMP/glwrap"; mkdir -p "$GLW"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/gl-args"\nexec "%s" "$@"\n' "$TMP" "$(command -v gitleaks)" > "$GLW/gitleaks"; chmod +x "$GLW/gitleaks"
note g; rm -f "$TMP/gl-args"; out=$( (cd "$SP" && PATH="$GLW:$PATH" git commit -q -m g) 2>&1 ); rc=$?
grep -qF -- "--config .gitleaks.toml" "$TMP/gl-args" 2>/dev/null || rc=1
                                               want_ok "CF1 pre-commit under the stub uses the spawn's own .gitleaks.toml when it has one" $rc "$out"
# With none, the install's spawn config: the kit's own .gitleaks.toml allowlists the kit's credential fixture by
# path, and that entry would exempt the same path in a spawn (decisions log §51).
SPC="$I1/leak-detection/spawn.gitleaks.toml"
{ [[ -f "$ROOT/leak-detection/spawn.gitleaks.toml" ]] \
  && diff <(grep -vE '^[[:space:]]*(#|$)' "$ROOT/.gitleaks.toml" | grep -v 'leak-detection/fixtures/synthetic_config') \
          <(grep -vE '^[[:space:]]*(#|$)' "$ROOT/leak-detection/spawn.gitleaks.toml") >/dev/null \
  && ! grep -q 'synthetic_config' "$ROOT/leak-detection/spawn.gitleaks.toml"; } 2>/dev/null
                                               want_ok "GL1 the spawn config is the kit's .gitleaks.toml without its fixture exemption, and nothing else" $? ""
# FILE: 0 when a gitleaks run recorded in gl-args was given --config naming FILE, however spelled: on Windows the hooks
# get the install's path in Windows form (decisions log §102).
glconfig() { local c
    while read -r c; do [[ -n "$c" && "$c" -ef "$1" ]] && return 0
    done < <(awk '{for (i = 1; i < NF; i++) if ($i == "--config") print $(i + 1)}' "$TMP/gl-args" 2>/dev/null)
    return 1; }
git -C "$SP" rm -q .gitleaks.toml; note h; rm -f "$TMP/gl-args"; out=$( (cd "$SP" && PATH="$GLW:$PATH" git commit -q -m h) 2>&1 ); rc=$?
glconfig "$SPC" || rc=1
                                               want_ok "CF2 with none in the spawn, pre-commit uses the install's spawn config" $rc "$out"
rm -f "$TMP/gl-args"; out=$( (cd "$SP" && PATH="$GLW:$PATH" git push -q origin main) 2>&1 ); rc=$?
glconfig "$SPC" || rc=1
                                               want_ok "CF3 with none in the spawn, pre-push uses the install's spawn config" $rc "$out"
# A credential shape at the path the kit's config allowlists: refused, for that reason, at commit and at push.
mkdir -p "$SP/leak-detection/fixtures"; install -m 0644 "$I1/leak-detection/fixtures/synthetic_config.txt" "$SP/leak-detection/fixtures/" 2>/dev/null
git -C "$SP" add leak-detection; out=$(sc)
                                               want_refused "CF4 with no config of its own, a spawn's credential shape at the kit's fixture path is blocked at commit" $? "$out" "credential shapes"
git -C "$SP" commit -q --no-verify -m "a credential shape at the fixture path"; out=$(sp)
                                               want_refused "CF5 and blocked at push" $? "$out" "gitleaks found credential shapes"
git -C "$SP" reset -q --hard HEAD~1

# ============================== kit-pin =========================================================
KP="$ROOT/bin/kit-pin"
kp() { (cd "$SP" && "$KP" "$@") 2>&1; }
out=$("$KP" verify v1.0.0 "$H1" 2>&1);         want_ok "KV0 verify passes an install against its release and manifest hash" $? "$out"
out=$("$KP" verify v9.9.9 "$H1" 2>&1);         refused_for "KV1 verify refuses a missing install" $? "$out" "no install for v9.9.9"
out=$("$KP" verify v1.0.0 "$H2" 2>&1);         refused_for "KV2 verify refuses a manifest that doesn't match the hash" $? "$out" "manifest doesn't match the pin"
chmod -R u+w "$I1" 2>/dev/null; echo "# edited" >> "$I1/leak-detection/pre-commit"
out=$("$KP" verify v1.0.0 "$H1" 2>&1);         refused_for "KV3 verify refuses an edited file" $? "$out" "leak-detection/pre-commit in the install doesn't match its manifest line"
reset_i1
out=$("$KP" verify v1.0.9 "$H1" 2>&1);         refused_for "KV4 verify refuses an install whose RELEASE names another tag" $? "$out" "RELEASE names v1.0.0, not v1.0.9"
out=$(kp check);                               want_ok "KC0 check passes a pinned spawn with its stubs and no hooks path" $? "$out"
git -C "$SP" config core.hooksPath hooks; hooks_before=$(cat "$SP/.git/hooks/pre-commit" | sha256sum)
out=$(kp check); rc=$?; [[ "$(git -C "$SP" config --get core.hooksPath)" == hooks && "$(cat "$SP/.git/hooks/pre-commit" | sha256sum)" == "$hooks_before" ]] || rc=0
                                               refused_for "KC1 check refuses when a hooks path is set, and changes nothing" $rc "$out" "core.hooksPath is set"
git -C "$SP" config --unset core.hooksPath
git config --global core.hooksPath /nowhere; out=$(kp check); rc=$?; git config --global --unset core.hooksPath
                                               refused_for "KC1b check refuses a hooks path set globally too" $rc "$out" "core.hooksPath is set"
mv "$SP/.git/hooks/pre-push" "$TMP/pre-push.aside"; out=$(kp check); rc=$?; mv "$TMP/pre-push.aside" "$SP/.git/hooks/pre-push"
                                               refused_for "KC2 check refuses a missing stub" $rc "$out" "the pre-push stub is missing"
echo '# drift' >> "$SP/.git/hooks/pre-push"; out=$(kp check); rc=$?; stubs "$I1"
                                               refused_for "KC3 check refuses a stub that differs from the release's" $rc "$out" "the pre-push stub differs from release v1.0.0's"
pin v1.0.0 "$H2"; out=$(kp check); rc=$?; git -C "$SP" checkout -q -- kit.pin
                                               refused_for "KC4 check refuses a pin whose manifest hash doesn't match the install" $rc "$out" "manifest doesn't match the pin"
pin v9.9.9 "$H1"; out=$(kp check); rc=$?; git -C "$SP" checkout -q -- kit.pin
                                               refused_for "KC5 check refuses a pin whose install is missing" $rc "$out" "no install for v9.9.9"
pinb=$(sha "$SP/kit.pin"); stubb=$(sha "$SP/.git/hooks/pre-commit")
same() { [[ "$(sha "$SP/kit.pin")" == "$pinb" && "$(sha "$SP/.git/hooks/pre-commit")" == "$stubb" && "$(sha "$SP/.git/hooks/pre-push")" == "$stubb" ]]; }
out=$(kp nosuchmode); rc=$?; same || rc=0;     refused_for "KP1 kit-pin refuses an unknown mode, and changes nothing" $rc "$out" "unknown mode"
# The installer's report, now check's (its I9 to I16): pre-push takes the pattern from the environment or else from
# .git/leak-pattern, read by the release's own reader, so check says which, or that the scan fails closed, and
# never prints the pattern. A list pre-push would refuse never reads as active, and no list text ever runs.
LPF="$SP/.git/leak-pattern"; FBIN="$TMP/listbin"; RAN="$TMP/list-text-ran"; mkdir -p "$FBIN"
printf '#!/bin/sh\ntouch "%s"\n' "$RAN" > "$FBIN/zqcmdz"; chmod +x "$FBIN/zqcmdz"
kl() { (cd "$SP" && env -u LEAK_PATTERN PATH="$FBIN:$PATH" "$KP" check) 2>&1; }
closed() { [[ "$1" == *"FAILING CLOSED"* && "$1" != *"identity scan is active"* ]]; }
# Failing closed is a state of its own, exit 3: installed and pinned, but every push will be refused (§112).
fc() { [[ $1 -eq 3 ]] && closed "$2"; }                                                    # RC OUTPUT
printf "LEAK_PATTERN='%s'\n" "$MARK" > "$LPF"; out=$(kl); rc=$?; closed "$out" && rc=1; [[ "$out" == *SYNTH-MARKER* ]] && rc=1
                                               want_ok "KL1 check: a pattern in .git/leak-pattern reads as active, and isn't printed" $rc "$out" ".git/leak-pattern"
printf '# sets nothing\n' > "$LPF"; out=$(kl); rc=$?; fc $rc "$out" && rc=0 || rc=1
                                               want_ok "KL2 check: a .git/leak-pattern that sets nothing reads as failing closed, exit 3" $rc "$out"
# Its first line matches its exit status: an exit-3 run never opens with "passed", nor says it anywhere (S4, §344).
out=$(kl); rc=$?; first=${out%%$'\n'*}; [[ $rc -eq 3 && "$first" != *passed* && "$out" != *passed* ]] && rc=0 || rc=1
                                               want_ok "KL2b check: an exit-3 run's first line doesn't say it passed, and no line does" $rc "$out"
rm -f "$RAN"; printf '%s\n' "LEAK_PATTERN='$MARK|zq'w|zqcmd'z'" > "$LPF"; out=$(kl); rc=$?
fc $rc "$out" && [[ ! -e "$RAN" && "$out" != *SYNTH-MARKER* ]] && rc=0 || rc=1
                                               want_ok "KL3 check: two terms with an apostrophe each: no list text runs, failing closed (exit 3), nothing printed" $rc "$out"
printf '%s\n' "LEAK_PATTERN='$MARK|zq'ab'cterm'" > "$LPF"; out=$(kl); rc=$?; fc $rc "$out" && rc=0 || rc=1
                                               want_ok "KL4 check: a term with two apostrophes reads as failing closed, exit 3" $rc "$out"
printf '%s\n' "LEAK_PATTERN='$MARK'" "LEAK_PATTERN='zqotherterm'" > "$LPF"; out=$(kl); rc=$?; fc $rc "$out" && rc=0 || rc=1
                                               want_ok "KL5 check: a second assignment reads as failing closed, exit 3" $rc "$out"
printf '%s\n' "LEAK_PATTERN='$MARK'  # a trailing note" > "$LPF"; out=$(kl); rc=$?; fc $rc "$out" && rc=0 || rc=1
                                               want_ok "KL6 check: a comment after the assignment reads as failing closed, exit 3" $rc "$out"
printf '%s\n' "export LEAK_PATTERN='$MARK'" > "$LPF"; out=$(kl); rc=$?; closed "$out" && rc=1
                                               want_ok "KL7 check: the export form reads as active" $rc "$out" "identity scan is active"
printf '%s\n' "# a note" "" "LEAK_PATTERN='$MARK'" "   # an indented note" > "$LPF"; out=$(kl); rc=$?; closed "$out" && rc=1
                                               want_ok "KL8 check: comments and blank lines around the setup form read as active" $rc "$out" "identity scan is active"
rm -f "$LPF"; out=$(kp check); rc=$?; closed "$out" && rc=1
                                               want_ok "KL9 check: LEAK_PATTERN in the environment reads as active" $rc "$out" "set in this environment"
# The reserved line (§308, §310 (a)): a project with no identity list says so with one pinned line, which check reports
# as identity checks off, not as every push refused; a list file it can't read gets its own message, not the missing
# list's; and with no list, its next step names the reserved line beside the list. The value comes from the suites' one
# definition, hooks_test's NOLIST line, so this suite and that one feed every reader the same value (queue 700 item 3).
NOLIST=$(sed -n "s/^NOLIST='\([^']*\)'\$/\1/p" "$ROOT/tests/hooks_test.sh")
[[ -n "$NOLIST" && "$NOLIST" != *$'\n'* ]];    want_ok "NV0 the reserved value comes from hooks_test's one definition, read once" $? "read: $(printf '%s' "$NOLIST" | tr '\n' ' ')"
cp -p "$SP/.git/leak-pattern.pin" "$TMP/sp-kl.pin"
printf "LEAK_PATTERN='%s'\n" "$NOLIST" > "$LPF"; tpin "$SP/.git/leak-pattern.pin" "$NOLIST" 1; out=$(kl); rc=$?
[[ $rc -eq 0 && "$out" == *"identity checks are off"* && "$out" != *"identity scan is active"* ]] && rc=0 || rc=1
                                               want_ok "KL10 check: a pinned reserved line reads as identity checks off, exit 0" $rc "$out"
# A list that exists is never overwritten by a next step (decisions log §353 F1): writes_list OUTPUT is true when the
# output holds a command that writes the list file, or the first-setup block's example list.
writes_list() { [[ "$1" =~ \>[[:space:]]*\"[^\"]*/leak-pattern\" || "$1" == *"marker1|marker2"* ]]; }
printf "LEAK_PATTERN='%s'\n" "$MARK" > "$LPF"; chmod 000 "$LPF"
if [[ -r "$LPF" ]]; then skip "KL11 check: a list file it can't read gets its own message, exit 3" "the file stays readable at mode 000 (root)"
else out=$(kl); rc=$?; [[ $rc -eq 3 && "$out" == *"exists but can't be read"* ]] && ! writes_list "$out" && rc=0 || rc=1
                                               want_ok "KL11 check: a list file it can't read gets its own message, exit 3, and no command that writes the list file" $rc "$out"; fi
chmod 600 "$LPF"; rm -f "$LPF"; out=$(kl); rc=$?; [[ $rc -eq 3 && "$out" == *"LEAK_PATTERN='$NOLIST'"* ]] && rc=0 || rc=1
                                               want_ok "KL12 check: with no list, its next step names the reserved line too, exit 3" $rc "$out"
cp -p "$TMP/sp-kl.pin" "$SP/.git/leak-pattern.pin"
# When the list exists, check gives the advice that fits it, as pre-push does: a list its pin doesn't name, record why
# and repin, or put the list back; no pin yet, the first pin; a list the reader can't read, how to fix it. Only a missing
# list, or one that sets nothing, gets the first-setup block (KL2, KL12).
printf "LEAK_PATTERN='%s'\n" "$MARK|zqadded" > "$LPF"; out=$(kl); rc=$?
[[ $rc -eq 3 && "$out" == *"record why and repin it"* && "$out" == *"put the list back"* ]] && ! writes_list "$out" && rc=0 || rc=1
                                               want_ok "KL13 check: a list changed after its pin: pre-push's advice, and no command that writes the list file" $rc "$out"
out=$( (cd "$SP" && LEAK_PATTERN=zqotherterm "$KP" check) 2>&1 ); rc=$?
[[ $rc -eq 3 && "$out" == *"record why and repin it"* && "$out" == *"put the list back"* ]] && ! writes_list "$out" && rc=0 || rc=1
                                               want_ok "KL14 check: an environment list its pin doesn't name: the same advice, no command that writes the list file" $rc "$out"
printf '%s\n' "LEAK_PATTERN='$MARK'" "LEAK_PATTERN='zqotherterm'" > "$LPF"; out=$(kl); rc=$?
[[ $rc -eq 3 && "$out" == *"not in a shape"* ]] && ! writes_list "$out" && rc=0 || rc=1
                                               want_ok "KL15 check: a list not in a shape the reader reads: how to fix it, no command that writes the list file" $rc "$out"
printf "LEAK_PATTERN='%s'\n" "$MARK" > "$LPF"; mv "$SP/.git/leak-pattern.pin" "$TMP/sp-kl2.pin"; out=$(kl); rc=$?
mv "$TMP/sp-kl2.pin" "$SP/.git/leak-pattern.pin"
[[ $rc -eq 3 && "$out" == *"repin local --first"* ]] && ! writes_list "$out" && rc=0 || rc=1
                                               want_ok "KL16 check: a list with no pin yet: its first pin, no command that writes the list file" $rc "$out"
rm -f "$LPF"
# check says whether pre-push will scan binaries, reading the switch at HEAD as pre-push reads it at the pushed tip
# (R4 (b)): a tracked kit.binaries holding scan=on, or a tracked reviewed list, or off; a kit.binaries that isn't the one
# line scan=on is named, since pre-push then refuses every push that carries a binary.
out=$(kp check); rc=$?;                        want_ok "KB1 check: with no switch and no reviewed list, it says the binary scan is off" $rc "$out" "binary scan is off"
printf 'scan=on\n' > "$SP/kit.binaries"; git -C "$SP" add kit.binaries; git -C "$SP" commit -q --no-verify -m "binary scan on"
out=$(kp check); rc=$?;                        want_ok "KB2 check: a tracked kit.binaries holding scan=on reads as the binary scan on" $rc "$out" "binary scan is on (kit.binaries)"
printf 'scan=yes\n' > "$SP/kit.binaries"; git -C "$SP" commit -q --no-verify -am "a malformed switch"
out=$(kp check); rc=$?;                        want_ok "KB3 check: a kit.binaries that isn't the one line scan=on is named, as pre-push refuses binaries then" $rc "$out" "isn't the one line scan=on"
git -C "$SP" rm -q kit.binaries; git -C "$SP" commit -q --no-verify -m "switch gone"
out=$(kp to v9.9.9); rc=$?; same || rc=0;      refused_for "KT1 to refuses a release with no install" $rc "$out" "no install for v9.9.9"
chmod -R u+w "$I2" 2>/dev/null; cp "$I2/leak-detection/pre-commit" "$TMP/i2-pre-commit"; echo "# edited" >> "$I2/leak-detection/pre-commit"
out=$(kp to v1.0.1); rc=$?; same || rc=0;      refused_for "KT2 to refuses a release whose install fails its own manifest" $rc "$out" "fails its own manifest"
cp "$TMP/i2-pre-commit" "$I2/leak-detection/pre-commit"; chmod -R a-w "$I2"
echo dirty >> "$SP/notes.txt"; out=$(kp to v1.0.1); rc=$?; same || rc=0; git -C "$SP" checkout -q -- notes.txt
                                               refused_for "KT3 to refuses a work tree with uncommitted changes" $rc "$out" "uncommitted changes"
git -C "$SP" config core.hooksPath hooks; out=$(kp to v1.0.1); rc=$?; same || rc=0; git -C "$SP" config --unset core.hooksPath
                                               refused_for "KT4 to refuses while a hooks path is set" $rc "$out" "core.hooksPath is set"
git -C "$SP" rm -q kit-pin.tests; git -C "$SP" commit -q --no-verify -m "no tests file"
out=$(kp to v1.0.1); rc=$?; same || rc=0;      refused_for "KT5 to refuses with no kit-pin.tests" $rc "$out" "no kit-pin.tests"
printf '# this spawn'"'"'s tests\ntrue\nfalse\n' > "$SP/kit-pin.tests"; git -C "$SP" add kit-pin.tests; git -C "$SP" commit -q --no-verify -m "a red test"
out=$(kp to v1.0.1); rc=$?
                                               refused_for "KT6 to refuses when a kit-pin.tests command fails" $rc "$out" "kit-pin.tests line 3 failed"
[[ "$out" == *"kit-pin.tests line 3 failed"* ]] && same && [[ -z "$(git -C "$SP" status --porcelain)" ]]
                                               want_ok "KT6b after that refusal, kit.pin and both stubs are back byte for byte" $? "$(git -C "$SP" status --porcelain)"
printf 'true\n' > "$SP/kit-pin.tests"; git -C "$SP" add kit-pin.tests
mkdir -p "$SP/patterns"; install -m 0644 "$I1/patterns/local-upgrade.md" "$SP/patterns/" 2>/dev/null; git -C "$SP" add patterns
git -C "$SP" commit -q --no-verify -m "a kit-owned copy, as v1.0.0 has it"
out=$(kp to v1.0.1); rc=$?; same || rc=0;      refused_for "KT7 to refuses when a kit-owned copy differs from the target release, and puts the pin back" $rc "$out" "patterns/local-upgrade.md: differs from release v1.0.1"
git -C "$SP" rm -q -r patterns; git -C "$SP" commit -q --no-verify -m "copy gone"
out=$(kp to v1.0.1); rc=$?
[[ "$(cat "$SP/kit.pin" 2>/dev/null)" == "$(printf 'release=v1.0.1\nmanifest=%s' "$H2")" ]] || rc=1
                                               want_ok "KT0 to moves the pin: kit.pin names the release and its manifest hash" $rc "$out"
cmp -s "$SP/.git/hooks/pre-commit" "$I2/leak-detection/stub-hook" && cmp -s "$SP/.git/hooks/pre-push" "$I2/leak-detection/stub-hook" \
    && [[ "$(git -C "$SP" status --porcelain)" == " M kit.pin" ]]
                                               want_ok "KT0b to refreshes both stubs and leaves only kit.pin to commit" $? "$(git -C "$SP" status --porcelain)"
note i; git -C "$SP" add kit.pin; out=$(sc "pin v1.0.1")
[[ $? -eq 0 ]] || echo "install_test: the pin commit failed: $out" >&2
# The installer's I6 and I17 to I18, here: a second move to the pinned release passes and leaves nothing to
# commit; a release whose list reader fails its selftest is refused, and everything is put back.
out=$(kp to v1.0.1); rc=$?; [[ -z "$(git -C "$SP" status --porcelain)" ]] || rc=1
                                               want_ok "KT8 to the release already pinned passes and leaves nothing to commit" $rc "$out"
irun v1.0.2 >/dev/null
pinb=$(sha "$SP/kit.pin"); stubb=$(sha "$SP/.git/hooks/pre-commit")
out=$(kp to v1.0.2); rc=$?; same || rc=0
                                               refused_for "KT9 to refuses a release whose list reader fails its selftest, and puts everything back" $rc "$out" "list reader failed its selftest"

# ============================== kit-pin migrate, on a spawn that runs a hooks path ==============
SM="$TMP/old-spawn"; git init -q -b main "$SM"; ident "$SM"; mkdir -p "$SM/hooks"; tpin "$SM/.git/leak-pattern.pin" "$MARK" 1
printf '# an older spawn\n' > "$SM/CLAUDE.md"; git -C "$SM" add -A; git -C "$SM" commit -q --no-verify -m one
git -C "$SM" config core.hooksPath hooks
printf '#!/bin/sh\n# an older hook\nexit 0\n' > "$SM/.git/hooks/pre-commit"; chmod +x "$SM/.git/hooks/pre-commit"
oldh=$(sha "$SM/.git/hooks/pre-commit")
km() { (cd "$SM" && "$KP" "$@") 2>&1; }
untouched() { [[ "$(git -C "$SM" config --local --get core.hooksPath)" == hooks && "$(sha "$SM/.git/hooks/pre-commit")" == "$oldh" \
               && ! -e "$SM/.git/hooks/pre-push" && ! -e "$SM/kit.pin" ]]; }
echo dirty >> "$SM/CLAUDE.md"; out=$(km migrate v1.0.0); rc=$?; untouched || rc=0; git -C "$SM" checkout -q -- CLAUDE.md
                                               refused_for "KM2 migrate refuses a work tree with uncommitted changes" $rc "$out" "uncommitted changes"
printf 'release=v1.0.0\nmanifest=%s\n' "$H1" > "$SM/kit.pin"; git -C "$SM" add kit.pin; git -C "$SM" commit -q --no-verify -m pinned
out=$(km migrate v1.0.0); rc=$?
                                               refused_for "KM3 migrate refuses a spawn that is already pinned" $rc "$out" "kit.pin already exists"
git -C "$SM" rm -q kit.pin; git -C "$SM" commit -q --no-verify -m unpinned
git config --global core.hooksPath /nowhere; out=$(km migrate v1.0.0); rc=$?; git config --global --unset core.hooksPath
                                               refused_for "KM1 migrate refuses when check fails after the switch" $rc "$out" "check failed after the switch"
[[ "$out" == *"check failed after the switch"* ]] && untouched
                                               want_ok "KM1b after that refusal, the hooks path, the old hook and the clone are back as they were" $? ""
out=$(km migrate v1.0.0); rc=$?;               want_ok "KM0 migrate moves a hooks-path spawn onto the install, and names the hooks path it unset" $rc "$out" "was 'hooks'"
[[ -z "$(git -C "$SM" config --local --get core.hooksPath)" && "$(sha "$SM/.git/hooks/pre-commit.pre-kit-pin")" == "$oldh" ]] \
    && cmp -s "$SM/.git/hooks/pre-commit" "$I1/leak-detection/stub-hook" && cmp -s "$SM/.git/hooks/pre-push" "$I1/leak-detection/stub-hook" \
    && [[ "$(cat "$SM/kit.pin" 2>/dev/null)" == "$(printf 'release=v1.0.0\nmanifest=%s' "$H1")" ]] && km check >/dev/null
                                               want_ok "KM0b after migrate: no hooks path, the old hook kept aside, both stubs, kit.pin, and check passes" $? ""

# ============================== the stubs beside an org's hooks and a project's own ================
# An org's IT may set core.hooksPath at the system or global level, so git would run only its hooks. kit-pin to then
# sets this clone's own hooks path to the stubs, and each stub runs the org's hook for its event first, as git would
# (the same arguments and standard input, from the top of the work tree, by its own path), then a hook of the project's
# own that kit-pin kept as <hook>.project, then the release's checks; any of them refusing refuses. A project's own hook
# is never overwritten (decisions log §274 ruling 4, §294). mkit DIR: IT's two hooks, each adding a line to DIR/ran
# (its name and folder, and pre-push's standard input) and exiting with the number in DIR/exit.
mkit() {
    local h; mkdir -p "$1"; echo 0 > "$1/exit"; : > "$1/ran"
    for h in pre-commit pre-push; do
        printf '#!/bin/sh\necho "%s ran in $(pwd)" >> "%s/ran"\nif [ %s = pre-push ]; then sed "s/^/stdin: /" >> "%s/ran"; fi\nexit "$(cat "%s/exit")"\n' \
            "$h" "$1" "$h" "$1" "$1" > "$1/$h"
        chmod 0755 "$1/$h"
    done; }
mkorg() {  # DIR: a project ready to pin, with a remote and the identity list's pin
    git init -q -b main "$1"; ident "$1"; printf '# an org project\n' > "$1/CLAUDE.md"; printf 'true\n' > "$1/kit-pin.tests"
    git -C "$1" add -A; git -C "$1" commit -q --no-verify -m one; tpin "$1/.git/leak-pattern.pin" "$MARK" 1
    git init -q --bare "$1.git"; git -C "$1" remote add origin "$1.git"; git -C "$1" push -q --no-verify origin main 2>/dev/null; }
SYSCFG="$TMP/system.gitconfig"; : > "$SYSCFG"
IT="$TMP/it-hooks"; mkit "$IT"; git config -f "$SYSCFG" core.hooksPath "$IT"
OS="$TMP/org-sys"; mkorg "$OS"
osy() { (cd "$OS" && env -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$SYSCFG" "$@") 2>&1; }
ostage() { echo "$1" >> "$OS/notes.txt"; git -C "$OS" add notes.txt; }
out=$(osy "$KP" to v1.0.0); rc=$?
[[ "$(git -C "$OS" config --local --get core.hooksPath)" == "$(git -C "$OS" rev-parse --path-format=absolute --git-common-dir)/hooks" ]] || rc=1
                                               want_ok "HO1 under a system hooks path, kit-pin to pins and sets this clone's own path to the stubs" $rc "$out"
out=$(osy "$KP" check); rc=$?;                 want_ok "HO1b and check passes, naming the org's hooks it chains" $rc "$out" "$IT"
echo 1 > "$IT/exit"; : > "$IT/ran"; ostage a; out=$(osy git commit -q -m a); rc=$?
grep -q 'pre-commit ran' "$IT/ran" || rc=0
                                               refused_for "HO2 the org's hook refusing refuses the commit, through the stub" $rc "$out" "refused (exit 1)"
echo 0 > "$IT/exit"; : > "$IT/ran"; git -C "$OS" reset -q; git -C "$OS" checkout -q -- . 2>/dev/null
cp "$ROOT/leak-detection/fixtures/synthetic_config.txt" "$OS/config.local.txt"; git -C "$OS" add config.local.txt; out=$(osy git commit -q -m b); rc=$?
grep -q 'pre-commit ran' "$IT/ran" || rc=0
                                               want_refused "HO3 the org's hook passing, a staged credential is still refused by the kit" $rc "$out" "credential shapes"
git -C "$OS" reset -q; rm -f "$OS/config.local.txt"; : > "$IT/ran"
ostage c; out=$(osy git commit -q -m c); rc=$?
grep -q "pre-commit ran in $OS\$" "$IT/ran" || rc=1
                                               want_ok "HO4 a clean commit passes, the org's hook run from the work tree's top and the kit's scan after it" $rc "$out" "scanned"
: > "$IT/ran"; out=$(osy git push -q origin main); rc=$?
grep -q '^stdin: refs/heads/main ' "$IT/ran" || rc=1
                                               want_ok "HO5 a push passes, the org's hook given git's ref lines and the kit's pre-push after it" $rc "$out" "metadata scan"
echo 1 > "$IT/exit"; ostage d; git -C "$OS" commit -q --no-verify -m d; out=$(osy git push -q origin main); rc=$?
                                               refused_for "HO6 the org's pre-push refusing refuses the push" $rc "$out" "refused (exit 1)"
echo 0 > "$IT/exit"
# The same under a global hooks path, in the suite's own global config.
ITG="$TMP/it-hooks-g"; mkit "$ITG"; git config --global core.hooksPath "$ITG"
OG="$TMP/org-glob"; mkorg "$OG"
og() { (cd "$OG" && "$@") 2>&1; }
out=$(og "$KP" to v1.0.0); rc=$?;              want_ok "HG1 under a global hooks path, kit-pin to pins and sets this clone's own path" $rc "$out"
cp "$ROOT/leak-detection/fixtures/synthetic_config.txt" "$OG/config.local.txt"; git -C "$OG" add config.local.txt
out=$(og git commit -q -m b); rc=$?
grep -q 'pre-commit ran' "$ITG/ran" || rc=0
                                               want_refused "HG2 the org's hook passing, a staged credential is still refused by the kit" $rc "$out" "credential shapes"
git -C "$OG" reset -q; rm -f "$OG/config.local.txt"; : > "$ITG/ran"
echo e >> "$OG/notes.txt"; git -C "$OG" add notes.txt; git -C "$OG" commit -q --no-verify -m e
out=$(og git push -q origin main); rc=$?
grep -q '^stdin: refs/heads/main ' "$ITG/ran" || rc=1
                                               want_ok "HG3 a push passes, the org's hook given git's ref lines and the kit's pre-push after it" $rc "$out" "metadata scan"
git config --global --unset core.hooksPath
# A project's own hook, where kit-pin writes a stub: kept as <hook>.project and run before the kit's checks; one that
# can't be run that way (here a link) is refused by name and left where it is.
OP="$TMP/org-own"; mkorg "$OP"
printf '#!/bin/sh\necho "project pre-commit ran" >> "%s"\nexit "$(cat "%s")"\n' "$TMP/own-ran" "$TMP/own-exit" > "$OP/.git/hooks/pre-commit"
chmod 0755 "$OP/.git/hooks/pre-commit"; echo 0 > "$TMP/own-exit"; ownh=$(sha "$OP/.git/hooks/pre-commit")
op() { (cd "$OP" && "$@") 2>&1; }
out=$(op "$KP" to v1.0.0); rc=$?
[[ "$(sha "$OP/.git/hooks/pre-commit.project" 2>/dev/null)" == "$ownh" ]] && cmp -s "$OP/.git/hooks/pre-commit" "$I1/leak-detection/stub-hook" || rc=1
                                               want_ok "HP1 kit-pin to keeps a project's own hook as <hook>.project, byte for byte, never overwriting it" $rc "$out"
echo f >> "$OP/notes.txt"; git -C "$OP" add notes.txt; : > "$TMP/own-ran"; out=$(op git commit -q -m f); rc=$?
grep -q 'project pre-commit ran' "$TMP/own-ran" || rc=1
                                               want_ok "HP2 the kept hook runs before the kit's checks, and a clean commit passes" $rc "$out" "scanned"
echo 1 > "$TMP/own-exit"; echo g >> "$OP/notes.txt"; git -C "$OP" add notes.txt; out=$(op git commit -q -m g); rc=$?
                                               refused_for "HP3 the kept hook refusing refuses the commit" $rc "$out" "refused (exit 1)"
git -C "$OP" reset -q; git -C "$OP" checkout -q -- .
OL="$TMP/org-link"; mkorg "$OL"; ln -s /bin/true "$OL/.git/hooks/pre-push"
out=$( (cd "$OL" && "$KP" to v1.0.0) 2>&1); rc=$?; [[ -L "$OL/.git/hooks/pre-push" && ! -e "$OL/kit.pin" ]] || rc=0
                                               refused_for "HP4 a project hook that can't be chained (a link) is refused by name, and left as it was" $rc "$out" "$OL/.git/hooks/pre-push"
# The org's path is the one git reads. Under GIT_CONFIG_NOSYSTEM (this suite's default) git skips the system file, which
# `git config --system` reads anyway; so neither check nor the stub may take a hooks path from it (decisions log §297;
# the stand-in's it-hookspath condition found it at bdae909).
echo 0 > "$TMP/own-exit"; echo 1 > "$IT/exit"; : > "$IT/ran"
out=$( (cd "$OP" && GIT_CONFIG_SYSTEM="$SYSCFG" "$KP" check) 2>&1); rc=$?
                                               want_ok "HN1 under GIT_CONFIG_NOSYSTEM, check takes no hooks path from the system file, as git takes none" $rc "$out" "no hooks path"
echo h >> "$OP/notes.txt"; git -C "$OP" add notes.txt; out=$( (cd "$OP" && GIT_CONFIG_SYSTEM="$SYSCFG" git commit -q -m h) 2>&1); rc=$?
[[ -s "$IT/ran" ]] && rc=1
                                               want_ok "HN2 and the stub runs no org hook from it, as git would run none, and the commit passes" $rc "$out" "scanned"
echo 0 > "$IT/exit"
# A kept project hook that isn't executable refuses, by name, as hook-checks/ refuses such an entry (§9's guard); an
# org's hook that isn't executable is skipped, as git skips it, and the kit's checks still run (decisions log §299).
chmod a-x "$OP/.git/hooks/pre-commit.project"; echo i >> "$OP/notes.txt"; git -C "$OP" add notes.txt
out=$(op git commit -q -m i); rc=$?
                                               refused_for "HX1 a kept project hook that has lost its execute bit refuses the commit, naming it" $rc "$out" "$OP/.git/hooks/pre-commit.project"
# check says so too: a clone whose every commit the stub refuses is not a clone that checks out (§300, plan R4 (c)).
out=$(op "$KP" check); rc=$?
                                               refused_for "KX1 kit-pin check: a kept project hook that has lost its execute bit fails the check, naming it" $rc "$out" "$OP/.git/hooks/pre-commit.project"
chmod u+x "$OP/.git/hooks/pre-commit.project"; : > "$TMP/own-ran"; echo j >> "$OP/notes.txt"; git -C "$OP" add notes.txt
out=$(op git commit -q -m j); rc=$?
grep -q 'project pre-commit ran' "$TMP/own-ran" || rc=1
                                               want_ok "HX2 its execute bit restored, the kept hook runs and the commit passes" $rc "$out" "scanned"
out=$(op "$KP" check); rc=$?;                  want_ok "KX2 kit-pin check: with the bit restored, the clone passes, naming the kept hook" $rc "$out" "pre-commit kept as pre-commit.project"
chmod a-x "$IT/pre-commit"; : > "$IT/ran"; ostage x; out=$(osy git commit -q -m x); rc=$?
[[ -s "$IT/ran" ]] && rc=1
                                               want_ok "HX3 an org's hook that isn't executable is skipped, as git skips it, and the kit's scan still runs" $rc "$out" "scanned"
cp "$ROOT/leak-detection/fixtures/synthetic_config.txt" "$OS/config.local.txt"; git -C "$OS" add config.local.txt
out=$(osy git commit -q -m y); rc=$?
                                               want_refused "HX4 and with it skipped, a staged credential is still refused by the kit" $rc "$out" "credential shapes"
git -C "$OS" reset -q; rm -f "$OS/config.local.txt"; chmod a+x "$IT/pre-commit"

# ============================== kit-pin restore =================================================
out=$(kp restore "$TMP/no-such-kit"); rc=$?;   refused_for "KR2 restore refuses with no kit repository" $rc "$out" "no kit repository"
pin v1.0.1 "$H1"; chmod -R u+w "$I2" 2>/dev/null; rm -rf "${I2:?}"
out=$(kp restore "$K"); rc=$?; [[ -e "$I2" ]] && rc=0
                                               refused_for "KR1 restore refuses a rebuild whose manifest isn't the pin's, and keeps none" $rc "$out" "doesn't match the pin"
git -C "$SP" checkout -q -- kit.pin
out=$(kp restore "$K"); rc=$?
[[ -d "$I2" ]] && kp check >/dev/null || rc=1; want_ok "KR0 restore rebuilds a missing install from the kit's repository, and check passes" $rc "$out"

# ============================== hashing without sha256sum =======================================
# A stock Mac has shasum and no sha256sum. With neither, every script that hashes refuses and names both; with shasum
# alone, each works. Each PATH here holds a link to every command on PATH but the ones left out (decisions log §88),
# each left out with its .exe, which Git Bash runs by the bare name; one ln per folder of PATH (hooks_test, §102).
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
NOSHA="$TMP/path-nosha"; pathless "$NOSHA" sha256sum shasum
SHAONLY="$TMP/path-shasum"; pathless "$SHAONLY" sha256sum
NOTOOL="neither sha256sum (GNU coreutils) nor shasum (Perl) is installed"
inpath() { (PATH=$1; command -v "$2" >/dev/null 2>&1); }
inpath "$NOSHA" git && inpath "$SHAONLY" git && ! inpath "$NOSHA" sha256sum && ! inpath "$NOSHA" shasum && ! inpath "$SHAONLY" sha256sum
                                               want_ok "HP0 the test PATHs: neither tool in one, no sha256sum in the other, git in both" $? ""
hp() { local p=$1; shift; (cd "$SP" && PATH="$p" "$@") 2>&1; }        # a command in the spawn, under PATH p
SPR="$TMP/spawn-remote.git"; head0=$(git -C "$SP" rev-parse HEAD); rem0=$(git -C "$SPR" rev-parse main)
note k; out=$(hp "$NOSHA" git commit -q -m k); rc=$?; [[ "$(git -C "$SP" rev-parse HEAD)" == "$head0" ]] || rc=0
                                               want_refused "NT1 with neither tool, a commit through the stub is refused" $rc "$out" "REFUSING"
                                               refused_for "NT1b and the refusal names both tools" $rc "$out" "$NOTOOL"
out=$(hp "$NOSHA" git push -q origin main); rc=$?; [[ "$(git -C "$SPR" rev-parse main)" == "$rem0" ]] || rc=0
                                               want_refused "NT2 with neither tool, a push through the stub is refused, and the remote doesn't move" $rc "$out" "REFUSING"
                                               refused_for "NT2b and the refusal names both tools" $rc "$out" "$NOTOOL"
out=$(hp "$NOSHA" "$KP" check); rc=$?;         want_refused "NT3 with neither tool, kit-pin check refuses" $rc "$out" "REFUSING"
                                               refused_for "NT3b and names both tools" $rc "$out" "$NOTOOL"
out=$( (cd "$K" && KIT_INSTALL_ROOT="$TMP/releases-nosha" PATH="$NOSHA" "$IRK" v1.0.0) 2>&1 ); rc=$?
[[ -z "$(ls -A "$TMP/releases-nosha" 2>/dev/null)" ]] || rc=0
                                               want_refused "NT4 with neither tool, install-release refuses and leaves nothing" $rc "$out" "REFUSING"
                                               refused_for "NT4b and names both tools" $rc "$out" "$NOTOOL"
git -C "$SP" cat-file -e :leak-detection/scan-tree.sh 2>/dev/null; held=$?
out=$(hp "$NOSHA" env KIT_INSTALL="$I2" "$I2/leak-detection/check-copies.sh" copies); rc=$?; (( held == 0 )) || rc=0
                                               want_refused "NT5 with neither tool, the checked-copies layer refuses a spawn holding a kit-owned copy" $rc "$out" "REFUSING"
                                               refused_for "NT5b and names both tools" $rc "$out" "$NOTOOL"
if inpath "$SHAONLY" shasum; then
    out=$(hp "$SHAONLY" git commit -q -m k); rc=$?; [[ "$(git -C "$SP" rev-parse HEAD)" != "$head0" ]] || rc=1
                                               want_ok "SH1 with shasum and no sha256sum, a clean commit passes through the stub" $rc "$out"
    out=$(hp "$SHAONLY" git push -q origin main); rc=$?; [[ "$(git -C "$SPR" rev-parse main)" == "$(git -C "$SP" rev-parse HEAD)" ]] || rc=1
                                               want_ok "SH2 and a push through the stub reaches the spawn's remote" $rc "$out"
    out=$(hp "$SHAONLY" "$KP" check); rc=$?;   want_ok "SH3 and kit-pin check passes" $rc "$out" "check passed"
    out=$( (cd "$K" && KIT_INSTALL_ROOT="$TMP/releases-shasum" PATH="$SHAONLY" "$IRK" v1.0.0) 2>&1 ); rc=$?
    cmp -s "$TMP/releases-shasum/v1.0.0/MANIFEST.sha256" "$PRISTINE/MANIFEST.sha256" || rc=1
                                               want_ok "SH4 and install-release installs, its manifest byte for byte the one sha256sum wrote" $rc "$out" "installed v1.0.0"
    out=$(hp "$SHAONLY" env KIT_INSTALL="$I2" "$I2/leak-detection/check-copies.sh" copies); rc=$?; (( held == 0 )) || rc=1
                                               want_ok "SH5 and the checked-copies layer passes a kit-owned copy equal to the release's" $rc "$out"
else
    for c in SH1 SH2 SH3 SH4 SH5; do skip "$c" "shasum is not installed here"; done
fi

# ============================== kit-pin and the git it needs ====================================
# kit-pin needs git 2.31 or later, as the hooks do: below it git echoes --path-format back as output, so to failed at
# mkdir on a folder named after the option, with no reason given (decisions log §290, §296; the stand-in container's
# old-git condition). A git that old, or one whose version can't be read, is refused by name before anything changes;
# verify reads no git, so it still runs. gitver DIR VERSION: a git that reports VERSION and is otherwise the real one.
gitver() { mkdir -p "$1"; { printf '#!/bin/sh\ncase "$1" in --version|version) echo "git version %s"; exit 0 ;; esac\n' "$2"
                            printf 'exec "%s" "$@"\n' "$(command -v git)"; } > "$1/git"; chmod 0755 "$1/git"; }
gitver "$TMP/git-old" 2.30.2; gitver "$TMP/git-odd" banana
out=$(PATH="$TMP/git-old:$PATH" "$KP" verify v1.0.1 "$H2" 2>&1)
                                               want_ok "KG0 kit-pin verify, which reads no git, still passes under a git older than 2.31" $? "$out" "verify passed"
OGK="$TMP/old-git-spawn"; mkorg "$OGK"
out=$( (cd "$OGK" && PATH="$TMP/git-old:$PATH" "$KP" to v1.0.0) 2>&1 ); rc=$?
[[ ! -e "$OGK/kit.pin" && ! -e "$OGK/.git/hooks/pre-commit" && ! -e "$OGK/.git/hooks/pre-push" \
   && -z "$(find "$OGK" -maxdepth 1 -name '--*' 2>/dev/null)" && -z "$(git -C "$OGK" status --porcelain)" ]] || rc=0
                                               refused_for "KG1 kit-pin to under a git older than 2.31 refuses, naming both versions, and changes nothing" $rc "$out" "git 2.30.2 is older than 2.31"
out=$( (cd "$SP" && PATH="$TMP/git-old:$PATH" "$KP" check) 2>&1 ); rc=$?
                                               refused_for "KG2 kit-pin check under a git older than 2.31 refuses, naming both versions" $rc "$out" "git 2.30.2 is older than 2.31"
out=$( (cd "$SP" && PATH="$TMP/git-odd:$PATH" "$KP" check) 2>&1 ); rc=$?
                                               refused_for "KG3 kit-pin under a git whose version can't be read refuses" $rc "$out" "could not read git's version"

# ============================== the checked-copies layer, read directly, and under bash 3 =========
# macOS's /bin/bash is 3.2. KIT_TEST_BASH3 names a bash 3 binary to run the layer under (a test tool, never a kit
# dependency); without it the V3 cases are skipped, counted. The spawn as it stands holds the release's ci/ variants,
# a declared fork and scan-tree.sh, so a pass reads all three of the layer's tables.
cc() { (cd "$SP" && env KIT_INSTALL="$I2" ${1:+"$1"} "$I2/leak-detection/check-copies.sh" copies) 2>&1; }   # [BASH]
B3=${KIT_TEST_BASH3:-}; b3why=""
if [[ -z "$B3" ]]; then b3why="KIT_TEST_BASH3 is not set"
elif [[ "$("$B3" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)" != 3 ]]; then b3why="KIT_TEST_BASH3 is not a bash 3"; fi
v3() { if [[ -n "$b3why" ]]; then skip "$1" "$b3why"; return 1; fi; }    # NAME: 0 when the case can run
putback() { git -C "$SP" checkout -q HEAD -- "$@"; }
out=$(cc); rc=$?;                              want_ok "CC9 read directly, the spawn as it stands passes the checked-copies layer" $rc "$out"
# The code patterns are examples (R6, decisions log §274 ruling 6): the manifest classes them example, which the layer
# doesn't police, so a project's edited copy of one passes, while an owned file's edited copy still refuses.
mkdir -p "$SP/patterns"; { cat "$I2/patterns/atomic_deploy.sh"; echo "# the project's own edit"; } > "$SP/patterns/atomic_deploy.sh"
git -C "$SP" add patterns/atomic_deploy.sh
out=$(cc); rc=$?;                              want_ok "EX2 a project's edited copy of a code pattern passes the checked-copies layer" $rc "$out"
echo "# a local edit" >> "$SP/leak-detection/scan-tree.sh"; git -C "$SP" add leak-detection/scan-tree.sh
out=$(cc); rc=$?;                              refused_for "EX1 beside it, an owned file's edited copy still refuses, naming it" $rc "$out" "leak-detection/scan-tree.sh: differs from release v1.0.1, and kit.forks doesn't declare it"
putback leak-detection/scan-tree.sh; git -C "$SP" rm -q --cached patterns/atomic_deploy.sh; rm -f "$SP/patterns/atomic_deploy.sh"
v3 V31 && { out=$(cc "$B3"); rc=$?;            want_ok "V31 under bash 3, the spawn as it stands passes the checked-copies layer" $rc "$out"; }
echo "# a local edit" >> "$SP/leak-detection/scan-tree.sh"; git -C "$SP" add leak-detection/scan-tree.sh
v3 V32 && { out=$(cc "$B3"); rc=$?;            refused_for "V32 under bash 3, a changed kit-owned copy refuses, naming it" $rc "$out" "leak-detection/scan-tree.sh: differs from release v1.0.1, and kit.forks doesn't declare it"; }
putback leak-detection/scan-tree.sh
install -m 0644 "$I2/.github/workflows/leak-scan.yml" "$SP/.github/workflows/leak-scan.yml" 2>/dev/null; git -C "$SP" add .github
v3 V33 && { out=$(cc "$B3"); rc=$?;            refused_for "V33 under bash 3, the kit's own workflow refuses, naming the variant it is held to" $rc "$out" ".github/workflows/leak-scan.yml: is the kit's own file; a project's copy is ci/leak-scan.yml"; }
putback .github/workflows/leak-scan.yml
echo "# another step" >> "$SP/.github/workflows/gitleaks.yml"; git -C "$SP" add .github
v3 V34 && { out=$(cc "$B3"); rc=$?;            refused_for "V34 under bash 3, a declared fork whose hash differs refuses" $rc "$out" ".github/workflows/gitleaks.yml: declared in kit.forks with another hash"; }
putback .github/workflows/gitleaks.yml
# A copy git lists but can't read: its loose object corrupted, so cat-file -e still finds it and git show fails.
oid=$(git -C "$SP" rev-parse :leak-detection/scan-tree.sh 2>/dev/null); obj="$SP/.git/objects/${oid:0:2}/${oid:2}"
[[ -n "$oid" && -f "$obj" ]] && chmod u+w "$obj" && printf 'not an object' > "$obj"
out=$(cc); rc=$?; [[ -f "$obj" ]] || rc=0;     refused_for "CC8 a kit-owned copy that can't be read refuses" $rc "$out" "leak-detection/scan-tree.sh could not be read"
v3 V35 && { out=$(cc "$B3"); rc=$?;            refused_for "V35 under bash 3, a kit-owned copy that can't be read refuses" $rc "$out" "leak-detection/scan-tree.sh could not be read"; }
[[ -n "$oid" ]] && { rm -f "$obj"; git -C "$SP" hash-object -w "$SP/leak-detection/scan-tree.sh" >/dev/null; }

# ============================== the stubs beside an org's hooks, under bash 3 =====================
# The stub's chain (an org's hook run first with git's arguments and standard input, then a project's kept hook, then
# the release's checks) under the bash 3 KIT_TEST_BASH3 names, as a stock Mac's /bin/bash runs the stub; no Mac case
# set an org's hooks path before (decisions log §304's macOS run). Each runs the stub as git does, from the top of the
# work tree; the release hook it hands over to runs under the bash on PATH. o3 HOOK [ARG...]: in the system-path
# project; p3: the kept hook's project.
o3() { (cd "$OS" && env -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$SYSCFG" "$B3" "$OS/.git/hooks/$1" "${@:2}") 2>&1; }
p3() { (cd "$OP" && "$B3" "$OP/.git/hooks/pre-commit") 2>&1; }
echo 1 > "$IT/exit"; : > "$IT/ran"; ostage b3a
v3 HB1 && { out=$(o3 pre-commit); rc=$?
            grep -q 'pre-commit ran' "$IT/ran" || rc=0
                                               refused_for "HB1 under bash 3, the org's hook refusing refuses the commit, through the stub" $rc "$out" "refused (exit 1)"; }
echo 0 > "$IT/exit"; : > "$IT/ran"
v3 HB2 && { out=$(o3 pre-commit); rc=$?
            grep -q "pre-commit ran in $OS\$" "$IT/ran" || rc=1
                                               want_ok "HB2 under bash 3, the org's hook passing, a clean commit's check passes, the org's hook run from the top" $rc "$out" "scanned"; }
git -C "$OS" reset -q; git -C "$OS" checkout -q -- . 2>/dev/null
cp "$ROOT/leak-detection/fixtures/synthetic_config.txt" "$OS/config.local.txt"; git -C "$OS" add config.local.txt; : > "$IT/ran"
v3 HB3 && { out=$(o3 pre-commit); rc=$?
            grep -q 'pre-commit ran' "$IT/ran" || rc=0
                                               want_refused "HB3 under bash 3, the org's hook passing, a staged credential is still refused by the kit" $rc "$out" "credential shapes"; }
git -C "$OS" reset -q; rm -f "$OS/config.local.txt"; : > "$IT/ran"
ob3=$(git -C "$OS" rev-parse HEAD); rb3=$(git -C "$OS.git" rev-parse refs/heads/main)
v3 HB4 && { out=$(printf 'refs/heads/main %s refs/heads/main %s\n' "$ob3" "$rb3" | o3 pre-push origin "$OS.git"); rc=$?
            grep -q '^stdin: refs/heads/main ' "$IT/ran" || rc=1
                                               want_ok "HB4 under bash 3, a push passes, the org's hook given git's ref lines and the kit's pre-push after it" $rc "$out" "metadata scan"; }
echo 1 > "$TMP/own-exit"; echo b3 >> "$OP/notes.txt"; git -C "$OP" add notes.txt; : > "$TMP/own-ran"
v3 HB5 && { out=$(p3); rc=$?
            grep -q 'project pre-commit ran' "$TMP/own-ran" || rc=0
                                               refused_for "HB5 under bash 3, the kept project hook runs first, and its refusal refuses the commit" $rc "$out" "refused (exit 1)"; }
echo 0 > "$TMP/own-exit"; chmod a-x "$OP/.git/hooks/pre-commit.project"
v3 HB6 && { out=$(p3); rc=$?;                  refused_for "HB6 under bash 3, a kept hook that has lost its execute bit refuses, naming it" $rc "$out" "$OP/.git/hooks/pre-commit.project"; }
chmod u+x "$OP/.git/hooks/pre-commit.project"; git -C "$OP" reset -q; git -C "$OP" checkout -q -- .

# ============================== install-release: the rename, and under bash 3 =====================
# The staged install becomes the target in one rename, which fails rather than putting the install inside anything
# that has appeared at the target since the check: v8.0.0's stand-in suite makes such a thing. install-release runs
# under bash 3.2 too, and moves the install with python3, so it refuses at once when python3 can't run.
ird() { local r=$1; shift; (cd "$K" && KIT_INSTALL_ROOT="$r" "$@") 2>&1; }      # INSTALL-ROOT CMD...
appeared_only() {  # INSTALL-ROOT: 0 when the root holds v8.0.0 alone, holding only what the stand-in made
    [[ "$(ls -A "$1" 2>/dev/null)" == v8.0.0 && "$(find "$1/v8.0.0" -mindepth 1 2>/dev/null)" == "$1/v8.0.0/appeared" ]]; }
out=$(ird "$TMP/releases-appear" "$IRK" v8.0.0); rc=$?; appeared_only "$TMP/releases-appear" || rc=0
                                               refused_for "IR10 something at the target by rename time refuses, and nothing goes inside it" $rc "$out" "could not move the staged install into place"
NOPY="$TMP/path-nopy"; pathless "$NOPY" python3
out=$( (cd "$K" && KIT_INSTALL_ROOT="$TMP/releases-nopy" PATH="$NOPY" "$IRK" v1.0.0) 2>&1 ); rc=$?
[[ -z "$(ls -A "$TMP/releases-nopy" 2>/dev/null)" ]] || rc=0
                                               refused_for "IR11 install-release refuses at once when python3 can't run, and leaves nothing" $rc "$out" "python3"
# python3 runs isolated (-I) at both of install-release's launches, so a module the caller's environment plants runs at
# neither (decisions log §147): the check that python3 can run, before anything is built (IR13), and the rename that
# moves the staged install into place, after its hook suite passed (IR14). The plant, a sitecustomize on PYTHONPATH,
# writes a line for each launch it runs in, giving that launch's argument count (1 at the check, 3 at the rename; ?
# where it can't tell, which counts against both), and at the rename edits the staged install's RELEASE, as a module
# planted there could edit any file the suite had just cleared.
mkdir -p "$TMP/plant"; cat > "$TMP/plant/sitecustomize.py" <<'PY'
import os, sys
n = len(sys.argv) if getattr(sys, "argv", None) else "?"
with open(os.environ["ZQ_PLANT_LOG"], "a") as f:
    f.write("argc=%s\n" % n)
if n == 3:
    p = os.path.join(sys.argv[1], "RELEASE")
    os.chmod(p, 0o644)
    with open(p, "a") as f:
        f.write("planted=1\n")
PY
out=$( (cd "$K" && env KIT_INSTALL_ROOT="$TMP/releases-plant" PYTHONPATH="$TMP/plant" ZQ_PLANT_LOG="$TMP/plant.log" "$IRK" v1.0.0) 2>&1 ); rc=$?
log=$(cat "$TMP/plant.log" 2>/dev/null); IP="$TMP/releases-plant/v1.0.0"
[[ $rc -eq 0 && "$out" == *"installed v1.0.0"* ]] && ! grep -qxE 'argc=(1|\?)' <<<"$log"
                                               want_ok "IR13 install-release's check that python3 can run runs no module planted on PYTHONPATH" $? "exit $rc; the plant ran at: [$(echo $log)]: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-120)"
[[ $rc -eq 0 && "$out" == *"installed v1.0.0"* ]] && ! grep -qxE 'argc=(3|\?)' <<<"$log" \
    && (cd "$IP" 2>/dev/null && sha256sum --quiet --strict -c MANIFEST.sha256 >/dev/null 2>&1)
                                               want_ok "IR14 install-release's rename runs no module planted on PYTHONPATH, so the install it leaves is the one its suite cleared" $? "exit $rc; the plant ran at: [$(echo $log)]; RELEASE: $(grep -c . "$IP/RELEASE" 2>/dev/null) line(s)"

# ============================== no shipped file starts python without -I ========================
# A python launch the caller's environment can reach runs whatever module that environment plants (PY1, PY2, LS13, IR13,
# IR14). So no file the release ships starts python without -I, but those this allowlist names, each with its reason
# (decisions log §147). A launch is python, python3 or python3.N at a word's start, then an argument starting with -, a
# quote, $ or /, on a line that isn't a comment, in a script (a .sh, .py, .yml or .yaml file, or one whose first line
# starts #!); and any #! line naming python. Its first argument must be -I, but for --version, which prints and runs no
# code (measured, §147). An entry names the file and how the launch's arguments start (#! for a first line); an entry
# that matches no launch fails too, so the list can't outlive its lines. The files are those the manifest of the v2.0.0
# install lists, ROOT's staged tree (IR9).
PL_ALLOW=(
    ".github/workflows/cross-platform.yml|-c 'print(\"x\")'|Windows' facts step, informational: it never fails the job"
    ".github/workflows/cross-platform.yml|-c 'import sys'|the same step: how python3 starts from a folder of links"
    ".github/workflows/cross-platform.yml|\"\$@\"|a shim to Windows' python, which hands on its caller's arguments, -I among them"
    "tests/hooks_test.sh|-c 'import site, sys;|PY2's precondition: asks the hook's python3, run as v0.9.0's hook ran it, whether its user site is on"
    "bin/kit-load-check|#!|nothing starts it by its path: the stub hands it to an isolated python3"
    "leak-detection/scan-binaries.py|#!|nothing starts it by its path: pre-push hands it to an isolated python3"
    "patterns/counted_skip_loader.py|#!|a pattern a project copies; the kit never runs it"
)
pl_scan() {  # DIR: "PATH|LINE|ARGS" for each launch without -I in the files DIR/MANIFEST.sha256 lists; ARGS is #! for a first line
    local dir=$1 sum path hit n text rest arg re='(^|[^A-Za-z0-9_./-])python(3(\.[0-9]+)?)?[[:space:]]+([^[:space:]].*)$'
    local isolated='[[:space:]]-I([[:space:]]|$)' comment='^[[:space:]]*#'
    while read -r sum path; do
        case "$path" in *.sh|*.py|*.yml|*.yaml) ;; *) [[ "$(head -c 2 "$dir/$path" 2>/dev/null)" == '#!' ]] || continue ;; esac
        while IFS= read -r hit; do
            n=${hit%%:*}; text=${hit#*:}
            if [[ $n == 1 && "$text" == '#!'* ]]; then
                [[ "$text" =~ $isolated ]] || printf '%s|%s|#!\n' "$path" "$n"; continue
            fi
            [[ "$text" =~ $comment ]] && continue
            rest=$text
            while [[ "$rest" =~ $re ]]; do
                rest=${BASH_REMATCH[4]}; arg=${rest%%[[:space:]]*}
                case "$arg" in
                    -I|--version) ;;
                    -*|\"*|\'*|\$*|/*) printf '%s|%s|%s\n' "$path" "$n" "$rest"; break ;;
                esac
            done
        done < <(LC_ALL=C grep -n -a 'python' "$dir/$path" 2>/dev/null)
    done < "$dir/MANIFEST.sha256"
}
pl_check() {  # DIR: prints each launch no entry names, and each entry that names none; 0 when there are neither
    local found entry e_path e_args hit h_path h_args bad="" used
    found=$(pl_scan "$1")
    while IFS= read -r hit; do
        [[ -n "$hit" ]] || continue
        h_path=${hit%%|*}; h_args=${hit#*|}; h_args=${h_args#*|}; used=""
        for entry in "${PL_ALLOW[@]}"; do
            e_path=${entry%%|*}; e_args=${entry#*|}; e_args=${e_args%%|*}
            [[ "$h_path" == "$e_path" && "$h_args" == "$e_args"* ]] && { used=1; break; }
        done
        [[ -n "$used" ]] || bad+="  $h_path:$(h=${hit#*|}; echo "${h%%|*}") starts it with: $h_args"$'\n'
    done <<<"$found"
    for entry in "${PL_ALLOW[@]}"; do
        e_path=${entry%%|*}; e_args=${entry#*|}; e_args=${e_args%%|*}; used=""
        while IFS= read -r hit; do
            h_path=${hit%%|*}; h_args=${hit#*|}; h_args=${h_args#*|}
            [[ -n "$hit" && "$h_path" == "$e_path" && "$h_args" == "$e_args"* ]] && { used=1; break; }
        done <<<"$found"
        [[ -n "$used" ]] || bad+="  an allowlist entry matches no launch: $e_path, $e_args"$'\n'
    done
    printf '%s' "$bad"; [[ -z "$bad" ]]
}
# PL0, its control: a scratch install whose one script holds a launch with -I, one without, one by --version, a comment
# and a #! line; only the second and the #! line are found. The script is written through %s, so this line is no
# launch the scan would find.
PLC="$TMP/pl-control"; mkdir -p "$PLC"; pc=python3
printf '#!/usr/bin/env %s\nx=$(%s -I -c "1")\ny=$(%s -c "1")\n%s --version\n# %s -c "a comment"\n' "$pc" "$pc" "$pc" "$pc" "$pc" > "$PLC/s.sh"
printf '0  s.sh\n' > "$PLC/MANIFEST.sha256"
got=$(pl_scan "$PLC" | cut -d'|' -f1,3)
[[ "$got" == "s.sh|#!"$'\n''s.sh|-c "1")' ]]
                                               want_ok "PL0 the launch scan finds a launch without -I and a #! line, and passes -I, --version and a comment" $? "found: [$(echo $got)]"
IV2="$KIT_INSTALL_ROOT/v2.0.0"
if [[ -s "$IV2/MANIFEST.sha256" ]]; then
    bad=$(pl_check "$IV2"); rc=$?
                                               want_ok "PL1 no file the release ships starts python without -I, but those its allowlist names" $rc "$(printf '%s' "$bad" | tr '\n' ' ' | cut -c1-600)"
else
    result "PL1 no file the release ships starts python without -I, but those its allowlist names" 1 "no v2.0.0 install to read (IR9)"
fi

# ============================== every grep call in a shipped file follows the gates' rule ===================
# BSD grep (a Mac's /usr/bin/grep) in a UTF-8 locale doesn't match ASCII text on a line holding invalid UTF-8, where GNU
# grep does (decisions log §155). The gates' rule (§157): a grep over content that could hold a term or invalid bytes
# runs twice, under LC_ALL=C and in the caller's locale, and a match in either counts; in pre-push that is
# list_matches. Every other call in a file the release ships is named below with its reason, so a new one fails until
# someone decides which it is (§156). A call is the word at a command's start: after a line's start, ; & | ! { ( `,
# $( or <(, or a shell keyword, behind any VAR=value words, command, env, exec, nice or ionice, and a path; git's own
# grep counts, and in a python file the word quoted as a string. Lines that are comments, and the lines of an
# allowlist like this one (NAME_ALLOW=( to its closing line), which are data, are skipped; a message naming the tool
# is found too and named as one. An entry names the file, how many calls it covers and how they start; a hit
# takes the entry with the longest start, and an entry whose count is off fails, so the list can't outlive its lines or
# hide a copy. The files are those the manifest of the v2.0.0 install lists (IR9), as PL1 reads them, but the gates LG1
# holds to the locale rule (below), whose every grep call LG_MATCH_ALLOW names instead, with the locale it runs in.
GP_ALLOW=(
    ".github/workflows/cross-platform.yml|1|grep -E ' on /(tmp)? '|a fact line for the CI log, over mount's output; it decides nothing"
    "bin/kit-load-check-stub|1|grep -E '^<!-- kit pin:'|the pin line, ASCII by its format: a miss refuses (no kit pin line), and BSD grep misses only a line that itself holds invalid UTF-8 (GF8), which the format refuses anyway"
    "tests/hooks_test.sh|1|grep -qE \"\$own\"|LP0, over the kit's own scripts, which hold no term and no invalid UTF-8 (§145 step 3(b))"
    "tests/hooks_test.sh|2|grep -q 'read-leak-pattern\\.sh'|LP0, over the kit's own scripts"
    "tests/hooks_test.sh|1|grep -c 'REFUSING'|an ASCII word over the hooks' own messages, each on a line of its own"
    "tests/hooks_test.sh|1|grep -F -- \"  \$f: \"|the binary scan's own refusal lines, for the suite's synthetic file names"
    "tests/hooks_test.sh|2|grep -a -i -x -E '|locale -a's names"
    "tests/hooks_test.sh|1|grep -qE \"\\\"RuleID\\\"|gitleaks' own JSON report"
    "tests/hooks_test.sh|1|grep -oE '\"RuleID\"|gitleaks' own JSON report"
    "tests/install_test.sh|1|grep -c 'REFUSING'|an ASCII word over the kit's own messages"
    "tests/install_test.sh|1|grep -qE 'sha256sum|the install's own scripts"
    "tests/install_test.sh|1|grep -m 1 '^[<>]'|a diff of two of git's file listings, for a failure message"
    "tests/install_test.sh|1|grep -q '^owned  |the install's CLASSES file, which install-release writes"
    "tests/install_test.sh|1|grep -q '^spawn  |the install's CLASSES file"
    "tests/install_test.sh|1|grep -q PLANTED|the installed copy of the kit's own file"
    "tests/install_test.sh|1|grep -a PY2|names a line of the suite's output, for a failure message"
    "tests/install_test.sh|1|grep -qF -- \"--config .gitleaks.toml\"|the stand-in gitleaks' argument log"
    "tests/install_test.sh|2|grep -vE '^[[:space:]]*(#|the kit's own gitleaks configs"
    "tests/install_test.sh|1|grep -v 'leak-detection/fixtures/synthetic_config'|the kit's own gitleaks config"
    "tests/install_test.sh|1|grep -q 'synthetic_config'|the kit's own gitleaks config"
    "tests/install_test.sh|2|grep -qxE 'argc=(|the plant's own log"
    "tests/install_test.sh|1|grep -c . \"\$IP/RELEASE\"|a failure message's count"
    "tests/install_test.sh|1|LC_ALL=C grep -n -a 'python'|PL1's scan, over every shipped file: an ASCII word and no -i, so LC_ALL=C alone sees it on a line holding invalid UTF-8 (GF), and the caller's locale adds nothing"
    "tests/install_test.sh|1|LC_ALL=C grep -q \"\$CR\"|LE1, over every script: one ASCII byte, so LC_ALL=C alone sees it, as PL1's scan"
    "tests/install_test.sh|5|grep -q 'pre-commit ran'|the suite's own stand-in org hook's marker file (HO, HG, HB1, HB3)"
    "tests/install_test.sh|2|grep -q \"pre-commit ran in|the stand-in org hook's marker file (HO4, HB2)"
    "tests/install_test.sh|3|grep -q '^stdin: refs/heads/main '|the stand-in org hook's marker file (HO5, HG3, HB4)"
    "tests/install_test.sh|3|grep -q 'project pre-commit ran'|the stand-in project hook's marker file (HP2, HX2, HB5)"
    "tests/install_test.sh|1|grep -q -E \"\$PC_REL\"|PC's look for a bin/kit-pin named by a relative path, over the kit's own messages, which are ASCII"
    "tests/install_test.sh|1|grep -m1 -E \"\$PC_REL\"|the same, for its failure message"
    "tests/load_check_test.sh|1|grep -oE 'kc-[0-9a-f]{16}'|load canaries, ASCII by their format, in the install's own skill files"
    "tests/load_check_test.sh|2|grep -ohE 'kc-[0-9a-f]{16}'|load canaries in the stand-in probe's answer files"
    "tests/load_check_test.sh|1|grep '^fail: '|the load check's own report"
    "tests/load_check_test.sh|1|grep -qE \"kc-[0-9a-f]{16}\"|the load check's own report"
    "tests/load_check_test.sh|1|grep -qF \"\$TMP\"|the load check's own report"
    "tests/load_check_test.sh|1|grep -qx HOME|names from the stand-in probe's environment"
    "tests/load_check_test.sh|1|grep -qx KIT_LOAD_PROBE|names from the stand-in probe's environment"
    "tests/load_check_test.sh|1|grep -qx KIT_LOAD_CHECK_PING|names from the stand-in probe's environment"
    "tests/load_check_test.sh|1|grep -q 'zq-check'|the stand-in probe's environment"
    "tests/load_check_test.sh|1|grep -c . <<<\"\$names\"|names from the stand-in probe's environment, for a failure message"
    "tests/load_check_test.sh|1|grep -cx KIT_LOAD_CHECK_PING|names from the stand-in probe's environment, for a failure message"
    "tests/load_check_test.sh|2|grep -c 'REFUSING'|an ASCII word over the load check's own messages"
    "tests/load_check_test.sh|1|grep -v 'kit pin:'|edits the suite's own fixture"
    "tests/load_check_test.sh|1|grep -q 'https://ping.invalid/zq-test/fail'|the stand-in curl's argument log"
    "tests/load_check_test.sh|1|grep -q 'zq-test'|the load check's own output"
    "tools/install-release.sh|1|grep '^FAIL '|names failing cases in a refusal; the suite's exit status decides (line 118)"
)
gp_lint() {  # DIR [ENTRY...]: with no entry, "PATH|LINE|CALL" for each call in the scripts DIR/MANIFEST.sha256 lists;
             # with entries, each call no entry names and each entry whose count is off; 0 when there are neither
    python3 -I - "$@" <<'PY'
import re, sys
W = "gr" + "ep"   # the tool's name is built, never written, so this program holds no call the scan would find
d, entries = sys.argv[1], [e for e in sys.argv[2:] if not e.startswith("skip=")]
skips = {e[len("skip="):] for e in sys.argv[2:] if e.startswith("skip=")}   # files LG1 holds instead
SEP = r"(?:^|[;&|!{(`]|\$\(|<\(|\b(?:then|do|else|if|elif|while|until|time)\b)"
PRE = (r"[ \t]*((?:[A-Za-z_][A-Za-z0-9_]*=[^ \t()]*[ \t]+)*"
       r"(?:(?:command|env|exec|nice[ \t]+-n[ \t]*-?[0-9]+|ionice[ \t]+-c[ \t]*[0-9])[ \t]+)*"
       r"(?:[^ \t;|&()]*/)?(?:git(?:[ \t]+-[cC][ \t]+[^ \t]+)*[ \t]+)?" + W + r")(?=[ \t]|$)")
SH, PY = re.compile(SEP + PRE), re.compile("[\"']" + W + "[\"']")
hits = []
for row in open(d + "/MANIFEST.sha256", "rb").read().decode("utf-8", "surrogateescape").splitlines():
    if not row.strip():
        continue
    path = row.split(None, 1)[1]
    if path in skips:
        continue
    try:
        raw = open(d + "/" + path, "rb").read()
    except OSError as e:
        hits.append((path, 0, "UNREADABLE " + e.__class__.__name__))
        continue
    if not (path.endswith((".sh", ".py", ".yml", ".yaml")) or raw[:2] == b"#!"):
        continue
    py = path.endswith(".py") or b"python" in raw.split(b"\n", 1)[0]
    data = False
    for n, line in enumerate(raw.decode("utf-8", "surrogateescape").split("\n"), 1):
        if not py and re.match(r"[A-Z][A-Z0-9_]*_ALLOW=\($", line):
            data = True
        if data:
            data = line != ")"
            continue
        if re.match(r"[ \t]*#", line):
            continue
        if py:
            if PY.search(line):
                hits.append((path, n, line.strip()))
        else:
            hits.extend((path, n, line[m.start(1):].rstrip()) for m in SH.finditer(line))
if not entries:
    for h in hits:
        print("%s|%d|%s" % h)
    sys.exit(0)
allow = [e.split("|", 3) for e in entries]
used, bad = [0] * len(allow), []
for path, n, call in hits:
    best = None
    for i, (p, c, start, why) in enumerate(allow):
        if p == path and call.startswith(start) and (best is None or len(start) > len(allow[best][2])):
            best = i
    if best is None:
        bad.append("  %s:%d calls %s outside the gates' rule, and no entry names it: %s" % (path, n, W, call[:100]))
    else:
        used[best] += 1
for (p, c, start, why), u in zip(allow, used):
    if str(u) != c:
        bad.append("  an entry names %s call(s) in %s starting %s, and %d match" % (c, p, start, u))
sys.stdout.write("".join(b + "\n" for b in bad))
sys.exit(1 if bad else 0)
PY
}
# GP0, its control: a scratch install whose script holds a call outside the rule, one in a comment, one under
# LC_ALL=C, one by git and one through a helper, and whose python file holds one; all but the comment and the helper
# are found. GP0b: the check names each call no entry covers and each entry whose count is off. Written through %s, so
# no line here is a call the scan would find.
GPC="$TMP/gp-control"; mkdir -p "$GPC"; g=gr; g=${g}ep
printf 'x=$(printf a | %s -q b)\n# %s -q c\ny=$(LC_ALL=C %s -c z f)\ngit %s -n q\nlist_matches "$t"\n' "$g" "$g" "$g" "$g" > "$GPC/s.sh"
printf 'r = run(["git", "%s", "-q"])\n' "$g" > "$GPC/p.py"
printf '0  s.sh\n0  p.py\n' > "$GPC/MANIFEST.sha256"
got=$(gp_lint "$GPC" | cut -d'|' -f1,2)
[[ "$got" == "s.sh|1"$'\n''s.sh|3'$'\n''s.sh|4'$'\n''p.py|1' ]]
                                               want_ok "GP0 the call scan finds a call, one under LC_ALL=C, one by git and one in python, and passes a comment and a helper" $? "found: [$(echo $got)]"
out=$(gp_lint "$GPC" "s.sh|1|LC_ALL=C $g -c z|a control" "p.py|2|r = run|a control" "s.sh|1|$g -n|a control"); rc=$?
[[ $rc -ne 0 && "$out" == *"s.sh:1 calls"* && "$out" == *"s.sh:4 calls"* && "$out" != *"s.sh:3 calls"* \
   && "$out" == *"names 2 call(s) in p.py starting r = run, and 1 match"* && "$out" == *"names 1 call(s) in s.sh starting $g -n, and 0 match"* ]]
                                               want_ok "GP0b the check names each call no entry covers, and each entry whose count is off" $? "exit $rc: $(echo $out | cut -c1-300)"
# ============================== each gate: text byte-wise, matching in the caller's locale =====================
# The locale rule (decisions log §158, §159): a gate that processes content which could hold a term runs its text tools
# byte-wise and its matchers in the locale its caller set. BSD tools in a UTF-8 locale stop on, skip or quote a line
# holding invalid UTF-8 (§150, §155, §157); a forced C locale folds only ASCII, git's matchers too (§158). So each gate
# saves the caller's locale and sets LC_ALL=C, in these two lines, before its first text tool; and every matcher in it
# (grep, git grep, git log or rev-list matching an author, a committer, a message or with -i) is named in
# LG_MATCH_ALLOW with how it starts: in the caller's locale (LC_ALL="$KIT_CALLER_LOCALE"), under LC_ALL=C, or as the gate
# runs (byte-wise), each with its reason. A matcher no entry names fails, so one added later can't lose the caller's
# locale unseen; the caller's locale used anywhere but a named matcher, or a hand-off LG_HANDOFF_ALLOW names, fails. In
# the python gate the same rule is CALLER_LOCALE and os.environ["LC_ALL"] = "C" before its first subprocess, and each
# matcher passing env=CALLER_ENV. The gates are those LG_GATE_ALLOW names; every other shipped script was read and
# named there or below with why it isn't one.
#   KIT_CALLER_LOCALE=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}
#   export LC_ALL=C
# Not gates under this rule (read): check-copies.sh hashes bytes and reads the release's RELEASE; the stub hook and the
# load check's stub read the install's own file list and the pin line; install-release.sh reads the release's own tree;
# read-leak-pattern.sh is sourced and runs under its gate's setting.
LG_GATE_ALLOW=(
    "leak-detection/pre-push|sh|the tree, the metadata, ref names, tag objects, the paths it names"
    "leak-detection/scan-tree.sh|sh|the tracked tree, in CI"
    "leak-detection/pre-commit|sh|the staged CLAUDE.md, the identity, the staged paths it lists"
    "bin/kit-pin|sh|the list itself, split into rows and hashed"
    "leak-detection/scan-binaries.py|py|a binary's bytes and UTF-16 text, and its path"
    "bin/kit-history-audit|sh|every field of a repository's history, and the control's terms"
)
LG_MATCH_ALLOW=(
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" git grep --no-color -inE \"\$LEAK_PATTERN\"|the tree scan, in the caller's locale: git's matcher sees a line holding invalid UTF-8 there (ML1 to ML4 on stock macOS) and keeps -i's folding (ML5)"
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -c -v -i -E -e \"\$ALLOW\"|the allowlist filter, in the caller's locale, as before; inverted, so a line it can't match counts as a hit"
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -v -i -E -e \"\$ALLOW\"|names the lines the filter above counted, in the same locale; the count decides"
    "leak-detection/pre-push|1|LC_ALL=C grep -a -q -i -E -e \"\$LEAK_PATTERN\"|list_matches' first pass, byte-wise, for BSD grep's miss on a line holding invalid UTF-8 (L9, MD14, MD15)"
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -q -i -E -e \"\$LEAK_PATTERN\"|list_matches' second pass, in the caller's locale, for -i's folding of a non-ASCII letter (MD19)"
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" git log --no-color --no-use-mailmap|the metadata scan, in the caller's locale (MD16, MD17, MD18)"
    "leak-detection/pre-push|1|git grep exit|message text naming the tool, not a call"
    "leak-detection/pre-push|3|grep exit|message text naming the tool, not a call"
    "leak-detection/pre-push|1|grep -v ' missing\$'|byte-wise, over object IDs from git cat-file"
    "leak-detection/pre-push|1|grep -qxF \"\$obj\"|byte-wise, over object IDs"
    "leak-detection/pre-push|3|grep -oE|byte-wise, over gitleaks' own summary lines"
    "leak-detection/scan-tree.sh|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" git grep -inE \"\$LEAK_PATTERN\"|the tree scan, in the caller's locale, as pre-push's (ML2, ML6)"
    "leak-detection/scan-tree.sh|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -c -v -i -E -e \"\$ALLOW\"|the allowlist filter, in the caller's locale, as pre-push's"
    "leak-detection/scan-tree.sh|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -v -i -E -e \"\$ALLOW\"|names the lines the filter above counted"
    "leak-detection/scan-tree.sh|1|git grep exit|message text naming the tool, not a call"
    "leak-detection/scan-tree.sh|1|grep exit|message text naming the tool, not a call"
    "leak-detection/pre-commit|1|LC_ALL=C grep -a -q -i -E -e \"\$list\"|the staged .local/ names its refusal lists, first pass, byte-wise, as pre-push's list_matches (C4d)"
    "leak-detection/pre-commit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -q -i -E -e \"\$list\"|the same names, second pass, in the caller's locale"
    "leak-detection/scan-binaries.py|1|r = subprocess.run([\"git\", \"grep\", \"--no-color\", \"--no-index\", \"-q\"|a binary's bytes and UTF-16 text, in the caller's locale (VQ's vq-mark.webm on stock macOS)"
    "leak-detection/scan-binaries.py|1|r = subprocess.run([\"git\", \"grep\", \"--no-color\", \"--no-index\", \"-n\"|the paths it names, matched in the caller's locale before any is printed (B16, B17)"
    "bin/kit-history-audit|1|LC_ALL=C grep -a -q -i -E -e \"\$LEAK_PATTERN\"|list_matches' first pass, byte-wise, as pre-push's: the list's compile check and the control's terms"
    "bin/kit-history-audit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -q -i -E -e \"\$LEAK_PATTERN\"|list_matches' second pass, in the caller's locale"
    "bin/kit-history-audit|1|LC_ALL=C git grep --no-index --no-color -a -l -i -E -e \"\$LEAK_PATTERN\"|the field files, git's engine, byte-wise, for BSD's miss on a line holding invalid UTF-8 (HA23)"
    "bin/kit-history-audit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" git grep --no-index --no-color -a -l -i -E -e \"\$LEAK_PATTERN\"|the field files, git's engine, in the caller's locale, for -i's folding of a non-ASCII letter"
    "bin/kit-history-audit|1|LC_ALL=C grep -a -l -r -i -E -e \"\$LEAK_PATTERN\"|the field files, grep's engine, byte-wise"
    "bin/kit-history-audit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -l -r -i -E -e \"\$LEAK_PATTERN\"|the field files, grep's engine, in the caller's locale"
    "bin/kit-history-audit|1|LC_ALL=C grep -a -n -i -E -e \"\$LEAK_PATTERN\"|a hit file's matching lines by number, byte-wise; the numbers, not printed lines, carry the verdict (§145 step 3, HA24)"
    "bin/kit-history-audit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" grep -a -n -i -E -e \"\$LEAK_PATTERN\"|the same lines, in the caller's locale"
)
LG_HANDOFF_ALLOW=(
    "leak-detection/pre-push|1|KIT_CALLER_LOCALE=\"\$KIT_CALLER_LOCALE\"|hands the saved locale to scan-binaries.py, which pre-push starts under LC_ALL=C"
    "leak-detection/pre-push|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" \"\$x\"|the project's own checks run in the caller's locale, as before the rule: their code is the project's"
    "leak-detection/pre-commit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" \"\$x\"|the project's own checks run in the caller's locale, as before the rule"
    "bin/kit-history-audit|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" \"\$BASH\" \"\$self\"|the control runs the audit over its throwaway repository in the caller's locale, as the caller would"
)
lg_lint() {  # DIR ARG...: gate=PATH|KIND, match=ENTRY, handoff=ENTRY; prints each break of the locale rule; 0 when none
    python3 -I - "$@" <<'PY'
import re, sys
W = "gr" + "ep"   # the tool's name is built, never written, so this program holds no call the scans would find
d = sys.argv[1]
take = lambda k: [a[len(k):].split("|", 3) for a in sys.argv[2:] if a.startswith(k)]
gates, match, hand = take("gate="), take("match="), take("handoff=")
SAVE, SET = "KIT_CALLER_LOCALE=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}", "export LC_ALL=C"
RESTORE = 'LC_ALL="$KIT_CALLER_LOCALE"'
SEP = r"(?:^|[;&|!{(`]|\$\(|<\(|\b(?:then|do|else|if|elif|while|until|time)\b)"
PRE = (r"[ \t]*((?:[A-Za-z_][A-Za-z0-9_]*=[^ \t()]*[ \t]+)*"
       r"(?:(?:command|env|exec|nice[ \t]+-n[ \t]*-?[0-9]+|ionice[ \t]+-c[ \t]*[0-9])[ \t]+)*")
GITC = r"git(?:[ \t]+-[cC][ \t]+[^ \t]+)*[ \t]+"
TOOL = re.compile(SEP + PRE + r"(?:[^ \t;|&()]*/)?(?:" + GITC + r"[a-z-]+|git|" + W +
                  r"|awk|sed|cut|tr|sort|uniq|head|tail|wc|comm|find|xargs|od|iconv|python3|gitleaks))(?=[ \t]|$)")
GREP = re.compile(SEP + PRE + r"(?:[^ \t;|&()]*/)?(?:" + GITC + r")?" + W + r")(?=[ \t]|$)")
LOG = re.compile(SEP + PRE + GITC + r"(?:log|rev-list))(?=[ \t])")
LOGOPT = re.compile(r"(?:--grep|--author|--committer)=|[ \t]-i(?=[ \t])|[ \t]-[GS]")
PYG = re.compile("[\"']" + W + "[\"']")
bad, calls = [], []
for path, kind in [(g[0], g[1]) for g in gates]:
    try:
        lines = open(d + "/" + path, "rb").read().decode("utf-8", "surrogateescape").split("\n")
    except OSError as e:
        bad.append("  %s: can't be read (%s)" % (path, e.__class__.__name__))
        continue
    code = [(n, l) for n, l in enumerate(lines, 1) if not re.match(r"[ \t]*#", l)]
    if kind == "sh":
        save = [n for n, l in code if l == SAVE]
        sets = [n for n, l in code if l == SET]
        first = next((n for n, l in code if TOOL.search(l)), None)
    else:
        save = [n for n, l in code if l.startswith("CALLER_LOCALE = ")]
        sets = [n for n, l in code if l.strip() == 'os.environ["LC_ALL"] = "C"']
        first = next((n for n, l in code if "subprocess." in l and not l.startswith("import")), None)
    if len(save) != 1 or len(sets) != 1:
        bad.append("  %s: the save line %d time(s) and the set line %d time(s), not once each" % (path, len(save), len(sets)))
    elif not (save[0] < sets[0] and (first is None or sets[0] < first)):
        bad.append("  %s: the save line (%d) and the set line (%d) don't both come before its first text tool (%s)"
                   % (path, save[0], sets[0], first))
    if kind == "sh":
        for n, l in code:
            mine = [(path, n, l[m.start(1):].rstrip()) for m in GREP.finditer(l)]
            mine += [(path, n, l[m.start(1):].rstrip()) for m in LOG.finditer(l) if LOGOPT.search(l, m.end())]
            calls += mine
            if "KIT_CALLER_LOCALE" in l and l != SAVE and not any(c[2].startswith(RESTORE) for c in mine) \
               and not any(h[0] == path and h[2] in l for h in hand):
                bad.append("  %s:%d uses the caller's locale outside a named matcher: %s" % (path, n, l.strip()[:100]))
    else:
        spans = []
        for i, (n, l) in enumerate(code):
            if PYG.search(l):
                depth, j, text = 0, i, ""
                while j < len(code):
                    text += code[j][1] + "\n"
                    depth += code[j][1].count("(") - code[j][1].count(")")
                    j += 1
                    if depth <= 0:
                        break
                spans.append((n, code[j - 1][0]))
                calls.append((path, n, l.strip()))
                if "env=CALLER_ENV" not in text:
                    bad.append("  %s:%d runs a matcher without the caller's locale (env=CALLER_ENV): %s" % (path, n, l.strip()[:100]))
        for n, l in code:
            if "CALLER_ENV" in l and not l.startswith("CALLER_ENV = ") and not any(a <= n <= b for a, b in spans):
                bad.append("  %s:%d uses the caller's locale outside a named matcher: %s" % (path, n, l.strip()[:100]))
used = [0] * len(match)
for path, n, call in calls:
    best = None
    for i, (p, c, start, why) in enumerate(match):
        if p == path and call.startswith(start) and (best is None or len(start) > len(match[best][2])):
            best = i
    if best is None:
        bad.append("  %s:%d holds a matcher no entry names: %s" % (path, n, call[:100]))
    else:
        used[best] += 1
for (p, c, start, why), u in zip(match, used):
    if str(u) != c:
        bad.append("  an entry names %s matcher(s) in %s starting %s, and %d match" % (c, p, start, u))
for p, c, sub, why in hand:
    u = sum(1 for path, kind in [(g[0], g[1]) for g in gates] if path == p
            for l in open(d + "/" + p, "rb").read().decode("utf-8", "surrogateescape").split("\n")
            if sub in l and not re.match(r"[ \t]*#", l))
    if str(u) != c:
        bad.append("  a hand-off entry names %s line(s) in %s holding %s, and %d do" % (c, p, sub, u))
sys.stdout.write("".join(b + "\n" for b in bad))
sys.exit(1 if bad else 0)
PY
}
lg_args() {  # DIR: lg_lint's arguments from the three lists
    local e; for e in "${LG_GATE_ALLOW[@]}"; do printf 'gate=%s\n' "$e"; done
    for e in "${LG_MATCH_ALLOW[@]}"; do printf 'match=%s\n' "$e"; done
    for e in "${LG_HANDOFF_ALLOW[@]}"; do printf 'handoff=%s\n' "$e"; done; }
# LG0, its control: a scratch install with a shell gate that saves and sets in time, uses the caller's locale on a named
# matcher and on a text tool, and holds an unnamed git log -i; a shell gate whose text tool comes first; and a python
# gate with one matcher passing CALLER_ENV and one not. LG0b: the lint names each break, and passes the named matcher.
# Written through %s, so no line here is a call the scans would find.
LGC="$TMP/lg-control"; mkdir -p "$LGC"; g=gr; g=${g}ep; s='KIT_CALLER_LOCALE=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}'
printf '#!/usr/bin/env bash\n%s\nexport LC_ALL=C\nx=$(printf a | LC_ALL="$KIT_CALLER_LOCALE" %s -q b)\ny=$(git log -i --format=%%h)\nz=$(LC_ALL="$KIT_CALLER_LOCALE" sort f)\n' "$s" "$g" > "$LGC/good.sh"
printf '#!/usr/bin/env bash\na=$(sed -n 1p f)\n%s\nexport LC_ALL=C\n' "$s" > "$LGC/late.sh"
printf 'import os, subprocess\nCALLER_LOCALE = "x"\nos.environ["LC_ALL"] = "C"\nr = subprocess.run(["git", "%s", "-q"],\n                   env=CALLER_ENV)\nq = subprocess.run(["git", "%s", "-c"])\n' "$g" "$g" > "$LGC/p.py"
printf '0  good.sh\n0  late.sh\n0  p.py\n' > "$LGC/MANIFEST.sha256"
out=$(lg_lint "$LGC" "gate=good.sh|sh" "gate=late.sh|sh" "gate=p.py|py" "match=good.sh|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" $g -q|a control" \
      "match=p.py|1|r = subprocess.run|a control"); rc=$?
[[ $rc -ne 0 && "$out" == *"good.sh:5 holds a matcher no entry names: git log -i"* && "$out" == *"good.sh:6 uses the caller's locale outside a named matcher"* \
   && "$out" == *"late.sh: the save line (3) and the set line (4) don't both come before its first text tool (2)"* \
   && "$out" == *"p.py:6 runs a matcher without the caller's locale"* && "$out" == *"p.py:6 holds a matcher no entry names"* \
   && "$out" != *"good.sh:4"* && "$out" != *"p.py:4"* ]]
                                               want_ok "LG0 the locale lint finds a text tool before the set line, an unnamed matcher and the caller's locale off a matcher, and passes a named one" $? "exit $rc: $(echo $out | cut -c1-400)"
out=$(lg_lint "$LGC" "gate=good.sh|sh" "match=good.sh|1|LC_ALL=\"\$KIT_CALLER_LOCALE\" $g -q|a control" "match=good.sh|1|git log -i|a control" "match=good.sh|2|sort|stale"); rc=$?
[[ $rc -ne 0 && "$out" == *"good.sh:6 uses the caller's locale"* && "$out" == *"names 2 matcher(s) in good.sh starting sort, and 0 match"* && "$out" != *"holds a matcher no entry names"* ]]
                                               want_ok "LG0b the locale lint takes named matchers, and fails an entry whose count is off" $? "exit $rc: $(echo $out | cut -c1-300)"
if [[ -s "$IV2/MANIFEST.sha256" ]]; then
    skips=(); for e in "${LG_GATE_ALLOW[@]}"; do skips+=("skip=${e%%|*}"); done
    bad=$(gp_lint "$IV2" "${GP_ALLOW[@]}" "${skips[@]}"); rc=$?
                                               want_ok "GP1 every grep call in a file the release ships follows the gates' rule, or its allowlist names it" $rc "$(printf '%s' "$bad" | tr '\n' ' ' | cut -c1-900)"
else
    result "GP1 every grep call in a file the release ships follows the gates' rule, or its allowlist names it" 1 "no v2.0.0 install to read (IR9)"
fi
if [[ -s "$IV2/MANIFEST.sha256" ]]; then
    args=(); while IFS= read -r a; do args+=("$a"); done < <(lg_args)
    bad=$(lg_lint "$IV2" "${args[@]}"); rc=$?
                                               want_ok "LG1 each gate runs its text tools byte-wise and every matcher named, in the locale its entry gives" $rc "$(printf '%s' "$bad" | tr '\n' ' ' | cut -c1-900)"
else
    result "LG1 each gate runs its text tools byte-wise and every matcher named, in the locale its entry gives" 1 "no v2.0.0 install to read (IR9)"
fi
v3 V36 && { out=$(ird "$TMP/releases-moved-b3" "$B3" "$IRK" v6.0.0); rc=$?
                                               refused_for "V36 under bash 3, install-release refuses a tag the remote has on another commit" $rc "$out" "points at another commit"; }
v3 V37 && { out=$(ird "$TMP/releases-appear-b3" "$B3" "$IRK" v8.0.0); rc=$?; appeared_only "$TMP/releases-appear-b3" || rc=0
                                               refused_for "V37 under bash 3, something at the target by rename time refuses, and nothing goes inside it" $rc "$out" "could not move the staged install into place"; }
v3 V38 && { out=$(ird "$TMP/releases-b3" "$B3" "$IRK" v1.0.0); rc=$?
            cmp -s "$TMP/releases-b3/v1.0.0/MANIFEST.sha256" "$PRISTINE/MANIFEST.sha256" || rc=1
                                               want_ok "V38 under bash 3, install-release installs, its manifest byte for byte the system bash's" $rc "$out" "installed v1.0.0"; }

# ============================== line endings =====================================================
# Where core.autocrlf is true (Git for Windows' default), a checkout writes CRLF unless .gitattributes says
# otherwise, and bash can't run a script whose lines end in CR. A script is a file whose first line starts #!, or
# whose name ends .sh or .py: the hooks, bin/kit-pin and the stubs have no extension. An install is built by
# git archive, so it is checked too.
CR=$(printf '\r')
crlf_scripts() {  # DIR: each script under DIR, as git or find lists it, that holds a CR
    local f
    { git -C "$1" ls-files 2>/dev/null || (cd "$1" && find . -type f | sed 's|^\./||'); } | while IFS= read -r f; do
        [[ -f "$1/$f" ]] || continue
        case "$f" in *.sh|*.py) ;; *) [[ "$(head -c 2 "$1/$f")" == '#!' ]] || continue ;; esac
        LC_ALL=C grep -q "$CR" "$1/$f" && echo "$f"
    done; }
CLN="$TMP/crlf-clone"; git clone -q -c core.autocrlf=true "$K" "$CLN" 2>/dev/null
n=$(git -C "$CLN" ls-files 2>/dev/null | wc -l); bad=$(crlf_scripts "$CLN")
[[ $n -gt 0 && -z "$bad" ]];                   want_ok "LE1 a clone made with core.autocrlf=true has LF in every script" $? "$n files; with CR: $(echo $bad | cut -c1-160)"
out=$( (cd "$CLN" && KIT_INSTALL_ROOT="$TMP/releases-crlf" bash tools/install-release.sh v1.0.0) 2>&1 ); rc=$?
bad=$(crlf_scripts "$TMP/releases-crlf/v1.0.0"); [[ -f "$TMP/releases-crlf/v1.0.0/MANIFEST.sha256" && -z "$bad" ]] || rc=1
                                               want_ok "LE2 and an install built from that clone has LF in every script" $rc "$out ${bad:+with CR: $(echo $bad | cut -c1-120)}" "installed v1.0.0"

# ============================== a pass only from the pass point ==================================
# The stub passes only by handing over (exec) to the release's hook, whose own pass point then decides; the
# checked-copies layer only from the pass point at its end. An EXIT trap in each turns any other exit 0 into a refusal
# (decisions log §96, §100). Copies with one line put right after their first check must refuse; the legitimate
# passes must still pass. Under the bash 3 that KIT_TEST_BASH3 names too, skipped, counted, without it.
inj() {  # SRC DST ANCHOR LINE: DST is SRC with LINE put before its first line starting ANCHOR; 0 only when one line went in
    # A missing SRC (its install refused, as on a git too old) returns 1, so the cases that need it fail by name; the
    # line count below would otherwise be an arithmetic error that stops the suite (decisions log §288, §290).
    [[ -f "$1" ]] || return 1
    mkdir -p "${2%/*}"; awk -v a="$3" -v l="$4" '!done && index($0, a) == 1 {print l; done = 1} {print}' "$1" > "$2"; chmod +x "$2"
    [[ $(( $(wc -l < "$2") - $(wc -l < "$1") )) -eq 1 ]]; }
STOPPED="stopped before it finished"
inj "$I2/leak-detection/stub-hook" "$TMP/stub-exit/pre-commit" 'top=$(git rev-parse' 'exit 0'; sx=$?
inj "$I2/leak-detection/stub-hook" "$TMP/stub-unset/pre-commit" 'top=$(git rev-parse' ': "$zq_unset_probe"'; su=$?
inj "$I2/leak-detection/check-copies.sh" "$TMP/cc-exit/check-copies.sh" 'if why=$(kit_no_sha256)' 'exit 0'; cx=$?
inj "$I2/leak-detection/check-copies.sh" "$TMP/cc-unset/check-copies.sh" 'if why=$(kit_no_sha256)' ': "$zq_unset_probe"'; cu=$?
NOK="$TMP/no-kit-owned"; git init -q "$NOK"; ident "$NOK"; echo own > "$NOK/own.txt"; git -C "$NOK" add own.txt
git -C "$NOK" commit -q --no-verify -m own
egs() { (cd "$SP" && "$1" "$2") 2>&1; }                                            # BASH STUB: as git runs it, here
egk() { (cd "${3:-$SP}" && env KIT_INSTALL="$I2" "$1" "$2" copies) 2>&1; }         # BASH COPIES-LAYER [REPO]
eg_install_run() {  # SUFFIX BASH
    local s=$1 b=$2 out rc
    note eg
    out=$(egs "$b" "$TMP/stub-exit/pre-commit"); rc=$?; (( sx == 0 )) || rc=0
    refused_for "EG10$s the stub: an exit 0 right after its first check refuses" $rc "$out" "$STOPPED"
    out=$(egs "$b" "$TMP/stub-unset/pre-commit"); rc=$?; (( su == 0 )) || rc=0
    want_refused "EG11$s the stub: an unset variable right after its first check refuses" $rc "$out" "zq_unset_probe"
    out=$(egs "$b" "$SP/.git/hooks/pre-commit")
    want_ok "EG12$s the stub: a clean commit's check still passes, handed over to the release's pre-commit" $? "$out"
    unstage
    out=$(egk "$b" "$TMP/cc-exit/check-copies.sh"); rc=$?; (( cx == 0 )) || rc=0
    refused_for "EG13$s the copies layer: an exit 0 right after its first check refuses" $rc "$out" "$STOPPED"
    out=$(egk "$b" "$TMP/cc-unset/check-copies.sh"); rc=$?; (( cu == 0 )) || rc=0
    want_refused "EG14$s the copies layer: an unset variable right after its first check refuses" $rc "$out" "zq_unset_probe"
    out=$(egk "$b" "$I2/leak-detection/check-copies.sh" "$NOK")
    want_ok "EG15$s the copies layer: a project holding no kit-owned copy still passes, with nothing to check" $? "$out"
}
eg_install_run "" bash
if [[ -z "$b3why" ]]; then eg_install_run " (bash 3)" "$B3"
else for c in EG10 EG11 EG12 EG13 EG14 EG15; do skip "$c (bash 3)" "$b3why"; done; fi

# install-release and kit-pin's check took the same guard (decisions log §105; the load check's stub is
# load_check_test's): install-release passes only from the pass point at its end, and any stop short of it removes the
# staging folder, as its refusals do; kit-pin's check passes only from the end of its check. Copies with one line put
# right after the first checks, or once the staging folder exists, must refuse; the legitimate passes must still pass.
# The install-release copies sit in the scratch kit's tools/, since it runs from the clone that holds it.
inj "$IRK" "$K/tools/eg-ir-exit.sh" '[[ "$tag" =~ ^v' 'exit 0'; irx=$?
inj "$IRK" "$K/tools/eg-ir-unset.sh" '[[ "$tag" =~ ^v' ': "$zq_unset_probe"'; iru=$?
inj "$IRK" "$K/tools/eg-ir-staged-exit.sh" 'manifest=$(git show' 'exit 0'; irsx=$?
inj "$IRK" "$K/tools/eg-ir-staged-unset.sh" 'manifest=$(git show' ': "$zq_unset_probe"'; irsu=$?
inj "$KP" "$TMP/kp-exit/kit-pin" '    in_clone; read_pin' 'exit 0'; kpx=$?
inj "$KP" "$TMP/kp-unset/kit-pin" '    in_clone; read_pin' ': "$zq_unset_probe"'; kpu=$?
egi() { local r="$TMP/releases-eg-$1"; rm -rf "${r:?}"; mkdir -p "$r"; (cd "$K" && KIT_INSTALL_ROOT="$r" "$2" "$3" v1.0.0) 2>&1; }  # ROOT-NAME BASH SCRIPT
egi_empty() { [[ -z "$(ls -A "$TMP/releases-eg-$1" 2>/dev/null)" ]]; }       # ROOT-NAME: nothing installed or staged
egk_check() { (cd "$SP" && env "${@:3}" "$1" "$2" check) 2>&1; }               # BASH KIT-PIN [ENV-CHANGE...]
eg_more_run() {  # SUFFIX BASH KEY (KEY names this run's install roots)
    local s=$1 b=$2 k=$3 out rc
    out=$(egi "exit$k" "$b" tools/eg-ir-exit.sh); rc=$?; (( irx == 0 )) && egi_empty "exit$k" || rc=0
    refused_for "EG16$s install-release: an exit 0 right after its first checks refuses, and installs nothing" $rc "$out" "$STOPPED"
    out=$(egi "unset$k" "$b" tools/eg-ir-unset.sh); rc=$?; (( iru == 0 )) && egi_empty "unset$k" || rc=0
    want_refused "EG17$s install-release: an unset variable right after its first checks refuses, and installs nothing" $rc "$out" "zq_unset_probe"
    out=$(egi "sexit$k" "$b" tools/eg-ir-staged-exit.sh); rc=$?; (( irsx == 0 )) && egi_empty "sexit$k" || rc=0
    refused_for "EG18$s install-release: an exit 0 once the staging folder exists refuses, and removes the staging folder" $rc "$out" "$STOPPED"
    out=$(egi "sunset$k" "$b" tools/eg-ir-staged-unset.sh); rc=$?; (( irsu == 0 )) && egi_empty "sunset$k" || rc=0
    want_refused "EG19$s install-release: an unset variable once the staging folder exists refuses, and removes the staging folder" $rc "$out" "zq_unset_probe"
    out=$(egi "pass$k" "$b" tools/install-release.sh); rc=$?; [[ -f "$TMP/releases-eg-pass$k/v1.0.0/MANIFEST.sha256" ]] || rc=1
    want_ok "EG20$s install-release: a clean install still passes" $rc "$out" "installed v1.0.0"
    out=$(egk_check "$b" "$TMP/kp-exit/kit-pin"); rc=$?; (( kpx == 0 )) || rc=0
    refused_for "EG21$s kit-pin check: an exit 0 right after its first check refuses" $rc "$out" "$STOPPED"
    out=$(egk_check "$b" "$TMP/kp-unset/kit-pin"); rc=$?; (( kpu == 0 )) || rc=0
    want_refused "EG22$s kit-pin check: an unset variable right after its first check refuses" $rc "$out" "zq_unset_probe"
    out=$(egk_check "$b" "$KP")
    want_ok "EG23$s kit-pin check: a pinned spawn still passes" $? "$out" "check passed"
    out=$(egk_check "$b" "$KP" -u LEAK_PATTERN); rc=$?; [[ $rc -eq 3 && "$out" == *"FAILING CLOSED"* ]] && rc=0 || rc=1
    want_ok "EG24$s kit-pin check: with no identity list it finishes with exit 3, saying the scan fails closed" $rc "$out"
}
eg_more_run "" bash b5
if [[ -z "$b3why" ]]; then eg_more_run " (bash 3)" "$B3" b3
else for c in EG16 EG17 EG18 EG19 EG20 EG21 EG22 EG23 EG24; do skip "$c (bash 3)" "$b3why"; done; fi

# kit-pin's other four modes take the same guard (decisions log §109): each passes only from its own pass point, and a
# stop short of it puts back what the mode had written, through the code its own refusals use. Copies with an exit 0
# put in once the mode has written something (verify writes nothing: after its first check) must refuse and leave the
# earlier state; each mode's own runs still pass.
inj "$KP" "$TMP/kp-vx/kit-pin" '    kit_verify_install "$ROOT_DIR/$1"' 'exit 0'; kvx=$?
inj "$KP" "$TMP/kp-tx/kit-pin" '    export KIT_INSTALL="$INST"' 'exit 0'; ktx=$?
inj "$KP" "$TMP/kp-mx/kit-pin" '    if (( had_hp )); then git config --local --unset' 'exit 0'; kmx=$?
inj "$KP" "$TMP/kp-rx/kit-pin" '        if ! kit_verify_install "$inst"' 'exit 0'; krx=$?
oldspawn() {  # DIR: an unpinned spawn that runs a hooks path, with an older pre-commit in .git/hooks
    git init -q -b main "$1"; ident "$1"; mkdir -p "$1/hooks"; printf '# an older spawn\n' > "$1/CLAUDE.md"; tpin "$1/.git/leak-pattern.pin" "$MARK" 1
    git -C "$1" add -A; git -C "$1" commit -q --no-verify -m one; git -C "$1" config core.hooksPath hooks
    printf '#!/bin/sh\n# an older hook\nexit 0\n' > "$1/.git/hooks/pre-commit"; chmod +x "$1/.git/hooks/pre-commit"; }
damaged() { chmod -R u+w "$I2" 2>/dev/null; echo damaged > "$I2/zz-damaged"; }   # a file the install's manifest doesn't list
asides() { find "$KIT_INSTALL_ROOT" -maxdepth 1 -name 'v1.0.1.set-aside.*' | wc -l | tr -d ' '; }
sp_reset() { git -C "$SP" checkout -q -- kit.pin; stubs "$I2"; }   # the spawn's committed pin and its stubs, whatever ran before
eg_kp_run() {  # SUFFIX BASH KEY
    local s=$1 b=$2 k=$3 out rc d oh n0
    out=$("$b" "$TMP/kp-vx/kit-pin" verify v1.0.1 "$H2" 2>&1); rc=$?; (( kvx == 0 )) || rc=0
    refused_for "EG28$s kit-pin verify: an exit 0 right after its first checks refuses" $rc "$out" "$STOPPED"
    out=$("$b" "$KP" verify v1.0.1 "$H2" 2>&1)
    want_ok "EG29$s kit-pin verify: an install that matches still passes" $? "$out" "verify passed"
    pinb=$(sha "$SP/kit.pin"); stubb=$(sha "$SP/.git/hooks/pre-commit")
    out=$( (cd "$SP" && "$b" "$TMP/kp-tx/kit-pin" to v1.0.0) 2>&1 ); rc=$?; (( ktx == 0 )) && same || rc=0
    refused_for "EG30$s kit-pin to: an exit 0 once the pin and stubs are written refuses, and puts them back" $rc "$out" "$STOPPED"
    sp_reset; out=$( (cd "$SP" && "$b" "$KP" to v1.0.1) 2>&1 ); rc=$?; [[ -z "$(git -C "$SP" status --porcelain)" ]] || rc=1
    want_ok "EG31$s kit-pin to: a move to the release already pinned still passes" $rc "$out" "now names v1.0.1"
    d="$TMP/eg-old-$k-x"; oldspawn "$d"; oh=$(sha "$d/.git/hooks/pre-commit")
    out=$( (cd "$d" && "$b" "$TMP/kp-mx/kit-pin" migrate v1.0.0) 2>&1 ); rc=$?
    (( kmx == 0 )) && [[ "$(git -C "$d" config --local --get core.hooksPath)" == hooks && "$(sha "$d/.git/hooks/pre-commit")" == "$oh" \
        && ! -e "$d/.git/hooks/pre-push" && ! -e "$d/kit.pin" && ! -e "$d/.git/hooks/pre-commit.pre-kit-pin" ]] || rc=0
    refused_for "EG32$s kit-pin migrate: an exit 0 once the stubs and kit.pin are written refuses, and puts everything back" $rc "$out" "$STOPPED"
    d="$TMP/eg-old-$k"; oldspawn "$d"
    out=$( (cd "$d" && "$b" "$KP" migrate v1.0.0) 2>&1 )
    want_ok "EG33$s kit-pin migrate: a hooks-path spawn still moves onto the install" $? "$out" "was 'hooks'"
    sp_reset; damaged; n0=$(asides)
    out=$( (cd "$SP" && "$b" "$TMP/kp-rx/kit-pin" restore "$K") 2>&1 ); rc=$?
    (( krx == 0 )) && [[ -f "$I2/zz-damaged" && "$(asides)" == "$n0" ]] || rc=0
    refused_for "EG34$s kit-pin restore: an exit 0 once the install is rebuilt refuses, and puts the earlier install back" $rc "$out" "$STOPPED"
    sp_reset; damaged; out=$( (cd "$SP" && "$b" "$KP" restore "$K") 2>&1 ); rc=$?; [[ ! -e "$I2/zz-damaged" ]] || rc=1
    want_ok "EG35$s kit-pin restore: a damaged install is still rebuilt, and check passes" $rc "$out" "check passed"
}
eg_kp_run "" bash b5
if [[ -z "$b3why" ]]; then eg_kp_run " (bash 3)" "$B3" b3
else for c in EG28 EG29 EG30 EG31 EG32 EG33 EG34 EG35; do skip "$c (bash 3)" "$b3why"; done; fi

# ============================== kit-pin and the list's pin ======================================
# check reads the identity list against its pin as pre-push does, and a list that is unusable or doesn't match its pin
# is a state of its own, exit 3: installed and pinned, but every push will be refused (decisions log §112). migrate
# keeps its switch on that state and says so; restore hands over to check and returns its 3. repin writes the pins:
# a first one only with --first; an append is the session's to make; any other change, a row retired with a
# placeholder included, cites the § that holds the owner's words; it gives rows before and after, never a term or a hash.
sp_reset; cp -p "$SP/.git/leak-pattern.pin" "$TMP/sp.pin"
tpin "$SP/.git/leak-pattern.pin" "$MARK|zqother" 2
out=$(kp check); rc=$?
[[ $rc -eq 3 && "$out" == *"every push will be refused"* && "$out" != *SYNTH-MARKER* && ! "$out" =~ [0-9a-f]{64} ]] && rc=0 || rc=1
want_ok "CP1 check: a list that doesn't match its pin finishes with exit 3, every push refused, no term or hash printed" $rc "$out"
rm -f "$SP/.git/leak-pattern.pin"; out=$(kp check); rc=$?; [[ $rc -eq 3 && "$out" == *"no pin"* ]] && rc=0 || rc=1
want_ok "CP2 check: no pin beside the list finishes with exit 3" $rc "$out"
out=$( (cd "$SP" && "$KP" restore "$K") 2>&1 ); rc=$?; [[ $rc -eq 3 ]] && rc=0 || rc=1
want_ok "KR3 restore hands over to check, and returns its exit 3 when every push would be refused" $rc "$out" "nothing to rebuild"
cp -p "$TMP/sp.pin" "$SP/.git/leak-pattern.pin"
out=$(kp check);                               want_ok "CP3 check: the list its pin names passes, exit 0" $? "$out" "matches its pin"
d="$TMP/km4"; oldspawn "$d"; rm -f "$d/.git/leak-pattern.pin"
out=$( (cd "$d" && "$KP" migrate v1.0.0) 2>&1 ); rc=$?
[[ $rc -eq 3 && -z "$(git -C "$d" config --local --get core.hooksPath)" && -f "$d/kit.pin" && -f "$d/.git/hooks/pre-push" \
   && "$out" == *"every push will be refused"* ]] && rc=0 || rc=1
want_ok "KM4 migrate with no pin keeps its switch, finishes with exit 3, and says every push will be refused" $rc "$out"
RPC="$TMP/repin"; git init -q -b main "$RPC"; ident "$RPC"; echo x > "$RPC/a.txt"; git -C "$RPC" add -A; git -C "$RPC" commit -q --no-verify -m one
RL="$RPC/.git/leak-pattern"; RPN="$RPC/.git/leak-pattern.pin"; allout=""
rp() { (cd "$RPC" && env -u LEAK_PATTERN "$KP" repin "$@") 2>&1; }
pinis() { [[ "$(sed -n 's/^rows=//p' "$1" 2>/dev/null)" == "$3" && "$(sed -n 's/^sha256=//p' "$1" 2>/dev/null)" == "$(printf '%s' "$2" | tsum)" ]]; }  # PIN VALUE ROWS
lput() { printf "LEAK_PATTERN='%s'\n" "$1" > "$RL"; }
lput "zqone|zqtwo|$MARK"
out=$(rp local); rc=$?; allout+=$out; [[ ! -e "$RPN" ]] || rc=0
refused_for "RP1 repin: no pin yet and no --first refuses, and writes none" $rc "$out" "no local pin yet"
out=$(rp local --first); rc=$?; allout+=$out; pinis "$RPN" "zqone|zqtwo|$MARK" 3 || rc=1
want_ok "RP2 repin --first writes the first pin: the rows, and the hash of the list's value" $rc "$out" "rows none -> 3, a first pin"
out=$(rp local); rc=$?; allout+=$out
want_ok "RP3 repin: an unchanged list already matches, and nothing is written" $rc "$out" "already matches its pin"
lput "zqone|zqtwo|$MARK|zqfour"; out=$(rp local); rc=$?; allout+=$out; pinis "$RPN" "zqone|zqtwo|$MARK|zqfour" 4 || rc=1
want_ok "RP4 repin: an append is taken without a ruling, giving the rows before and after" $rc "$out" "rows 3 -> 4, an append"
cp -p "$RPN" "$TMP/rp.pin"
lput "zqone|zqTWO|$MARK|zqfour"; out=$(rp local); rc=$?; allout+=$out; cmp -s "$RPN" "$TMP/rp.pin" || rc=0
refused_for "RP5 repin: a row changed in place, without --ruling, refuses and keeps the pin" $rc "$out" "changed by more than an append"
lput "zqone|zqzqretired|$MARK|zqfour"; out=$(rp local); rc=$?; allout+=$out; cmp -s "$RPN" "$TMP/rp.pin" || rc=0
refused_for "RP6 repin: a row retired with a placeholder, without --ruling, refuses" $rc "$out" "changed by more than an append"
lput "zqone|zqtwo"; out=$(rp local); rc=$?; allout+=$out; cmp -s "$RPN" "$TMP/rp.pin" || rc=0
refused_for "RP7 repin: a cut list, without --ruling, refuses" $rc "$out" "changed by more than an append"
out=$(rp local --ruling twelve); rc=$?; allout+=$out; cmp -s "$RPN" "$TMP/rp.pin" || rc=0
refused_for "RP8 repin: a --ruling that cites no § refuses" $rc "$out" "changed by more than an append"
out=$(rp local --ruling §12); rc=$?; allout+=$out; pinis "$RPN" "zqone|zqtwo" 2 || rc=1
want_ok "RP9 repin --ruling §N takes any other change, and names the §" $rc "$out" "rows 4 -> 2, a change ruled in §12"
lput 'zq(ab|cd)e|zq[[:digit:]|]f|zq\.g'; out=$(rp local --ruling §12); rc=$?; allout+=$out
pinis "$RPN" 'zq(ab|cd)e|zq[[:digit:]|]f|zq\.g' 3 || rc=1
want_ok "RP10 repin counts top-level rows: groups, bracket expressions and escapes don't split one" $rc "$out" "rows 2 -> 3"
printf '%s' "zqcanary|zqpath" > "$RPC/.git/leak-pattern.ci"
out=$(rp ci --first); rc=$?; allout+=$out; pinis "$RPC/.github/leak-pattern.pin" "zqcanary|zqpath" 2 || rc=1
want_ok "RP11 repin ci --first pins CI's list, kept in .git/leak-pattern.ci, in the tracked .github/leak-pattern.pin" $rc "$out" "Commit .github/leak-pattern.pin"
[[ -n "$allout" && "$allout" != *SYNTH-MARKER* && "$allout" != *zqone* && "$allout" != *zqcanary* && ! "$allout" =~ [0-9a-f]{64} ]]
want_ok "RP12 nothing repin printed holds a term or a hash" $? "$(printf '%s' "$allout" | tr '\n' ' ' | cut -c1-200)"
# A row with a non-ASCII letter (decisions log §159): kit-pin splits and hashes the list byte-wise, whatever its caller's
# locale, so a pin written in a UTF-8 locale matches the list read with none.
NA_LO=$(printf 'synth-mark\303\251r-7f3a')
lput "zqone|$NA_LO"; out=$( (cd "$RPC" && env -u LEAK_PATTERN LC_ALL=C.UTF-8 "$KP" repin local --ruling §12) 2>&1 ); rc=$?
out2=$( (cd "$RPC" && env -u LEAK_PATTERN -u LANG -u LC_ALL -u LC_CTYPE "$KP" repin local) 2>&1 ); rc2=$?
[[ $rc -eq 0 && $rc2 -eq 0 && "$out2" == *"already matches its pin"* ]] && pinis "$RPN" "zqone|$NA_LO" 2
want_ok "RP13 a list row with a non-ASCII letter pins alike in a UTF-8 locale and with none" $? "exit $rc/$rc2: $(printf '%s' "$out $out2" | tr '\n' ' ' | cut -c1-200)"

# ============================== every printed kit-pin command runs (S3) =========================
# A kit-pin command a refusal or a report prints runs from inside the project it was printed in (decisions log §348):
# a quoted path ending /bin/kit-pin, then its words up to a ")", ";", "#" or the line's end. The path is absolute, or
# "$INST/..." or "$KIT/...", which the message says on a line of its own what each names. pc_runs runs each command
# from a copy of the project, INST and KIT set to an install and to a clone of the kit, the words as printed, but
# restore alone, which would rebuild an install. Exit 126 or 127 fails a case, as do a bin/kit-pin named by a relative
# path, a variable the message doesn't say, and no command at all. PC0 shows the check can fail.
PC_RE='"([^"]*/bin/kit-pin)"([^";)#]*)'
PC_REL='(^|[^/"A-Za-z0-9_.$-])bin/kit-pin'
pc_runs() {   # OUTPUT PROJECT INST KIT: 0, or 1 with PC_WHY saying why
    local out=$1 proj=$2 inst=$3 kit=$4 line rest prog args n=0 rc copy="$TMP/pc-copy"
    local -a a
    PC_WHY=""
    if printf '%s\n' "$out" | grep -q -E "$PC_REL"; then
        PC_WHY="a relative bin/kit-pin: $(printf '%s\n' "$out" | grep -m1 -E "$PC_REL" | cut -c1-120)"; return 1
    fi
    while IFS= read -r line; do
        rest=$line
        while [[ "$rest" =~ $PC_RE ]]; do
            prog=${BASH_REMATCH[1]}; args=${BASH_REMATCH[2]}; rest=${rest#*"${BASH_REMATCH[0]}"}
            if [[ "$prog" == '$INST/'* ]]; then
                [[ "$out" == *"INST is "* ]] || { PC_WHY="\$INST printed, and no line says what it is"; return 1; }
                prog="$inst/${prog#\$INST/}"
            elif [[ "$prog" == '$KIT/'* ]]; then
                [[ "$out" == *"KIT is "* ]] || { PC_WHY="\$KIT printed, and no line says what it is"; return 1; }
                prog="$kit/${prog#\$KIT/}"
            fi
            [[ "$prog" == /* && -f "$prog" && -x "$prog" ]] || { PC_WHY="not an executable file named by an absolute path: $prog"; return 1; }
            args=${args%.}
            # A placeholder a shell misreads (a redirect, a pipe), such as <64 hex>, can't be run as printed (§353 F4).
            [[ "$args" != *[\<\>\|\&]* ]] || { PC_WHY="a placeholder a shell misreads, in: $prog$args"; return 1; }
            read -r -a a <<< "$args"
            [[ "${a[0]:-}" == restore ]] && a=()
            chmod -R u+w "$copy" 2>/dev/null; rm -rf "$copy"; cp -a "$proj" "$copy" || { PC_WHY="the project could not be copied"; return 1; }
            (cd "$copy" && "$prog" ${a[@]+"${a[@]}"} </dev/null >/dev/null 2>&1); rc=$?
            (( rc != 126 && rc != 127 )) || { PC_WHY="exit $rc from: $prog ${a[*]:-}"; return 1; }
            n=$((n + 1))
        done
    done <<< "$out"
    chmod -R u+w "$copy" 2>/dev/null; rm -rf "$copy"
    (( n > 0 )) || { PC_WHY="no kit-pin command printed"; return 1; }
}
pcw() { if pc_runs "$2" "$3" "${4:-$I2}" "${5:-$K}"; then result "$1" 0; else result "$1" 1 "$PC_WHY | $(printf '%s' "$2" | tr '\n' ' ' | cut -c1-160)"; fi; }
PCP="$TMP/pc"; mkorg "$PCP"
out=$( (cd "$PCP" && "$KP" to v1.0.1) 2>&1 ); rc=$?
git -C "$PCP" add kit.pin 2>/dev/null && git -C "$PCP" commit -q --no-verify -m pin 2>/dev/null
if [[ $rc -ne 0 || ! -f "$PCP/kit.pin" ]]; then
    for c in PC0 PC1 PC2 PC3 PC4 PC5 PC6 PC7 PC8 PC9 PC10 PC11 PC12 PC13 PC14 PC15 PC16 PC17 PC18 PC19 PC20 PC21 PC22 PC23 PC24 PC25; do
        skip "$c" "kit-pin to v1.0.1 did not pin the scratch project: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
    done
else
PCX="$TMP/pc-x"
pcx() { chmod -R u+w "$PCX" 2>/dev/null; rm -rf "$PCX"; cp -a "$PCP" "$PCX"; }      # a fresh copy of the pinned project
pcnote() { echo "$1" >> "$PCX/notes.txt"; git -C "$PCX" add notes.txt; }
pc_runs "run bin/kit-pin check" "$PCP" "$I2" "$K"; r1=$?; pc_runs "\"$TMP/nowhere/bin/kit-pin\" check" "$PCP" "$I2" "$K"; r2=$?
pc_runs "\"\$INST/bin/kit-pin\" check" "$PCP" "$I2" "$K"; r3=$?; pc_runs "\"$KP\" check" "$PCP" "$I2" "$K"; r4=$?
[[ $r1 -ne 0 && $r2 -ne 0 && $r3 -ne 0 && $r4 -eq 0 ]]
                                               want_ok "PC0 the check fails a relative path, a missing one and an unexplained INST, and passes a real one" $? "$r1 $r2 $r3 $r4"
# kit-pin's report and refusals.
out=$( (cd "$PCP" && env -u LEAK_PATTERN "$KP" check) 2>&1 ); pcw "PC1 kit-pin check with no list (exit 3): its next steps run" "$out" "$PCP"
PCN="$TMP/pc-nopin"; git init -q "$PCN"; out=$( (cd "$PCN" && "$KP" check) 2>&1 ); pcw "PC2 kit-pin, no kit.pin: its hint runs" "$out" "$PCN"
pcx; rm -f "$PCX/.git/hooks/pre-push"; out=$( (cd "$PCX" && "$KP" check) 2>&1 ); pcw "PC3 kit-pin check, a stub missing: its hint runs" "$out" "$PCX"
pcx; echo '# drift' >> "$PCX/.git/hooks/pre-push"; out=$( (cd "$PCX" && "$KP" check) 2>&1 ); pcw "PC4 kit-pin check, a stub changed: its hint runs" "$out" "$PCX"
PCS="$TMP/pc-system.gitconfig"; mkdir -p "$TMP/pc-it"; git config -f "$PCS" core.hooksPath "$TMP/pc-it"
out=$( (cd "$PCP" && env -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$PCS" "$KP" check) 2>&1 )
                                               pcw "PC5 kit-pin check under an org's hooks path the clone doesn't override: its hint runs" "$out" "$PCP"
out=$( (cd "$PCP" && "$KP" verify) 2>&1 );     pcw "PC6 kit-pin verify with no release: its usage line runs" "$out" "$PCP"
out=$( (cd "$PCP" && "$KP" to) 2>&1 );         pcw "PC7 kit-pin to with no release: its usage line runs" "$out" "$PCP"
out=$( (cd "$PCP" && "$KP" migrate) 2>&1 );    pcw "PC8 kit-pin migrate with no release: its usage line runs" "$out" "$PCP"
out=$( (cd "$PCP" && "$KP" migrate v1.0.1) 2>&1 ); pcw "PC9 kit-pin migrate in a pinned spawn: its hint runs" "$out" "$PCP"
pcx; git -C "$PCX" config core.hooksPath "$TMP/elsewhere"; out=$( (cd "$PCX" && "$KP" to v1.0.1) 2>&1 )
                                               pcw "PC10 kit-pin to in a clone with a hooks path of its own: its hint runs" "$out" "$PCX"
# pre-push and pre-commit, through the stub and, for the missing rules, run from a copy of the install without them.
pcx; pcnote a; git -C "$PCX" commit -q --no-verify -m a; out=$( (cd "$PCX" && env -u LEAK_PATTERN git push -q origin main) 2>&1 )
                                               pcw "PC11 pre-push with no list: its next step runs" "$out" "$PCX"
pcx; pcnote b; git -C "$PCX" commit -q --no-verify -m b; printf "LEAK_PATTERN='zqchanged'\n" > "$PCX/.git/leak-pattern"
out=$( (cd "$PCX" && env -u LEAK_PATTERN git push -q origin main) 2>&1 ); pcw "PC12 pre-push with a list its pin doesn't name: its hint runs" "$out" "$PCX"
PCI="$TMP/pc-inst"; chmod -R u+w "$PCI" 2>/dev/null; rm -rf "$PCI"; cp -a "$I2" "$PCI"; chmod -R u+w "$PCI"; rm -f "$PCI/leak-detection/spawn.gitleaks.toml"
pcx; pcnote c; out=$( (cd "$PCX" && env -u KIT_INSTALL git -c core.hooksPath="$PCI/leak-detection" commit -q -m c) 2>&1 )
                                               pcw "PC13 pre-commit with no credential rules: its hint runs" "$out" "$PCX"
pcx; pcnote d; git -C "$PCX" commit -q --no-verify -m d
out=$( (cd "$PCX" && env -u KIT_INSTALL git -c core.hooksPath="$PCI/leak-detection" push -q origin main) 2>&1 )
                                               pcw "PC14 pre-push with no credential rules: its hint runs" "$out" "$PCX"
# The stub.
pcx; rm -f "$PCX/kit.pin"; pcnote e; out=$( (cd "$PCX" && git commit -q -m e) 2>&1 ); pcw "PC15 the stub, no kit.pin: its hint runs" "$out" "$PCX"
mkdir -p "$TMP/pc-root-empty"; pcx; pcnote f; out=$( (cd "$PCX" && KIT_INSTALL_ROOT="$TMP/pc-root-empty" git commit -q -m f) 2>&1 )
                                               pcw "PC16 the stub, the install missing: its hint runs" "$out" "$PCX"
PCR="$TMP/pc-root"; chmod -R u+w "$PCR" 2>/dev/null; rm -rf "$PCR"; mkdir -p "$PCR"; cp -a "$I2" "$PCR/v1.0.1"; chmod -R u+w "$PCR"
echo '# changed' >> "$PCR/v1.0.1/patterns/repo-genesis.md"
pcx; pcnote g; out=$( (cd "$PCX" && KIT_INSTALL_ROOT="$PCR" git commit -q -m g) 2>&1 ); pcw "PC17 the stub, the install changed: its hints run" "$out" "$PCX"
pcx; echo '# drift' >> "$PCX/.git/hooks/pre-commit"; pcnote h; out=$( (cd "$PCX" && git commit -q -m h) 2>&1 )
                                               pcw "PC18 the stub differs from the release's: its hints run" "$out" "$PCX"
# At a commit, kit-pin to refuses while the refused commit's change is staged, so the hint sets it aside first, and
# brings it back after (§353 F2): its steps, followed in order from the project, let the commit through.
pc25=1; steps=$(printf '%s\n' "$out" | sed -n 's/.*then commit again: //p' | head -1)
if [[ -n "$steps" ]]; then
    pc25=0; IFS=';' read -r -a st <<< "$steps"
    for s in "${st[@]}"; do (cd "$PCX" && bash -c "$s" </dev/null >/dev/null 2>&1) || { pc25=1; break; }; done
    (( pc25 )) || { (cd "$PCX" && git commit -q -m h >/dev/null 2>&1) && [[ "$(git -C "$PCX" log -1 --format=%s)" == h ]] || pc25=1; }
fi
                                               want_ok "PC25 the stub, changed, refuses a commit with steps that, followed in order, let the commit through" $pc25 "steps: [${steps:-none}] $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-140)"
chmod -R u+w "$PCR" 2>/dev/null; rm -rf "$PCR"; mkdir -p "$PCR"; cp -a "$I2" "$PCR/v1.0.1"; chmod u+w "$PCR/v1.0.1/leak-detection"; chmod a-x "$PCR/v1.0.1/leak-detection/pre-commit"
pcx; pcnote i; out=$( (cd "$PCX" && KIT_INSTALL_ROOT="$PCR" git commit -q -m i) 2>&1 )
                                               pcw "PC19 the stub, the release's hook not executable: its hint runs" "$out" "$PCX" "$PCR/v1.0.1"
# The CI scan, where no install exists, names "$INST/bin/kit-pin" and says what INST is.
pcx; out=$( (cd "$PCX" && env -u LEAK_PATTERN bash "$I2/leak-detection/scan-tree.sh") 2>&1 ); pcw "PC20 the CI scan with no secret: its hint runs" "$out" "$PCX"
pcx; tpin "$PCX/.github/leak-pattern.pin" "zqother" 1; git -C "$PCX" add .github; git -C "$PCX" commit -q --no-verify -m ci
out=$( (cd "$PCX" && LEAK_PATTERN="$MARK" bash "$I2/leak-detection/scan-tree.sh") 2>&1 ); pcw "PC21 the CI scan with a secret its pin doesn't name: its hint runs" "$out" "$PCX"
# The history check, and the installer.
pcx; out=$( (cd "$PCX" && "$I2/bin/kit-history-audit" .) 2>&1 ); pcw "PC22 the history check with no list: its hint runs" "$out" "$PCX"
pcx; printf "LEAK_PATTERN='zqchanged'\n" > "$PCX/.git/leak-pattern"; out=$( (cd "$PCX" && "$I2/bin/kit-history-audit" .) 2>&1 )
                                               pcw "PC23 the history check with a list its pin doesn't name: its hint runs" "$out" "$PCX"
out=$(irun v1.0.1);                            pcw "PC24 install-release over an install that exists: its hint runs" "$out" "$PCP"
chmod -R u+w "$PCX" "$PCI" "$PCR" 2>/dev/null; rm -rf "${PCX:?}" "${PCI:?}" "${PCR:?}"
fi

echo
echo "install_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

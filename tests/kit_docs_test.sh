#!/usr/bin/env bash
#
# kit_docs_test.sh — regression tests for the kit's OWN documents: the CLAUDE.md template
# (templates/CLAUDE.md), the record templates, the patterns, the manifest and the workflows.
#
#   tests/kit_docs_test.sh [ROOT]    ROOT = a checkout of this kit (default: the one holding this file)
#
# KIT-ONLY. kit-manifest.txt keeps this file out of every install, because these cases read the kit's
# template files as templates: T5 asserts the stakes-frame TODO is still in the template, which in a spawn
# with its frame written is red by construction. The hook and install tests, which ship, are in
# tests/hooks_test.sh and tests/install_test.sh; CI runs this file only where it exists.
#
# Exit 0 only when every case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
H="$ROOT/leak-detection"
MANIFEST="$ROOT/kit-manifest.txt"
TPL="$ROOT/templates/CLAUDE.md"     # the spawn template; the kit's own CLAUDE.md is the kit's
PASS=0; FAIL=0; SKIP=0

result() { if [[ $2 -eq 0 ]]; then PASS=$((PASS+1)); printf 'ok    %s\n' "$1"
           else FAIL=$((FAIL+1)); printf 'FAIL  %s  -- %s\n' "$1" "$3"; fi; }
# A counted skip, as in the other suites: only for a tool the case needs and the machine lacks (shasum on Windows).
skip() { SKIP=$((SKIP+1)); printf 'skip  %s  -- %s\n' "$1" "$2"; }
want_ok() { if [[ $2 -eq 0 ]]; then result "$1" 0; else result "$1" 1 "exit $2: $(printf '%s' "${3:-}" | tr '\n' ' ' | cut -c1-160)"; fi; }

# ============================== the manifest ====================================================
[[ -f "$MANIFEST" ]];                          want_ok "K1 kit-manifest.txt exists" $? ""
bad=$(awk '/^[^#]/ && NF { if (NF != 2 || ($1 != "kit" && $1 != "spawn" && $1 != "owned" && $1 != "example")) print }' "$MANIFEST" 2>/dev/null)
[[ -z "$bad" ]];                               want_ok "K2 every manifest entry is 'kit PATH', 'spawn PATH', 'owned PATH' or 'example PATH'" $? "$bad"
# Fail closed: every tracked path has a class, from its own entry or its directory's. A path no entry
# covers would travel to every spawn by default, unreviewed: the case a release that adds files makes
# likely. unlisted MANIFEST prints, from the paths on stdin, each one no entry covers.
unlisted() { awk 'NR == FNR { if (/^[^#]/ && NF == 2) e[++n] = $2; next }
                  { for (i = 1; i <= n; i++) if ($0 == e[i] || (substr(e[i], length(e[i])) == "/" && index($0, e[i]) == 1)) next; print }' "$1" -; }
out=$(git -C "$ROOT" ls-files | unlisted "$MANIFEST")
[[ -z "$out" ]];                               want_ok "K18 every tracked path has a class in the manifest" $? "$out"
out=$(printf '%s\n' "$(git -C "$ROOT" ls-files)" "not-in-any-entry/new-file.md" | unlisted "$MANIFEST")
[[ "$out" == "not-in-any-entry/new-file.md" ]]; want_ok "K18b the check names a tracked path no entry covers, and only that one" $? "$out"
missing=$(awk '/^[^#]/ && NF == 2 { print $2 }' "$MANIFEST" 2>/dev/null | while read -r p; do
              if [[ "$p" == */ ]]; then git -C "$ROOT" ls-files -- "$p" | grep -q . || echo "$p"
              else git -C "$ROOT" ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || echo "$p"; fi; done)
[[ -z "$missing" ]];                           want_ok "K3 every manifest path is tracked (no stale entries)" $? "$missing"
for f in kit-manifest.txt README.md CHANGELOG.md tests/kit_docs_test.sh CLAUDE.md; do
    grep -qE "^kit[[:space:]]+$f\$" "$MANIFEST" 2>/dev/null
                                               want_ok "K4 manifest keeps $f in the kit" $? ""
done
grep -qE '^spawn[[:space:]]+records/$' "$MANIFEST" 2>/dev/null
                                               want_ok "K5 manifest gives records/ to the spawn" $? ""
grep -qE '^spawn[[:space:]]+templates/$' "$MANIFEST" 2>/dev/null
                                               want_ok "K5b manifest gives templates/ to the spawn" $? ""
mode=$(git -C "$ROOT" ls-files -s -- tests/kit_docs_test.sh | awk '{print $1}')
[[ "$mode" == 100755 ]];                       want_ok "K6 kit_docs_test.sh is tracked executable" $? "mode '$mode'"
grep -q 'CLASSES' "$ROOT/patterns/local-spawn.md" 2>/dev/null
                                               want_ok "K7 local-spawn's copy step reads the install's CLASSES" $? ""
awk '/run: tests\/hooks_test.sh/ {h=1} /run: tests\/install_test.sh/ {i=1} /run: tests\/load_check_test.sh/ {l=1}
     /tests\/kit_docs_test.sh/ && /-f/ {k=1} END {exit !(h && i && l && k)}' "$ROOT/.github/workflows/gitleaks.yml" 2>/dev/null
                                               want_ok "K8 gitleaks.yml runs the hook, install and load-check tests always and the kit docs tests only when present" $? ""
# The kit-docs step must be keyed on the manifest, and must FAIL when the manifest is present and the
# test file is not: run the step's script in two scratch trees and read its exit codes.
step=$(awk '/name: Kit document tests/ {f=1; next} f && /run: \|/ {r=1; next} r && /^          / {sub(/^          /, ""); print; next} r {exit}' "$ROOT/.github/workflows/gitleaks.yml" 2>/dev/null)
W=$(mktemp -d); mkdir -p "$W/spawn" "$W/kit/tests"; : > "$W/kit/kit-manifest.txt"
printf '%s\n' "$step" > "$W/step.sh"     # a program reaches the shell through a file, never a -c string
( cd "$W/spawn" && bash "$W/step.sh" >/dev/null 2>&1 ); rc_spawn=$?
( cd "$W/kit"   && bash "$W/step.sh" >/dev/null 2>&1 ); rc_kit=$?; rm -rf "$W"
[[ -n "$step" && $rc_spawn -eq 0 && $rc_kit -ne 0 ]]
                                               want_ok "K16 kit-docs step: no manifest passes; manifest without the test file fails" $? "spawn=$rc_spawn kit=$rc_kit"
# gitleaks goes on the PATH once, for the whole job, from the step that installs it: a per-step PATH reached
# the hook tests and missed the kit-docs step, whose K19 then failed in CI with nothing to say why.
{ awk '/name: Install gitleaks/ {f=1; next} f && /- name:/ {exit} f && /GITHUB_PATH/ {g=1} END {exit !g}' "$ROOT/.github/workflows/gitleaks.yml" \
  && ! grep -qE 'PATH="?\$PWD' "$ROOT/.github/workflows/gitleaks.yml"; } 2>/dev/null
                                               want_ok "K20 the install step puts gitleaks on the job's PATH, and no step adds its own" $? ""

# ============================== the ci/ variants: a pinned project's CI =========================
# A pinned project's workflows are the release's ci/ variants (ci/copies.txt): the scans, none of the kit's suites,
# scanning with the project's .gitleaks.toml, which the copies layer holds to the spawn config.
CG="$ROOT/ci/gitleaks.yml"; CL="$ROOT/ci/leak-scan.yml"
{ [[ -f "$CG" && -f "$CL" ]] && ! grep -qE 'tests/(hooks|install|load_check|kit_docs)_test' "$CG" "$CL" \
  && grep -q -- '--config .gitleaks.toml' "$CG" && grep -q 'run: leak-detection/scan-tree.sh' "$CL" && grep -q 'secrets.LEAK_PATTERN' "$CL" \
  && grep -qE '^\.github/workflows/gitleaks\.yml[[:space:]]+ci/gitleaks\.yml$' "$ROOT/ci/copies.txt" \
  && grep -qE '^\.github/workflows/leak-scan\.yml[[:space:]]+ci/leak-scan\.yml$' "$ROOT/ci/copies.txt" \
  && grep -qE '^\.gitleaks\.toml[[:space:]]+leak-detection/spawn\.gitleaks\.toml$' "$ROOT/ci/copies.txt"; } 2>/dev/null
                                               want_ok "V1 the ci/ variants run the scans and none of the kit's suites, and ci/copies.txt maps each project path" $? ""
# The variant's own scan step, run in scratch projects holding the spawn config as their .gitleaks.toml: a credential
# shape at the path the kit's own config exempts is caught, and a clean tree passes.
step=$(awk '/name: Scan working tree/ {f=1; next} f && /run: \|/ {r=1; next} r && /^          / {sub(/^          /, ""); print; next}
            r && /^[[:space:]]*$/ {print ""; next} r {exit}' "$CG" 2>/dev/null)
[[ "$step" == *"gitleaks dir . --config .gitleaks.toml"* ]] || step=""   # the whole step, or nothing
V=$(mktemp -d); printf '%s\n' "$step" > "$V/step.sh"     # a program reaches the shell through a file, never a -c string
mkvp() { git init -q -b main "$1" && cp "$ROOT/leak-detection/spawn.gitleaks.toml" "$1/.gitleaks.toml" 2>/dev/null && echo "# a project" > "$1/README.md"; }
mkvp "$V/clean" && git -C "$V/clean" add -A
mkvp "$V/hit" && mkdir -p "$V/hit/leak-detection/fixtures" && cp "$ROOT/leak-detection/fixtures/synthetic_config.txt" "$V/hit/leak-detection/fixtures/" \
    && git -C "$V/hit" add -A
( cd "$V/clean" && bash "$V/step.sh" ) > /dev/null 2>&1; rc_clean=$?
( cd "$V/hit" && bash "$V/step.sh" ) > /dev/null 2>&1; rc_hit=$?; rm -rf "${V:?}"
[[ -n "$step" && $rc_clean -eq 0 && $rc_hit -ne 0 ]]
                                               want_ok "V2 the variant's scan, with the spawn config, catches a credential at the path the kit's config exempts, and passes a clean tree" $? "clean=$rc_clean hit=$rc_hit"
# The variant installs gitleaks with the kit's own step, pinned by version and sha256, line for line, so a release
# moves both together; its scan runs that gitleaks from the PATH, never one fetched into the checkout.
glstep() { awk '/- name: Install gitleaks/ {f=1; next} f && /- name:/ {exit} f' "$1" 2>/dev/null; }
a=$(glstep "$ROOT/.github/workflows/gitleaks.yml"); b=$(glstep "$CG")
[[ -n "$a" && "$a" == "$b" && "$a" == *'ver=8.'* && "$a" == *'if [ "$got" != "$want" ]'* ]] && ! grep -q '\./gitleaks' "$CG" 2>/dev/null
                                               want_ok "K26 ci/gitleaks.yml installs gitleaks with the kit's own pinned step, line for line, and scans with it" $? "$(diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | grep -c '^[<>]') line(s) differ"

# ============================== the frame TODO: hook, template and test fixture agree ===========
todo=$(sed -n "s/^FRAME_TODO=\"\(.*\)\"$/\1/p" "$H/pre-commit" 2>/dev/null)
[[ -n "$todo" ]];                              want_ok "K9 pre-commit names its FRAME_TODO string" $? ""
grep -qF "$todo" "$TPL" 2>/dev/null
                                               want_ok "K10 the CLAUDE.md template carries the TODO the hook refuses" $? ""
grep -qF "$todo" "$ROOT/tests/hooks_test.sh" 2>/dev/null
                                               want_ok "K11 hooks_test's inline fixture carries the same TODO" $? ""
! grep -q 'ROOT/CLAUDE.md' "$ROOT/tests/hooks_test.sh" 2>/dev/null
                                               want_ok "K12 hooks_test never reads the checkout's CLAUDE.md" $? ""

# ============================== pattern documents ===============================================
{ grep -q 'kit-pin" to' "$ROOT/patterns/local-spawn.md" && ! grep -q 'install_hooks' "$ROOT/patterns/local-spawn.md"; } 2>/dev/null
                                               want_ok "D1 local-spawn pins the new project with kit-pin to, and runs no installer" $? ""
{ grep -q '\.local/operator-notes\.md' "$TPL" && ! grep -q 'identity, credentials, and remotes live' "$TPL"; } 2>/dev/null
                                               want_ok "D2 template names the operator-notes path, not credentials" $? ""

# An install to make projects from, built here from ROOT's staged tree the way tools/install-release.sh builds any
# release: a new repository holding that tree (a clone of CI's shallow checkout couldn't push its tag), its hook suite
# replaced by a stand-in (install_test's IR9 runs the real one on an install), a tag, a bare remote, the install.
# K19 and U1 make projects from it. A failure names its stage and cause: an empty reason once hid a missing gitleaks
# in CI for a whole run.
# A project's list lives under the home folder the user database gives, never $HOME's: the install's reader is a test
# copy whose kit_list_home alone prints TH, so K19 and U1 read and write lists there and never in the real home; if the
# copy doesn't, neither runs.
E=$(mktemp -d); IROOT="$E/releases"; KK="$E/kit"; INST="$IROOT/v1.0.0"; why_install=""; TH="$E/home"; mkdir -p "$TH"
KR="$KK/leak-detection/read-leak-pattern.sh"
if ! command -v gitleaks >/dev/null 2>&1; then
    why_install="gitleaks is not on PATH: a project's pre-commit refuses without it"
elif ! { git init -q -b main "$KK" && git -C "$ROOT" checkout-index -a --prefix="$KK/" \
         && printf '#!/usr/bin/env bash\necho "hooks_test: a stand-in"\n' > "$KK/tests/hooks_test.sh" \
         && RS_BODY="    printf '%s\\n' '$TH'   # a suite's test copy: its scratch home" \
            awk '/^kit_list_home\(\) \{/ {print; print ENVIRON["RS_BODY"]; s=1; next} s && /^\}/ {s=0} !s {print}' "$KR" > "$E/reader.swap" \
         && cat "$E/reader.swap" > "$KR" \
         && [[ "$(bash -c '. "$1" && kit_list_home' _ "$KR" 2>/dev/null)" == "$TH" ]] \
         && git -C "$KK" add -A && git -C "$KK" -c user.name=t -c user.email=t@invalid.local -c core.hooksPath=/dev/null commit -q -m kit \
         && git -C "$KK" -c user.name=t -c user.email=t@invalid.local tag -a v1.0.0 -m v1.0.0 \
         && git init -q --bare "$E/remote.git" && git -C "$KK" remote add origin "$E/remote.git" \
         && git -C "$KK" push -q --no-verify origin v1.0.0; } > "$E/kit.log" 2>&1; then
    why_install="the scratch kit could not be made: $(tail -n 1 "$E/kit.log")"
elif ! (cd "$KK" && KIT_INSTALL_ROOT="$IROOT" tools/install-release.sh v1.0.0) > "$E/install.log" 2>&1; then
    why_install="install-release could not build the install: $(grep -m 1 -E 'REFUSING|error|No such' "$E/install.log")"
fi

# End to end: a project made by local-spawn's own procedure block, from that install. Commit one goes through the
# stubs: refused while the frame TODO stands, made once the frame is written. The project holds no kit-owned file,
# and kit-pin check passes.
SP="$E/spawn"; why="$why_install"
awk '/^## Procedure/ {p=1} p && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$ROOT/patterns/local-spawn.md" 2>/dev/null \
    | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$SP'|" > "$E/spawn.sh"
if [[ -n "$why" ]]; then :
elif [[ ! -s "$E/spawn.sh" ]]; then
    why="no procedure block found in patterns/local-spawn.md"
elif ! KIT_INSTALL_ROOT="$IROOT" bash "$E/spawn.sh" > "$E/spawn.log" 2>&1; then
    why="local-spawn's procedure block failed: $(tail -n 1 "$E/spawn.log")"
elif ! (cd "$SP" && git config --local user.name kit-docs-test && git config --local user.email kit-docs-test@invalid.local \
        && git add -A) > "$E/stage.log" 2>&1; then
    why="the project's commit identity or its staging failed"
elif (cd "$SP" && KIT_INSTALL_ROOT="$IROOT" git commit -q -m one) > "$E/c0.log" 2>&1 || ! grep -q 'stakes-frame TODO' "$E/c0.log"; then
    why="commit one was not refused for the frame TODO: $(tr '\n' ' ' < "$E/c0.log" | cut -c1-120)"
elif ! (cd "$SP" && sed -i "/TODO: write this project's stakes frame fresh/,/-->/d" CLAUDE.md && git add CLAUDE.md \
        && KIT_INSTALL_ROOT="$IROOT" git commit -q -m "commit one") > "$E/c1.log" 2>&1; then
    why="commit one was refused with the frame written: $(grep -m 1 -E 'REFUSING|BLOCKED|error|fatal' "$E/c1.log")"
else
    held=$(cd "$SP" && awk '$1 == "owned" {print $2}' "$INST/CLASSES" | while read -r f; do [[ -e "$f" ]] && echo "$f"; done)
    [[ -z "$held" ]] || why="the project holds kit-owned files: $(echo $held | cut -c1-120)"
    # Its do-not-publish list written over the line the block pinned, and repinned citing its decision, as local-spawn
    # says (a stand-in list); then check passes, where it finishes with exit 3 while every push would be refused.
    [[ -n "$why" ]] || { (umask 077 && printf "LEAK_PATTERN='%s'\n" "zqdocsmarker" > "$TH/.config/morrowcairn/lists/$(cat "$SP/kit.list-id" 2>/dev/null)") \
        && (cd "$SP" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" repin local --ruling §1) > "$E/pin.log" 2>&1; } \
        || why="the project's list could not be pinned: $(grep -m 1 REFUSING "$E/pin.log")"
    [[ -n "$why" ]] || (cd "$SP" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) > "$E/check.log" 2>&1 \
        || why="kit-pin check failed: $(grep -m 1 -E 'REFUSING|exit 3' "$E/check.log")"
fi
[[ -z "$why" ]];                               want_ok "K19 a project made by local-spawn from an install commits through the stubs, frame TODO refused first, and holds no kit-owned file" $? "$why"

# A new project's defaults: local-spawn's block leaves it with no do-not-publish list, the one line saying so written at
# the list's place and pinned, and with no identity guard, so commit one goes under the identity git resolves (here a
# scratch global one standing for the machine's, or IT's); the block says so, and each is turned on as the docs say. An
# existing project moved onto the release keeps its list and its identity.
SN="$E/newproj"; NG="$E/np-global.gitconfig"; NR="$E/np-remote.git"; npwhy="$why_install"; npout=""
printf '[user]\n\tname = np-machine\n\temail = np-machine@invalid.local\n' > "$NG"
npg() { (cd "$SN" && env GIT_CONFIG_GLOBAL="$NG" KIT_INSTALL_ROOT="$IROOT" "$@") 2>&1; }     # CMD...: in SN, the scratch machine identity
npsum() { local s; if command -v sha256sum >/dev/null 2>&1; then s=$(sha256sum); else s=$(shasum -a 256); fi; printf '%s' "${s%% *}"; }
if [[ -z "$npwhy" ]]; then
    awk '/^## Procedure/ {p=1} p && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$ROOT/patterns/local-spawn.md" 2>/dev/null \
        | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$SN'|" > "$E/np-spawn.sh"
    npout=$(env GIT_CONFIG_GLOBAL="$NG" KIT_INSTALL_ROOT="$IROOT" bash "$E/np-spawn.sh" 2>&1) || npwhy="local-spawn's block failed: $(printf '%s' "$npout" | tail -n 1)"
fi
out=$(npg "$INST/bin/kit-pin" check); rc=$?
[[ -z "$npwhy" && $rc -eq 0 && "$out" == *"the do-not-publish check is off"* && "$npout" == *"starts with no do-not-publish list"* \
   && "$npout" == *"nothing will remind"* ]]
                                               want_ok "NP1 a new project starts with the reserved line at its list's place, pinned (check passes, the do-not-publish check off), and the block says so" $? "${npwhy:-check exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)}"
npg sed -i "/TODO: write this project's stakes frame fresh/,/-->/d" CLAUDE.md >/dev/null; npg git add -A >/dev/null
out=$(npg git commit -q -m one); rc=$?
[[ -z "$npwhy" && $rc -eq 0 && "$(npg git log -1 --format='%an <%ae>')" == "np-machine <np-machine@invalid.local>" ]]
                                               want_ok "NP3 with the identity guard off by default, commit one goes under the machine's own identity" $? "${npwhy:-exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)}"
git init -q --bare "$NR" 2>/dev/null; npg git remote add origin "$NR" >/dev/null
out=$(npg git push -q origin HEAD:refs/heads/main); rc=$?
[[ -z "$npwhy" && $rc -eq 0 && "$out" == *"the do-not-publish check is off for this project"* ]]
                                               want_ok "NP1b and its pushes pass with name checks off, each saying so" $? "${npwhy:-exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)}"
np1=$(printf '%s' "$npout" | tr '\n' ' ')
[[ -z "$npwhy" && "$np1" == *"so its pushes say the do-not-publish check is off, and still scan for credentials"* \
   && "$np1" != *"name checks are off"* ]]
                                               want_ok "NP1c the block's printed lines say what its pushes say: the do-not-publish check is off" $? "${npwhy:-$(printf '%s' "$np1" | cut -c1-160)}"
# Adding a list, as local-spawn says: its own step, the command as the pattern prints it, run in the project with the
# suite's home. Over a list already at its place (a real one) it refuses and leaves it as it was; over the line saying
# the project has none it puts the list in place. Then the repin citing the decision (a change other than an append
# takes a § of the project's decisions log).
# The command is the fenced block holding the stand-in terms, or, written on one line, the code span holding them.
lscmd=$(awk '/^ *```/ { if (inb && b ~ /term1\|term2/) { printf "%s", b; found = 1; exit } inb = !inb; b = ""; next }
  inb { sub(/^  /, ""); b = b $0 "\n"; next }
  !one && /`\([^`]*term1\|term2[^`]*\)`/ { one = $0; sub(/^[^`]*`\(/, "(", one); sub(/\)`.*$/, ")", one) }
  END { if (!found && one != "") print one }' "$ROOT/patterns/local-spawn.md" 2>/dev/null)
lsf=$(cd "$SN" && . "$INST/leak-detection/read-leak-pattern.sh" 2>/dev/null && kit_list_file && printf '%s' "$KL_FILE")
case "$lsf" in "$TH"/*) ;; *) lsf="" ;; esac   # only ever the suite's home, never a real list
cp -p "${lsf:?}" "$E/np-line.aside" 2>/dev/null; (umask 077 && printf "LEAK_PATTERN='%s'\n" zqnpreal > "${lsf:?}")
lssum=$(cksum < "$lsf"); printf '%s\n' "$lscmd" | (cd "$SN" && HOME="$TH" bash) >/dev/null 2>&1; lsrc=$?
[[ -n "$lscmd" && $lsrc -ne 0 && "$(cksum < "$lsf")" == "$lssum" ]]
                                               want_ok "NP6 local-spawn's step for adding a list refuses a list already at its place, leaving it unchanged" $? "exit $lsrc: ${lscmd:-no command found}"
cp -p "$E/np-line.aside" "${lsf:?}" 2>/dev/null; rm -f "${lsf:?}.new"
printf '%s\n' "$lscmd" | (cd "$SN" && HOME="$TH" bash) >/dev/null 2>&1; lsrc=$?
[[ $lsrc -eq 0 && "$(cat "$lsf")" == "LEAK_PATTERN='term1|term2'" && ! -e "$lsf.new" ]]
                                               want_ok "NP6b and over the line saying there is none it puts the list in place, leaving nothing beside it" $? "exit $lsrc: $(wc -l < "$lsf") line(s)"
pout=$(npg "$INST/bin/kit-pin" repin local --ruling §1); prc=$?
echo "a note naming term1" > "$SN/np-note.txt"; npg git add np-note.txt >/dev/null; npg git commit -q -m note >/dev/null
out=$(npg git push -q origin HEAD:refs/heads/main); rc=$?
[[ -z "$npwhy" && $prc -eq 0 && $rc -ne 0 && "$out" == *"listed terms"* ]]
                                               want_ok "NP2 a project that then adds a list, repinned with its §, gets name refusals" $? "${npwhy:-repin exit $prc, push exit $rc: $(printf '%s' "$pout $out" | tr '\n' ' ' | cut -c1-200)}"
npg git reset -q --hard HEAD~1 >/dev/null
npg git config --local user.name UNSET-SEE-REPO-GENESIS >/dev/null; npg git config --local user.email unset@invalid.local >/dev/null
echo x > "$SN/np-x.txt"; npg git add np-x.txt >/dev/null
out=$(npg git commit -q -m x); rc=$?
[[ -z "$npwhy" && $rc -ne 0 && "$out" == *"genesis sentinel"* ]]
                                               want_ok "NP4 with the guard turned on (the sentinel written in the clone), a commit is refused as before" $? "${npwhy:-exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)}"
# An existing project: its list in .git/leak-pattern with its pin, its own local identity; moved onto the release.
SX="$E/existing"; why5="$why_install"
if [[ -z "$why5" ]]; then
    { git init -q -b main "$SX" && git -C "$SX" config --local user.name np-existing && git -C "$SX" config --local user.email np-existing@invalid.local \
      && printf '# none\n' > "$SX/kit-pin.tests" && echo a > "$SX/a.txt" && git -C "$SX" add -A && git -C "$SX" commit -q --no-verify -m one \
      && printf "LEAK_PATTERN='%s'\n" zqexisting > "$SX/.git/leak-pattern" && chmod 600 "$SX/.git/leak-pattern" \
      && printf 'rows=1\nsha256=%s\n' "$(printf '%s' zqexisting | npsum)" > "$SX/.git/leak-pattern.pin"; } >/dev/null 2>&1 || why5="the existing project could not be made"
fi
out=$( (cd "$SX" && env GIT_CONFIG_GLOBAL="$NG" KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" to v1.0.0 && env GIT_CONFIG_GLOBAL="$NG" KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) 2>&1 ); rc=$?
[[ -z "$why5" && $rc -eq 0 && "$out" == *"the do-not-publish check is active"* && "$out" != *"the do-not-publish check is off"* \
   && "$(git -C "$SX" config --local user.name)" == np-existing ]]
                                               want_ok "NP5 an existing project moved onto the release keeps its list and its own identity" $? "${why5:-exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)}"

# The same block where a stock Mac stands: shasum and no sha256sum, then neither. Each PATH holds a link to every
# command on PATH but the ones left out (install_test's pathless), each left out with its .exe, which Git Bash runs by
# the bare name; with neither, the block stops before DST is made.
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
NOSHA="$E/path-nosha"; pathless "$NOSHA" sha256sum shasum
SHAONLY="$E/path-shasum"; pathless "$SHAONLY" sha256sum
NOTOOL="neither sha256sum (GNU coreutils) nor shasum (Perl) is installed"
sblock() {  # DST: local-spawn's procedure block for v1.0.0 and DST
    awk '/^## Procedure/ {p=1} p && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$ROOT/patterns/local-spawn.md" 2>/dev/null \
        | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$1'|"; }
why="$why_install"; sblock "$E/spawn-shasum" > "$E/spawn-shasum.sh"
if [[ -z "$why" ]] && ! (PATH="$SHAONLY"; command -v shasum >/dev/null 2>&1); then
    skip "K19b with shasum and no sha256sum, local-spawn's block verifies the install and pins the project" "shasum is not installed here"
else
    if [[ -z "$why" ]]; then
        KIT_INSTALL_ROOT="$IROOT" PATH="$SHAONLY" bash "$E/spawn-shasum.sh" > "$E/spawn-shasum.log" 2>&1
        grep -q 'verify passed' "$E/spawn-shasum.log" && [[ -f "$E/spawn-shasum/kit.pin" ]] \
            || why="no verify pass and kit.pin: $(grep -m 1 -E 'REFUSING|error|not found' "$E/spawn-shasum.log")"
    fi
    [[ -z "$why" ]];                           want_ok "K19b with shasum and no sha256sum, local-spawn's block verifies the install and pins the project" $? "$why"
fi
why="$why_install"; sblock "$E/spawn-notool" > "$E/spawn-notool.sh"
if [[ -z "$why" ]]; then
    KIT_INSTALL_ROOT="$IROOT" PATH="$NOSHA" bash "$E/spawn-notool.sh" > "$E/spawn-notool.log" 2>&1
    if [[ -e "$E/spawn-notool" ]]; then why="DST was made: the block went on past the hash"
    elif ! grep -qF "$NOTOOL" "$E/spawn-notool.log"; then why="the missing tools aren't named: $(tail -n 1 "$E/spawn-notool.log")"
    elif ! grep -q 'parameter null or not set' "$E/spawn-notool.log"; then why="no \${VAR:?} stopped it"; fi
fi
[[ -z "$why" ]];                               want_ok "K19c with neither tool, local-spawn's block names both and stops before DST is made" $? "$why"

# local-spawn's guards. An agent's shell calls don't keep variables, so a block run in pieces starts with
# REL and DST empty; in v0.6.0 `cd ""` then succeeded and stayed put, the copy landed in whatever folder
# the shell was in, and that folder's repository got the placeholder identity. Each run below happens in
# a scratch repository standing in for that folder, which must come out unchanged: the whole block with
# both unset, the whole block with DST empty, the whole block with REL empty (DST must not even be
# made: no half-made project), and the block in pieces (one fresh shell per paragraph, as an agent runs
# it), where every piece after the first starts with both unset. No install is reachable from these runs.
V=$(mktemp -d); W="$V/here"
awk '/^## Procedure/ {p=1} p && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$ROOT/patterns/local-spawn.md" > "$V/block.sh" 2>/dev/null
state() { ( cd "$W" && find . -path ./.git -prune -o -type f -exec cksum {} + | sort && find . -path ./.git -prune -o -print | sort \
            && git config --local --list | sort ) 2>&1 | cksum; }
fresh() { rm -rf "${W:?}" "${V:?}/dst" && mkdir -p "$W" && git -C "$W" init -q -b main && git -C "$W" config --local user.name here-test \
          && git -C "$W" config --local user.email here-test@invalid.local && echo keep > "$W/keep.txt"; }
sed -e '/^REL=/d' -e '/^DST=/d' "$V/block.sh" > "$V/unset.sh"
sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST=''|" "$V/block.sh" > "$V/dst-empty.sh"
sed -e "s|^REL=.*|REL=''|" -e "s|^DST=.*|DST='$V/dst'|" "$V/block.sh" > "$V/rel-empty.sh"
awk -v d="$V" 'BEGIN {n = 1} /^$/ {n++; next} {print > sprintf("%s/piece%02d.sh", d, n)}' "$V/block.sh"
why=""
[[ -s "$V/block.sh" ]] || why="no procedure block found in patterns/local-spawn.md"
for run in unset dst-empty rel-empty pieces; do
    [[ -z "$why" ]] || break
    fresh || { why="the scratch repository could not be made"; break; }
    before=$(state)
    if [[ $run == pieces ]]; then
        for p in "$V"/piece*.sh; do (cd "$W" && KIT_INSTALL_ROOT="$V/none" bash "$p") >> "$V/$run.log" 2>&1; done
    else
        (cd "$W" && KIT_INSTALL_ROOT="$V/none" bash "$V/$run.sh") > "$V/$run.log" 2>&1
    fi
    [[ $(state) == "$before" ]] \
        || why="$run: the folder the block ran in was changed ($(grep -m 1 -E 'Reinitialized|Initialized|error|fatal' "$V/$run.log"))"
    [[ -n "$why" || ! -e "$V/dst" ]] || why="$run: DST was made although REL was empty: a half-made project"
    [[ -n "$why" ]] || grep -q 'parameter null or not set' "$V/$run.log" \
        || why="$run: no \${VAR:?} stopped it: $(tail -n 1 "$V/$run.log")"
done
rm -rf "${V:?}"
[[ -z "$why" ]];                               want_ok "K21 local-spawn with REL or DST empty or unset stops before it touches the folder it runs in" $? "$why"

# local-upgrade's move onto an install, run whole on a scratch project that runs its hooks from a hooks path and
# holds kit-owned copies, one as the release has it and one changed and declared in kit.forks. Afterwards no hooks
# path is set, the unchanged copies are gone in one commit made through the stubs, the fork stays, and check passes.
UD="$E/older"; why="$why_install"
ublock() { awk -v h="$1" '$0 == h {f=1; next} f && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$ROOT/patterns/local-upgrade.md" 2>/dev/null; }
ublock '### 2. Move onto the install' | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$UD'|" > "$E/move.sh"
# local-upgrade's step 1b on a scratch project given a stand-in list, and with CI the record of its secret: the pins the
# move takes.
pins() {  # DIR
    local g; g=$(git -C "$1" rev-parse --absolute-git-dir) || return 1
    printf "LEAK_PATTERN='%s'\n" "zqdocsmarker|zqsecondrow" > "$g/leak-pattern"
    [[ ! -f "$1/.github/workflows/leak-scan.yml" ]] || printf '%s' "zqdocsci" > "$g/leak-pattern.ci"
    ublock "### 1b. The list's pins" | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$1'|" > "$E/pins.sh"
    [[ -s "$E/pins.sh" ]] && KIT_INSTALL_ROOT="$IROOT" bash "$E/pins.sh"; }
if [[ -n "$why" ]]; then :
elif [[ ! -s "$E/move.sh" ]]; then
    why="no move block found under '### 2. Move onto the install' in patterns/local-upgrade.md"
elif ! { git init -q -b main "$UD" && git -C "$UD" config user.name t && git -C "$UD" config user.email t@invalid.local \
         && mkdir -p "$UD/leak-detection" "$UD/patterns" \
         && install -m 0755 "$INST/leak-detection/pre-commit" "$INST/leak-detection/pre-push" "$UD/leak-detection/" \
         && install -m 0644 "$INST/patterns/repo-genesis.md" "$INST/patterns/local-spawn.md" "$UD/patterns/" \
         && echo "a local change" >> "$UD/patterns/local-spawn.md" \
         && printf '# an older project\n' > "$UD/CLAUDE.md" && printf 'true\n' > "$UD/kit-pin.tests" \
         && printf 'patterns/local-spawn.md  sha256:%s  §3  kept on purpose\n' "$(sha256sum < "$UD/patterns/local-spawn.md" | cut -d' ' -f1)" > "$UD/kit.forks" \
         && git -C "$UD" add -A && git -C "$UD" commit -q --no-verify -m "an older project" \
         && git -C "$UD" config core.hooksPath leak-detection; } > "$E/older.log" 2>&1; then
    why="the scratch project could not be made: $(tail -n 1 "$E/older.log")"
elif ! pins "$UD" > "$E/pins.log" 2>&1; then
    why="local-upgrade's pins block failed: $(grep -m 1 -E 'REFUSING|error|fatal|^$' "$E/pins.log")"
elif ! KIT_INSTALL_ROOT="$IROOT" bash "$E/move.sh" > "$E/move.log" 2>&1; then
    why="local-upgrade's move block failed: $(grep -m 1 -E 'REFUSING|BLOCKED|error|fatal' "$E/move.log")"
else
    [[ -z "$(git -C "$UD" config --get core.hooksPath)" ]] || why="a hooks path is still set"
    [[ -n "$why" || ( ! -e "$UD/leak-detection/pre-push" && ! -e "$UD/patterns/repo-genesis.md" && -e "$UD/patterns/local-spawn.md" ) ]] \
        || why="the copies are not as expected: the unchanged ones gone, the declared fork kept"
    [[ -n "$why" ]] || [[ "$(git -C "$UD" rev-list --count HEAD)" -eq 2 && -z "$(git -C "$UD" status --porcelain)" ]] \
        || why="not one clean commit after the move"
    [[ -n "$why" ]] || (cd "$UD" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) >/dev/null 2>&1 || why="kit-pin check failed after the move"
fi
[[ -z "$why" ]];                               want_ok "U1 local-upgrade's move pins a hooks-path project and removes its unchanged kit-owned copies in one commit; a declared fork stays" $? "$why"

# The move with CI (ci/copies.txt): a project holding the kit's own workflows, .gitleaks.toml and scan-tree.sh, as a
# project made before v0.8.0 does. After the move each is the release's file for a project: its ci/ variant, the spawn
# config, the release's scan-tree.sh. A copy kit.forks declares is the project's own and comes through byte for byte.
ci_project() {  # DIR [FORK]
    local d=$1
    git init -q -b main "$d" && git -C "$d" config user.name t && git -C "$d" config user.email t@invalid.local \
    && mkdir -p "$d/.github/workflows" "$d/leak-detection" \
    && install -m 0644 "$INST/.github/workflows/gitleaks.yml" "$INST/.github/workflows/leak-scan.yml" "$d/.github/workflows/" \
    && install -m 0644 "$INST/.gitleaks.toml" "$d/" && install -m 0755 "$INST/leak-detection/scan-tree.sh" "$INST/leak-detection/pre-commit" "$d/leak-detection/" \
    && printf '# a project with CI\n' > "$d/CLAUDE.md" && printf 'true\n' > "$d/kit-pin.tests" \
    && if [[ -n "${2:-}" ]]; then echo "      # a step of the project's own" >> "$d/.github/workflows/gitleaks.yml" \
           && printf '.github/workflows/gitleaks.yml  sha256:%s  §4  its own step\n' "$(sha256sum < "$d/.github/workflows/gitleaks.yml" | cut -d' ' -f1)" > "$d/kit.forks"; fi \
    && git -C "$d" add -A && git -C "$d" commit -q --no-verify -m "a project with CI" && git -C "$d" config core.hooksPath leak-detection; }
held() { cmp -s "$1/.github/workflows/leak-scan.yml" "$INST/ci/leak-scan.yml" && cmp -s "$1/.gitleaks.toml" "$INST/leak-detection/spawn.gitleaks.toml" \
         && cmp -s "$1/leak-detection/scan-tree.sh" "$INST/leak-detection/scan-tree.sh" && [[ -x "$1/leak-detection/scan-tree.sh" ]]; }
for u in U2 U3; do
    UD="$E/ci-$u"; why="$why_install"; fork=""; [[ $u == U3 ]] && fork=1
    ublock '### 2. Move onto the install' | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$UD'|" > "$E/move-$u.sh"
    if [[ -n "$why" ]]; then :
    elif ! ci_project "$UD" "$fork" > "$E/$u.log" 2>&1; then
        why="the scratch project could not be made: $(tail -n 1 "$E/$u.log")"
    elif ! pins "$UD" > "$E/pins-$u.log" 2>&1; then
        why="local-upgrade's pins block failed: $(grep -m 1 -E 'REFUSING|error|fatal' "$E/pins-$u.log")"
    else
        before=$(sha256sum < "$UD/.github/workflows/gitleaks.yml")
        if ! KIT_INSTALL_ROOT="$IROOT" bash "$E/move-$u.sh" > "$E/move-$u.log" 2>&1; then
            why="the move failed: $(grep -m 1 -E 'REFUSING|BLOCKED|error|fatal' "$E/move-$u.log")"
        elif ! held "$UD"; then
            why="leak-scan.yml, .gitleaks.toml or scan-tree.sh is missing or is not the release's file for a project"
        elif [[ $u == U2 ]] && ! cmp -s "$UD/.github/workflows/gitleaks.yml" "$INST/ci/gitleaks.yml"; then
            why="gitleaks.yml is missing or is not the release's ci/ variant"
        elif [[ $u == U3 && "$(sha256sum < "$UD/.github/workflows/gitleaks.yml")" != "$before" ]]; then
            why="the declared fork was changed"
        elif [[ -e "$UD/leak-detection/pre-commit" || "$(git -C "$UD" rev-list --count HEAD)" -ne 2 || -n "$(git -C "$UD" status --porcelain)" ]]; then
            why="not one clean commit with the other kit-owned copies gone"
        elif ! (cd "$UD" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) >/dev/null 2>&1; then
            why="kit-pin check failed after the move"
        fi
    fi
    if [[ $u == U2 ]]; then [[ -z "$why" ]]; want_ok "U2 a project with CI ends the move with its workflows present, each held to the release's ci/ variant, its .gitleaks.toml the spawn config" $? "$why"
    else [[ -z "$why" ]]; want_ok "U3 a declared fork of a workflow comes through the move untouched; the other CI copies are held to the release's files" $? "$why"; fi
done

# local-upgrade's move on a project made before v0.8.0 that holds a doctrine copy changed since its spawn (a project
# made from the kit met it at v0.9.0). The move's commit runs through the stubs, whose copies layer refuses a kit-owned copy that
# differs from the release, so the move brings the doctrine copies to the release's in that commit; step 3 removes
# them once the user level imports the doctrine. The project also holds a copy of v0.11.0's shell-commands.md, a file
# the release no longer ships: the copies layer checks only the paths the release's CLASSES names, so
# the move leaves that copy as it was and nothing refuses it.
UO="$E/older-doctrine"; why="$why_install"
ublock '### 2. Move onto the install' | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$UO'|" > "$E/move-doctrine.sh"
if [[ -n "$why" ]]; then :
elif ! { git init -q -b main "$UO" && git -C "$UO" config user.name t && git -C "$UO" config user.email t@invalid.local \
         && mkdir -p "$UO/leak-detection" "$UO/skills" "$UO/.claude/skills/gates" \
         && install -m 0755 "$INST/leak-detection/pre-commit" "$INST/leak-detection/pre-push" "$UO/leak-detection/" \
         && install -m 0644 "$INST/.claude/skills/gates/SKILL.md" "$UO/.claude/skills/gates/" \
         && echo "an older rule" >> "$UO/.claude/skills/gates/SKILL.md" \
         && printf '# Shell commands\n\nA copy of a file v0.11.0 shipped.\n' > "$UO/skills/shell-commands.md" \
         && printf '# an older project\n@skills/shell-commands.md\n' > "$UO/CLAUDE.md" && printf 'true\n' > "$UO/kit-pin.tests" \
         && git -C "$UO" add -A && git -C "$UO" commit -q --no-verify -m "an older project" \
         && git -C "$UO" config core.hooksPath leak-detection; } > "$E/older-doctrine.log" 2>&1; then
    why="the scratch project could not be made: $(tail -n 1 "$E/older-doctrine.log")"
elif ! pins "$UO" > "$E/pins-doctrine.log" 2>&1; then
    why="local-upgrade's pins block failed: $(grep -m 1 -E 'REFUSING|error|fatal|^$' "$E/pins-doctrine.log")"
elif ! KIT_INSTALL_ROOT="$IROOT" bash "$E/move-doctrine.sh" > "$E/move-doctrine.log" 2>&1; then
    why="local-upgrade's move block failed: $(grep -m 1 -E 'REFUSING|BLOCKED|differs|error|fatal' "$E/move-doctrine.log")"
else
    [[ "$(git -C "$UO" rev-list --count HEAD)" -eq 2 && -z "$(git -C "$UO" status --porcelain)" ]] || why="not one clean commit after the move"
    [[ -n "$why" ]] || cmp -s "$UO/.claude/skills/gates/SKILL.md" "$INST/.claude/skills/gates/SKILL.md" || why="the doctrine copy is not the release's"
    [[ -n "$why" || ( ! -e "$INST/skills/shell-commands.md" \
                      && "$(git -C "$UO" show HEAD:skills/shell-commands.md 2>/dev/null)" == "$(printf '# Shell commands\n\nA copy of a file v0.11.0 shipped.')" ) ]] \
        || why="the copy of a file the release no longer ships didn't come through as it was"
    [[ -n "$why" ]] || (cd "$UO" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) >/dev/null 2>&1 || why="kit-pin check failed after the move"
fi
[[ -z "$why" ]];                               want_ok "U8 local-upgrade's move on a project holding a changed doctrine copy commits through the stubs, the copy now the release's, and a copy of a file the release no longer ships kept as it was" $? "$why"

# local-upgrade's check for the kit's old LICENSE, run in a scratch folder with the hash it holds swapped for a
# stand-in file's (the real file isn't in a shallow checkout): it names a match, says nothing for another file, and
# with neither hashing tool names both instead of saying nothing.
LIC_HASH=1eba867c29a6e5d920f993266e344d847a7046dab968762b7349d09e3bbdb42e
L="$E/lic"; mkdir -p "$L"; printf 'a stand-in license\n' > "$L/stand-in"
ublock '## A LICENSE the kit copied in' > "$E/lic-orig.sh"
sed "s|$LIC_HASH|$(sha256sum < "$L/stand-in" | cut -d' ' -f1)|" "$E/lic-orig.sh" > "$E/lic.sh"
lic() { (cd "$L" && PATH="$1" bash "$E/lic.sh") 2>&1; }   # PATH-FOR-THE-BLOCK
lic_why=""; grep -q "$LIC_HASH" "$E/lic-orig.sh" || lic_why="the block no longer holds the old LICENSE's hash"
cp "$L/stand-in" "$L/LICENSE"; out=$(lic "$PATH")
[[ -z "$lic_why" && "$out" == *"copied in at spawn"* ]]; want_ok "U4 local-upgrade's LICENSE check names a LICENSE whose hash it holds" $? "${lic_why:-$out}"
if (PATH="$SHAONLY"; command -v shasum >/dev/null 2>&1); then
    out=$(lic "$SHAONLY")
    [[ -z "$lic_why" && "$out" == *"copied in at spawn"* ]]; want_ok "U5 and with shasum and no sha256sum, names it too" $? "${lic_why:-$out}"
else skip "U5 and with shasum and no sha256sum, names it too" "shasum is not installed here"; fi
out=$(lic "$NOSHA")
[[ -z "$lic_why" && "$out" == *"$NOTOOL"* && "$out" != *"copied in at spawn"* ]]
                                               want_ok "U6 and with neither tool, names both tools and gives no verdict" $? "${lic_why:-$out}"
printf 'another license\n' > "$L/LICENSE"; out=$(lic "$PATH")
[[ -z "$lic_why" && -z "$out" ]];              want_ok "U7 and says nothing for another LICENSE" $? "${lic_why:-$out}"
chmod -R u+w "$E" 2>/dev/null; rm -rf "${E:?}"

# ============================== doctrine: skills/ and .claude/skills/ ===========================
# An import line naming a missing file loads nothing and says nothing: the session simply runs without
# that doctrine. bad_imports FILE prints each @-import in FILE that names no tracked file.
bad_imports() { sed -n 's/^@\([^[:space:]]*\)[[:space:]]*$/\1/p' "$1" | while read -r p; do
                    git -C "$ROOT" ls-files --error-unmatch -- "$p" >/dev/null 2>&1 || echo "$p"; done; }
# Since v0.12.0 the always-on rules reach every session through the user level, from the rules file kit-pin user links,
# so the kit's own CLAUDE.md imports nothing either.
n=$(grep -c '^@' "$ROOT/CLAUDE.md" 2>/dev/null)
[[ -f "$ROOT/CLAUDE.md" && "$n" == 0 ]];       want_ok "P1 the kit's own CLAUDE.md imports nothing: the rules arrive through the user level" $? "imports=$n"
# The template imports none: a project holds no copy of the doctrine, which loads once, at user level.
[[ -f "$TPL" ]] && ! grep -q '^@' "$TPL"
                                               want_ok "P1c the template imports no doctrine" $? ""
W=$(mktemp); { cat "$ROOT/CLAUDE.md"; echo "@skills/no-such-file.md"; } > "$W"; out=$(bad_imports "$W"); rm -f "$W"
[[ "$out" == "skills/no-such-file.md" ]];      want_ok "P1b the import check names an import of a missing file" $? "$out"
bad=$(for s in "$ROOT"/.claude/skills/*/SKILL.md; do
          [[ -f "$s" ]] || continue; d=$(basename "$(dirname "$s")")
          awk -v d="$d" 'NR == 1 && $0 != "---" {exit 1} NR > 1 && $0 == "---" {exit !(nm && ds)}
                         $0 == "name: " d {nm = 1} /^description: ./ {ds = 1}' "$s" || echo "$d"
      done)
n=$(ls "$ROOT"/.claude/skills/*/SKILL.md 2>/dev/null | wc -l)
[[ "$n" -ge 1 && -z "$bad" ]];                 want_ok "P2 every triggered skill has front matter naming its folder and a description" $? "skills=$n bad=$bad"
# Every numbered procedure has a retirement condition and a provenance line. Five are left in skill files since the
# always-on procedures moved to the rules file, whose why is the explainer's.
bad=$(for s in "$ROOT"/skills/*.md "$ROOT"/.claude/skills/*/SKILL.md; do
          [[ -f "$s" ]] || continue
          awk '/^## [0-9]+\. / {if (p && !w) print p; p = $2; sub(/\.$/, "", p); w = 0} /^\*\*Would revisit if:\*\*/ {w = 1}
               END {if (p && !w) print p}' "$s"
          grep -oE '^## [0-9]+\.' "$s" | grep -oE '[0-9]+' | while read -r k; do
              grep -qE "^- $k: " "$ROOT/skills/PROVENANCE.md" 2>/dev/null || echo "provenance $k"; done
      done)
n=$(cat "$ROOT"/skills/*.md "$ROOT"/.claude/skills/*/SKILL.md 2>/dev/null | grep -cE '^## [0-9]+\. ')
[[ "$n" -ge 5 && -z "$bad" ]];                 want_ok "P3 every numbered procedure has a Would-revisit line and a provenance line" $? "procedures=$n missing=$bad"
# PROVENANCE holds the lines the shipped files cite, and no others: each skill procedure's number, and each line a
# shipped file names by its name ("PROVENANCE.md`, the <name> line"); none points into the kit's private records.
want=$( { cat "$ROOT"/.claude/skills/*/SKILL.md 2>/dev/null | grep -oE '^## [0-9]+\.' | grep -oE '[0-9]+'
          git -C "$ROOT" ls-files -z | (cd "$ROOT" && xargs -0 grep -ohE 'PROVENANCE\.md`, the [a-z-]+ line' 2>/dev/null) \
              | sed -E 's/.*, the ([a-z-]+) line/\1/'; } | tr 'A-Z-' 'a-z ' | sort -u)
have=$(sed -nE 's/^- ([^:]+): .*/\1/p' "$ROOT/skills/PROVENANCE.md" 2>/dev/null | tr 'A-Z-' 'a-z ' | sort -u)
[[ -n "$want" && "$want" == "$have" ]] && ! grep -qE '§[0-9]' "$ROOT/skills/PROVENANCE.md" 2>/dev/null
                                               want_ok "P3b PROVENANCE holds exactly the lines the shipped files cite, with no pointer into the kit's records" $? "cited: $(echo $want) | held: $(echo $have)"
grep -q "run by the kit's operator" "$ROOT/skills/README.md" 2>/dev/null && ! grep -q 'arriving after the extraction' "$ROOT/skills/README.md" \
    && ! grep -q 'the projects the kit was' "$ROOT/skills/README.md"
                                               want_ok "P4 skills/README states the evidence rule: spawns or projects run by the kit's operator" $? ""
# The rules file's sections, each matched on the section joined into one line: the file wraps at 120 columns, and a
# phrase split across a line break is still the phrase. rsec N prints section N.
rsec() { awk -v n="$1" 'index($0, "## " n ". ") == 1 {s=1; next} s && /^## / {exit} s' "$ROOT/rules/morrowcairn.md" 2>/dev/null | tr -s '[:space:]' ' '; }
# The size rule's lower-end cap, its schema-change sentence (a change after which reverting the code alone would
# leave existing data unreadable) and the project's-own-bar clause "report a conflict". Until
# v0.12.0 these were procedure 1 and its last section in skills/working-from-a-brief.md.
J5=$(rsec 5); J12=$(rsec 12)
grep -q 'lower end plus 2' <<<"$J5" && grep -q 'existing data unreadable' <<<"$J5" && grep -q 'never reconcile it silently' <<<"$J12"
                                               want_ok "P6 the rules file carries the lower-end cap, the schema-change sentence, and says to report a conflict, never reconcile it silently" $? ""
# Rule 6's end line and its numbering cases.
{ grep -q 'End of relay' "$ROOT/patterns/numbered-relays.md" && grep -q 'Supersedes #N' "$ROOT/patterns/numbered-relays.md" \
  && grep -qi 'above #1' "$ROOT/patterns/numbered-relays.md"; } 2>/dev/null
                                               want_ok "K25 numbered-relays carries the end line and the numbering cases" $? ""
# The compaction line, the log's reading where one is kept and unconfirmed until it has recorded one, a disagreement a
# finding, the handoff rewrite before each report, and reprints copied verbatim (section 4). Until v0.12.0 this
# was procedure 10 of skills/working-from-a-brief.md.
J10=$(rsec 10); J4=$(rsec 4)
grep -q 'compacted since its last report' <<<"$J10" && grep -q 'unconfirmed until it has recorded one' <<<"$J10" \
    && grep -q 'never something to reconcile' <<<"$J10" && grep -q 'rewrite it so a new session can take over' <<<"$J10" \
    && grep -q 'copies the report verbatim' <<<"$J4"
                                               want_ok "P7 the rules file carries the compaction line, the log's reading unconfirmed until it has one, the handoff rewrite and verbatim reprints" $? ""
# A search that may conclude "none found": it names its command and each search's exit status, covers
# ignored, binary and non-UTF-8 files by the forms named, under LC_ALL=C, never -I, says what exit 2 means and that a
# subagent's "none found" is a lead (section 7); a search for a listed term never prints matching lines (section 9).
# Until v0.12.0 this was procedure 11 of skills/shell-commands.md.
J7=$(rsec 7); J9=$(rsec 9)
grep -qF 'the exit status of each search in it' <<<"$J7" && grep -qF 'ignored, binary and non-UTF-8 files' <<<"$J7" \
    && grep -qF 'under `LC_ALL=C` with `-l`, `-c` or `-q`' <<<"$J7" && grep -qF 'never `-I`' <<<"$J7" \
    && grep -qF 'ripgrep only with `--text --hidden --no-ignore`' <<<"$J7" && grep -qF "exit 2 means a file couldn't be read" <<<"$J7" \
    && grep -qF "A subagent's \"none found\" is a lead" <<<"$J7" && grep -qF 'never prints matching lines' <<<"$J9"
                                               want_ok "P8 the rules file says what an absence check names and covers (ignored, binary and non-UTF-8 files; -l, -c, -q under LC_ALL=C; never -I; ripgrep --text --hidden --no-ignore), what exit 2 means, that a subagent's none-found is a lead, and that a listed-term search never prints matching lines" $? ""
# The system grep by its path, since a bare grep typed in a Claude Code session is Claude Code's own search wrapper,
# which skips gitignored files, and command grep is whichever grep comes first on PATH; the explainer gives the
# measurements behind it, the wrapper's -v in its quiet modes among them.
grep -qF 'the system grep, called by its path (`/usr/bin/grep` on Linux, macOS and WSL)' <<<"$J7" \
    && grep -qF 'A bare `grep` typed in a Claude Code session is Claude Code'"'"'s own search wrapper' <<<"$J7" \
    && ! grep -qF 'a system grep under' <<<"$J7" && grep -qF 'grep -qv b' "$ROOT/docs/rules-explained.md" 2>/dev/null
                                               want_ok "P8b the absence rule names the system grep by its path, never a bare grep typed in a session, and the explainer says why" $? ""
# The operator's close prompt, a triggered skill: its key phrases, matched on the file joined into one line as
# P7, and its row in skills/README.md.
J=$(tr -s '[:space:]' ' ' 2>/dev/null < "$ROOT/.claude/skills/session-close/SKILL.md")
{ grep -q 'finished but not shipped' <<<"$J" && grep -q 'Five is a ceiling' <<<"$J" \
  && grep -qF '| `.claude/skills/session-close/SKILL.md` |' "$ROOT/skills/README.md"; } 2>/dev/null
                                               want_ok "K27 the session-close skill carries its key phrases, and skills/README lists it" $? ""

# ============================== the rules file and its companions ===============================
# The kit's rules file is the one file the user level loads from the install: kit-pin's user mode links it, and the
# morning check looks for its canary in the probe's answer. Its cap is Claude Code's
# memory guidance, under 200 lines per file; its canary is one of its own, on a visible line, as K23's are; it imports
# nothing, so the explainer is never loaded; and its sections are the explainer's, number for number.
RF="$ROOT/rules/morrowcairn.md"; RX="$ROOT/docs/rules-explained.md"; RL="$ROOT/rules/morrowcairn-local.example.md"
RULES_HEADS='## 1. Where instructions come from
## 2. A relay'"'"'s form, checked before acting
## 3. Labels
## 4. Replies and reports
## 5. Size, before starting
## 6. Reopen a decision on a fact
## 7. Say what you measured, and against what
## 8. Rulings, drafts and proposals
## 9. Output, permissions and the shell
## 10. Compaction, rotation and the handoff file
## 11. Keep going, without padding
## 12. Where a project sets its own bar'
n=$(awk 'END {print NR}' "$RF" 2>/dev/null)
[[ -f "$RF" && -n "$n" && "$n" -le 200 ]];   want_ok "R1 rules/morrowcairn.md exists and is 200 lines or fewer" $? "lines=${n:-no file}"
rc=$(grep -oE 'kc-[0-9a-f]{16}' "$RF" 2>/dev/null)
others=$([[ -n "$rc" && $(printf '%s\n' "$rc" | grep -c .) -eq 1 ]] && git -C "$ROOT" grep -l -F -e "$rc" -- . ':!rules/morrowcairn.md' 2>/dev/null)
[[ -n "$rc" && $(printf '%s\n' "$rc" | grep -c .) -eq 1 && -z "$others" ]] \
    && ! grep -B1 -A1 -E 'kc-[0-9a-f]{16}' "$RF" | grep -q '<!--'
                                               want_ok "R2 the rules file carries one load canary, on a visible line, that no other tracked file carries" $? "canaries=[$(echo $rc)] also in [$(echo $others)]"
heads=$(grep -E '^## ' "$RF" 2>/dev/null)
[[ "$heads" == "$RULES_HEADS" ]];            want_ok "R3 the rules file's sections are the twelve, in order" $? "$(diff <(printf '%s\n' "$RULES_HEADS") <(printf '%s\n' "$heads") | grep -c '^[<>]') line(s) differ"
xheads=$(grep -E '^## [0-9]+\. ' "$RX" 2>/dev/null)
[[ -n "$xheads" && "$xheads" == "$RULES_HEADS" ]]
                                               want_ok "R4 docs/rules-explained.md explains the same sections, number for number" $? "$(diff <(printf '%s\n' "$RULES_HEADS") <(printf '%s\n' "$xheads") | grep -c '^[<>]') line(s) differ"
[[ -f "$RF" ]] && ! grep -qE '^@' "$RF" && ! grep -qE '^@docs/' "$ROOT/CLAUDE.md" 2>/dev/null
                                               want_ok "R5 the rules file imports nothing, and nothing imports the explainer" $? ""
missing=$(grep -oE '\[[a-z][a-z'"'"' ]+\]' "$RF" 2>/dev/null | sort -u | while read -r s; do grep -qF -e "**$s:**" "$RL" 2>/dev/null || echo "$s"; done)
[[ -f "$RF" && -f "$RL" && -z "$missing" ]]; want_ok "R6 the local example lists every setting the rules file names" $? "missing: $(echo $missing)"
{ grep -q 'End of relay <project> <label> #N' "$ROOT/docs/drafting-chat-instructions.md" \
  && grep -q 'rules/morrowcairn.md' "$ROOT/docs/drafting-chat-instructions.md"; } 2>/dev/null
                                               want_ok "R7 the chat's half is there, docs/drafting-chat-instructions.md, with the relay's end line and the rules file named" $? ""
{ grep -qE '^owned[[:space:]]+rules/$' "$MANIFEST" && grep -qE '^owned[[:space:]]+docs/$' "$MANIFEST"; } 2>/dev/null
                                               want_ok "R8 the manifest ships rules/ and docs/ in every install" $? ""
# The rules file names the reply file as the reply-file hook builds it: the pattern after [reply folder]/, read
# placeholder by placeholder, gives the hook's name line, its format and its arguments in that order; the hook's own
# comment carries the same pattern, and the rules say lowercase, two digits and the tag kept.
HK="$ROOT/claude-hooks/reply-file"
rfp=$(grep -oE '\[reply folder\]/[A-Za-z0-9<>-]+\.md' "$RF" 2>/dev/null | head -n 1); rfp=${rfp#"[reply folder]/"}
rfl=$(printf '%s\n' "${rfp%.md}" | tr '-' '\n' | awk '
  $0 == "<project>" {f[++k] = "%s"; a[k] = "project.lower()"; next}
  $0 == "<label>"   {f[++k] = "%s"; a[k] = "label.lower()"; next}
  $0 == "<id8>"     {f[++k] = "%s"; a[k] = "session[:8].lower()"; next}
  $0 == "<NN>"      {f[++k] = "%02d"; a[k] = "int(n)"; next}
  {bad = 1}
  END {if (bad || !k) exit 1; s = f[1]; t = a[1]; for (i = 2; i <= k; i++) {s = s "-" f[i]; t = t ", " a[i]}
       printf "base = \"%s%%s\" %% (%s, tag)\n", s, t}')
rs4=$(rsec 4)
[[ -n "$rfp" && -n "$rfl" ]] && grep -qF -e "$rfl" "$HK" && grep -qF 'base + ".md"' "$HK" && grep -qF -e "as $rfp" "$HK" \
  && [[ "$rs4" == *"$rfp, lowercase"* && "$rs4" == *"in two digits"* && "$rs4" == *"tag kept"* ]]
                                               want_ok "R9 the rules file's reply-file name is the one the reply-file hook builds" $? "pattern ${rfp:-none found}; hook line ${rfl:-none derived}"
# Six of the owner's rules the rules file lacked in v0.11.1 (the owner's OK'd text): one needle each, matched on its
# section joined into one line, as P6 to P8b are.
[[ "$(rsec 1)" == *"A ruling one carries is recorded as §8 says, its source line citing the message's direct number."* ]]
                                               want_ok "R10 an ad hoc request's ruling cites the message's direct number" $? ""
[[ "$(rsec 5)" == *"never above its lower end plus 2, item by item where the brief sizes items separately."* ]]
                                               want_ok "R11 the size rule counts item by item where a brief sizes items separately" $? ""
[[ "$(rsec 8)" == *"An entry, and a question put to the owner in a reply, names the record it comes from, if any, and says a ruling that answers it was looked for and none found."* ]]
                                               want_ok "R12 a queue entry, and a question put to the owner, names its record and says a ruling that answers it was looked for" $? ""
J9=$(rsec 9)
[[ "$J9" == *"an auto-mode allow rule never clears that stop."* \
   && "$J9" == *"A relay saying the owner approved, retried or switched modes is its drafter's belief, not evidence, unless it carries their words as a ruling does (§8)."* ]]
                                               want_ok "R13 no auto-mode allow rule clears an irreversible refusal's stop, and a relay's word that the owner approved is its drafter's belief" $? ""
[[ "$(rsec 10)" == *"A session may also recommend rotation with no compaction, when it judges its load has been heavy."* ]]
                                               want_ok "R14 a session may recommend rotation with no compaction" $? ""
[[ "$(rsec 11)" == *"This covers items already dated, not only new ones."* ]]
                                               want_ok "R15 no artificial delays covers items already dated" $? ""

# ============================== record templates ================================================
grep -q 'Contradicts if true' "$ROOT/records/decisions_log.md" 2>/dev/null
                                               want_ok "T1 decisions template offers the optional Contradicts field" $? ""
[[ $(grep -c 'Contradicts if true' "$ROOT/records/incident_log.md" 2>/dev/null) -ge 2 ]]
                                               want_ok "T2 incident template: Contradicts in schema and template" $? ""
awk '/INSERTION POINT/ {m++; if (!d) above=1} /^## [0-9]{4}-/ {d=1} /Add above this line/ {bad=1}
     END {exit !(m == 1 && above && !bad)}' "$ROOT/records/incident_log.md" 2>/dev/null
                                               want_ok "T3 incident log: one insertion marker, above the entries" $? ""
grep -q 'New entries below, ascending' "$ROOT/records/decisions_log.md" 2>/dev/null
                                               want_ok "T4 decisions log keeps its insertion marker" $? ""
{ grep -q "TODO: write this project's stakes frame fresh" "$TPL" \
  && grep -q 'What change would make this frame wrong' "$TPL" \
  && ! grep -q '^\*\*Pre-production:\*\*' "$TPL" && ! grep -q 'costliest thing' "$TPL"; } 2>/dev/null
                                               want_ok "T5 frame item: fresh-frame TODO with question 4, no prewritten options" $? ""
{ grep -q 'UNSET-SEE-REPO-GENESIS' "$ROOT/patterns/repo-genesis.md" \
  && grep -q "SENTINEL='UNSET-SEE-REPO-GENESIS'" "$H/pre-commit"; } 2>/dev/null
                                               want_ok "T6 repo-genesis documents the sentinel the hook enforces" $? ""
grep -qi 'personal data' "$H/README.md" 2>/dev/null
                                               want_ok "T7 leak-detection README states the personal-data limit" $? ""
# The shipped patterns call the list the do-not-publish list; v0.11.0's name for it, the identity list, is gone from them.
n=$(cat "$ROOT"/patterns/*.md 2>/dev/null | grep -ci 'identity list')
[[ "$n" == 0 ]];                               want_ok "PT1 the shipped patterns call the list the do-not-publish list, never the identity list" $? "$n line(s)"
# So does the leak-detection README, but for its note on what v0.11.0's messages called it.
n=$(awk 'tolower($0) ~ /identity list/ && tolower($0) !~ /called the identity list in/ {c++} END {print c+0}' "$H/README.md" 2>/dev/null)
[[ "$n" == 0 ]];                               want_ok "LR1 the leak-detection README calls the list the do-not-publish list; the identity list only in its note on v0.11.0's messages" $? "${n:-no README} line(s)"
# The bullet must describe the layout §1 below it actually uses: the date on the status line, not in
# the heading. A spawn took the v0.2.1 bullet and found it contradicted every entry it had.
{ awk '/^## Conventions/ {c=1} /^---/ {c=0} c && /Entry layout/ {ok=1} END {exit !ok}' "$ROOT/records/decisions_log.md" \
  && ! grep -q 'Title (YYYY-MM-DD)' "$ROOT/records/decisions_log.md" && grep -q '^## §1\. [^(]*$' "$ROOT/records/decisions_log.md"; } 2>/dev/null
                                               want_ok "T8 decisions template documents the entry layout its own §1 uses" $? ""

# ============================== rationale ships with the check; setup text matches the secret policy
! grep -q 'incident_log' "$ROOT/.github/workflows/gitleaks.yml" "$H/pre-push" 2>/dev/null
                                               want_ok "K13 workflow and pre-push carry the range-scan rationale, not a citation" $? ""
{ grep -q "it never holds terms you've agreed or are required to keep confidential" "$ROOT/bin/kit-pin" \
  && grep -q "CI's secret never holds terms you've agreed or are required to keep confidential; those stay" "$H/README.md" \
  && ! grep -q -e 'identify no one' -e "not ones you've agreed" "$ROOT/bin/kit-pin" "$H/README.md" \
  && ! grep -qi 'same value' "$ROOT/bin/kit-pin" "$H/README.md"; } 2>/dev/null
                                               want_ok "K14 setup text: the terms kept confidential stay local, the secret holds none of them" $? ""
{ grep -q 'kit-pin" migrate' "$ROOT/patterns/local-upgrade.md" && grep -q 'kit.forks' "$ROOT/patterns/local-upgrade.md" \
  && grep -q 'read_leak_pattern' "$ROOT/patterns/local-upgrade.md" && grep -q 'local-upgrade.md' "$ROOT/README.md"; } 2>/dev/null
                                               want_ok "K15 local-upgrade moves a project with kit-pin migrate, compares the list reader's value first, keeps declared forks, and the README points at it" $? ""
# The installer is retired (v0.8.0, stage 4): nothing tracked runs or names it, so no instruction sends a reader to it.
out=$(git -C "$ROOT" grep -l 'install_hooks' -- . ':!tests/kit_docs_test.sh' 2>/dev/null)
[[ ! -e "$H/install_hooks.sh" && -z "$out" ]]; want_ok "K22 the installer is gone, and no tracked file names it" $? "$(echo $out)"
{ grep -q 'went stale in the same commit' "$ROOT/patterns/local-spawn.md" && ! grep -qi 'the README warns' "$ROOT/patterns/local-spawn.md"; } 2>/dev/null
                                               want_ok "K17 local-spawn states the inventory reason inline; the kit README does not travel" $? ""
# The setup prompt (docs/setup-prompt.md) installs the release the README installs, from the address the README clones:
# its checkout, install and user steps name that release, and no other release appears in it. It edits no settings
# file, showing the lines instead, and names the IT document.
sprel=$(grep -oE 'git checkout v[0-9]+\.[0-9]+\.[0-9]+' "$ROOT/README.md" 2>/dev/null | head -n 1); sprel=${sprel#git checkout }
spurl=$(grep -oE 'git clone https://[^ `]+' "$ROOT/README.md" 2>/dev/null | head -n 1); spurl=${spurl#git clone }
SPF="$ROOT/docs/setup-prompt.md"
{ [[ -n "$sprel" && -n "$spurl" && -f "$SPF" ]] && grep -qF "git clone $spurl " "$SPF" && grep -qF "checkout $sprel" "$SPF" \
  && grep -qF "tools/install-release.sh $sprel" "$SPF" && grep -qF "releases/$sprel/bin/kit-pin user $sprel" "$SPF" \
  && ! grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$SPF" | grep -qvxF "$sprel" \
  && grep -qF 'Never edit a settings file' "$SPF" && grep -qF 'docs/for-it.md' "$SPF"; } 2>/dev/null
                                               want_ok "SP1 the setup prompt installs the README's release from its address, edits no settings file and names the IT document" $? "release ${sprel:-none found}, address ${spurl:-none found}"
# It finds the organization's settings by reading them, not by asking a person who may not know: /status's Setting
# sources line, the managed files on Linux and WSL, and a remote policy, which only IT can show.
{ grep -qF '/status' "$SPF" && grep -qF 'Setting sources' "$SPF" && grep -qF '/etc/claude-code/managed-settings.json' "$SPF" \
  && grep -qF 'managed-settings.d' "$SPF" && grep -qF '(remote)' "$SPF" \
  && ! grep -qF 'ask me whether my organization' "$SPF"; } 2>/dev/null
                                               want_ok "SP2 the setup prompt reads the managed settings' source from /status and the managed files, asking IT only for what isn't there" $? ""
# It offers the daily load check: the stub copied out of the install, the daily line shown for the person to add, one
# headless Claude Code request a day, a ping only with a ping URL set.
{ grep -qF 'kit-load-check-stub' "$SPF" && grep -qF 'headless' "$SPF" && grep -qF 'KIT_LOAD_CHECK_PING' "$SPF" \
  && grep -qiF 'once a day' "$SPF"; } 2>/dev/null
                                               want_ok "SP3 the setup prompt offers the daily load check, showing its line, its one request a day and its ping" $? ""
# Under a lock on skills it still offers the daily load check, saying the check reads the rules file only: it sees the
# skills linked, not loading, so a lock on skills goes unnoticed by it.
sp8=$(awk '/^8\. / {p=1} /^9\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp8" == *"under a lock on skills too"* && "$sp8" == *"checks the rules file only"* && "$sp8" == *"goes unnoticed by it"* \
   && "$sp8" != *"don't offer it"* ]]
                                               want_ok "SP4 under a lock on skills the setup prompt still offers the daily load check, saying it checks the rules file only" $? "${sp8:0:200}"
# Step 5's kit-pin writes into Claude Code's own folder, which Claude Code's sandbox, where it is on, keeps a session's
# commands out of (measured: the rules, skills and hooks folders): the person runs it in their own terminal and the
# session reads back what it printed. Step 6's copy lands in the same folder, so the person runs it there too.
sp5=$(awk '/^5\. / {p=1} /^6\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
sp6=$(awk '/^6\. / {p=1} /^7\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp5" == *"in my own terminal, outside Claude Code"* && "$sp5" == *"sandbox"* && "$sp5" == *"what it printed"* \
   && "$sp6" == *"in my own terminal"* ]]
                                               want_ok "SP5 the person runs step 5's kit-pin and step 6's copy in their own terminal, the prompt saying why" $? "${sp5:0:200}"
# A refusal is reported when it happens. Only a plain read that needs no review is rerun in a plain form, and saying so;
# once a check refuses a command, anything that writes, deletes or sends waits for the person, in any form. The wait
# follows a refusal only: a model read it as every step and asked before the clone and the install.
sph=$(awk '/^```text$/ {p=1; next} /^1\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sph" == *"at that moment"* && "$sph" == *"plain form, saying so"* \
   && "$sph" == *"Once a check refuses a command, anything that writes, deletes or sends waits for my say, in any form"* \
   && "$sph" == *"the clone and the install among them, go ahead as written"* && "$sph" != *"work around a refusal"* ]]
                                               want_ok "SP6 the setup prompt reports a refusal at once and reruns only a plain read, saying so; after a refusal a write waits, and the steps go ahead as written" $? "${sph:0:200}"
# Step 1 checks each tool by its own version command, one per tool, with no loop and no variable: Claude Code's check
# refused a loop over a variable ("can't be checked before it runs"), and the plain rerun went unreported. It checks
# rather than reports, stopping at the first tool missing or too old: asked twice to repeat the versions before step 2,
# a model let the commands' own output stand. Step 10's summary lists them.
sp1=$(awk '/^1\. / {p=1} /^2\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
sp10=$(awk '/^10\. / {p=1} /^```$/ {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp1" == *"git --version"* && "$sp1" == *"gitleaks version"* && "$sp1" == *"python3 --version"* \
   && "$sp1" == *"sha256sum --version"* && "$sp1" == *"shasum --version"* && "$sp1" == *"no loop and no variable"* \
   && "$sp1" == *"Stop at the first tool that is missing or too old"* && "$sp1" != *"before going on to step 2"* \
   && "$sp1" != *"Report each one's version"* ]]
                                               want_ok "SP7 step 1 checks each tool with its own version command, one per tool, with no loop and no variable, stopping at the first missing or too old" $? "${sp1:0:200}"
[[ "$sp10" == *"summary: the versions step 1 found,"* ]]
                                               want_ok "SP9 step 10's summary lists the versions step 1 found" $? "${sp10:0:200}"
# The opening says the person runs the one command that links the session rules (step 5 has them do it), and step 1
# names the gitleaks the kit is tested with, since only git's minimum is stated and an older gitleaks lacks a command.
spo=$(awk '/^```text$/ {exit} {print}' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$spo" == *"shows you the one command that links the session rules at your user level, which you run in your own terminal"* \
   && "$spo" != *"and links the session rules at your user level"* && "$sp1" == *"gitleaks on PATH (the kit is tested with 8.30.1)"* ]]
                                               want_ok "SP10 the opening has the person run the command that links the session rules; step 1 names the gitleaks tested" $? "${spo:0:200}"
# Step 4 reports the install's last lines as printed, without explaining them: a model explained the hook suite's skips
# wrongly from a comment.
sp4=$(awk '/^4\. / {p=1} /^5\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp4" == *"last lines as it printed them, without explaining them"* ]]
                                               want_ok "SP8 step 4 reports the install's last lines as printed, without explaining them" $? "${sp4:0:200}"
# M1 in an install: an install has no git history of its own, so its skip says where M1 runs instead; "rerun after
# commit one" is for a project. The block is hooks_test's own, run in a folder git finds no repository in.
M=$(mktemp -d); mkdir -p "$M/none"
awk '/^# =+ tracked modes/ {p=1} /^# =+ pre-commit: genesis gates/ {p=0} p' "$ROOT/tests/hooks_test.sh" > "$M/m1.sh" 2>/dev/null
m1run() { ( ROOT="$M/none"; export GIT_CEILING_DIRECTORIES="$M"
            result() { printf 'result %s\n' "$1"; }; skip() { printf 'skip %s -- %s\n' "$1" "$2"; }; . "$M/m1.sh" ) 2>&1; }
m1inst=$(KIT_INSTALL_CHECK=1 m1run); m1proj=$(unset KIT_INSTALL_CHECK; m1run); rm -rf "${M:?}"
[[ "$m1inst" == "skip M1 "*"no git history of its own"*"the kit's repository"* && "$m1inst" != *"rerun after commit one"* \
   && "$m1proj" == "skip M1 "*"rerun after commit one"* ]]
                                               want_ok "M1i an install's M1 skip says it has no git history of its own; a project's says rerun after commit one" $? "install: ${m1inst:0:120}; project: ${m1proj:0:80}"
# The README's Install leads with the setup prompt, its numbered steps what the prompt does by hand; and "Off by
# default" says what the daily load check's line is.
awk '/^\*\*Install\.\*\*/ {i=1} /^\*\*Off by default\.\*\*/ {i=0} i && /setup-prompt\.md/ && !s {s=NR} i && /^1\. / && !c {c=NR}
     END {exit !(s && c && s < c)}' "$ROOT/README.md" 2>/dev/null
                                               want_ok "RM1 the README's Install names the setup prompt before its numbered steps" $? ""
{ awk '/^\*\*Off by default\.\*\*/ {o=1} /^---$/ {o=0} o && /^- \*The daily load check:\*/ {b=1; printf "%s ", $0; next}
       b && (/^- / || /^$/) {b=0} b {printf "%s ", $0}' "$ROOT/README.md" | grep -qiF 'once a day' \
  && ! grep -qF 'a daily line you give its stub' "$ROOT/README.md"; } 2>/dev/null
                                               want_ok "RM2 the README's off-by-default list says what the daily load check's line is" $? ""
# The release-by-release history lives in CHANGELOG.md, every release's entry there and none left in the README, under
# a first line saying that earlier releases' entries keep the list's old name; the README keeps a short Versioning
# paragraph: what a minor and a patch mean for a project, with a link to CHANGELOG.md.
CL="$ROOT/CHANGELOG.md"
{ [[ -f "$CL" ]] && grep -qF 'called the do-not-publish list the identity list' "$CL" && grep -qF 'keep the words of their time' "$CL" \
  && grep -qF 'v0.2.0 is one' "$CL" && grep -qF 'v0.4.1 is one' "$CL" && grep -qF 'v0.11.1 is another' "$CL" \
  && grep -qF 'v0.12.0 is another' "$CL"; } 2>/dev/null
                                               want_ok "CL1 CHANGELOG.md holds every release's entry, under its line on the list's old name" $? ""
# One heading per release, newest first: the first the release the README installs, the last v0.1.0, no version twice,
# each with text under it; above the first, a short introduction holding the general paragraphs (point releases, how
# a project takes one, what a minor and a patch mean), and no stray bold version line.
clh=$(grep -E '^## v[0-9]+\.[0-9]+\.[0-9]+$' "$CL" 2>/dev/null | sed 's/^## v//')
clo=$(printf '%s\n' "$clh" | sort -t. -k1,1nr -k2,2nr -k3,3nr -u)
intro=$(awk '/^## v/ {exit} {print}' "$CL" 2>/dev/null)
empty=$(awk '/^## v/ {if (h && !t) print h; h=$0; t=0; next} h && NF {t=1} END {if (h && !t) print h}' "$CL" 2>/dev/null)
[[ -n "$clh" && "$clh" == "$clo" && "v$(printf '%s\n' "$clh" | head -n 1)" == "$sprel" && "$(printf '%s\n' "$clh" | tail -n 1)" == 0.1.0 \
   && -z "$empty" && "$intro" == *"Point releases are driven by"* && "$intro" == *"A **minor** release"* \
   && "$intro" == *"A **patch**"* ]] && ! grep -qE '^\*\*v[0-9]+\.[0-9]+\.[0-9]+\.\*\*' "$CL" 2>/dev/null
                                               want_ok "CL2 CHANGELOG.md has one heading per release, newest first from the README's release to v0.1.0, each with an entry, under an introduction" $? "headings: $(echo $clh); empty: $empty"
vers=$(awk '/^## Versioning/ {v=1; next} /^## / {v=0} v' "$ROOT/README.md" 2>/dev/null)
[[ -n "$vers" && "$vers" == *"(CHANGELOG.md)"* && "$vers" == *"**minor**"* && "$vers" == *"**patch**"* \
   && "$vers" != *" is one"* && "$vers" != *" is another"* && $(printf '%s\n' "$vers" | grep -c .) -le 8 ]]
                                               want_ok "RM3 the README's Versioning is a short paragraph on minors and patches, linking CHANGELOG.md, with no release's entry" $? "$(printf '%s' "$vers" | head -c 200)"
aip=$(awk '/^## What.s public, and what isn.t$/ {a=1; next} /^## / {a=0} a' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$aip" == *"private repository"* && "$aip" == *"without the working history"* && "$aip" == *"leak in"* \
   && "$aip" != *"credible"* && "$aip" != *"from commit one"* ]]
                                               want_ok "RM4 What's public, and what isn't says the kit is developed privately and its public repository holds each release's files, and keeps leaks both ways" $? "${aip:0:200}"
# Its repo-genesis sentence says what the default path does: the identity git will record is read back before the
# first commit, a local one set first where git's is wrong; the guard that refuses a commit before then is an opt-in.
[[ "$aip" == *"reads back"* && "$aip" == *"identity guard"* && "$aip" == *"an opt-in"* && "$aip" != *"is configured and"* ]]
                                               want_ok "RM9 the README's repo-genesis sentence says the read-back is the default and the identity guard an opt-in" $? "${aip:0:200}"
# The tagline sits under the title, once.
[[ "$(sed -n '3p' "$ROOT/README.md" 2>/dev/null)" == "A cairn is a waymarker built for the next traveler." \
   && "$(grep -c '^A cairn is' "$ROOT/README.md" 2>/dev/null)" == 1 ]]
                                               want_ok "RM7 the README's tagline sits under its title, once" $? ""
# Prune posture says which rules carry a retirement condition and a provenance line (the skills' procedures) and where
# the rules file's reasons are, rather than claiming it of every rule.
pp=$(awk '/^## Prune posture/ {p=1; next} /^## / {p=0} p' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$pp" != *"every rule that ships here carries"* && "$pp" == *"Would revisit if:"* && "$pp" == *"skills/PROVENANCE.md"* \
   && "$pp" == *"docs/rules-explained.md"* ]]
                                               want_ok "RM8 Prune posture says the skills' procedures carry retirement conditions and provenance, and where the rules file's reasons are" $? "${pp:0:200}"
n=$(grep -c 'project-genesis kit' "$ROOT/README.md" 2>/dev/null); op=$(awk '/^\*\*Install\.\*\*/ {exit} {print}' "$ROOT/README.md" 2>/dev/null)
[[ "$n" == 1 && "$op" == *"project-genesis kit"* ]] && ! grep -q '^\*\*Status:' "$ROOT/README.md" 2>/dev/null
                                               want_ok "RM5 the README describes the kit once, in its opening, with no Status line" $? "project-genesis kit: $n"
r34=0
for f in "$ROOT/README.md" "$CL" "$MANIFEST"; do
    [[ -f "$f" ]] || { r34=1; continue; }
    grep -qE '§ ?[0-9]|\bR[0-9]{1,2}\b|\bqueues? [0-9]' "$f" && r34=1
    [[ $(grep -oE '\b[0-9a-f]{7,40}\b' "$f" | grep -c '[0-9]') == 0 ]] || r34=1
done
[[ $r34 == 0 ]];                               want_ok "RM6 the README, CHANGELOG.md and kit-manifest.txt (all three in the public repository) carry no § number, R-label, queue number, commit hash or CI run ID" $? ""
# v0.12.0's entry names the setup prompt and the ping's fixed words, and what kit-pin user links; the v0.11.0 passage
# amended since is marked as a note added in v0.12.0, since entries keep the words of their time.
c12=$(awk '/^## v0\.12\.0$/ {p=1; next} /^## / {p=0} p' "$CL" 2>/dev/null | tr -s ' \n' '  ')
c110=$(awk '/^## v0\.11\.0$/ {p=1; next} /^## / {p=0} p' "$CL" 2>/dev/null | tr -s ' \n' '  ')
[[ "$c12" == *'[`docs/setup-prompt.md`](docs/setup-prompt.md),** a prompt pasted into Claude Code'* \
   && "$c12" == *"ping carries the kit's fixed words alone"* \
   && "$c12" == *"the three skills and the two hooks' scripts into Claude Code's folder"* \
   && "$c110" == *"(A note added in v0.12.0: the org's other hooks stopped running in the project"* ]]
                                               want_ok "CL3 v0.12.0's entry names the setup prompt, the ping's fixed words and the hooks' links; the later note in v0.11.0's says so" $? "${c12:0:120}"
# It says every push needs python3, which finds the list, that a push refuses too from an account the user database
# gives no absolute home, and the two smaller changes that came with it.
[[ "$c12" == *"- **Every push needs python3,** which finds the project's do-not-publish list; without it the push refuses and says why, and so does a push from an account the user database gives no absolute home (in a container, a user with no line in \`/etc/passwd\`). \`kit-pin user\` makes \`~/.config/morrowcairn\` at 700, and the daily load check's probe asks Claude Code not to save its session."* ]]
                                               want_ok "CL4 v0.12.0's entry says every push needs python3, a push from an account with no usable home refuses too, kit-pin user's 700 folder and the probe's unsaved session" $? "${c12:0:120}"
# The README's step 4 says all that kit-pin user writes: the rules file, the skills, the two hooks' scripts, the pin.
rs4=$(awk '/^4\. Load the session rules/ {p=1} p && /^[0-9]+\. / && !/^4\. / {p=0} p' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$rs4" == *"the three triggered skills and the two optional hooks' scripts into Claude Code's folder, writes the kit's user pin"* ]]
                                               want_ok "RM10 the README's step 4 names everything kit-pin user writes" $? "${rs4:0:160}"

# The Monday macOS run skips when main hasn't changed since the last green macOS run.
# Its decision is the mac-gate job's function, taken from the workflow and run here on recorded inputs: one line per
# successful run, newest first, its commit and its macOS suites job's conclusion. It skips only on a match, and runs on
# anything it can't read; the macOS jobs run unless the gate says exactly false, so a gate that never ran skips nothing.
WF="$ROOT/.github/workflows/cross-platform.yml"; W=$(mktemp -d)
awk '/# mac-gate: begin/ {p=1; next} /# mac-gate: end/ {exit} p {sub(/^          /, ""); print}' "$WF" > "$W/mac-gate.sh" 2>/dev/null
A1=$(printf 'a%.0s' {1..40}); B1=$(printf 'b%.0s' {1..40})
gate() {  # MAIN-SHA, then the run lines on stdin: the function's run= line
    bash -c '. "$1" && mac_gate_decide "$2"' _ "$W/mac-gate.sh" "$1" 2>/dev/null | sed -n 's/^run=//p'; }
[[ -s "$W/mac-gate.sh" && "$(printf '%s success\n' "$A1" | gate "$A1")" == false ]]
                                               want_ok "MS1 the last green macOS run on main's commit: the Monday run skips" $? "$(head -c 160 "$W/mac-gate.sh")"
[[ "$(printf '%s success\n' "$B1" | gate "$A1")" == true ]]
                                               want_ok "MS2 main changed since the last green macOS run: it runs" $? ""
[[ "$(printf '' | gate "$A1")" == true ]];    want_ok "MS3 no green macOS run found: it runs" $? ""
[[ "$(printf '%s skipped\n%s success\n' "$A1" "$A1" | gate "$A1")" == false && "$(printf '%s skipped\n%s success\n' "$A1" "$B1" | gate "$A1")" == true ]]
                                               want_ok "MS4 a skipped Monday isn't a green run: the one before it decides" $? ""
[[ "$(printf '%s success\n' "$A1" | gate "not-a-sha")" == true ]]
                                               want_ok "MS5 main's commit unreadable: it runs" $? ""
mg=$(awk '/^  mac-gate:/ {p=1} p && /^  [a-z]/ && !/^  mac-gate:/ {exit} p' "$WF")
for j in suites smoke; do
    jb=$(awk -v j="  $j:" '$0 == j {p=1; next} p && /^  [a-z]/ {exit} p' "$WF")
    [[ "$jb" == *"needs: [mac-gate]"* && "$jb" == *"!cancelled()"* && "$jb" == *"needs.mac-gate.outputs.run != 'false'"* ]] || mg_why+=" [$j isn't wired to the gate]"
done
[[ "$mg" == *"github.event_name == 'schedule'"* && "$mg" == *"actions: read"* && "$mg" != *"write"* ]] || mg_why+=" [the gate job's trigger or permissions]"
[[ -z "${mg_why:-}" ]];                        want_ok "MS6 both macOS jobs run unless the gate says exactly false, and the gate runs on the schedule alone, reading only" $? "${mg_why:-}"
rm -rf "${W:?}"

# ============================== the forge's scanning exclusion ==================================
# The public copy runs GitHub's secret scanning and push protection; the credential fixture's dummy keys would set them
# off. .github/secret_scanning.yml ignores the fixtures folder, GitHub's route for a file of dummy keys, and nothing
# wider: its one setting is paths-ignore with the one entry, and the folder holds the fixture alone. The kit's own
# scans still read the folder.
SSY="$ROOT/.github/secret_scanning.yml"
ssy=$(grep -v -E '^[[:space:]]*(#|$)' "$SSY" 2>/dev/null)
[[ -f "$SSY" && "$ssy" == "paths-ignore:"$'\n''  - "leak-detection/fixtures/**"' ]]
                                               want_ok "K28 .github/secret_scanning.yml ignores exactly leak-detection/fixtures/** and nothing wider" $? "$(printf '%s' "${ssy:-no file}" | tr '\n' '|')"
fx=$(git -C "$ROOT" ls-files -- leak-detection/fixtures)
[[ "$fx" == "leak-detection/fixtures/synthetic_config.txt" ]]
                                               want_ok "K28b the folder it ignores holds the credential fixture and nothing else" $? "$(printf '%s' "$fx" | tr '\n' ' ')"

echo
echo "kit_docs_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

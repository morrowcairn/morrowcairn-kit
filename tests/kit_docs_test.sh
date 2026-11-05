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
# The decision a list records is written without naming any listed term: a record that names one is refused at the
# next push, the decisions log included (measured on a fresh machine's run).
lsp=$(tr -s ' \n' '  ' < "$ROOT/patterns/local-spawn.md" 2>/dev/null)
[[ "$lsp" == *"without naming any listed term"* && "$lsp" == *"how many terms the list holds"* ]]
                                               want_ok "NP7 local-spawn says to record the list's decision without naming any listed term" $? ""
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
# The target is about 200 lines (the owner's §171), so every session reads the whole file; R120 (the decisions log
# §600) lets it stand at 209 with this limit at 210: an addition past 210 needs a trim or a new ruling first.
[[ -f "$RF" && -n "$n" && "$n" -le 210 ]];   want_ok "R1 rules/morrowcairn.md exists and is 210 lines or fewer" $? "lines=${n:-no file}"
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
# Someone who runs no relays is told to follow only what fits them: the preamble says a session that has received no
# relay skips §2 to §4, §10 and §1's numbering of direct messages; §1's direct messages, §3, §4 and §10 each say they
# apply once a session has received a relay; and the explainer gives the reason.
rpre=$(awk '/^## 1\. / {exit} {print}' "$RF" 2>/dev/null | tr -s '[:space:]' ' ')
rapp='This section applies once a session has received a relay.'
[[ "$rpre" == *"An owner may work with Claude Code sessions"* \
   && "$rpre" == *"A session that has received no relay follows all of this file but §2 to §4, §10 and §1's numbering of direct messages, which are for relays."* \
   && "$(rsec 1)" == *"Once a session has received a relay, the owner can still instruct it directly"* \
   && "$(rsec 3)" == " $rapp"* && "$(rsec 4)" == " $rapp"* && "$(rsec 10)" == " $rapp"* ]] \
  && grep -qF 'received no relay' "$RX" 2>/dev/null
                                               want_ok "R16 a session that has received no relay skips the relay sections, each saying so, and the explainer says why" $? ""
# R111 (the decisions log §593): the absence rule carries the user level's grep -v sentence, in short to fit the file's
# 200 lines: through Claude Code's search wrapper, -v under -q or -l, or with its output discarded, exits 0 only if no
# line matches, not if any line doesn't (as the system grep's does), so a -v test calls /usr/bin/grep by its path too.
r7=$(rsec 7)
# Its "its" names the wrapper, so the clause follows "not the system's" and the command grep clause comes last
# (purple's §604, P1).
[[ "$r7" == *'search wrapper, not the system'"'"'s: with `-q`, `-l` or output discarded, its `-v` exits 0 only if no line matches, not if any doesn'"'"'t'* \
   && "$r7" == *'so `-v` goes by path too; and `command grep` takes whichever grep comes first on `PATH`'* \
   && "$r7" == *'called by its path (`/usr/bin/grep`'* ]]
                                               want_ok "R17 the absence rule says the session wrapper's grep -v answers differently, so a -v test calls /usr/bin/grep by path" $? "${r7:0:200}"
# R112 (§593): beside §8's queue lines, an entry that turns out to be the drafter's call may be reassigned by the
# drafter, with its reason, shown in its next Outbox, and the owner can pull it back.
r8=$(rsec 8)
[[ "$r8" == *"reassign an entry that turns out to be the drafter's call"* && "$r8" == *"with its reason"* \
   && "$r8" == *"next Outbox"* && "$r8" == *"pull it back"* \
   && "${r8%%turns out to be the drafter*}" == *"a larger one is the drafter's"* ]]
                                               want_ok "R18 beside the queue lines, the drafter may reassign an entry that is its call, with its reason, in its next Outbox; the owner can pull it back" $? "${r8:0:200}"
# R116 (§596, D12): a check run on a release candidate is internal until re-read on the published release; the
# candidate no longer counts as the surface a measurement is read from.
[[ "$r7" == *'"internal, unverified", and so is a check run on a release candidate until it is re-read on the published release'* \
   && "$r7" != *"before release, the candidate itself, named as such"* ]]
                                               want_ok "R19 a check on a release candidate is internal, unverified, until re-read on the published release" $? "${r7:0:200}"
# R118 (§599, D16) with relay #10's reading: a small or low-risk reversible call the session makes itself and goes on,
# naming each on a "Calls I made:" line of its report, never past a stop, a boundary or what goes to the owner; a larger
# one is the drafter's.
# Relay #13: the drafter's reading widens it to technical calls too; the calls are listed under a heading (§604, P3).
# R125 (§624) and R126, purple's words (§625): the owner's reasons name a call on purpose, no longer on scope, and a
# reversible call is the session's or the drafter's only with none of those reasons.
[[ "$r8" == *"A reversible call, technical or on scope or sequence, that has none of these reasons isn't theirs"* \
   && "$r8" == *"reputation), it is a call on purpose, it touches their ruling"* \
   && "$r8" != *"a call on scope or purpose"* && "$r8" != *"that touches no ruling isn't theirs"* \
   && "$r8" == *"the session makes a small or low-risk one itself and goes on"* \
   && "$r8" == *'listing each in its report under the heading "Calls I made:"'* \
   && "$r8" == *"so the drafter or the owner can undo it"* \
   && "$r8" == *"never past a relay's stop condition, the size rule's stops, a relay's boundary or anything another rule sends to the owner"* \
   && "$r8" == *"a larger one is the drafter's, a technical one included."* ]]
                                               want_ok "R20 a small reversible call the session makes itself, on a Calls I made: line, never past a stop, a boundary or the owner's" $? "${r8:0:200}"
# R119 (§599, D18) with relay #10's reading: a refusal that doesn't make clear which it is about counts as about what
# would be read, which holds for every route; and D32 (R117, §596): keep the work's history.
r9=$(rsec 9)
# Relay #13, the drafter's reading on purple's Q1: as the sentence before it, read or changed.
[[ "$r9" == *"A refusal over what would be read or changed holds for every route; one that doesn't make clear which it is about is taken as about what would be read or changed"* ]]
                                               want_ok "R21 a refusal unclear about its reason is taken as about what would be read, which holds for every route" $? "${r9:0:200}"
[[ "$r9" == *"**Keep the work's history:**"* && "$r9" == *"exact duplicate or kept elsewhere"* && "$r9" == *"never deleted"* \
   && "$r9" == *"A secret's value is kept in no copy (what holds one is removed)"* && "$r9" == *"citing it"* \
   && "$r9" == *"An archive takes the same scans as everything else, run before archiving"* ]]
                                               want_ok "R22 keep the work's history: a delete only of an exact duplicate or a kept copy, else archive, a secret never kept" $? "${r9:0:200}"
# R117 (§596, D33): a report that ends the turn says so in one line.
[[ "$(rsec 11)" == *'A report that ends your turn says so in one line: "Stopped: waiting on", then who or what.'* ]]
                                               want_ok "R23 a report that ends the turn says so in one Stopped: waiting on line" $? "$(rsec 11 | cut -c1-200)"
# R121 (§610): a second report under one relay ends #N-part2, then -part3, so each has its own file, and the reply
# file's name keeps the part tag as it keeps a direct or wake one.
r4=$(rsec 4)
[[ "$r4" == *"a second report under the same relay ends #N-part2, then -part3, so each has its own file"* \
   && "$r4" == *"a direct, wake or part tag kept (-04-direct1, -04-part2)"* ]]
                                               want_ok "R24 a second report under one relay ends #N-part2, its file keeping the part tag" $? "${r4:0:200}"
# Purple's §613 wordings: §4 says a report sent in several messages carries the end line on its last message, so "part"
# keeps one sense (#N-part2); the chat's document checks a report's ends with the part tag beside the direct and wake ones.
dci=$(tr -s ' \n' '  ' < "$ROOT/docs/drafting-chat-instructions.md" 2>/dev/null)
[[ "$r4" == *"A report sent in several messages carries the end line on its last message only."* \
   && "$r4" != *"A report in parts"* \
   && "$dci" == *"with a direct, wake or part tag after N (#N-directM, #N-wake1, #N-part2) for a direct message, a wake-up or a second report under one relay, the two matching."* \
   && "$dci" != *"with a direct or wake tag after N"* ]]
                                               want_ok "R25 a report in several messages ends on its last; the chat's document checks the part tag beside direct and wake" $? "${r4:0:200}"
# The same in the chat's half (R126, purple's §625): a call on purpose goes to the owner, one on scope no longer does;
# a reversible call on scope or sequence is the chat's only with none of the reasons above.
[[ "$dci" == *"when it is a call on purpose, when it touches their ruling"* && "$dci" != *"a call on scope or purpose"* \
   && "$dci" == *"- **A reversible call on scope or sequence with none of the reasons above is the chat's,** flagged as its own."* \
   && "$dci" != *"that touches no ruling is the chat's"* ]]
                                               want_ok "R26 the chat's document: a call on purpose is the owner's; a reversible call on scope or sequence with none of the reasons is the chat's" $? "${dci:0:200}"
# §11's "No idle" bullet, word for word: open items and work that could come next are reported as suggestions, none of
# it started. The explainer's §11 opens with its paragraph, word for word, and holds nothing else before the sentence
# on scheduling, which ends the section, word for word, in the present tense.
r11=$(rsec 11); x11=$(awk 'index($0, "## 11. ") == 1 {s=1; next} s && /^## / {exit} s' "$RX" 2>/dev/null | tr -s '[:space:]' ' ')
[[ "$r11" == *"- **No idle:** when a relay's work is done, never report \"nothing to do\". Report what you are blocked on and who or what unblocks each item, any open items, and work that could come next, as suggestions; start none of it. A report that ends your turn says so in one line: \"Stopped: waiting on\", then who or what. - **No artificial delays:**"* \
   && "$r11" != *"next item"* && "$r11" != *"unblocked items run out"* \
   && "$x11" == " Time and attention are the constraint, so a session never leaves anyone guessing. When its relay's work is done, a session never reports just \"nothing to do\": it says what it is blocked on and who unblocks each item, lists any open items, and suggests work that could come next, starting none of it, so the next request is easy to choose. A report that ends its turn says so in one line, so what it waits on shows at a glance. Nothing is scheduled out without a reason either; a delay needs one: a technical dependency, a run it must ride, a ruling or a test it needs first, or the owner's own availability for an item that needs them. " \
   && "$x11" != *"best-practices"* && "$x11" != *"reversible parts"* ]]
                                               want_ok "R27 No idle reports open items and next work as suggestions, starting none, word for word, and the explainer's §11 paragraph word for word" $? "${r11:0:200}"

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
  && grep -qF 'Never edit a managed settings file' "$SPF" && grep -qF 'never write over a file that is already there' "$SPF" \
  && ! grep -qF 'Never edit a settings file' "$SPF" && grep -qF 'docs/for-it.md' "$SPF"; } 2>/dev/null
                                               want_ok "SP1 the setup prompt installs the README's release from its address, edits no managed settings and no file already there, and names the IT document" $? "release ${sprel:-none found}, address ${spurl:-none found}"
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
# commands out of (measured: the rules, skills and hooks folders). So the session runs it, and where the sandbox blocks
# it, retries it outside the sandbox, which Claude Code asks the person to approve ("Bash command (unsandboxed)", in its
# sandboxing documentation); only where unsandboxed commands are turned off (allowUnsandboxedCommands set false, by IT,
# say) does it hand the person the command, saying why, to type after ! or in a terminal; it reads back what it printed.
sp5=$(awk '/^5\. / {p=1} /^6\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp5" == *"Run it yourself"* && "$sp5" == *"Bash command (unsandboxed)"* && "$sp5" == *"allowUnsandboxedCommands"* \
   && "$sp5" == *"saying why"* && "$sp5" == *"after !"* && "$sp5" == *"what it printed"* \
   && "$sp5" != *"I run it myself, in my own terminal"* ]]
                                               want_ok "SP5 step 5's kit-pin is run by the session, outside the sandbox at Claude Code's prompt where needed, and handed over only where that is off, saying why" $? "${sp5:0:200}"
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
sp10=$(awk '/^12\. / {p=1} /^```$/ {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp1" == *"git --version"* && "$sp1" == *"gitleaks version"* && "$sp1" == *"python3 --version"* \
   && "$sp1" == *"sha256sum --version"* && "$sp1" == *"shasum --version"* && "$sp1" == *"no loop and no variable"* \
   && "$sp1" == *"Stop at the first tool that is missing or too old"* && "$sp1" != *"before going on to step 2"* \
   && "$sp1" != *"Report each one's version"* ]]
                                               want_ok "SP7 step 1 checks each tool with its own version command, one per tool, with no loop and no variable, stopping at the first missing or too old" $? "${sp1:0:200}"
[[ "$sp10" == *"summary: the versions step 1 found,"* ]]
                                               want_ok "SP9 the last step's summary lists the versions step 1 found" $? "${sp10:0:200}"
# The opening says Claude Code leads: the session does each step it may, with the person's approval at Claude Code's
# own prompts, and hands over a command only where it can't, saying why; and step 1 names the gitleaks the kit is tested
# with, since only git's minimum is stated and an older gitleaks lacks a command.
spo=$(awk '/^```text$/ {exit} {print}' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$spo" == *"Claude Code leads"* && "$spo" == *"your approval at Claude Code's own prompts"* \
   && "$spo" == *"only where it can't, saying why"* && "$spo" != *"which you run in your own terminal"* \
   && "$sp1" == *"gitleaks on PATH (the kit is tested with 8.30.1)"* ]]
                                               want_ok "SP10 the opening says Claude Code leads, each step done with the person's approval, a command handed over only where it can't; step 1 names the gitleaks tested" $? "${spo:0:200}"
# Step 4 reports the install's last lines as printed, without explaining them: a model explained the hook suite's skips
# wrongly from a comment.
sp4=$(awk '/^4\. / {p=1} /^5\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp4" == *"last lines as it printed them, without explaining them"* ]]
                                               want_ok "SP8 step 4 reports the install's last lines as printed, without explaining them" $? "${sp4:0:200}"
# The guided setup (v0.12.1): a person who doesn't know the kit's author's way of working was lost at the settings file
# and the last questions. Claude Code asks one plain question at a time, each saying what it's for and what skipping it
# means, with a default to accept; it keeps everything in the Linux home on WSL; it fetches a missing gitleaks only
# against the sha256 the kit pins; the relay settings and hooks only after a yes to relays; it writes the settings file
# itself, never over one; it offers to add each hook to the person's settings or to give the lines; it offers to set up
# the daily check; and, for relays, it prints the chat's half for a claude.ai Project, as it is.
sph2=$(awk '/^```text$/ {p=1; next} /^1\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sph2" == *"one question at a time"* && "$sph2" == *"what it's for and what skipping it means"* \
   && "$sph2" == *"'ok' takes it, 'skip' skips it"* && "$sph2" == *"only when you truly can't, saying why"* ]]
                                               want_ok "SP11 the prompt asks one plain question at a time, saying what each is for and what skipping means, with a default; a command only when the session can't" $? "${sph2:0:200}"
sp3=$(awk '/^3\. / {p=1} /^4\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp3" == *"WSL"* && "$sp3" == *"/mnt/c"* && "$sp3" == *"Linux home"* && "$sp3" == *"Windows tools can change their line endings"* \
   && "$sp3" != *"lose their Linux permissions and line endings"* \
   && "$sp3" == *"Windows side"* && "$sp3" == *"~/morrowcairn-kit"* ]] && grep -qF '~/projects/<name>' "$SPF"
                                               want_ok "SP12 step 3 keeps everything in the Linux home on WSL, never /mnt/c, says why, warns at a Windows-side start, and gives the folders' defaults" $? "${sp3:0:200}"
# The person decides on the download, plainly, with no question about IT's approval: the setup asks for none anywhere
# (the owner's ruling against an IT-approval step); on a no it says what to install and where, and waits.
[[ "$sp4" == *"May I download gitleaks"* && "$sp4" == *"ci/gitleaks.yml"* && "$sp4" == *"sha256"* \
   && "$sp4" == *"what to install and where to get it"* && "$sp4" == *"wait until I say it's there"* \
   && "$sp4" != *"IT"* && "$sp1" == *"unless it is gitleaks"* ]] \
  && ! grep -qE 'IT (lets|allows|approves) |whether (my |your )?IT (lets|allows)' "$SPF" "$ROOT/docs/for-it.md" "$ROOT/CHANGELOG.md"
                                               want_ok "SP13 a missing gitleaks is downloaded only if the person says so, checked against the sha256 the kit pins; on a no, what to install and where; no IT-approval question anywhere" $? "${sp4:0:200}"
sp6=$(awk '/^6\. / {p=1} /^7\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp6" == *"Will you run work through relays"* && "$sp6" == *"If I say no, write no settings file"* \
   && "$sp6" == *"[owner phrase]"* && "$sp6" == *"[reply folder]"* && "$sp6" == *"[relay log]"* && "$sp6" == *"[owner's queue]"* \
   && "$sp6" == *"[compaction log]"* && "$sp6" == *"morrowcairn-local.md"* && "$sp6" == *"never over a file that is already there"* \
   && "$sp6" != *"in my own terminal"* ]]
                                               want_ok "SP14 the relay settings come only after a yes to relays, and the session writes the settings file itself, never over one" $? "${sp6:0:200}"
sp7=$(awk '/^7\. / {p=1} /^8\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp7" == *"add it to my user settings yourself"* && "$sp7" == *"give me the lines to paste"* \
   && "$sp7" == *"my answer at the start"* && "$sp7" != *"I choose"* && "$sp7" == *"Under a lock on hooks"* && "$sp7" == *"/hooks"* ]]
                                               want_ok "SP15 each optional hook follows the person's answer at the start: added to their settings by the session, or the lines given; skipped under a lock on hooks" $? "${sp7:0:200}"
[[ "$sp8" == *"set it up yourself"* && "$sp8" == *"my answer at the start"* && "$sp8" == *"crontab"* \
   && "$sp8" == *"whether a scheduler is running"* ]]
                                               want_ok "SP16 the daily check follows the person's answer at the start: set up by the session, with approval, a scheduler checked first, or each change shown" $? "${sp8:0:200}"
# The person's comfort, asked once (the owner's direction after his second rehearsal): before step 1, one question, the
# session doing every step itself, Claude Code's settings and the crontab included, or showing each change, its default
# "do it for me"; the session then drives the whole setup through its last step, the person reading nothing.
sph3=$(awk '/^```text$/ {p=1; next} /^1\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sph3" == *"Before step 1, ask me once"* && "$sph3" == *"Claude Code's settings, the kit's settings file and your crontab included"* \
   && "$sph3" == *"[do it for me]"* && "$sph3" == *"every later step follows that answer"* \
   && "$sph3" == *"Drive the whole setup"* && "$sph3" == *"without waiting for me to ask"* ]]
                                               want_ok "SP20 the prompt asks the person's comfort once, before step 1, defaulting to doing it all, and drives the setup through its last step" $? "${sph3:0:200}"
# A last step checks it works, the session doing it: the daily check as cron runs it; for relay users, a test relay with
# the session's own ID and a Claude Code color for the reply-file hook, and /compact for the compaction log.
sp11=$(awk '/^11\. / {p=1} /^12\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp11" == *"Check that it works"* && "$sp11" == *"the way cron runs it"* && "$sp11" == *"test relay"* \
   && "$sp11" == *"CLAUDE_CODE_SESSION_ID"* && "$sp11" == *"/color"* && "$sp11" == *"/compact"* \
   && "$sp11" == *"each result plainly"* ]]
                                               want_ok "SP21 a last step checks it works: the daily check as cron runs it, a test relay for the reply-file hook, /compact for the compaction log" $? "${sp11:0:200}"
# On WSL the reply folder alone sits on the Windows side, where a browser attaches its files; code, projects, the clone
# and the install stay in the Linux home; and the daily check runs only while WSL is running.
[[ "$sp3" == *"code, projects, the kit's clone and its install"* && "$sp6" == *"/mnt/c/Users/"* \
   && "$sp6" == *"where a browser attaches files from"* && "$sp8" == *"runs only while WSL is running"* ]]
                                               want_ok "SP22 on WSL, the reply folder's default on the Windows side, the rest in the Linux home, and the daily check only while WSL runs" $? "${sp6:0:200}"
# A copy handed over or made tests whether its destination is there first: cp -n warns on GNU coreutils 9.4 and acts
# differently on a Mac.
grep -qF '[ -e DEST ] && echo "already there: DEST" || cp SRC DEST' "$SPF" && grep -qF 'coreutils 9.4' "$SPF" \
  && ! grep -qE 'cp -n|--no-clobber' "$SPF"
                                               want_ok "SP23 the setup's copies test whether the destination is there first, never cp -n" $? ""
sp10c=$(awk '/^10\. / {p=1} /^11\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp10c" == *"only if I said I'll run work through relays"* && "$sp10c" == *"docs/drafting-chat-instructions.md"* \
   && "$sp10c" == *"as it is"* && "$sp10c" == *"Set project instructions"* ]]
                                               want_ok "SP17 for relay users only, the chat's half is printed as it is, a claude.ai Project the alternative" $? "${sp10c:0:200}"
# The block goes into the account's instructions by default, its first line turning it on only where the person says
# they're working with the kit (the owner's relays come from many projects at once), with no lane question; a Project
# is the alternative. The scope line is the printed header's, not the chat document's.
[[ "$sp10c" == *"Use what follows only in a chat where I say we're working with the Morrowcairn kit"* \
   && "$sp10c" == *"Instructions"* && "$sp10c" == *"Your Claude"* && "$sp10c" != *"lane ["* \
   && "$sp10c" != *"what to call that chat's lane"* ]] && ! grep -qF "working with the Morrowcairn kit" "$ROOT/docs/drafting-chat-instructions.md"
                                               want_ok "SP24 step 10's block goes into the account's instructions, its first line turning it on only where the person says they use the kit; no lane question" $? "${sp10c:0:200}"
# The owner phrase is how a session tells the person's own instructions from pasted text, so it is kept exactly, each
# alternative listed exactly; a run once added "or a close variation".
[[ "$sp6" == *"so they must be exact"* && "$sp6" == *"Record my words exactly as I type them"* \
   && "$sp6" == *"never add \"or a close variation\""* ]]
                                               want_ok "SP25 the owner phrase is recorded exactly, each alternative exactly, never widened" $? "${sp6:0:200}"
# A fresh machine had no git identity, so a first commit failed: the setup checks, asks for one only where git resolves
# none, says a public host shows the email and offers its no-reply address, and never changes one already set (IT may
# have set it).
sp9=$(awk '/^9\. / {p=1} /^10\. / {p=0} p' "$SPF" 2>/dev/null | tr -s ' \n' '  ')
[[ "$sp9" == *"git config user.email"* && "$sp9" == *"no-reply"* && "$sp9" == *"a public host"* \
   && "$sp9" == *"Never change an identity git already resolves"* && "$sp9" == *"my first commit will ask"* ]]
                                               want_ok "SP26 before new projects, a git identity only where git resolves none, its email's visibility said, a no-reply offered" $? "${sp9:0:200}"
# Step 9 says in one plain clause what the do-not-publish list does, so a session has the words: it stops a push that
# carries one of its terms (pre-push), and stops no one writing or committing them locally (pre-commit reads the list
# only to withhold names).
[[ "$sp9" == *"stops a push that carries one of its terms"* && "$sp9" == *"doesn't stop anyone writing or committing them locally"* ]]
                                               want_ok "SP27 step 9 says what the do-not-publish list does: it stops a push carrying a term, not writing or committing one" $? "${sp9:0:200}"
# Claude Code's sandbox, where it is on, may refuse step 9's git config --global (it writes ~/.gitconfig) and fail step
# 11's run of the daily check for its own reasons: each retries outside the sandbox at Claude Code's prompt, as step 5
# does, following the person's answer at the start, and step 11 says which run gave which result.
[[ "$sp9" == *"outside the sandbox"* && "$sp9" == *"Bash command (unsandboxed)"* && "$sp9" == *"~/.gitconfig"* \
   && "$sp11" == *"outside the sandbox"* && "$sp11" == *"Bash command (unsandboxed)"* && "$sp11" == *"which run gave which result"* ]]
                                               want_ok "SP28 steps 9 and 11 retry a sandbox refusal outside the sandbox at Claude Code's prompt, as step 5 does, by the person's answer" $? "${sp9:0:120} / ${sp11:0:120}"
# Step 5's kit-pin user writes into Claude Code's own folder, so it follows the person's answer at the start too: on
# "show me" the person gets the command.
[[ "$sp5" == *"Follow my answer at the start"* && "$sp5" == *"If I said show me, hand me the command"* ]]
                                               want_ok "SP29 step 5 follows the person's answer at the start: on show me, the session hands over kit-pin user's command" $? "${sp5:0:200}"
# Step 9 set both name and email whenever either was missing, which could change one git already resolves (purple's
# §588 note 2): only the missing one is asked for and set, at user scope, and one git resolves at any scope is left.
[[ "$sp9" == *"For each of the two that is missing, and only for it"* && "$sp9" == *"Set only the missing one, at user scope"* \
   && "$sp9" == *"already resolves, at any scope"* && "$sp9" != *"If either is missing, ask me what name and email"* ]]
                                               want_ok "SP30 step 9 asks for and sets only the missing name or email, at user scope, never one git resolves at any scope" $? "${sp9:0:200}"
# Step 7 added the kit's reply-file hook beside any Stop hook already filing reports, so each report could land twice,
# one copy as -resend2 (purple's §589): it looks first, and with one there says so and skips the kit's, unless the
# person asks for both; step 11's test checks that exactly one file appeared, with no -resend copy.
# Hooks come from more places than the settings files (projects, plugins, skills, an admin console), so the session
# asks the person for /hooks, which labels where each comes from, and asks about each Stop hook it lists (purple's
# §602, F4).
[[ "$sp7" == *"ask me to type /hooks"* && "$sp7" == *"labels where each comes from"* \
   && "$sp7" == *"ask me about each Stop hook it lists"* && "$sp7" == *"skip the kit's reply-file hook"* \
   && "$sp7" == *"unless I ask for both"* ]]
                                               want_ok "SP31 step 7 asks for /hooks and about each Stop hook it lists, and skips the kit's beside one already filing reports unless asked for both" $? "${sp7:0:200}"
# Step 11's test passes only with no second hook filing reports anywhere: /hooks again, and every file new in the
# reply folder since the test relay counted by time, not by name (§602, F5).
[[ "$sp11" == *"/hooks"* && "$sp11" == *"count every file that appeared in [reply folder] since the test relay, by its time, not its name"* \
   && "$sp11" == *"exactly one"* && "$sp11" == *"no -new or -resend copy"* ]]
                                               want_ok "SP32 step 11 checks /hooks and counts every new file in the reply folder by time: exactly one" $? "${sp11:0:200}"
# An identity set for some folders by a conditional include, or by the environment, doesn't show in git config from the
# home folder, so the step checks both, by name only, and sets nothing where either is found (§602, F3).
[[ "$sp9" == *"git config --get-regexp '^includeif\.'"* && "$sp9" == *"GIT_AUTHOR_EMAIL"* && "$sp9" == *"GIT_COMMITTER_NAME"* \
   && "$sp9" == *"by name only, never printing a value"* && "$sp9" == *"set nothing"* ]]
                                               want_ok "SP33 step 9 checks git's conditional includes and the identity variables, by name only, and sets nothing where either is found" $? "${sp9:0:200}"
# The documents agree with it: the README's setup paragraph, its CI secret lines, the IT document, the local example and
# v0.12.1's CHANGELOG entry.
rmi=$(awk '/^The usual way is the setup prompt/ {p=1} /^1\. / {p=0} p' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$rmi" == *"with your approval at Claude Code's own prompts"* && "$rmi" == *"Claude Code settings only when you say so"* \
   && "$rmi" != *"editing no settings file itself"* ]]
                                               want_ok "RM11 the README's setup paragraph says the session does each step with approval and edits Claude Code's settings only when asked" $? "${rmi:0:200}"
grep -qF 'reads a repository secret named `LEAK_PATTERN`, which you set' "$ROOT/README.md" && grep -qF 'no kit step sets it' "$ROOT/README.md" \
  && ! grep -qF 'which the setup fills' "$ROOT/README.md"
                                               want_ok "RM12 the README says the person sets CI's LEAK_PATTERN secret, and no kit step does" $? ""
FIT="$ROOT/docs/for-it.md"
grep -qF 'the setup session writes it from the person' "$FIT" && ! grep -qF 'the kit never writes it' "$FIT" \
  && grep -qF 'only where the person asks' "$FIT" && ! grep -qF 'has every person copy it in' "$FIT"
                                               want_ok "FI1 the IT document says the setup writes the local settings, and Claude Code's settings only where the person asks" $? ""
# The removal steps cover what the setup itself may set for the person, a user-scope git identity and gitleaks, how to
# see each and that both are theirs to keep or remove; the identity line no longer says the kit sets none at all.
fit6=$(tr -s ' \n' '  ' < "$FIT")
[[ "$fit6" == *"What the setup may have set for the person"* && "$fit6" == *"is theirs to keep or remove"* \
   && "$fit6" == *'git config --global --show-origin --get user.name'* && "$fit6" == *'git config --global --unset user.name'* \
   && "$fit6" == *'command -v gitleaks'* && "$fit6" != *"The kit sets no commit identity"* ]]
                                               want_ok "FI6 the IT document's removal steps show and remove the setup's user-scope identity and gitleaks, the person's to keep" $? ""
grep -qF 'a missing gitleaks' "$FIT" && grep -qF 'against the sha256 the kit pins' "$FIT"
                                               want_ok "FI2 the IT document names the setup's one download, a missing gitleaks, checked against the sha256 the kit pins" $? ""
grep -qF 'The setup prompt writes this file from your answers' "$ROOT/rules/morrowcairn-local.example.md"
                                               want_ok "LX1 the local example says the setup writes it from the person's answers" $? ""
# As the setup's step 6 does it: itself, at Claude Code's prompt, for someone who asked it to do the steps, or by a
# copy command handed over, for someone who asked to be shown each change.
lx2=$(tr -s ' \n' '  ' < "$ROOT/rules/morrowcairn-local.example.md")
[[ "$lx2" == *"if you asked it to do the setup's steps for you"* && "$lx2" == *"handing you one command that copies it there"* \
   && "$lx2" != *"with Claude Code's approval prompt"* ]]
                                               want_ok "LX2 the local example says the setup writes it itself or hands over a copy command, as the person answered" $? "${lx2:0:200}"
c121=$(awk '/^## v0\.12\.1$/ {p=1; next} /^## v/ {p=0} p' "$ROOT/CHANGELOG.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$c121" == *"v0.12.1 is another, a patch"* && "$c121" == *"one question at a time"* && "$c121" == *"patterns/practices.md"* \
   && "$c121" == *"sets the CI secret"* && "$c121" == *"v0.12.0's stub put it on curl's command line"* \
   && "$c121" == *"asks you once"* && "$c121" == *"checks that it works"* ]]
                                               want_ok "CL5 v0.12.1's entry names the guided setup, says v0.12.0 added patterns/practices.md, and the person sets CI's secret" $? "${c121:0:200}"
# gitleaks put in ~/.local/bin is found by the install that follows, whose own hook suite needs it on PATH, and the
# person learns whether new terminals will find it (Ubuntu's login profile adds that folder when it exists; macOS's
# default PATH has none in the home). The daily check's ping link reaches the stub only through its environment, so the
# person adds it to the scheduled line themselves, never through the conversation, and the line is then a private one.
[[ "$sp4" == *"with ~/.local/bin at the front of PATH"* && "$sp4" == *"whether my new terminals will find gitleaks"* \
   && "$sp4" == *"~/.profile"* ]]
                                               want_ok "SP18 step 4 runs the install with ~/.local/bin on PATH and says whether new terminals will find gitleaks" $? "${sp4:0:200}"
# A job's command line is readable by every local user while it runs, its environment by its owner alone; so the link
# goes on a crontab line of its own, above the check's, which crontab(5) makes part of the environment of the jobs after it.
[[ "$sp8" == *"KIT_LOAD_CHECK_PING=<my URL> on a line of its own"* && "$sp8" == *"above the check's line"* \
   && "$sp8" == *"never at the start of the check's line"* && "$sp8" == *"reaches any later job"* \
   && "$sp8" == *"a link to keep private"* && "$sp8" == *"I add it myself"* && "$sp8" != *"at the start of that line"* ]] \
  && grep -E '^\| the person.s crontab' "$FIT" 2>/dev/null | grep -qF 'on a line of its own above that line'
                                               want_ok "SP19 step 8's ping link goes on a crontab line of its own above the check's, added by the person, never in the job's line; the IT document's row says so" $? "${sp8:0:200}"
rmi3=$(awk '/^The usual way is the setup prompt/ {p=1} /^1\. / {p=0} p' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$rmi3" == *"asks you once whether it should do every step itself"* && "$rmi3" == *"checks that it works"* ]]
                                               want_ok "RM14 the README's setup paragraph says the setup asks once how much it may do, then drives to a check that it works" $? "${rmi3:0:200}"
fit4=$(grep -E '^\| ' "$FIT" 2>/dev/null)
[[ "$fit4" == *"the person's answer to the setup's first question"* ]] && grep -qF '/mnt/c/Users/' "$FIT" 2>/dev/null
                                               want_ok "FI4 the IT document says the setup's writes follow the person's answer to its first question, and where the reply folder sits on WSL" $? ""
# WSL2 as measured, not "not yet tested": two Windows machines, Ubuntu 24.04 and 26.04 under WSL2; the setup end to end;
# the five suites green on 26.04 with uutils; the Windows side's costs; an organization-managed machine not measured.
wsr=$(tr -s ' \n' '  ' < "$ROOT/README.md"); wsi=$(tr -s ' \n' '  ' < "$FIT"); wsc=$(tr -s ' \n' '  ' < "$ROOT/CLAUDE.md")
wsl121=$(awk '/^## v0\.12\.1$/ {p=1; next} /^## v/ {p=0} p' "$ROOT/CHANGELOG.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$wsr" != *"where it hasn't yet run"* && "$wsr" == *"Ubuntu 24.04 and 26.04"* && "$wsr" == *"3 to 5 times slower"* \
   && "$wsr" == *"an organization manages"* && "$wsi" != *"**Not yet tested**: a rehearsal"* && "$wsi" != *"(below, **not yet tested**)"* \
   && "$wsi" == *"uutils"* && "$wsi" == *"3 to 5 times slower"* && "$wsi" == *"Ubuntu 26.04"* && "$wsc" == *"Windows, inside WSL2"* \
   && "$wsc" == *"Ubuntu 26.04"* && "$wsl121" == *"WSL2"* && "$wsl121" == *"3 to 5 times slower"* ]]
                                               want_ok "WS1 README, the IT document, CLAUDE.md and v0.12.1's entry give WSL2 as measured on two machines, its costs, and what isn't measured" $? ""
# Which setup ran where: v0.12.0's setup prompt on the 24.04 laptop, a draft of v0.12.1's on the 26.04 desktop, both
# installing v0.12.0's code; "the setup ran end to end" alone read as this release's. The README and the IT document
# name v0.12.1, since from v0.13.0 on "this release's" would name the wrong one; v0.12.1's own entry keeps its words.
[[ "$wsr" == *"v0.12.0's setup prompt on the 24.04 laptop"* && "$wsr" == *"a draft of v0.12.1's on the 26.04 desktop"* \
   && "$wsr" != *"a draft of this release's"* \
   && "$wsr" == *"both installing v0.12.0's code"* && "$wsl121" == *"where v0.12.0's setup prompt ran"* \
   && "$wsl121" == *"where a draft of this release's setup prompt ran end to end"* && "$wsl121" == *"both installing v0.12.0's code"* \
   && "$wsi" == *"where v0.12.0's setup prompt ran"* && "$wsi" == *"where a draft of v0.12.1's setup prompt ran end to end"* \
   && "$wsi" != *"a draft of this release's"* ]]
                                               want_ok "WS2 README, the IT document and v0.12.1's entry say which setup prompt ran on which machine, both installing v0.12.0's code" $? ""
# What v0.12.1 changes beyond the documents, as the IT document says it: pre-push (a gate, in how it writes two counts),
# the load check's stub, the reply-file hook, the three test suites an install carries, and the deploy pattern.
[[ "$wsi" != *"changes only the load check's stub"* && "$wsi" == *"v0.12.1 changes pre-push, a gate"* \
   && "$wsi" == *"the load check's stub"* && "$wsi" == *"the reply-file hook"* \
   && "$wsi" == *"the three test suites an install carries"* && "$wsi" == *"the deploy pattern"* ]]
                                               want_ok "FI5 the IT document says what v0.12.1 changes: pre-push, the stub, the reply-file hook, three suites, the deploy pattern, the documents" $? ""
# What v0.13.0 changes against v0.12.1, in a section of its own: pre-push and kit-pin, each a gate; the reply-file
# hook's names; the session rules; the setup prompt; the three test suites an install carries; and the documents.
fi7=$(awk '/^## What this release changes$/ {p=1; next} /^## / {p=0} p' "$FIT" 2>/dev/null | tr -s ' \n' '  ')
[[ "$fi7" == *"v0.13.0, against v0.12.1"* && "$fi7" == *"pre-push, a gate"* && "$fi7" == *"linked worktree"* \
   && "$fi7" == *"kit-pin, a gate"* && "$fi7" == *"grafts"* && "$fi7" == *"doesn't compile"* && "$fi7" == *"-part2"* \
   && "$fi7" == *"-new2"* && "$fi7" == *"The session rules"* && "$fi7" == *"The setup prompt"* \
   && "$fi7" == *"the three test suites an install carries"* ]]
                                               want_ok "FI7 the IT document lists what v0.13.0 changes: pre-push, kit-pin, the reply-file hook's names, the rules, the setup prompt, three suites" $? "${fi7:0:200}"
# This release's line, ahead of v0.13.0's list in the same section: that one sentence and nothing else.
fi131=$(awk '/^## What this release changes$/ {p=1; next} /^v0\.13\.0, against v0\.12\.1/ {p=0} p' "$FIT" 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
[[ "$fi131" == "Wording only, in the session rules; no code changed." ]]
                                               want_ok "FI8 the IT document's line for this release, ahead of v0.13.0's list, is that sentence alone" $? "${fi131:0:200}"
# v0.12.1's entry names the two code changes this relay adds: the reply-file hook matching a path line whole when the
# reply folder's path holds a space, and the deploy pattern's headroom line, which GNU df refused.
[[ "$wsl121" == *"the reply-file hook"* && "$wsl121" == *"a space"* && "$wsl121" == *"options -P and --output are mutually exclusive"* \
   && "$wsl121" == *"df -Pk"* ]]
                                               want_ok "CL6 v0.12.1's entry names the reply-file hook's path match with a space and the deploy pattern's df line" $? "${wsl121:0:200}"
# v0.13.0's entry, which was the Unreleased section: a minor, taken with kit-pin to, naming each change, kit-pin's
# compile check of the list and its dropping of inherited git settings among them (built before v0.12.1 shipped).
c130=$(awk '/^## v0\.13\.0$/ {p=1; next} /^## v/ {p=0} p' "$ROOT/CHANGELOG.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$c130" == *"v0.13.0 is another, a minor"* && "$c130" == *"kit-pin to v0.13.0"* && "$c130" == *"A push from a linked worktree"* \
   && "$c130" == *"kit-pin refuses a repository with grafts"* && "$c130" == *"a list that doesn't compile"* \
   && "$c130" == *"inherited"* && "$c130" == *"Additions to the session rules"* && "$c130" == *"-part2"* \
   && "$c130" != *"On the way to the next release"* \
   && "$c130" == *"The file stands at 210 lines, its check's limit."* && "$c130" != *"209 lines"* \
   && "$c130" == *"with the warning only where one isn't a tag the rules name."* ]]
                                               want_ok "CL7 v0.13.0's entry is a minor taken with kit-pin to, naming the worktree push, grafts, the compile check, the rules and the hook's names" $? "${c130:0:200}"
# v0.13.1's entry is one sentence and nothing else.
c131=$(awk '/^## v0\.13\.1$/ {p=1; next} /^## v/ {p=0} p' "$ROOT/CHANGELOG.md" 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
[[ "$c131" == "Wording only, in the session rules; no code changed." ]]
                                               want_ok "CL8 v0.13.1's entry is that one sentence alone" $? "${c131:0:200}"
rmi2=$(awk '/^The usual way is the setup prompt/ {p=1} /^1\. / {p=0} p' "$ROOT/README.md" 2>/dev/null | tr -s ' \n' '  ')
[[ "$rmi2" == *"If you say you'll run work through relays, it writes the kit's settings file"* ]]
                                               want_ok "RM13 the README's setup paragraph writes the settings file only for someone who says they'll run relays" $? "${rmi2:0:200}"
fit=$(grep -E '^\| ' "$FIT" 2>/dev/null)
[[ "$fit" == *'`~/.local/bin/gitleaks`'* && "$fit" == *'load-check/kit-load-check-stub'* && "$fit" == *'crontab'* \
   && "$fit" == *'`~/.claude/settings.json`'* ]]
                                               want_ok "FI3 the IT document's file table names what the setup writes at the person's say: gitleaks, the stub's copy, the crontab line, the hooks' entries" $? ""
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

# ============================== head and tail counts, the -n form ===============================
# head's and tail's count written straight after the command name (a minus or a plus, then digits) is the obsolete
# form: POSIX replaced it with -n, and uutils' tail, Ubuntu 26.04's default, has been reported refusing one. Every
# shipped file and every suite writes the count with -n (tail's from-line form as -n +N). obsolete_ht prints the
# path and line of each use in the files it is given, never the line itself.
obsolete_ht() { LC_ALL=C grep -a -H -n -E '(^|[^[:alnum:]_.-])(head|tail)[[:space:]]+[-+][0-9]' "$@" 2>/dev/null | cut -d: -f1,2; }
# The files: every tracked file the manifest doesn't keep in the kit (the first entry that matches decides, as the
# install's reader does), and every file under tests/, the kit-only suites included.
ht_files=()
while IFS= read -r f; do ht_files+=("$f"); done < <(git -C "$ROOT" ls-files | awk '
    NR == FNR { if (/^[^#]/ && NF == 2) { c[++n] = $1; e[n] = $2 } next }
    { k = "owned"; for (i = 1; i <= n; i++) if ($0 == e[i] || (substr(e[i], length(e[i])) == "/" && index($0, e[i]) == 1)) { k = c[i]; break }
      if (k != "kit" || index($0, "tests/") == 1) print }' "$MANIFEST" -)
ht=""; (( ${#ht_files[@]} > 50 )) && ht=$( (cd "$ROOT" && obsolete_ht "${ht_files[@]}" </dev/null) | tr '\n' ' ')
(( ${#ht_files[@]} > 50 )) && [[ -z "$ht" ]]
                                               want_ok "HT1 no shipped file or suite writes head's or tail's count in the obsolete form (head -N, tail -N, tail +N)" $? "${ht:-none}(${#ht_files[@]} files)"
# The matcher itself, on planted lines: the three obsolete forms caught, the -n forms and other flags passed. The
# planted command names come from variables, so this file's own text never holds the form it looks for.
W=$(mktemp -d); hd=head; tl=tail
printf '%s\n' "a | $hd -1" "b | $tl -3" "c | $tl +2" "d | $hd -n 1" "e | $tl -n 3" "f | $tl -n +2" "g | $hd -c 4" \
    "h=\$(x | $tl -n 1)" "i  $hd -40)" > "$W/p.sh"
ht=$(obsolete_ht "$W/p.sh" | tr '\n' ' ')
[[ "$ht" == "$W/p.sh:1 $W/p.sh:2 $W/p.sh:3 $W/p.sh:9 " ]]
                                               want_ok "HT1b the matcher catches head -N, tail -N and tail +N, and passes -n N, -n +N and -c" $? "${ht:-none}"
rm -rf "${W:?}"

# ============================== the deploy pattern, run =========================================
# patterns/atomic_deploy.sh read its headroom with df's -P and --output together, which GNU df refuses ("options -P and
# --output are mutually exclusive"), so on GNU it stopped before any transfer, whatever came after df. Run here in
# scratch, by this machine's own tools: a new artifact swapped over an old one, through to the smoke gate, a stand-in
# smoke_check on PATH passing only when the live file holds the new artifact.
W=$(mktemp -d); mkdir -p "$W/bin" "$W/live"
printf 'new artifact\n' > "$W/new.txt"; printf 'old artifact\n' > "$W/live/app.txt"
printf '#!/bin/sh\n[ "$(cat "$1")" = "new artifact" ]\n' > "$W/bin/smoke_check"; chmod +x "$W/bin/smoke_check"
out=$(cd "$W" && env PATH="$W/bin:$PATH" TARGET="$W/live/app.txt" bash "$ROOT/patterns/atomic_deploy.sh" "$W/new.txt" 2>&1); rc=$?
[[ $rc -eq 0 && "$(cat "$W/live/app.txt")" == "new artifact" && ! -e "$W/live/app.txt.new" \
   && "$out" == *"smoke gate"* && "$out" == *"SUMMARY: deploy complete, smoke gate green"* ]]
                                               want_ok "DP1 the deploy pattern runs here through its headroom line and swap to a green smoke gate" $? "exit $rc: $out"
rm -rf "${W:?}"

echo
echo "kit_docs_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

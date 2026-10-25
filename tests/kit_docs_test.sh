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
TPL="$ROOT/templates/CLAUDE.md"     # the spawn template; the kit's own CLAUDE.md is the kit's (decisions log §49)
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
for f in kit-manifest.txt README.md tests/kit_docs_test.sh CLAUDE.md; do
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
# moves both together; its scan runs that gitleaks from the PATH, never one fetched into the checkout (decisions log
# §69, §98, §103).
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
E=$(mktemp -d); IROOT="$E/releases"; KK="$E/kit"; INST="$IROOT/v1.0.0"; why_install=""
if ! command -v gitleaks >/dev/null 2>&1; then
    why_install="gitleaks is not on PATH: a project's pre-commit refuses without it"
elif ! { git init -q -b main "$KK" && git -C "$ROOT" checkout-index -a --prefix="$KK/" \
         && printf '#!/usr/bin/env bash\necho "hooks_test: a stand-in"\n' > "$KK/tests/hooks_test.sh" \
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
    # Its identity list and the list's pin, as leak-detection/README.md's Setup writes them (a stand-in list); then check
    # passes, where it finishes with exit 3 while every push would be refused (decisions log §112).
    [[ -n "$why" ]] || { printf "LEAK_PATTERN='%s'\n" "zqdocsmarker" > "$SP/.git/leak-pattern" \
        && (cd "$SP" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" repin local --first) > "$E/pin.log" 2>&1; } \
        || why="the project's list could not be pinned: $(grep -m 1 REFUSING "$E/pin.log")"
    [[ -n "$why" ]] || (cd "$SP" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) > "$E/check.log" 2>&1 \
        || why="kit-pin check failed: $(grep -m 1 -E 'REFUSING|exit 3' "$E/check.log")"
fi
[[ -z "$why" ]];                               want_ok "K19 a project made by local-spawn from an install commits through the stubs, frame TODO refused first, and holds no kit-owned file" $? "$why"

# The same block where a stock Mac stands: shasum and no sha256sum, then neither. Each PATH holds a link to every
# command on PATH but the ones left out (install_test's pathless), each left out with its .exe, which Git Bash runs by
# the bare name (decisions log §102); with neither, the block stops before DST is made.
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
# move takes (decisions log §112).
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

# local-upgrade's move on a project made before v0.8.0 that holds a doctrine copy changed since its spawn (queue 499;
# beneforth met it at v0.9.0). The move's commit runs through the stubs, whose copies layer refuses a kit-owned copy that
# differs from the release, so the move brings the doctrine copies to the release's in that commit; step 3 removes
# them once the user level imports the doctrine.
UO="$E/older-doctrine"; why="$why_install"
ublock '### 2. Move onto the install' | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$UO'|" > "$E/move-doctrine.sh"
if [[ -n "$why" ]]; then :
elif ! { git init -q -b main "$UO" && git -C "$UO" config user.name t && git -C "$UO" config user.email t@invalid.local \
         && mkdir -p "$UO/leak-detection" "$UO/skills" \
         && install -m 0755 "$INST/leak-detection/pre-commit" "$INST/leak-detection/pre-push" "$UO/leak-detection/" \
         && install -m 0644 "$INST/skills/shell-commands.md" "$UO/skills/" && echo "an older rule" >> "$UO/skills/shell-commands.md" \
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
    [[ -n "$why" ]] || cmp -s "$UO/skills/shell-commands.md" "$INST/skills/shell-commands.md" || why="the doctrine copy is not the release's"
    [[ -n "$why" ]] || (cd "$UO" && KIT_INSTALL_ROOT="$IROOT" "$INST/bin/kit-pin" check) >/dev/null 2>&1 || why="kit-pin check failed after the move"
fi
[[ -z "$why" ]];                               want_ok "U8 local-upgrade's move on a project holding a changed doctrine copy commits through the stubs, the copy now the release's" $? "$why"

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
n=$(grep -c '^@' "$ROOT/CLAUDE.md" 2>/dev/null); out=$(bad_imports "$ROOT/CLAUDE.md")
[[ "$n" -ge 2 && -z "$out" ]];                 want_ok "P1 the kit's own CLAUDE.md imports the always-on doctrine, and every import names a tracked file" $? "imports=$n missing=$out"
# The template imports none: a project holds no copy of the doctrine, which loads once, at user level (§48, §49).
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
# Every numbered procedure has a retirement condition and a provenance line.
bad=$(for s in "$ROOT"/skills/*.md "$ROOT"/.claude/skills/*/SKILL.md; do
          [[ -f "$s" ]] || continue
          awk '/^## [0-9]+\. / {if (p && !w) print p; p = $2; sub(/\.$/, "", p); w = 0} /^\*\*Would revisit if:\*\*/ {w = 1}
               END {if (p && !w) print p}' "$s"
          grep -oE '^## [0-9]+\.' "$s" | grep -oE '[0-9]+' | while read -r k; do
              grep -qE "^- $k: " "$ROOT/skills/PROVENANCE.md" 2>/dev/null || echo "provenance $k"; done
      done)
n=$(cat "$ROOT"/skills/*.md "$ROOT"/.claude/skills/*/SKILL.md 2>/dev/null | grep -cE '^## [0-9]+\. ')
[[ "$n" -ge 9 && -z "$bad" ]];                 want_ok "P3 every numbered procedure has a Would-revisit line and a provenance line" $? "procedures=$n missing=$bad"
grep -q "run by the kit's operator" "$ROOT/skills/README.md" 2>/dev/null && ! grep -q 'arriving after the extraction' "$ROOT/skills/README.md" \
    && ! grep -q 'the projects the kit was' "$ROOT/skills/README.md"
                                               want_ok "P4 skills/README states the evidence rule: spawns or projects run by the kit's operator" $? ""
# The size procedure's lower-end cap, its schema-change sentence (§85: a change after which reverting the code alone
# would leave existing data unreadable) and the project's-own-bar clause "report a conflict" (§23 item 6; design c).
{ grep -q 'lower end plus 2' "$ROOT/skills/working-from-a-brief.md" \
  && grep -q 'existing data unreadable' "$ROOT/skills/working-from-a-brief.md" \
  && awk '/^## Where a project sets its own bar/ {s=1; next} s && /^## / {exit} s && /never reconcile it silently/ {f=1} END {exit !f}' \
         "$ROOT/skills/working-from-a-brief.md"; } 2>/dev/null
                                               want_ok "P6 working-from-a-brief carries the lower-end cap, the schema-change sentence, and says to report a conflict, never reconcile it silently" $? ""
# The daily load check finds each always-loaded file by one canary of its own: a visible line, since Claude Code drops
# HTML comments from what it loads (§49), and one per file, so a dropped file can't hide behind another.
c1=$(grep -oE 'kc-[0-9a-f]{16}' "$ROOT/skills/working-from-a-brief.md" 2>/dev/null); c2=$(grep -oE 'kc-[0-9a-f]{16}' "$ROOT/skills/shell-commands.md" 2>/dev/null)
[[ $(printf '%s\n' "$c1" | grep -c .) -eq 1 && $(printf '%s\n' "$c2" | grep -c .) -eq 1 && "$c1" != "$c2" ]] \
    && ! grep -B1 -A1 -E 'kc-[0-9a-f]{16}' "$ROOT/skills/working-from-a-brief.md" "$ROOT/skills/shell-commands.md" | grep -q '<!--'
                                               want_ok "K23 each always-loaded skill carries one load canary of its own, on a visible line" $? ""
for s in working-from-a-brief shell-commands; do
    grep -E '^\*\*Loaded:\*\*' "$ROOT/skills/$s.md" 2>/dev/null | grep -q 'user-level'
                                               want_ok "K24 skills/$s.md says it loads at user level, once" $? ""
done
# Rule 6's end line and its numbering cases (§23 items 4 and 5).
{ grep -q 'End of relay' "$ROOT/patterns/numbered-relays.md" && grep -q 'Supersedes #N' "$ROOT/patterns/numbered-relays.md" \
  && grep -qi 'above #1' "$ROOT/patterns/numbered-relays.md"; } 2>/dev/null
                                               want_ok "K25 numbered-relays carries the end line and the numbering cases" $? ""
awk '/^## Where a project sets its own bar/ {s=1; next} s && /^## / {exit} s && /^\*\*Would revisit if:\*\*/ {w=1} END {exit !w}' \
    "$ROOT/skills/working-from-a-brief.md" 2>/dev/null && grep -q '^- Precedence: ' "$ROOT/skills/PROVENANCE.md" 2>/dev/null
                                               want_ok "P5 the project's-own-bar section has a Would-revisit line and a provenance line" $? ""
# Procedure 10 (§83): the report's compaction line, the log reading optional and labelled unconfirmed, the handoff
# rewrite before each report, and reprints copied verbatim. The kit ships no compaction hook, so the text must say so.
# The phrases are matched on the section joined into one line: the skill wraps at 100 columns, and a phrase split
# across a line break is still the phrase (the first run of this case missed one that way).
W=$(mktemp); awk '/^## 10\. Compaction, rotation and the handoff file/ {s=1; next} s && /^## / {exit} s' \
    "$ROOT/skills/working-from-a-brief.md" > "$W" 2>/dev/null
J=$(tr -s '[:space:]' ' ' < "$W")
{ grep -q 'compacted since its previous report' <<<"$J" && grep -q 'labelled unconfirmed' <<<"$J" && grep -q 'ships no such hook' <<<"$J" \
  && grep -q 'rewrites its handoff file' <<<"$J" && grep -q 'verbatim' <<<"$J" && grep -q '^\*\*Would revisit if:\*\*' "$W"; } 2>/dev/null
                                               want_ok "P7 working-from-a-brief's procedure 10 carries the compaction line, the log reading optional, the handoff rewrite and verbatim reprints" $? ""
rm -f "$W"
# Procedure 11 (§84): a search that may conclude "none found" uses a search shown to include gitignored and hidden
# files, names it in the report, and the text says which of the session's own tools skip such files. Since §155 its
# grep forms run under LC_ALL=C on every platform, for BSD grep's miss in a UTF-8 locale, and it says what -i
# does to a term with a non-ASCII letter there. Matched on the section joined into one line, as P7.
W=$(mktemp); awk '/^## 11\. / {s=1; next} s && /^## / {exit} s' "$ROOT/skills/shell-commands.md" > "$W" 2>/dev/null
J=$(tr -s '[:space:]' ' ' < "$W")
{ grep -q 'none found' <<<"$J" && grep -q 'gitignored' <<<"$J" && grep -q 'non-UTF-8' <<<"$J" \
  && grep -q 'exit status of each' <<<"$J" \
  && grep -q 'command grep under LC_ALL=C' <<<"$J" && grep -q 'on every platform' <<<"$J" \
  && grep -q 'BSD grep' <<<"$J" && grep -q 'folds case only for ASCII' <<<"$J" && grep -q 'non-ASCII letter' <<<"$J" \
  && grep -q 'ripgrep only with --text --hidden --no-ignore' <<<"$J" \
  && grep -q 'Never grep -I' <<<"$J" && grep -q 'Exit status 2' <<<"$J" \
  && grep -q 'never prints matching lines' <<<"$J" && grep -q -e '-a included' <<<"$J" \
  && grep -q "Bash tool" <<<"$J" && grep -q 'Explore subagents' <<<"$J" \
  && grep -q '^\*\*Would revisit if:\*\*' "$W"; } 2>/dev/null
                                               want_ok "P8 shell-commands' procedure 11 names the exit status of each search command, the forms that cover binary and non-UTF-8 files (-l,-c,-q,-a under LC_ALL=C on every platform, for BSD grep, with what -i does to a non-ASCII letter there; ripgrep --text --hidden --no-ignore), never grep -I, what status 2 means, and that an identity-list search never prints matching lines" $? ""
rm -f "$W"
# The operator's close prompt, a triggered skill (§106): its key phrases, matched on the file joined into one line as
# P7, and its row in skills/README.md.
J=$(tr -s '[:space:]' ' ' 2>/dev/null < "$ROOT/.claude/skills/session-close/SKILL.md")
{ grep -q 'finished but not shipped' <<<"$J" && grep -q 'Five is a ceiling' <<<"$J" \
  && grep -qF '| `.claude/skills/session-close/SKILL.md` |' "$ROOT/skills/README.md"; } 2>/dev/null
                                               want_ok "K27 the session-close skill carries its key phrases, and skills/README lists it" $? ""

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
# The bullet must describe the layout §1 below it actually uses: the date on the status line, not in
# the heading. A spawn took the v0.2.1 bullet and found it contradicted every entry it had.
{ awk '/^## Conventions/ {c=1} /^---/ {c=0} c && /Entry layout/ {ok=1} END {exit !ok}' "$ROOT/records/decisions_log.md" \
  && ! grep -q 'Title (YYYY-MM-DD)' "$ROOT/records/decisions_log.md" && grep -q '^## §1\. [^(]*$' "$ROOT/records/decisions_log.md"; } 2>/dev/null
                                               want_ok "T8 decisions template documents the entry layout its own §1 uses" $? ""

# ============================== rationale ships with the check; setup text matches the secret policy
! grep -q 'incident_log' "$ROOT/.github/workflows/gitleaks.yml" "$H/pre-push" 2>/dev/null
                                               want_ok "K13 workflow and pre-push carry the range-scan rationale, not a citation" $? ""
{ grep -q 'identify no one' "$ROOT/bin/kit-pin" && grep -q 'identify no one' "$H/README.md" \
  && ! grep -qi 'same value' "$ROOT/bin/kit-pin" "$H/README.md"; } 2>/dev/null
                                               want_ok "K14 setup text: identity terms local only, the secret holds non-identity terms" $? ""
{ grep -q 'kit-pin" migrate' "$ROOT/patterns/local-upgrade.md" && grep -q 'kit.forks' "$ROOT/patterns/local-upgrade.md" \
  && grep -q 'read_leak_pattern' "$ROOT/patterns/local-upgrade.md" && grep -q 'local-upgrade.md' "$ROOT/README.md"; } 2>/dev/null
                                               want_ok "K15 local-upgrade moves a project with kit-pin migrate, compares the list reader's value first, keeps declared forks, and the README points at it" $? ""
# The installer is retired (v0.8.0, stage 4): nothing tracked runs or names it, so no instruction sends a reader to it.
out=$(git -C "$ROOT" grep -l 'install_hooks' -- . ':!tests/kit_docs_test.sh' 2>/dev/null)
[[ ! -e "$H/install_hooks.sh" && -z "$out" ]]; want_ok "K22 the installer is gone, and no tracked file names it" $? "$(echo $out)"
{ grep -q 'went stale in the same commit' "$ROOT/patterns/local-spawn.md" && ! grep -qi 'the README warns' "$ROOT/patterns/local-spawn.md"; } 2>/dev/null
                                               want_ok "K17 local-spawn states the inventory reason inline; the kit README does not travel" $? ""

# The Monday macOS run skips when main hasn't changed since the last green macOS run (queue 463, the owner's §310 (f)).
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
# wider: its one setting is paths-ignore with the one entry, and the folder holds the fixture alone (decisions log §351,
# §352). The kit's own scans still read the folder.
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

#!/usr/bin/env bash
#
# smoke_test.sh — the user's path, end to end, on the machine that runs it: install a release with
# tools/install-release.sh, make a project as patterns/local-spawn.md says, pin its identity list (bin/kit-pin repin),
# commit and push through its stubs, and
# see a planted credential refused at commit and a planted identity marker refused at push (pre-commit doesn't read
# the identity list; pre-push does).
#
#   tests/smoke_test.sh [ROOT]    ROOT = a checkout of this kit (default: the one holding this file)
#
# CI runs it on Linux, on Windows under Git Bash, and on macOS with Homebrew's folders taken off PATH, which is what
# a stock Mac has: /bin/bash 3.2, BSD tools, shasum and no sha256sum. So this file keeps to bash 3.2 and to what
# BSD and GNU tools share. It uses the machine's own git settings (a default Git for Windows turns LF into CRLF on
# checkout), but an empty global file in place of the user's, unless SMOKE_OWN_GLOBAL=1 keeps the user's own: the
# stand-in machine's org conditions run it so, with an org's hooks path in it (tests/standin/entry.sh).
#
# If the install fails and SMOKE_INSTALL_BASH names a newer bash, the install is built again with that bash, said
# so on its own line, so the later steps still run with the machine's own tools; the run still fails.
#
# Every step prints one line: PASS, FAIL and why, or NOT RUN when a step it needs failed. Stand-in terms only.
# Exit 0 only when every step passed.
#
set -u

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
T=$(mktemp -d "${TMPDIR:-/tmp}/kit-smoke.XXXXXX") || exit 1
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
if [[ "${SMOKE_OWN_GLOBAL:-}" != 1 ]]; then export GIT_CONFIG_GLOBAL="$T/global.gitconfig"; : > "$GIT_CONFIG_GLOBAL"; fi
export KIT_INSTALL_ROOT="$T/releases"
unset LEAK_PATTERN
MARK=ZQSMOKEMARKER
PASS=0; FAIL=0; NOTRUN=0
pass() { PASS=$((PASS+1)); echo "smoke: $1: PASS${2:+ -- $2}"; }
fail() { FAIL=$((FAIL+1)); echo "smoke: $1: FAIL -- $2"; }
notrun() { NOTRUN=$((NOTRUN+1)); echo "smoke: $1: NOT RUN -- $2"; }
one() { printf '%s' "$1" | tr '\n' ' ' | cut -c1-240; }      # an output, on one line

# ============================== what this machine has ===========================================
echo "smoke: system: $(uname -s) $(uname -m)"
echo "smoke: bash on PATH: $(command -v bash) -- $(bash --version | head -n 1)"
echo "smoke: this script's bash: $BASH_VERSION"
echo "smoke: sha256sum: $(command -v sha256sum || echo none); shasum: $(command -v shasum || echo none)"
echo "smoke: gitleaks: $(command -v gitleaks || echo none)"
echo "smoke: git: $(command -v git || echo none) -- $(git --version 2>&1 | head -n 1)"
echo "smoke: python3: $(command -v python3 || echo none) -- $(python3 --version 2>&1 | head -n 1), running $(python3 -c 'import sys; print(sys.executable)' 2>&1 | head -n 1)"
echo "smoke: git core.autocrlf, system: $(git config --system --get core.autocrlf || echo unset)"
echo "smoke: git's global config: $([[ "${SMOKE_OWN_GLOBAL:-}" == 1 ]] && echo "the user's own" || echo "an empty file")"
echo "smoke: PATH, in order:"; printf '%s\n' "$PATH" | tr ':' '\n' | sed 's/^/smoke:   /'

# ============================== a kit clone with a release tag, and its remote ==================
K="$T/kit"
if git init -q "$K" && git -C "$ROOT" checkout-index -a --prefix="$K/" && git -C "$K" add -A \
   && git -C "$K" -c user.name=smoke -c user.email=smoke@invalid.local commit -q -m kit \
   && git -C "$K" -c user.name=smoke -c user.email=smoke@invalid.local tag -a v1.0.0 -m v1.0.0 \
   && git init -q --bare "$T/kit-remote.git" && git -C "$K" remote add origin "$T/kit-remote.git" \
   && git -C "$K" push -q origin v1.0.0; then
    pass "kit clone" "v1.0.0 tagged and on its remote"
else
    fail "kit clone" "the scratch kit could not be made"
fi

# ============================== install the release =============================================
INST="$KIT_INSTALL_ROOT/v1.0.0"
if [[ $FAIL -eq 0 ]]; then
    out=$( (cd "$K" && tools/install-release.sh v1.0.0) 2>&1 ); rc=$?
    if [[ $rc -eq 0 && -f "$INST/MANIFEST.sha256" ]]; then pass install "$(one "$(printf '%s\n' "$out" | head -n 1)")"
    else
        fail install "exit $rc: $(one "$(printf '%s\n' "$out" | grep -v '^ *FAIL ' | tail -n 4)")"
        # A refusal for the release's hook suite names its failing cases: each on a line of its own.
        printf '%s\n' "$out" | grep '^ *FAIL ' | sed 's/^ */smoke:   /'
    fi
    if [[ ! -f "$INST/MANIFEST.sha256" && -n "${SMOKE_INSTALL_BASH:-}" ]]; then
        B="$T/newer-bash"; mkdir -p "$B"; ln -s "$SMOKE_INSTALL_BASH" "$B/bash"
        out=$( (cd "$K" && PATH="$B:$PATH" "$SMOKE_INSTALL_BASH" tools/install-release.sh v1.0.0) 2>&1 ); rc=$?
        label="install again with SMOKE_INSTALL_BASH ($("$SMOKE_INSTALL_BASH" -c 'echo $BASH_VERSION')), so the later steps run"
        if [[ $rc -eq 0 && -f "$INST/MANIFEST.sha256" ]]; then pass "$label"; else fail "$label" "exit $rc: $(one "$(printf '%s\n' "$out" | tail -n 4)")"; fi
    fi
else
    notrun install "no kit clone"
fi

# ============================== a project, as patterns/local-spawn.md says ======================
SP="$T/project"
if [[ -f "$INST/MANIFEST.sha256" ]]; then
    awk '/^## Procedure/ {p=1} p && /^```bash$/ {b=1; next} b && /^```$/ {exit} b {print}' "$INST/patterns/local-spawn.md" \
        | sed -e "s|^REL=.*|REL=v1.0.0|" -e "s|^DST=.*|DST='$SP'|" > "$T/spawn.sh"
    out=$( (cd "$T" && bash "$T/spawn.sh") 2>&1 ); rc=$?
    if [[ ! -s "$T/spawn.sh" ]]; then fail spawn "no procedure block found in the install's patterns/local-spawn.md"
    elif [[ $rc -eq 0 && -f "$SP/kit.pin" && "$out" == *"verify passed"* ]]; then pass spawn "kit-pin verify passed; kit.pin and the stubs written"
    else fail spawn "exit $rc: $(one "$(printf '%s\n' "$out" | grep -E 'REFUSING|error|not found|verify' | head -n 3)")"; fi
else
    notrun spawn "no install"
fi

# ============================== commit one, through the stubs ===================================
if [[ -f "$SP/kit.pin" ]]; then
    git -C "$SP" config --local user.name smoke-test && git -C "$SP" config --local user.email smoke-test@invalid.local
    if [[ "$(git -C "$SP" config --local user.name)" != smoke-test ]]; then fail "commit one" "the identity didn't read back"
    else
        # The project's first commit needs its stakes frame written: the template's TODO block goes.
        sed "/TODO: write this project's stakes frame fresh/,/-->/d" "$SP/CLAUDE.md" > "$T/CLAUDE.md.new" && mv "$T/CLAUDE.md.new" "$SP/CLAUDE.md"
        out=$( (cd "$SP" && git add -A && git commit -q -m "commit one") 2>&1 ); rc=$?
        if [[ $rc -eq 0 ]] && git -C "$SP" rev-parse -q --verify HEAD >/dev/null; then pass "commit one"
        else fail "commit one" "exit $rc: $(one "$(printf '%s\n' "$out" | grep -E 'REFUSING|BLOCKED|error|fatal' | head -n 3)")"; fi
    fi
else
    notrun "commit one" "no project"
fi

# ============================== push, then the two planted stand-ins ============================
if git -C "$SP" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    printf "LEAK_PATTERN='%s'\n" "$MARK" > "$SP/.git/leak-pattern"
    # Its pin, as leak-detection/README.md's Setup writes it; pre-push refuses a list without one (decisions log §112).
    out=$( (cd "$SP" && "$INST/bin/kit-pin" repin local --first) 2>&1 ); rc=$?
    if [[ $rc -eq 0 && -f "$SP/.git/leak-pattern.pin" ]]; then pass "list pinned" "$(one "$(printf '%s\n' "$out" | head -n 1)")"
    else fail "list pinned" "exit $rc: $(one "$out")"; fi
    git init -q --bare "$T/project-remote.git" && git -C "$SP" remote add origin "$T/project-remote.git"
    out=$( (cd "$SP" && git push -q origin main) 2>&1 ); rc=$?
    if [[ $rc -eq 0 && "$(git -C "$T/project-remote.git" rev-parse -q --verify main 2>/dev/null)" == "$(git -C "$SP" rev-parse HEAD)" ]]; then
        pass "push" "the remote has commit one"
    else fail "push" "exit $rc: $(one "$(printf '%s\n' "$out" | grep -E 'REFUSING|BLOCKED|error|fatal' | head -n 3)")"; fi

    head1=$(git -C "$SP" rev-parse HEAD)
    cp "$INST/leak-detection/fixtures/synthetic_config.txt" "$SP/config.local.txt" && chmod u+w "$SP/config.local.txt"
    git -C "$SP" add config.local.txt
    out=$( (cd "$SP" && git commit -q -m "a credential shape") 2>&1 ); rc=$?
    if [[ $rc -ne 0 && "$out" == *"credential shapes"* && "$(git -C "$SP" rev-parse HEAD)" == "$head1" ]]; then
        pass "planted credential refused at commit"
    else fail "planted credential refused at commit" "exit $rc, not refused for credential shapes: $(one "$out")"; fi
    git -C "$SP" rm -q --cached config.local.txt 2>/dev/null; rm -f "$SP/config.local.txt"
    git -C "$SP" reset -q --hard "$head1" 2>/dev/null

    echo "has $MARK here" > "$SP/m.txt"; git -C "$SP" add m.txt
    out=$( (cd "$SP" && git commit -q -m "a stand-in marker") 2>&1 ); rc=$?
    if [[ $rc -ne 0 ]]; then fail "planted marker refused at push" "the commit itself was refused (exit $rc): $(one "$out")"
    else
        out=$( (cd "$SP" && git push -q origin main) 2>&1 ); rc=$?
        if [[ $rc -ne 0 && "$out" == *"identity markers"* \
              && "$(git -C "$T/project-remote.git" rev-parse main 2>/dev/null)" == "$head1" ]]; then
            pass "planted marker refused at push"
        else fail "planted marker refused at push" "exit $rc, not refused for identity markers: $(one "$out")"; fi
    fi
else
    for s in "list pinned" push "planted credential refused at commit" "planted marker refused at push"; do notrun "$s" "no commit one"; done
fi

echo
echo "smoke_test: $PASS passed, $FAIL failed, $NOTRUN not run"
[[ $FAIL -eq 0 && $NOTRUN -eq 0 && $PASS -gt 0 ]]

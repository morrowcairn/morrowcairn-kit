#!/usr/bin/env bash
#
# scan-tree.sh — marker scan over every tracked file in the working tree, against LEAK_PATTERN, every line read as
# text whatever bytes it holds. CI runs it (.github/workflows/leak-scan.yml); tests/hooks_test.sh runs it directly.
#
# Mechanism only: the pattern comes from LEAK_PATTERN in the environment (a repository secret in
# CI), never from this file, because the pattern IS the marker list.
#
# Its output says what was matched and how much was examined, never what KIND of term the list
# holds. The same script runs in CI against a secret that may hold no identity term at all (the
# kit's policy: leak-detection/README.md, Setup) and locally against a full list; a line naming a
# category would be true of one and false of the other.
#
# Exit 0 = examined and clean, or the pinned reserved value saying the project has no identity list (said so). Exit 1 =
# markers found, pattern unset, a pattern its pin doesn't name, grafts, or the scan could not run.
# Output is file:line only -- echoing matched content would put the markers into a build log --
# and never git's own error text, which can quote the pattern.
#
set -uo pipefail
# Text handling runs byte-wise, matching in the caller's locale (decisions log §155 to §159), as in pre-push: every
# text tool here runs under LC_ALL=C, each matcher in the locale saved here (install test LG1).
KIT_CALLER_LOCALE=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}
export LC_ALL=C

# It runs outside a hook, so it follows no git setting it inherits (the user-level rule 13 (c); decisions log §120,
# §121): every GIT_ variable from the caller goes, so git finds the repository from the folder the scan runs in, and
# replace refs are off. A repository with grafts is refused below (hooks_test RG5, RG6).
for v in $(compgen -e); do case $v in GIT_*) unset "$v" ;; esac; done
export GIT_NO_REPLACE_OBJECTS=1

# SHA-256 by sha256sum where it is installed, else by shasum -a 256, which a stock Mac has instead: one routine, the
# same text in each script that hashes (install test HS1). kit_sha256 hashes stdin and prints what sha256sum prints;
# kit_no_sha256 succeeds, saying why, only when neither tool is installed, and the caller refuses then.
kit_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256
    else return 127; fi
}
kit_no_sha256() {
    if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then return 1; fi
    printf 'neither sha256sum (GNU coreutils) nor shasum (Perl) is installed'
}

# A list's pin: two lines, rows= and sha256=, giving how many rows the list holds and the SHA-256 of its value (decisions
# log §108, §112). A row is one top-level alternative of the extended regex: groups, bracket expressions and escapes
# don't split one. One routine, the same text in each script that reads a pin (install test PN0). kit_list_rows VALUE
# prints how many rows VALUE holds; kit_list_head VALUE N prints its first N rows as written; kit_pin_check VALUE PINFILE
# succeeds when VALUE is the list PINFILE names, and otherwise fails with KP_ERROR saying why, in rows, never in a term
# or a hash. It needs kit_sha256.
kit_list_split='{ s = s (NR > 1 ? "\n" : "") $0 }
END { n = length(s); rows = 1; depth = 0; i = 1; cut = n + 1
      while (i <= n) {
          c = substr(s, i, 1)
          if (c == "\\") { i += 2; continue }
          if (c == "[") {
              j = i + 1
              if (substr(s, j, 1) == "^") j++
              if (substr(s, j, 1) == "]") j++
              while (j <= n && substr(s, j, 1) != "]") {
                  d = substr(s, j + 1, 1)
                  if (substr(s, j, 1) == "[" && (d == ":" || d == "." || d == "=")) { k = index(substr(s, j + 2), d "]"); j = k ? j + k + 3 : j + 1 }
                  else j++
              }
              i = j + 1; continue
          }
          if (c == "(") depth++
          else if (c == ")") depth--
          else if (c == "|" && depth == 0) { if (rows == want) { cut = i; break }; rows++ }
          i++
      }
      if (want > 0) printf "%s", substr(s, 1, cut - 1); else print rows }'
kit_list_rows() { printf '%s' "$1" | awk -v want=0 "$kit_list_split"; }
kit_list_head() { printf '%s' "$1" | awk -v want="$2" "$kit_list_split"; }
kit_pin_check() {
    local rows sum got_rows got_sum
    KP_ERROR=""
    if [[ ! -f "$2" ]]; then KP_ERROR="it has no pin"; return 1; fi
    rows=$(sed -n 's/^rows=//p' "$2" 2>/dev/null); sum=$(sed -n 's/^sha256=//p' "$2" 2>/dev/null)
    if [[ ! "$rows" =~ ^[0-9]+$ || ! "$sum" =~ ^[0-9a-f]{64}$ ]]; then KP_ERROR="its pin is malformed"; return 1; fi
    got_rows=$(kit_list_rows "$1")
    got_sum=$(printf '%s' "$1" | kit_sha256) || got_sum=""
    if [[ -z "$got_sum" ]]; then KP_ERROR="it could not be hashed"; return 1; fi
    if [[ "$got_rows" != "$rows" ]]; then KP_ERROR="it holds $got_rows row(s) where its pin expects $rows"; return 1; fi
    if [[ "${got_sum%% *}" != "$sum" ]]; then KP_ERROR="it holds the $rows row(s) its pin expects, but not the same ones"; return 1; fi
    return 0
}

# A project with no identity list says so with the reserved value in its secret, pinned like any list: the scan then
# reads no tracked file for identity terms and says so (decisions log §308, §310 (a)). An unset secret still refuses.
KIT_NO_LIST='kit:no-identity-list'
if [ -z "${LEAK_PATTERN:-}" ]; then
    echo "::error::LEAK_PATTERN secret is unset on this repository."
    echo "::error::Set it with 'gh secret set LEAK_PATTERN'. Do NOT add the pattern to this file."
    echo "::error::If this project has no identity list, set the secret to $KIT_NO_LIST and pin it (\"\$INST/bin/kit-pin\" repin ci --first)."
    echo "::error::INST is your install of the release this project pins, as patterns/local-spawn.md names it: ~/.local/share/morrowcairn/releases/vX.Y.Z, or under KIT_INSTALL_ROOT."
    exit 1
fi

# CI's list must be the one its tracked pin names, .github/leak-pattern.pin: a secret cut, or changed in place, would scan
# for less while every run kept passing (decisions log §108, §112). bin/kit-pin repin ci writes the pin, in a commit
# reviewed like any other. A refusal gives rows, never a term or a hash.
if why=$(kit_no_sha256); then
    echo "::error::$why, so LEAK_PATTERN can't be checked against its pin."
    exit 1
fi
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "::error::not inside a git work tree; refusing."; exit 1; }
grafts=$(git rev-parse --git-path info/grafts 2>/dev/null) || grafts=""
if [ -n "$grafts" ] && [ -s "$grafts" ]; then
    echo "::error::this repository has grafts, which change the history git shows; refusing. Remove them (info/grafts)."
    exit 1
fi
if ! kit_pin_check "$LEAK_PATTERN" "$top/.github/leak-pattern.pin"; then
    echo "::error::LEAK_PATTERN doesn't match its pin, .github/leak-pattern.pin: $KP_ERROR."
    echo "::error::If the secret changed on purpose, repin it in a reviewed commit (\"\$INST/bin/kit-pin\" repin ci); if not, set the secret back."
    echo "::error::INST is your install of the release this project pins, as patterns/local-spawn.md names it: ~/.local/share/morrowcairn/releases/vX.Y.Z, or under KIT_INSTALL_ROOT."
    exit 1
fi
if [ "$LEAK_PATTERN" = "$KIT_NO_LIST" ]; then
    echo "clean: identity checks are off for this project: its LEAK_PATTERN secret is the pinned line saying it has no identity list, so no tracked file was scanned for identity terms"
    exit 0
fi

# Exact documented placeholders that are supposed to appear, if any.
# Do not grow this to silence a real finding -- sanitize the occurrence instead.
ALLOW='__NEVER_MATCHES_BY_DEFAULT__'

# The examined set, counted before the scan so the clean line can say how much was looked at.
lrc=0
tracked=$(git ls-files -- . 2>/dev/null) || lrc=$?
if [ "$lrc" -ne 0 ]; then
    echo "::error::could not list tracked files (git ls-files exit $lrc); refusing to report a clean result."
    exit 1
fi
nfiles=$(printf '%s\n' "$tracked" | awk 'NF' | wc -l)

# Whole tree, not just the diff: pre-existing residuals are the ones still present at publish
# time, and an added-lines scan is structurally blind to them.
#
# The exit code is the verdict: 0 = markers found, 1 = examined and clean, anything else = the
# scan did not run. Only 1 is clean. Each exit code is captured with `|| rc=$?` rather than
# swallowed with `|| true`, which also keeps this correct under a caller's `bash -e`.
rc=0
scan=$(LC_ALL="$KIT_CALLER_LOCALE" git grep -inE "$LEAK_PATTERN" -- . 2>&1) || rc=$?
if [ "$rc" -gt 1 ]; then
    # Never print git's own message: for a pattern that fails to compile, git quotes the
    # pattern -- the marker list -- and a build log is where it would land.
    echo "::error::scan did not run (git grep exit $rc): LEAK_PATTERN may not compile as an extended regex."
    echo "::error::A scan that could not run examined nothing; refusing to report a clean result."
    exit 1
fi

hits=""; nline=0
if [ "$rc" -eq 0 ]; then
    # Same rule for the allowlist filter, which decides by count and only then names: grep -c -v exits 1 when every hit
    # was allowlisted, and above 1 when it did not run. A broken allowlist must not erase real hits. Both steps read
    # every line as text (-a): without it, grep in a UTF-8 locale takes a line holding invalid UTF-8 as binary and
    # prints nothing for it, and v0.9.0 reported such a hit clean (decisions log §145, §148).
    frc=0
    nline=$(printf '%s\n' "$scan" | LC_ALL="$KIT_CALLER_LOCALE" grep -a -c -v -i -E -e "$ALLOW") || frc=$?
    if [ "$frc" -le 1 ] && [ "$nline" -gt 0 ]; then
        frc=0
        hits=$(printf '%s\n' "$scan" | LC_ALL="$KIT_CALLER_LOCALE" grep -a -v -i -E -e "$ALLOW") || frc=$?
    fi
    if [ "$frc" -gt 1 ]; then
        echo "::error::allowlist filter did not run (grep exit $frc): ALLOW is malformed, or grep is missing."
        exit 1
    fi
fi

if [ "$nline" -gt 0 ] && [ -z "$hits" ]; then
    echo "::error::$nline matching line(s) that couldn't be named; refusing to report a clean result."
    exit 1
fi
if [ -n "$hits" ]; then
    # Name each hit's file and line (never the matched text). cut and sort read bytes (LC_ALL=C): BSD cut in a UTF-8
    # locale stops on an invalid byte in a hit's line ("Illegal byte sequence") and would name nothing while the scan
    # still refused (decisions log §150, §152). git grep already decided the match reading every line as text (-a);
    # this only splits each line on ':' to take its path and line number.
    nhit=$(printf '%s\n' "$hits" | LC_ALL=C cut -d: -f1 | LC_ALL=C sort -u | wc -l)
    echo "::error::$nhit of $nfiles tracked files match LEAK_PATTERN (file:line below; matched text not shown):"
    printf '%s\n' "$hits" | LC_ALL=C cut -d: -f1,2 | LC_ALL=C sort -u
    exit 1
fi

echo "clean: $nfiles tracked files scanned, none matches LEAK_PATTERN"

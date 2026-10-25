#!/usr/bin/env bash
#
# check-copies.sh — the checked-copies layer. pre-commit runs it on the index and pre-push on each pushed tip
# whenever the stub has exported KIT_INSTALL; bin/kit-pin to runs it before it keeps a pin move.
#
#   check-copies.sh LABEL [COMMIT]     LABEL starts its refusal line; no COMMIT means the index
#
# Every path the release classes owned (the install's CLASSES file) that the spawn holds must equal the
# release's file (its MANIFEST.sha256 line), unless the spawn's kit.forks declares it, read from the same
# index or commit: the path, sha256:<the hash of the spawn's version>, and the spawn's decisions-log § that
# rules the fork, then anything else as a note:
#     leak-detection/pre-push  sha256:<64 hex>  §31  why it is forked
# A kit-owned file the spawn doesn't hold is fine: a pinned spawn isn't meant to hold them. Prints one
# REFUSING line and each path with its reason; never a file's contents.
#
# The files a project keeps for its CI are held to what the release ships for a project, which the install's
# ci/copies.txt names (PROJECT-PATH RELEASE-PATH): its workflows to the ci/ variants, which run the scans and none
# of the kit's suites, and its .gitleaks.toml to leak-detection/spawn.gitleaks.toml, not the kit's own config, which
# allowlists the kit's credential fixture by path (decisions log §51, §54, §57). A project copy that is the kit's own
# file is refused for that, and any refusal there names the release file the copy is held to.
#
set -uo pipefail

label=${1:?usage: check-copies.sh LABEL [COMMIT]}
at=${2:-}
refuse() { echo "$label: REFUSING -- $1." >&2; exit 1; }

# A pass comes only from the pass point at the end of this file. Any other exit 0 -- an early exit, or a stop on an
# unset variable that the shell reports as 0, as bash 3.2 did here before 2e0ffbd -- is turned into a refusal
# (decisions log §96, §100). A refusal's own non-zero exit is left as it is.
kit_passed=0
kit_guard() {
    local rc=$?
    if [[ $rc -eq 0 && "${kit_passed:-0}" != 1 ]]; then
        echo "$label: REFUSING -- the check stopped before it finished, so what it had not reached was never checked." >&2
        exit 1
    fi
}
trap kit_guard EXIT

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

[[ -n "${KIT_INSTALL:-}" && -r "$KIT_INSTALL/CLASSES" && -r "$KIT_INSTALL/MANIFEST.sha256" && -r "$KIT_INSTALL/RELEASE" ]] \
    || refuse "the checked-copies layer can't read the install's CLASSES, MANIFEST.sha256 or RELEASE"
if why=$(kit_no_sha256); then refuse "$why, so the kit-owned copies can't be checked"; fi
tag=$(sed -n 's/^tag=//p' "$KIT_INSTALL/RELEASE")
obj() { if [[ -n "$at" ]]; then printf '%s:%s' "$at" "$1"; else printf ':%s' "$1"; fi; }

# Each table is lists side by side, searched by exact path, so bash 3.2 runs this: macOS's /bin/bash has no
# associative arrays, and with them this layer stopped there with exit 0, passing every copy (decisions log §96).
# Where a table names a path twice, its last line counts.
mpath=(); msum=()
while read -r sum path; do mpath+=("$path"); msum+=("$sum"); done < "$KIT_INSTALL/MANIFEST.sha256"
fpath=(); fsum=(); fref=()
if git cat-file -e "$(obj kit.forks)" 2>/dev/null; then
    forks=$(git show "$(obj kit.forks)") || refuse "kit.forks could not be read"
    while read -r p s r _; do
        [[ -z "$p" || "$p" == \#* ]] && continue
        fpath+=("$p"); fsum+=("$s"); fref+=("${r:-}")
    done <<< "$forks"
fi

# What a project holds at PATH, when it isn't the release's own file at PATH (ci/copies.txt).
apath=(); arel=()
if [[ -r "$KIT_INSTALL/ci/copies.txt" ]]; then
    while read -r p r _; do
        [[ -z "$p" || "$p" == \#* || -z "${r:-}" || "$p" == "$r" ]] || { apath+=("$p"); arel+=("$r"); }
    done < "$KIT_INSTALL/ci/copies.txt"
fi

last() {   # KEY PATH...: the index of KEY's last place among the PATHs, or -1
    local key=$1 i=0 at=-1 p; shift
    for p in "$@"; do [[ "$p" == "$key" ]] && at=$i; i=$((i + 1)); done
    echo "$at"; }
want_of() { local i; i=$(last "$1" ${mpath[@]+"${mpath[@]}"}); (( i < 0 )) || printf '%s' "${msum[i]}"; }
as_of() { local i; i=$(last "$1" ${apath[@]+"${apath[@]}"}); (( i < 0 )) || printf '%s' "${arel[i]}"; }

bad=()
while read -r class path; do
    [[ "$class" == owned ]] || continue
    git cat-file -e "$(obj "$path")" 2>/dev/null || continue
    got=$(git show "$(obj "$path")" | kit_sha256) || refuse "$path could not be read"
    got=${got%% *}
    as=$(as_of "$path")
    [[ "$got" == "$(want_of "${as:-$path}")" ]] && continue
    own=$(want_of "$path"); f=$(last "$path" ${fpath[@]+"${fpath[@]}"})
    held=""; [[ -z "$as" ]] || held=" (a project's copy is $as)"
    if [[ -n "$as" && "$got" == "$own" && "$path" == .gitleaks.toml ]]; then
        bad+=("$path: is the kit's own config, with its kit-only fixture exemption; a project's copy is $as")
    elif [[ -n "$as" && "$got" == "$own" ]]; then
        bad+=("$path: is the kit's own file; a project's copy is $as")
    elif (( f < 0 )); then
        bad+=("$path: differs from release $tag, and kit.forks doesn't declare it$held")
    elif [[ ! "${fref[f]}" =~ ^§[0-9]+ ]]; then
        bad+=("$path: declared in kit.forks without a decisions-log §")
    elif [[ "${fsum[f]}" != "sha256:$got" ]]; then
        bad+=("$path: declared in kit.forks with another hash")
    fi
done < "$KIT_INSTALL/CLASSES"

if (( ${#bad[@]} )); then
    echo "$label: REFUSING -- kit-owned file(s) differ from release $tag${at:+ at ${at:0:12}}:" >&2
    printf '  %s\n' "${bad[@]}" >&2
    echo "  Put back the release's version, or declare the fork in kit.forks: the path, sha256:<hash> and the § that rules it." >&2
    exit 1
fi

# ---- the pass point ----------------------------------------------------------------------------
kit_passed=1
exit 0

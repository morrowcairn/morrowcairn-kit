#!/usr/bin/env bash
#
# install-release.sh — builds the install of one released version of the kit, which pinned spawns run from.
#
#   tools/install-release.sh TAG [REMOTE]     run in a clone of the kit; REMOTE defaults to origin
#
# The install is $KIT_INSTALL_ROOT/TAG (default ~/.local/share/morrowcairn/releases/TAG): the tag's tree minus
# the files kit-manifest.txt classes kit, plus three files of its own:
#   RELEASE           tag=, commit= and tree= of the release;
#   CLASSES           "owned  PATH", "spawn  PATH" or "example  PATH" for every file the release ships (the
#                     checked-copies layer reads which are kit-owned; kit-manifest.txt itself doesn't ship);
#   MANIFEST.sha256   "SHA-256  PATH" for every other file, sorted; a spawn's kit.pin holds this file's hash.
#
# REFUSES unless TAG is a vX.Y.Z annotated tag whose commit is the one REMOTE has under that tag, and the
# target doesn't exist yet: a release installs once (bin/kit-pin restore rebuilds a damaged one). It builds
# from `git archive` of the tag into a staging folder beside the target, never from the working tree; runs
# the release's own hook suite on the staged install; makes it read-only; and renames it into place in one
# step. Any refusal after the staging folder exists removes it, so nothing half-built is left.
#
set -uo pipefail

tag=${1:-}; remote=${2:-origin}
refuse() {
    echo "install-release: REFUSING -- $1." >&2
    [[ -z "${2:-}" ]] || echo "  $2" >&2
    exit 1
}

# A pass comes only from the pass point at the end of this file. Any other exit 0 -- an early exit, or a stop on an
# unset variable that the shell reports as 0, as bash 3.2 can -- is turned into a refusal, and any stop short of the
# pass point removes the staging folder, as a refusal does. A refusal's own non-zero
# exit is left as it is.
kit_passed=0
kit_guard() {
    local rc=$?
    [[ "${kit_passed:-0}" == 1 ]] && return
    if [[ -n "${staging:-}" && -e "$staging" ]]; then chmod -R u+w "${staging:?}" 2>/dev/null; rm -rf "${staging:?}" "${staging:?}.manifest"; fi
    if [[ $rc -eq 0 ]]; then
        echo "install-release: REFUSING -- the check stopped before it finished, so what it had not reached was never checked." >&2
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

cd "$(dirname "${BASH_SOURCE[0]}")/.." || refuse "could not enter the clone holding this script"
git rev-parse --git-dir >/dev/null 2>&1 || refuse "this script is not in a clone of the kit"

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || refuse "'$tag' is not a release tag name (vX.Y.Z)"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || refuse "$tag is not a tag in this clone"
[[ "$(git cat-file -t "refs/tags/$tag")" == tag ]] || refuse "$tag is a lightweight tag, not an annotated one"
commit=$(git rev-parse "refs/tags/$tag^{commit}") || refuse "$tag names no commit"
# Never print ls-remote's own output or errors: a URL can carry a token.
theirs=$(git ls-remote --tags "$remote" "refs/tags/$tag^{}" 2>/dev/null)
rc=$?
(( rc == 0 )) || refuse "could not list the tags of remote $remote (git ls-remote exit $rc)"
[[ -n "$theirs" ]] || refuse "$tag is not on the remote $remote" "Push the tag first: a release is what the remote has."
[[ "${theirs%%[[:space:]]*}" == "$commit" ]] || refuse "$tag on the remote $remote points at another commit"

if why=$(kit_no_sha256); then refuse "$why, so the install's manifest can't be written"; fi
# The move into place is python3's os.rename (below): checked here, so a python3 that can't run (none, or Windows'
# store alias) refuses before anything is built. Both launches are isolated (-I), so no module the environment plants
# on PYTHONPATH or in the user site runs inside the install (install_test IR13, IR14).
python3 -I -c 'import os' >/dev/null 2>&1 || refuse "python3 can't run here, so the install can't be moved into place in one step"
root=${KIT_INSTALL_ROOT:-${HOME:-}/.local/share/morrowcairn/releases}
target="$root/$tag"
[[ ! -e "$target" ]] || refuse "$target already exists: a release installs once" \
    "A damaged install is rebuilt from a pinned spawn, run there: \"$PWD/bin/kit-pin\" restore \"$PWD\""
mkdir -p "$root" || refuse "could not make $root"
staging=$(mktemp -d "$root/.staging-$tag.XXXXXX") || refuse "could not make a staging folder in $root"
abandon() { chmod -R u+w "${staging:?}" 2>/dev/null; rm -rf "${staging:?}" "${staging:?}.manifest"; refuse "$@"; }

# What ships: every file of the tag that kit-manifest.txt, as the tag has it, doesn't class kit. A path no
# entry covers is owned, as local-spawn reads it. The manifest reaches awk through the environment: macOS's awk
# refuses a -v value that holds a newline.
manifest=$(git show "$commit:kit-manifest.txt" 2>/dev/null) || abandon "$tag has no kit-manifest.txt"
classes=$(git ls-tree -r --name-only "$commit" | KIT_MANIFEST="$manifest" awk '
    BEGIN { n = split(ENVIRON["KIT_MANIFEST"], ls, "\n"); for (i = 1; i <= n; i++) if (ls[i] !~ /^#/ && split(ls[i], f, " ") == 2) { c[++k] = f[1]; p[k] = f[2] } }
    { cls = "owned"
      for (i = 1; i <= k; i++) if ($0 == p[i] || (substr(p[i], length(p[i])) == "/" && index($0, p[i]) == 1)) { cls = c[i]; break }
      if (cls != "kit") print cls "  " $0 }') || abandon "could not class the files of $tag"
[[ -n "$classes" ]] || abandon "$tag ships no files"
files=()      # read line by line: bash 3.2, macOS's /bin/bash, has no mapfile
while IFS= read -r f; do files+=("$f"); done < <(printf '%s\n' "$classes" | awk '{print $2}')
git archive "$commit" -- "${files[@]}" | tar -x -C "$staging" || abandon "git archive of $tag did not unpack"
printf '%s\n' "$classes" | LC_ALL=C sort -k2 > "$staging/CLASSES" || abandon "could not write CLASSES"
printf 'tag=%s\ncommit=%s\ntree=%s\n' "$tag" "$commit" "$(git rev-parse "$commit^{tree}")" > "$staging/RELEASE" \
    || abandon "could not write RELEASE"
# Written beside the staging folder, then moved in, so the manifest never lists itself half-written. One file at a
# time through kit_sha256, so either tool writes the same "SHA-256  PATH" lines.
( cd "$staging" && find . ! -type d | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do
      s=$(kit_sha256 < "$f") || exit 1; printf '%s  %s\n' "${s%% *}" "$f"; done ) > "$staging.manifest" \
    && mv "$staging.manifest" "$staging/MANIFEST.sha256" || abandon "could not write MANIFEST.sha256"

# The release's own hook suite, on the staged install. GIT_CEILING_DIRECTORIES keeps git from finding a
# repository above it, so the suite's clone cases skip, counted, instead of testing some other clone. A refusal
# names the suite's failing cases, up to 40.
[[ -f "$staging/tests/hooks_test.sh" ]] || abandon "$tag has no tests/hooks_test.sh to run on the install"
# KIT_INSTALL_CHECK tells the suite it runs as part of an install: a check that can't be exercised because this
# machine's python3 has its user site off (PY2) is a loud skip, not a failure, since the isolation itself (python3
# -I, shown by PY1) doesn't depend on that machine setting. In CI and a direct run the marker is absent, so the same
# check fails there instead -- a gate check is never silently skipped (hooks_test PY2, install test IR15, IR16).
suite=$(KIT_INSTALL_CHECK=1 GIT_CEILING_DIRECTORIES="$root" bash "$staging/tests/hooks_test.sh" "$staging" 2>&1)
rc=$?
(( rc == 0 )) || abandon "the release's hook suite failed on the staged install (exit $rc); nothing was installed" \
    "Its summary: $(printf '%s\n' "$suite" | tail -n 1)$(printf '%s\n' "$suite" | grep '^FAIL ' | head -n 40 | cut -c1-200 | awk '{printf "\n  %s", $0}')"

chmod -R a-w "$staging" || abandon "could not make the staged install read-only"
# One rename(2), as GNU mv -T made, which BSD mv can't: the staged folder becomes the target whole, and if anything
# has appeared at the target since the check above, the rename fails rather than putting the install inside it.
python3 -I -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$staging" "$target" 2>/dev/null \
    || abandon "could not move the staged install into place at $target"
echo "install-release: installed $tag at $target ($(wc -l < "$target/MANIFEST.sha256") files; manifest sha256:$(kit_sha256 < "$target/MANIFEST.sha256" | cut -d' ' -f1))."
echo "  Its suite: $(printf '%s\n' "$suite" | tail -n 1)"

# ---- the pass point ----------------------------------------------------------------------------
kit_passed=1
exit 0

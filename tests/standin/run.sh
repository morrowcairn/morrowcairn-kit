#!/usr/bin/env bash
#
# run.sh — the kit's stand-in machine: build the two images, then run the kit's
# git-level suites (hooks, install, smoke) in a fresh container for each org-like condition, and print one line a
# suite and condition. Kit-only (kit-manifest.txt classes tests/standin/ kit); Linux with Docker; the containers have
# no network; no model call.
#
#   tests/standin/run.sh [COMMIT [CONDITION...]]    COMMIT defaults to HEAD; the conditions, to all five (entry.sh)
#
# What goes into a container: a one-commit snapshot of COMMIT's tree under a test identity (no history: the kit's
# .git stays out), the gitleaks binary first on this machine's PATH, entry.sh and the IT hook, all read-only. Nothing
# else from the home folder: no do-not-publish list, no credentials, no keys. Each container runs with --rm.
# Results: one folder a condition under STANDIN_OUT (default: a new temp folder, printed), holding facts.txt,
# exits.txt and a log a suite. Exit 0 when every suite passed in every condition; 1 when any failed (failures are
# findings: read the logs); 2 when an image, the snapshot or a container couldn't be made.
#
# The images stay in the local store under kit-standin:ubuntu and kit-standin:debian until removed; remove them, and
# the two base images, when done (docker image rm), since this machine's Docker store is shared.
set -u
KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 2
HERE="$KIT/tests/standin"
# Base images pinned by digest, so a red run and a green run are on the same image. Bumped by
# hand: a new digest is a new baseline.
UBUNTU=ubuntu:26.04@sha256:c098726dd9b9733f3e885f8de0ef375206a311b0a317eadc40d347b1115fb944
DEBIAN=debian:11@sha256:6f519a81440354a85eb592c5f32109ab80605f6b892455983a6f618bf87fabe9
# Debian 11 is past its end of life: deb.debian.org's security pool answers 404 for its packages (measured 10-24), so
# its image takes them from archive.debian.org.
DEBIAN_SOURCES='deb http://archive.debian.org/debian bullseye main
deb http://archive.debian.org/debian-security bullseye-security main'

commit=${1:-HEAD}; (( $# > 0 )) && shift
conds=("$@"); (( ${#conds[@]} )) || conds=(no-sudo user-gitleaks it-hookspath global-hookspath old-git)
command -v docker >/dev/null 2>&1 || { echo "run.sh: docker is not installed" >&2; exit 2; }
gl=$(command -v gitleaks) || { echo "run.sh: gitleaks is not on PATH" >&2; exit 2; }
gl=$(readlink -f "$gl")
OUT=${STANDIN_OUT:-$(mktemp -d)} && mkdir -p "$OUT" || exit 2
W=$(mktemp -d) || exit 2
trap 'rm -rf "${W:?}"' EXIT

# The snapshot: COMMIT's tree, committed once, so the suites find a repository with HEAD and an index (install_test
# and hooks_test read ROOT's modes from it) and nothing of the kit's history or local files.
snap="$W/kit"; mkdir "$snap" || exit 2
git -C "$KIT" archive "$commit" | tar -x -C "$snap" || { echo "run.sh: $commit could not be archived" >&2; exit 2; }
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  git -C "$snap" init -q && git -C "$snap" add -A \
  && git -C "$snap" -c user.name=standin -c user.email=standin@invalid.local commit -q --no-verify -m "kit snapshot" ) \
  || { echo "run.sh: the snapshot could not be committed" >&2; exit 2; }

build() {   # TAG BASE [APT-SOURCES]
    docker build -q --force-rm --build-arg BASE="$2" --build-arg APT_SOURCES="${3:-}" -t "$1" -f "$HERE/Containerfile" "$HERE" \
        >/dev/null || { echo "run.sh: image $1 could not be built from $2" >&2; exit 2; }
}
need_ubuntu=0; need_debian=0
for c in "${conds[@]}"; do if [[ "$c" == old-git ]]; then need_debian=1; else need_ubuntu=1; fi; done
(( need_ubuntu )) && build kit-standin:ubuntu "$UBUNTU"
(( need_debian )) && build kit-standin:debian "$DEBIAN" "$DEBIAN_SOURCES"

echo "run.sh: $(git -C "$KIT" rev-parse --short "$commit"), results in $OUT"
rc=0
for c in "${conds[@]}"; do
    img=kit-standin:ubuntu; [[ "$c" == old-git ]] && img=kit-standin:debian
    mkdir -p "$OUT/$c" || exit 2
    docker run --rm --network none --cpu-shares 128 \
        -v "$snap:/opt/kit-src:ro" -v "$gl:/opt/gitleaks:ro" -v "$HERE/entry.sh:/opt/entry.sh:ro" \
        -v "$HERE/it-hook:/opt/it-hook:ro" -v "$OUT/$c:/out" -e HOST_UID="$(id -u)" \
        "$img" bash /opt/entry.sh "$c" >/dev/null 2>"$OUT/$c/container.err"
    st=$?
    (( st == 0 )) || rc=1
    if [[ ! -s "$OUT/$c/exits.txt" ]]; then
        echo "$c: the container did not run the suites (exit $st; $OUT/$c/container.err)"; rc=2; continue
    fi
    echo "$c: $(sed -n 's/^git: //p' "$OUT/$c/facts.txt")"
    for s in hooks_test install_test smoke_test smoke_own_config; do
        LC_ALL=C grep -q "^$s " "$OUT/$c/exits.txt" || continue
        printf '  %-13s %s; %s\n' "$s" "$(sed -n "s/^$s //p" "$OUT/$c/exits.txt")" "$(tail -n 1 "$OUT/$c/$s.log" 2>/dev/null)"
    done
done
exit "$rc"

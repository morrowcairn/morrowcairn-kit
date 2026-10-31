#!/usr/bin/env bash
#
# Pattern: atomic deploy with failure propagation and a post-deploy smoke gate.
#
# An example (kit-manifest.txt classes it so): copy it into the project and change it as the project's own. The kit
# never runs it, and the checked-copies layer doesn't hold a copy to the release's.
#
# THREE FAILURES THIS PREVENTS
# ----------------------------
# 1. PARTIAL ARTIFACT ON THE LIVE PATH. Transferring directly to the live filename means any
#    interruption -- kill, dropped connection, disk full -- can leave a half-written file where
#    the serving path expects a whole one. Some transfer tools make this worse: resume features
#    that rename a partial temp file INTO the destination on interrupt will overwrite a good
#    live artifact with an incomplete one. Transfer to `${TARGET}.new`, then `mv` into place.
#    The rename is atomic; the transfer is not.
#
# 2. THE CALLER REPORTS SUCCESS OVER A FAILED STEP. This is the one that actually bites, because
#    the deploy script itself usually fails correctly and loudly -- and the orchestrator that
#    called it prints "Complete", runs its checks against the OLD state, and exits 0. Nothing
#    alerts. Track failure explicitly, skip downstream steps with an explanatory log, make the
#    summary reflect status, and exit non-zero so schedulers notice.
#
# 3. A SMOKE GATE THAT CANNOT FAIL. A post-deploy check that queries something invariant, or
#    that runs against the old artifact, reads as coverage while exercising nothing. Verify the
#    gate can go red before trusting it green -- see the red-first note at the bottom.
#
set -euo pipefail   # -e: stop on error. -u: unset vars are bugs. -o pipefail: a failing stage in
                    # a pipeline is a failing pipeline. Without pipefail, `build | tee log` reports
                    # tee's exit code and a failed build reads as success.

SRC="${1:?usage: atomic_deploy.sh <source-artifact>}"
TARGET="${TARGET:?set TARGET to the live path}"
DEPLOY_FAILED=0

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }   # define BEFORE first use: an undefined `die` prints
                                     # "command not found" and obscures the real failure

# --- preflight: refuse rather than half-deploy -------------------------------------------
[[ -f "$SRC" ]] || die "source artifact missing: $SRC"

need_bytes=$(stat -c %s "$SRC")
# Headroom for the new artifact ALONGSIDE the old one -- they coexist between transfer and mv,
# and a rollback copy may too. Sizing for one copy is how deploys die at 99%.
free_bytes=$(( $(df -P --output=avail "$(dirname "$TARGET")" | tail -1) * 1024 ))
(( free_bytes >= need_bytes * 2 )) || die "insufficient headroom: need 2x $need_bytes, have $free_bytes"

# --- transfer aside, then swap ------------------------------------------------------------
log "transferring to ${TARGET}.new"
# cp gives ${TARGET}.new the source's mode under the umask, and mv keeps it: a live file at 0755 or 0644 swapped
# from a 0600 source becomes 0600 (measured). Where the live file's mode matters, as for a script
# a scheduler runs, copy it onto ${TARGET}.new before the swap.
if ! cp "$SRC" "${TARGET}.new"; then
    DEPLOY_FAILED=1
    log "transfer FAILED -- live artifact untouched at $TARGET"
fi

if (( DEPLOY_FAILED == 0 )); then
    log "atomic swap"
    mv "${TARGET}.new" "$TARGET" || { DEPLOY_FAILED=1; log "swap FAILED"; }
fi

# --- smoke gate: only meaningful against the NEW state ------------------------------------
if (( DEPLOY_FAILED == 0 )); then
    log "smoke gate"
    if ! smoke_check "$TARGET"; then
        DEPLOY_FAILED=1
        log "smoke gate FAILED -- consider rollback"
    fi
else
    # THE CRITICAL BRANCH. Running checks here would grade the OLD artifact and pass, which is
    # how "deploy failed" becomes "deploy complete, QC PASS" in a log nobody re-reads.
    log "smoke gate SKIPPED -- deploy failed; checks would grade the previous artifact and pass"
fi

# --- honest summary + honest exit code ----------------------------------------------------
if (( DEPLOY_FAILED )); then
    log "SUMMARY: DEPLOY FAILED (source artifact intact; live path unchanged or partially swapped)"
    exit 2      # distinct from 1 so a scheduler can tell "deploy failed" from "script crashed"
fi
log "SUMMARY: deploy complete, smoke gate green"

# smoke_check() -- replace. Assert something that DIFFERS between the old and new artifact
# (a version marker, a row count, a checksum). A check that passes against both proves nothing.
#
# RED-FIRST: before trusting this gate, make it fail on purpose once -- point it at the old
# artifact and confirm it goes red. A gate that has never failed has not been shown to work; it
# has only been shown to be quiet. Both look identical in a log.

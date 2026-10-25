#!/usr/bin/env bash
#
# Pattern: dry-run-gated runner for irreversible or externally-visible actions.
#
# An example (kit-manifest.txt classes it so): copy it into the project and change it as the project's own. The kit
# never runs it, and the checked-copies layer doesn't hold a copy to the release's.
#
# THE FAILURE THIS PREVENTS
# -------------------------
# An action with external side effects -- a live POST, an email send, a publish, a bulk delete --
# executed before anyone has seen what it would do. Unlike a bad local write, these cannot be
# rolled back: the request arrived, the message sent, the quota burned.
#
# The rule: **irreversible external actions sit behind an explicit human authorization gate with
# a dry-run lane.** Dry-run is the DEFAULT; live fire requires a deliberate flag AND an
# interactive confirmation that a stray `yes |` cannot satisfy.
#
# THE DESIGN CONSTRAINT PEOPLE MISS
# ---------------------------------
# The dry-run path must exercise **the same code** as the live path, diverging only at the final
# side-effecting call. A dry-run implemented as a separate branch proves that the DRY-RUN branch
# works. Build the payload, validate it, log it -- then either send or don't.
#
set -euo pipefail

LIVE=0
[[ "${1:-}" == "--live" ]] && LIVE=1

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# --- build the work list: identical in both modes ------------------------------------------
mapfile -t ITEMS < <(enumerate_targets)
log "planned actions: ${#ITEMS[@]}"
for item in "${ITEMS[@]}"; do
    payload="$(build_payload "$item")"          # same builder both modes
    validate_payload "$payload" || { log "INVALID payload for $item -- aborting"; exit 1; }
    log "  WOULD $ACTION_DESC: $item -> ${payload:0:120}"
done

if (( ! LIVE )); then
    log "DRY RUN -- nothing sent. Review the list above, then re-run with --live."
    exit 0
fi

# --- authorization gate ---------------------------------------------------------------------
# Reads from the terminal, not stdin, so a piped `yes` or a cron redirect cannot answer it.
# If there is no terminal, refuse: an unattended run must never satisfy a human gate.
[[ -t 0 ]] || { log "REFUSED: --live requires an interactive terminal"; exit 1; }

printf 'About to %s for %d items. This is IRREVERSIBLE.\nType the item count to confirm: ' \
    "$ACTION_DESC" "${#ITEMS[@]}" > /dev/tty
read -r reply < /dev/tty
[[ "$reply" == "${#ITEMS[@]}" ]] || { log "ABORTED: confirmation did not match"; exit 1; }
# Typing the COUNT, not "yes", forces the operator to have read the number -- the single most
# common near-miss is authorizing a run whose scope silently grew since it was last reviewed.

# --- live fire: same payloads, now actually sent --------------------------------------------
sent=0; failed=0
for item in "${ITEMS[@]}"; do
    payload="$(build_payload "$item")"
    if send "$payload"; then
        (( ++sent ))
    else
        (( ++failed ))
        log "FAILED: $item"      # count it; a silent failure here is an unsent action nobody sees
    fi
done

log "SUMMARY: sent=$sent failed=$failed of ${#ITEMS[@]}"
(( failed == 0 )) || exit 2

# enumerate_targets / build_payload / validate_payload / send -- replace.
# ACTION_DESC -- a human phrase, e.g. "publish 40 records to the public API".
#
# Would revisit if: the downstream service grows a native preview/idempotency-key mechanism that
# makes a local dry-run redundant. Until then, the local lane is the only preview that exists.

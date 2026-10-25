#!/usr/bin/env python3
"""Pattern: loader with counted skip paths and writer-side idempotency guards.

An example (kit-manifest.txt classes it so): copy it into the project and change it as the project's own. The kit never
runs it, and the checked-copies layer doesn't hold a copy to the release's.

THE FAILURE THIS PREVENTS
-------------------------
A loader that skips rows silently under-counts without ever erroring. The run exits 0, the log
says nothing, and the shortfall is discovered — if ever — months later by someone reconciling
totals. Two mechanisms produce it, and they need different fixes:

  1. SILENT SKIP.  An "insert or ignore" write drops conflicting rows and returns success. The
     database is doing exactly what it was told; nothing is broken; rows are simply gone.
  2. SWALLOWED EXCEPTION.  A bare `except: continue` turns a parse failure into a missing row.

The rule both obey: **every skip and every failure path emits a count or a log line. "No output"
is never a success signal.** A run that processed 10,000 rows and one that processed 400 must not
produce identical logs.

Corollary, which is the part people drop: it is not enough to count. **Reconcile the counts** —
read + skipped + failed must equal attempted, and the loader should say so out loud. An
unreconciled tally is a number nobody checks.

IDEMPOTENCY IS TWO OBLIGATIONS
------------------------------
  (a) DISCOVERY  — audit for violations that already exist. A guard added today does not clean
      up yesterday's duplicates, and assuming it did is how a "fixed" table stays wrong.
  (b) WRITER-SIDE GUARD — prevent new ones, in the writer, not by convention downstream.

Shipping only (b) leaves a corrupted table that now looks protected. Ship both.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

log = logging.getLogger(__name__)


@dataclass
class LoadStats:
    """Every disposition a row can reach. If you add a code path, add a counter."""

    attempted: int = 0
    inserted: int = 0
    skipped_duplicate: int = 0
    skipped_invalid: int = 0
    failed: int = 0
    skip_examples: list = field(default_factory=list)  # first few, for diagnosis

    def reconciles(self) -> bool:
        accounted = (
            self.inserted + self.skipped_duplicate + self.skipped_invalid + self.failed
        )
        return accounted == self.attempted

    def report(self) -> str:
        return (
            f"attempted={self.attempted} inserted={self.inserted} "
            f"dup={self.skipped_duplicate} invalid={self.skipped_invalid} "
            f"failed={self.failed}"
        )


def load(rows, conn, table: str, key_cols: tuple[str, ...], max_examples: int = 5) -> LoadStats:
    """Load `rows`, counting every disposition. Raises if the tally does not reconcile."""
    st = LoadStats()

    for row in rows:
        st.attempted += 1
        try:
            if not _is_valid(row):
                st.skipped_invalid += 1
                _record_example(st, "invalid", row, max_examples)
                continue

            # Writer-side idempotency guard: check explicitly so the skip is COUNTABLE.
            # An "insert or ignore" would be silent here -- that is the whole bug.
            if _exists(conn, table, key_cols, row):
                st.skipped_duplicate += 1
                _record_example(st, "duplicate", row, max_examples)
                continue

            _insert(conn, table, row)
            st.inserted += 1

        except Exception as exc:  # noqa: BLE001 -- deliberate: catch, COUNT, and keep going
            st.failed += 1
            _record_example(st, f"error:{type(exc).__name__}", row, max_examples)
            # WARNING, not debug: a swallowed failure that only whispers is still swallowed.
            log.warning("row failed (%s): %s", type(exc).__name__, exc)

    # Speak up unconditionally -- including, especially, when nothing was skipped.
    log.info("load %s: %s", table, st.report())
    for ex in st.skip_examples:
        log.info("  example %s: %s", *ex)

    if not st.reconciles():
        # Unreachable unless a code path forgot its counter -- which is exactly the bug class
        # this pattern exists to surface, so fail loudly rather than log and continue.
        raise RuntimeError(f"load tally does not reconcile: {st.report()}")

    return st


def audit_existing_duplicates(conn, table: str, key_cols: tuple[str, ...]) -> int:
    """Obligation (a): DISCOVERY. Run before trusting a newly-added writer-side guard.

    Returns the number of key groups already duplicated. A guard added today does not repair
    yesterday's damage; this is the check that tells you whether repair is owed.
    """
    keys = ", ".join(key_cols)
    cur = conn.execute(
        f"SELECT COUNT(*) FROM (SELECT {keys} FROM {table} GROUP BY {keys} HAVING COUNT(*) > 1)"
    )
    n = cur.fetchone()[0]
    if n:
        log.warning("%s: %d duplicated key groups PREDATE the writer-side guard", table, n)
    else:
        log.info("%s: no pre-existing duplicates", table)
    return n


# --- project-specific; replace ------------------------------------------------------------

def _is_valid(row) -> bool:
    raise NotImplementedError


def _exists(conn, table, key_cols, row) -> bool:
    raise NotImplementedError


def _insert(conn, table, row) -> None:
    raise NotImplementedError


def _record_example(st: LoadStats, reason: str, row, cap: int) -> None:
    if len(st.skip_examples) < cap:
        st.skip_examples.append((reason, repr(row)[:200]))

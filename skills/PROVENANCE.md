# Provenance of the doctrine

The separable appendix the kit's prune posture asks for: one line for each procedure or pattern a
shipped file cites, naming the recorded incident behind it. A line no longer traces to anything real
is a removal candidate. Incidents come from projects spawned from the kit and from projects run by
the kit's operator; the records themselves stay with those projects. The always-on rules' reasons are
in `docs/rules-explained.md`.

- 4: A spawned project, 2026-09. Its first four checks were each seen red on a synthetic case before
  green. Later, one test failed with and without the change it was meant to catch, and one mutation
  could not fire; both were redone until the red was real. In a project the kit was drawn from, the
  same month, two gate fixes found their holes only through the run against the old code. Items 6
  and 7, the week's replay and the whole-file swap: the operator's own rules, 2026-10, ruled in the
  words the procedure carries; no kit record traces the incident behind them, so until one does,
  they rest on the ruling alone.
- 5: A project the kit was drawn from, 2026-10. A session split a script's name so that an ask rule
  meant to stop deploys wouldn't match, and passed text naming the scripts through files for the
  same reason. Also the kit, 2026-09: a permission check refused a session's
  attempt to delete evidence its own audit would read; stopping and reporting was upheld.
- 9: A spawned project, 2026-10. Four time stamps typed by hand in one session were each wrong, by 3
  to 57 minutes in both directions, and each was caught only after writing. Its record of the day
  before lists the same mistake.
- Numbered relays: a spawned project's sessions, 2026-10. A relay of build decisions never reached its
  session, and nothing noticed until a confirmation was asked for by reference. A relay meant for one
  session reached another, caught only because a number repeated. Two sessions of one project, each
  taking relays the same day, would have read each other's numbers as gaps. The end line: a project
  the kit's operator runs, 2026-10, where two relays arrived cut off mid-sentence; a cut at a clean
  break between items would have looked complete. The numbering cases: in the same projects that
  month, a relay reached a session after its handover under a number it had already received, and
  nothing said what to do; and in the kit, 2026-10, a new session's first relay carried #17, and a
  relay arrived before the one it followed.
- 12: the operator's own close prompt, run in the kit on 2026-10-17 for the first time. It surfaced
  fixes that were finished but in no release, which nobody was
  tracking: every gate fix of that day was on the main branch only, with no release cut to carry it.
- 13: projects run by the kit's operator, 2026-10. Two days of gate work found each item's hole in a
  live gate: terms taken from the caller's environment, so a one-entry list reported clean; a test
  override honoured on a real push; an inherited `GIT_DIR` that pointed a gate at another repository
  or list, and a replace ref that hid a term from a pre-push gate; a gate that skipped with a warning
  when its scanner was missing, and one that died with a traceback on an unset list. The operator's
  own rules then made the five items one ruling, with a shared set of must-fail tests.

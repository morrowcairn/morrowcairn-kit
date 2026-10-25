# Provenance of the doctrine

The separable appendix the kit's prune posture asks for: one line per procedure, naming the recorded
incident behind it. A procedure whose line no longer traces to anything real is a removal candidate.
Incidents come from projects spawned from the kit and from projects run by the kit's operator; the
records themselves stay with those projects.

- 1: A spawned project, 2026-09. On an estimate of 0 to 2 files, fixing two stale documents would
  have made 4 files and fired the doubling stop. The session left them stale to stay under it, then
  recorded that as a trim the rule forbids. The threshold was then measured over the procedure's
  first twelve days, in the shared log several projects kept: 802 sized asks, 112 stops. A difference
  in kind changed the decision 14 times against 10 approved as proposed. Doubling changed it 4 times
  against 13, and caused every trivial-fix cost (6 round trips or trims, on doc and record edits of
  2 to 4 files). With a gate the brief didn't identify counted as a difference in kind, a floor of 5
  files keeps all 4 doubling catches and drops all 6 costs. Exempting docs instead would have dropped
  5 of the 6 and left the executor to judge what counts as a doc.
- 2: A spawned project, 2026-09. A brief assumed a field that a data source turned out not to carry,
  so nothing was built on it and the question went back. A ruled assumption held for one case in
  three, so two were paused and reopened.
- 3: A spawned project, 2026-09. A close-out line described a trim as staying in budget; the session's
  correction entry recorded it as a breach. The same week, a pause rested on a misread that a measured
  sample overturned.
- Precedence: a project the kit was drawn from, 2026-09. When these procedures were first installed,
  a review found that project's ratified bar ("escalate only when an action is irreversible and
  consequential and forecloses an option") told a session to carry on with a doubled size estimate,
  where the size procedure said to stop: same action, opposite instruction. Read strictly, the same
  bar also ruled out the pause in procedure 2. In the next twelve days, 20 sized asks whose stop
  fired went ahead under a project's own bar, 12 of them in that project, and none is recorded as
  work undone.
- 4: A spawned project, 2026-09. Its first four checks were each seen red on a synthetic case before
  green. Later, one test failed with and without the change it was meant to catch, and one mutation
  could not fire; both were redone until the red was real. In a project the kit was drawn from, the
  same month, two gate fixes found their holes only through the run against the old code.
- 5: A project the kit was drawn from, 2026-10. A session split a script's name so that an ask rule
  meant to stop deploys wouldn't match, and passed text naming the scripts through files for the
  same reason. Also the kit, 2026-09: a permission check refused a session's
  attempt to delete evidence its own audit would read; stopping and reporting was upheld.
- 6: A project the kit was drawn from, 2026-09. An apostrophe in a quoted payload ended the shell
  string. The shell ran a program line as a screen-capture command of the same name, which wrote the
  display to a file in the working tree. Also the kit, 2026-09: a check returned 0 matches because of
  a quoting error in the check, not because the target was clean.
- 7: A spawned project, 2026-09. An extraction into an unset variable's directory was refused only
  because an empty `-C` happens to be an error. A `cd`-then-glob delete was stopped only by the
  tool's static check.
- 8: A spawned project, 2026-09. A search of a crontab printed three ping URLs whole: tokens, not
  lines, so the rule was followed in form, and a capability URL is a token. In a project the kit was
  drawn from, the same month, a presence test printed a live token twice into a transcript, and the
  credentials were rotated.
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
- 1, the lower-end cap: a project run by the kit's operator, 2026-10, ruled with the threshold above.
  Counted at its upper end, a wide blind range sets the doubling stop far past the work it sized: a
  blind 3 to 8 would stop only at 16 files; capped, it stops at 10.
- 1, the schema-change sentence: the operator's own rules, 2026-10, ruled in the words the
  procedure carries. The incident behind it is recorded in the operator's own log, which the kit
  session that took the sentence did not read; until a kit record traces it, this line rests on
  the ruling alone. The sentence gives the kind prong a test that doesn't depend on the storage:
  reverting the code alone would leave existing data unreadable.
- 10: the projects run by the kit's operator, 2026-10. After a change to the tool, a conversation
  left idle long enough was compacted too, and most compactions were of idle sessions. Sessions
  then worked from summaries; reports were cut off, and the requests to reprint them mostly came
  right after an idle compaction; a reprint regenerated from the summary was not the report. The
  rule was first written for the operator's machine, where a hook logs each compaction; the kit's
  text makes that reading optional, since it ships no such hook, on the operator's word.
- 11: the kit, 2026-10. A session reported that no kit document named a tool, after a recursive
  `grep` over the kit folder found nothing; the shell's `grep` was a function running ugrep with
  `--ignore-files`, and two files in a gitignored folder named it. Measured the same month in a
  scratch repository holding a stand-in string in a tracked file, a gitignored file, a file in an
  ignored directory and a dot file: the function and its backslash form found the tracked and dot
  files only; `command grep -r` and `/usr/bin/grep -r` found all four. Measured again with a binary
  file and a non-UTF-8 text file added, named and piped as well as found by `-r`: the function
  skipped both, its `-c` printing nothing and exiting 1; the other two forms read them. A first run
  of that check, started as a separate `bash` process, measured the system's `grep` three times,
  because the function belongs to the session's shell. Item 3, the locale: the kit's own CI, 2026-10.
  On GitHub's macOS runner, in its UTF-8 locale, the stock `/usr/bin/grep` (BSD grep) with `-l`,
  `-a -l`, `-l -I` and `-c` did not match an ASCII stand-in on a line holding invalid UTF-8: `-l` and
  `-a -l` named 2 of 3 files where GNU grep named 3, `-l -I` 1 of 2, and `-c` counted 2 of 3. `LC_ALL=C` is set on every platform so that one rule serves a
  reader who doesn't know which grep they have. Measured on GNU grep under `LC_ALL=C`: `-i` did not
  fold a non-ASCII letter's case, and `\b` did not match beside one.
- 12: the operator's own close prompt, run in the kit on 2026-10-17 for the first time (the kit's
  decisions log, §101). It surfaced fixes that were finished but in no release, which nobody was
  tracking: every gate fix of that day was on the main branch only, with no release cut to carry it.

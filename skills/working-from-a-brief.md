# Working from a brief

**Loaded:** always, once per session: the machine's user-level `CLAUDE.md` imports it from the kit's
pinned install, and a project holds no copy (`skills/README.md`). Procedures 2 and 3 apply to every
request, whether an agent drafted it or a person typed it. Procedure 1 applies only to a brief that
states a size. Procedure 10 applies to every report a session makes, and to its handover.

Load canary: kc-7e570370ff2b938b. A daily check looks for this line in what sessions loaded; leave it as it is.

A brief written by someone who can't see the code holds two kinds of statement about the code:
things reported earlier, and assumptions. Neither has been checked against the code as it is now.
These procedures turn a brief into work without letting its assumptions pass as facts.

## 1. Size a brief that states one

1. When a brief states an expected size in countable terms (files or tables touched; any migration,
   schema change, new dependency, new component or data deletion; a rough step count), treat it as
   blind and correct it against the code before starting. State the corrected size, even when it
   agrees.
2. Count hand-edited files, against the upper end of the estimate's range but never above its
   lower end plus 2 (a blind 3 to 8 counts as 5, so the doubling stop is at 10, not 16), item by item
   when the brief sizes items separately.
3. Stop and report before starting if the correction differs in kind (for example, a migration,
   schema change, new dependency, new component or data deletion the brief didn't name), or if it
   doubles and the corrected size is 5 files or more. A gate the brief didn't identify as one is a difference in
   kind; a gate is anything whose job is to allow, block or alert: a hook, a CI check, a validator, a
   backup filter, an alert route, a secrets guard, a permission setting. A change after which
   reverting the code alone would leave existing data unreadable counts as a schema change, for
   example a new record type that an older reader rejects.
4. If the work crosses either line partway, stop where nothing is half-applied, and report.
5. Never trim the work to fit the estimate, and never pass the line quietly. Leaving a file you know
   is stale, to stay under the line, is a trim.
6. Keep one line per sized ask in an append-only log, in fixed fields:
   `date | ask | estimate | corrected | stop: none, kind or doubling | outcome`. The outcome is one
   word: proceeded, cut, redirected, or open while unresolved. Write the line even when nothing
   fired: a log kept only on firings can't tell "live and quiet" from "never applied". The log line
   is not part of the size.

**Would revisit if:** briefs come from someone who reads the current code before writing them; or the
log shows a doubling catch below 5 files that isn't a gate, or round trips on trivial fixes returning
at 5 files or more.

## 2. Reopen a decision on a fact

1. A factual error, a code reality that contradicts the plan, or a consequence nobody named reopens
   the decision, including one already marked decided.
2. Ask it as a short question on its own, never as a line inside a completion report. Give what you
   measured, and what would have to be true for the current plan to still be right.
3. Pause only the part the question affects, at a point where nothing is half-applied. Carry on with
   the rest.
4. Don't act on the alternative until the person who owns the decision answers.

**Would revisit if:** briefs come from someone who reads the current code before writing them, or
reopened decisions almost always end with the plan unchanged.

## 3. Say what you measured

1. In every report about code, mark which statements you checked, with the command or reading behind
   each, and which you infer.
2. A measured statement overrides the brief's assumption. An inference does not: report it as one,
   and say what would check it.

**Would revisit if:** whoever acts on a report reads the code themselves instead of the report.

## Where a project sets its own bar

A project's `CLAUDE.md` may set its own bar for stopping, such as "proceed by default; stop only
before an action that is irreversible and consequential". Where procedure 1's stop or procedure 2's
pause meets that bar, the project's bar decides: record the stop as fired, say so in the report, and
proceed. Four things never relax: the corrected-size statement, the log line, the measured and
inferred split, and the gate tests (`gates`). A decision its owner ruled still pauses when it is
reopened. Where the project's bar and this procedure disagree, report the conflict:
never reconcile it silently.

**Would revisit if:** the log shows work going ahead under a project's bar that a stop would have
saved, or no project sets a bar of its own.

## 10. Compaction, rotation and the handoff file

After a compaction a session works from a summary and has lost specifics: the state it held, the
steps it ran, the report it wrote. A conversation left idle long enough is compacted too, so a report
can be cut off between its writing and its reading. This procedure makes every report say where the
session stands, keeps one file a new session can take over from, and times the handover.

1. **Rotation.** A session's first compaction, during a brief or while idle, starts it looking for a
   good stopping and rotation point. When that point comes is the session's judgment, weighing what
   the work in hand needs; it may push on for quite a while. A session may also recommend rotation
   without any compaction, when it judges its load has been heavy. At the second compaction, rotation
   becomes the priority, though the session may still push a few turns to reach a better stopping
   point. From the first compaction on, each report names the stopping point the session is aiming
   for, and after the second, why pushing on to it beats rotating now. The target is neither a full
   day nor a rotation every hour; needing to rotate after one or two turns means something is wrong.
   A compaction mid-brief doesn't stop the work. After a compaction while idle, the session re-reads
   its handoff file before acting on the next brief.
2. **Reports.** A report is the reply that closes a brief or an ad hoc request from whoever gives
   the session its briefs.
   Heartbeats, progress notes and monitor updates during a long task are not reports: a monitored
   process gets one report, at its end. Only reports carry the compaction line and the handoff
   rewrite.
3. **The compaction line.** Every report says whether the session has compacted since its previous
   report, during a brief or while idle between briefs, as the session itself sees it. If the machine
   keeps a compaction log (one line per completed compaction, written by a hook when one ends), the
   report gives that log's reading for its session ID too, labelled unconfirmed until the log has
   recorded its first real compaction. A disagreement between the two readings is a finding to
   report, never something to reconcile. The kit ships no such hook; the session's own reading is
   never optional. If the session compacted mid-brief, the report names the steps that ran after the
   compaction. When the session recommends rotating now, the report's first line says so: in a project
   that uses numbered relays (`patterns/numbered-relays.md`), on the echo line after the session ID,
   so the echo still opens the reply; otherwise as the reply's first line.
4. **The handoff file.** Before each report, the session rewrites its handoff file, so that a new
   session can take over by reading that one file. It holds current state only, rewritten each time
   rather than appended; history stays in the decisions log. It points to the decisions log by section
   and to a queue by entry number (the project's follow-up queue, `records/followup_queue.md`, or
   the operator's queue where one is kept) instead of restating them, and never holds a queue item. It
   records the session's ID prefix and, in a project that uses numbered relays, its label and its last
   relay number. Where a project runs more than one live session, each session label has its own
   handoff file. It lives wherever the project already keeps its handoffs; if that would put it in a
   tracked repository of a project that belongs to an organization, the session flags that to the
   project's owner instead of deciding. Any time stamp in a handoff file is taken from the clock,
   never written from memory (procedure 9, `record-stamps`).
5. **Reprints.** A reprint copies the report verbatim, never regenerating it from a summary: from the
   session's own transcript, or from a reply file where the machine keeps one and no turn has ended
   since the report.

**Would revisit if:** the tool keeps a session's specifics through compaction, or carries a session's
state to its successor itself.

*Provenance: `skills/PROVENANCE.md`, lines 1 to 3, the precedence line and line 10.*

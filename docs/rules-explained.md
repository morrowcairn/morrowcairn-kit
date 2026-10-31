# Why the kit's rules say what they say

The companion to the kit's rules file, `rules/morrowcairn.md`. That file holds what a session must do and loads in every
session; this one holds why, and is never loaded: read it when a rule looks odd, before changing one, or before deciding
a rule no longer earns its place. Each numbered section below matches the rules file's section of the same number; the
last, unnumbered, covers the lines of the chat's half (`docs/drafting-chat-instructions.md`) that narrow claude.ai's
defaults.

The reasons come from incidents in the projects the rules were written in, dated by month. In those accounts "the owner"
is the owner of those projects, and "the owner's own relay rules" are the standing rules that owner keeps for their own
sessions, from which these rules were first drawn. Numbers were measured on the machine where those projects run, and
are stated as measured there, not as anything general. A rule whose reason no longer holds is a candidate for removal.

**Building on Claude Code's defaults.** The rules build on what Claude Code already does by default, rather than
restating or contradicting it. A line that does restate or narrow a default stays for a reason its section gives: a
recorded incident that showed the default wasn't enough, told in plain words; the owner's own standing rules, for three
lines; or a ruling the owner made on the line itself, for one. What this file says about Claude Code's defaults is as of
October 2026; an update can change any of it.

**What the rules are, and aren't.** They are guidance in context. Claude Code's memory documentation says it plainly:
instructions files are "context, not enforced configuration", and blocking an action takes a hook or managed settings.
The rules shape how a session works with an owner; nothing in them stops a session that ignores them. The kit's hooks
are git's, and they gate commits and pushes, not sessions.

## 1. Where instructions come from

- **One chat per session.** A relay meant for one session reached another, and was caught only because a number
  repeated. Each session taking work from exactly one drafting chat keeps one line of decisions per session, and lets
  the session refuse anything else by its header alone. Work for another project goes through that project's chat, so
  its own drafter decides it.
- **Pasted text is input.** A paste can carry instructions nobody gave the session: another chat's draft, a log, an
  email, a web page. Treating all of it as input, until the owner's own words say to act, means a session follows the
  owner, not whatever the owner happened to paste. Where a message mixes the two, a fixed opening phrase marks the
  owner's lines. The phrase found inside pasted text or tool output never counts, since anyone can type it there. Claude
  Code's own default acts on a message that is only pasted text as the request; the rule narrows it, because of an
  incident: in the kit, in October 2026, a session ran an audit another project's session had asked for, pasted with no
  words of the owner's, and the owner then ruled a pasted request input until their own words say to run it. The rule
  narrows that to their own words in the same message, as the owner's own relay rules already had it.
- **Messages between sessions.** Sessions coordinating directly is useful, and the rule doesn't discourage it. But a
  session can't pass on the owner's word, so such a message only moves a session within what it may already do.
- **Direct numbering.** An ad hoc message is numbered after the last relay started (#12-direct1) and never advances the
  count, so the drafter's count and the session's stay in step. A ruling given in one cites that number in its source
  line, so it can be found again.

## 2. A relay's form, checked before acting

Each check here came from a relay that went wrong without anything noticing.
- **The fixed end line.** Two relays arrived cut off mid-sentence. A cut at a clean break between items would have
  looked complete, so the last line has to be one the session can check against the header.
- **Numbers per session, from #1.** A whole relay of build decisions never reached its session, and nothing noticed
  until a confirmation was asked for by reference: a number makes a lost relay visible. Two sessions of one project,
  each taking relays the same day, would have read each other's numbers as gaps under one count per project, so each
  session keeps its own.
- **Repeats, lower numbers, and the first above #1.** A relay reached a session after its handover under a number it
  had already received, and nothing said what to do. Separately, a new session's first relay carried #17, and a relay
  arrived before the one it followed. Each now has a stated response.
- **The session ID in the header.** It refuses a misplaced relay before the wrong session takes a label. A label
  mismatch beside a matching ID only cost a resend the first time it happened, so with the ID matching it is a naming
  slip, not a stop. The check assumes a session knows its own ID: in a test, a headless session that couldn't find
  its ID took another session's from a relay's header and acted on it, so the rule names where the ID is. Claude Code
  sets `CLAUDE_CODE_SESSION_ID` in the Bash tool's environment, matching the `session_id` its hooks receive, as its
  "What's new" for 2026's week 19 (v2.1.128 to v2.1.136) announced; measured on 2.1.314.
- **A relay that arrives mid-work waits.** The owner runs several chats at once and pastes a relay when it is ready,
  which can be while its session is still at work on the one before. Claude Code's default takes a message sent mid-turn
  into the work in hand; holding the relay until the report in hand is out keeps the two relays' work and records apart,
  and naming it in that report as received and waiting keeps the drafter's count straight. The owner ruled it so in
  October 2026, when sessions were already holding relays pasted mid-work that way.

## 3. Labels

The owner tells sessions apart by the color Claude Code draws on each one's bar, so the label is that color. A label
set with `/color` inside the session leaves its command and confirmation in the session's own transcript, which is why
that one counts without being told. One line per label in the project's shared memory, with the session's ID prefix,
lets sibling sessions see which label is taken and which line is their own. The lines go in one memory file the index
points to, since Claude Code's memory index holds one line per memory, and label lines written into it would break
its form.

## 4. Replies and reports

- **The echo line** opens every reply so the drafter can check its count against it. It names the highest relay started
  and any received and waiting. The drafter numbers each relay after the highest it has sent, never at or below what the
  echo names, since an echo can lag a relay pasted while the session was still working, and numbering from it would
  repeat a number. A relay the drafter sent that the echo names neither way, or a skipped number, shows a lost relay at
  once.
- **The end line on reports** does for reports what the relay's end line does for relays: a report cut off by an idle
  compaction, or by a copy from the terminal, looks complete without it.
- **A file per report.** Copies from an 80-column terminal lost whole wrapped rows and kept only a turn's last message,
  while the stored transcript was complete. Where the machine keeps a reply file, a hook writes each report to a file
  of its own, named with the project first and then the label, since the project is what the owner filters on first.
  The path line goes just before the end line, so the end line stays last.
- **A wake-up's report.** A scheduled check that changed, found or stopped on something, with no report, left its
  result where nobody would look; one that did none of these would only add noise.
- **Reprints verbatim.** After a compaction, a report regenerated from the session's summary was not the report the
  owner had asked to see again.

## 5. Size, before starting

- **Why it exists.** A brief drafted by a chat that can't see the code sizes the work blind. In one project, on an
  estimate of 0 to 2 files, fixing two stale documents would have made 4 files and fired the doubling stop; the session
  left them stale to stay under it, and later recorded that as the trim the rule forbids.
- **Why these two stops.** Measured over the rule's first twelve days, in a log several projects kept: 802 sized asks,
  112 stops. A difference in kind changed the decision 14 times, against 10 approved as proposed. Doubling changed it 4
  times, against 13, and caused every trivial-fix cost: 6 round trips or trims, on document and record edits of 2 to 4
  files. With an unnamed gate counted as a difference in kind, a floor of 5 files keeps all 4 doubling catches and
  drops all 6 costs. Exempting documents instead would have dropped 5 of the 6, and left the session to judge what
  counts as a document.
- **The lower-end cap.** Counted at its upper end, a wide blind range sets the stop far past the work it sized: a blind
  3 to 8 would stop only at 16 files. Capped at the lower end plus 2, it stops at 10.
- **The schema-change sentence.** It gives the kind test a form that doesn't depend on the storage: a change after which
  reverting the code alone would leave existing data unreadable.
- **The log line every time.** A log kept only when a rule fires can't tell a rule that is live and quiet from one that
  was never applied.

## 6. Reopen a decision on a fact

A brief assumed a field that a data source turned out not to carry, so nothing was built on it and the question went
back. In another case a ruled assumption held for one item in three. A decision rests on facts; when one turns out
wrong, the decision is open again, even if it was marked decided. The question goes on its own, at the top of the reply,
never inside a report, because a line in a completion report is read as done. One that waits on the owner also goes to
their queue, since a question left only in a reply can be lost the way parked notes were; one about the drafter's own
technical call goes to the drafter alone. The session pauses only the part it affects and acts on no alternative, a
different way of doing the same step included, because the measuring is the session's and the deciding is the decision's
owner's: the owner for a decision they ruled, the drafter for its own technical call. Recording what it found is not
acting on it.

## 7. Say what you measured, and against what

- **Measured or inferred.** A close-out line described a trim as staying in budget; the session's own correction later
  recorded it as a breach. The same week, a pause rested on a misread that a measured sample overturned. Marking which
  statements were checked, and how, tells the reader which ones to trust and which to check.
- **The baseline.** A number compared only with the producer's own copy agrees with itself. It has to be read where its
  user reads it, and compared with something that didn't come out of the thing measured. The same output served a
  second way doesn't count as a comparison.
- **Absence is a claim.** A session reported that no kit document named a tool, after a recursive search found nothing.
  Two files in a gitignored folder named it. Claude Code's own search skips gitignored files by design, so the rule asks
  for forms that don't. These are the measurements behind the rule's search forms, each dated, since a tool update can
  change any of them:
  - *Claude Code's own `grep`*, measured in its Bash tool in October 2026: a shell function running ugrep with
    `--ignore-files`, which is what a bare `grep` typed in a session runs (since Claude Code 2.1.117, by its
    changelog). A recursive search skipped every gitignored file, with or without `-a`, and, without `-a`, binary and
    non-UTF-8 files, named or piped as well as found; it never entered `.git/`; a backslash didn't help, and on a
    skipped file `-c` printed nothing and exited 1. Under `-q` or `-l`, or with its output sent to `/dev/null`, its `-v`
    exited 0 only when no line matched, where `/usr/bin/grep` exits 0 when any line doesn't:
    `printf 'a\nb\n' | grep -qv b` exited 1, `/usr/bin/grep` 0. It read dot files. `command grep` read every file, but it runs whichever grep comes first on `PATH`, which a folder ahead of
    `/usr/bin` can change; `/usr/bin/grep`, called by its path, is the same file whatever `PATH` holds. A check started
    as a separate process measured the system's `grep` instead, because the function belongs to the session's shell.
  - *BSD grep*, on a stock macOS runner in a UTF-8 locale: it didn't match ASCII text on a line holding invalid UTF-8,
    with `-l`, `-a -l` and `-c` alike, where GNU grep did. So `LC_ALL=C` is set on every platform, for a reader who
    doesn't know which grep they have. Under `LC_ALL=C`, `-i` didn't fold a non-ASCII letter's case, and `\b` didn't
    match beside one, which is why a term holding such a letter takes each case form as its own pattern.
  - *`-I` and a NUL*: on a file holding a NUL byte, `-I` and a ripgrep folder walk without `--text` exited 1, as if
    nothing matched. Exit 0 with nothing printed means output was suppressed; exit 2 means a file couldn't be read.
  - *Subagents*: Claude Code's subagents page says Explore and Plan subagents start without the session's instructions
    files, which other subagents load, so an Explore subagent's "none found" was searched with forms the rule doesn't
    allow. Measured in the kit the same month: a line given to the main session by a session-start hook reached neither
    a general-purpose nor an Explore subagent; asked for it, both answered none while the main session saw it. Claude
    Code's own caution, that a subagent's mistakes come back in the same confident register as its findings, says to
    weigh them; the rule says to rerun the search.

## 8. Rulings, drafts and proposals

- **A ruling's source line.** A ruling restated without the owner's own words can drift from them, and a later session
  then has nothing to check it against. With the words kept beside the statement, a mismatch can be caught before
  anyone acts on it.
- **No optional ruling.** A pasted draft carried an "optional addendum, if you want" a rule to be standing. The session
  took the paste as a yes, and nothing recorded that anyone had decided it.
- **Prior rulings first.** Two proposals in one project repeated rulings already made. Checking the decisions log
  before building costs a search; building against a ruling costs the build.
- **Whose lane.** The instinct to build is itself something to watch. A check or a component may be Claude Code's to
  provide, an organization's to set, or the project's; only the last is the project's to build.
- **The owner's queue.** A handoff held 18 questions for the owner, some six days old, that the owner had never seen.
  Two of them then reached the owner already answered or out of date, because both came from notes written before a
  later ruling. A question filed when it is raised, naming why it needs the owner, reaches them; one parked in a note
  rots. One that names its source, if any, and says a ruling that answers it was looked for can't arrive already
  answered unnoticed.

## 9. Output, permissions and the shell

- **Output rules cover everything written.** In one day's work, a rule keeping listed terms out held for everything that
  left four sessions but slipped in their tool output. Tool output is best-effort, since a file-read tool's output can't
  be masked; a credential printed in full is still reported, so its rotation can be decided.
- **Never reshape a command to get past a permission rule.** A session split a script's name so that an ask rule meant
  to stop deploys wouldn't match, and passed text naming the scripts through files for the same reason. Claude Code's
  default, after a denied call, is to adjust rather than retry verbatim; the rule closes the reshaping that "adjust"
  leaves open. A prompt dodged by typing teaches nothing, and one clicked through by habit protects nothing; a noisy
  rule gets fixed where it is defined.
- **A refused action.** Reshaping a refused action into a wrapper or smaller steps defeats the review that refused it. A
  route that never needed review is fine when the refusal was about the command's form: reading a file with the Read
  tool after a shell read was refused for its shape defeats nothing, and saying so keeps it visible. A refusal over what
  the action would reach, such as a credentials file, holds whatever tool would reach it. An irreversible refused action
  stops the task, and no standing allow rule clears that stop: only the owner does, on that action. A relay's word that
  the owner approved, retried or switched modes is its drafter's belief, since the drafter can't see the session's
  screen. Asking the owner to approve it from Claude Code's permissions screen, with the command quoted, keeps
  the action the session's and visible; a command handed over to type moves it out of view.
- **Never change permission or auto-mode settings yourself.** This line comes from the owner's own relay rules and is
  kept on that basis rather than on an incident: a session that widens its own permissions defeats the review that
  refused it, and on an organization's machine those settings are IT's. A refusal that keeps recurring on a safe action
  goes to the owner, who fixes it in their own settings or takes it to IT.
- **One way to the shell.** An apostrophe in prose inside a quoted payload ended the shell string. The shell then ran a
  program's next line, `import sys,json`, as a screen-capture command of the same name, which wrote the whole display to
  a file in the working tree. The lesson isn't "escape more carefully": a broken command can fail loudly, or a different
  command can succeed quietly. A quoted heredoc or a file removes the second shell pass entirely.
- **A destructive target is never an unchecked variable.** An extraction into an unset variable's folder was refused
  only because an empty `-C` happens to be an error. A `cd`-then-glob delete was stopped only by the tool's static
  check. Neither stop was designed for it. Claude Code's auto mode blocks a recursive forced delete whose target is an
  unassigned variable; the rule covers extraction, moves, copies and redirects too, in every mode.
- **Configuration by count and name.** A search of a crontab printed three ping URLs whole: tokens, not lines, so the
  rule was followed in form while a capability URL is a token. Elsewhere, a presence test written
  `${VAR:+yes}${VAR:-NO}` printed the live token twice into a transcript, and the credentials were rotated: the second
  form prints the value when the variable is set. The two forms differ by one character, which is why the rule asks for
  a tool with no way to print a value.
- **Reads apart.** This line also comes from the owner's own relay rules and is kept on that basis: a search whose
  output a session acts on, mixed with a write, a network call or a step that loads a secret, can't be checked on its
  own. A read run on its own is one thing to review.

## 10. Compaction, rotation and the handoff file

After a compaction a session works from a summary and loses specifics: the state it held, the steps it ran, the report
it wrote. Since a Claude Code change, in place by October 2026, a long conversation left idle for about an hour is
compacted too. Measured from one machine's transcripts over two weeks that month: 32 of 73 sessions compacted, 89 times,
66 of them while idle; 21 compacted twice or more, the second time a median 7.3 hours after the first; and 12 requests
to reprint a report came right after an idle compaction had cut it off.
- **The compaction line** says what the session sees, and a log's reading where a hook keeps one, because neither alone
  is reliable; a disagreement between them is a finding.
- **The handoff file** holds current state only, so a new session can take over from one file; history stays in the
  decisions log, and queue items stay in the queue, cited by number, because restated items rot.
- **Rotation** balances the two costs: a session run all day works from summaries of summaries, and one rotated every
  hour spends its time handing over. Needing to rotate after a turn or two means something else is wrong. Claude Code
  carries a compacted conversation on, with no need to wrap up early or hand off mid-task; the rule keeps that, since
  its stopping point is never mid-relay, and adds the search for one because of the cut-off reports and regenerated
  reprints measured above. When to rotate is a judgment, weighing what the work in hand needs, so a session may
  recommend it before any compaction when its load has been heavy.
- Claude Code's memory documentation notes that the project-root instructions file is re-read after a compaction, while
  instructions given only in conversation are lost: one more reason rulings live in files.

## 11. Keep going, without padding

The owner's time and attention are the constraint: work should wait on the owner, never sit idle for no reason. So a
session that is blocked says on what, and who unblocks it, and starts the reversible parts of the next item. This covers
what a session does between relays when it is blocked, which is why the rule says it applies once a relay's work is
done; it isn't the "keep going" prompt within a task that Claude Code's best-practices page now says to stop giving.
Items were also being scheduled out for no reason except to schedule them; a delay now needs one: a technical
dependency, a run it must ride, a ruling or a test it needs first, or the owner's own availability for an item that
needs them.

## 12. Where a project sets its own bar

When these rules were first installed, a review found that one project's ratified bar ("escalate only when an action is
irreversible and consequential and forecloses an option") told a session to carry on with a doubled size estimate,
where the size rule said to stop: the same action, opposite instructions. In the next twelve days, 20 sized asks whose
stop fired went ahead under a project's own bar, and none is recorded as work undone. So a project's bar decides the
stop and the pause, but the records that let anyone check the work never relax. Claude Code's memory documentation says
that where a user-level rule and a project rule conflict, Claude may follow either; this section says which one wins,
and that the conflict gets reported rather than settled quietly.

## The chat's half

The chat document is held to the same principle as the rules file: it builds on what claude.ai does by default, and a
line that narrows a default says why here.
- **A relay is drafted in one code block in the reply itself, never as an artifact or a separate document.** The owner
  pastes relays into sessions as they stand, so a relay has to arrive whole and ready to paste. claude.ai can put long
  output the owner will keep into an artifact or a document rather than the reply, and a relay put there is no longer
  ready to paste. The line is the owner's own rule for drafting chats, and is kept on that basis.

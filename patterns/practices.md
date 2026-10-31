# Building practices

On-demand guidance for what Claude Code builds: read the practice a task touches. Nothing loads this file into a
session; it ships in each install beside the other patterns. Each practice was written down in a real project after
work went wrong without it. Where Claude Code's own best-practices page covers part of one, the practice keeps only
the rest and points to the page's section (read 2026-10-27; the page changes, so follow the link, not this summary).

## 1. One deploy path, shipping exactly the bytes that were tested

- Deploy through one script or job, and make it the only way in: a way around it carries none of its checks.
- Run the tests on a snapshot of the exact commit you ship, and have the deploy refuse bytes whose hash differs from
  the ones the tests ran on.
- Why: a gate guards only the path it sits on. An ad hoc deploy, or a rebuild after the tests ran, ships bytes no check
  has seen; an unaudited build going live, or stale data served for half an hour, is what that looks like.

## 2. Done means read where the user reads it

- Check the delivered thing the way its user reaches it: the public URL, the file as downloaded, the number as the
  report shows it. Never only the producer's own copy, its log line, or a monitor's summary.
- Compare it with a source that didn't come from it: the original's own count or index, or an independent pull. A
  number checked only against itself is internal and unverified, and the report says so.
- Why: a producer and its monitors report on their own work. A count can collapse where it's consumed for days while
  every check on the producer's side stays green.
- Claude Code's page already says to give Claude a check it can run and to ask for its evidence; this adds where to
  read and against what. See [Give Claude a check to
  run](https://code.claude.com/docs/en/best-practices#give-claude-a-check-to-run).

## 3. A check counts once it's seen letting good input through

- A check that refuses a bad input has shown half of what it claims. Run it on a known-good input too, and watch it
  pass.
- Say what the check would still pass if it were broken (an empty input, a stub, a stale fixture), and test that it
  doesn't.
- Why: a suite that never tells good from bad stays green just like a working one, and a detector that fires on
  everything sends people alarms until they stop reading them.
- Writing a failing test first is on Claude Code's page, under [Write a specific
  prompt](https://code.claude.com/docs/en/best-practices#write-a-specific-prompt); this is the other half. For a gate,
  the kit's `gates` skill holds the red half.

## 4. Going public is a checklist run before any visibility change

- [`going-public.md`](going-public.md), beside this file.

## 5. Backups: know what they take, keep secrets out of them, prove a restore

- Know what each backup copies. One that takes everything not excluded takes keys, credentials and live databases too:
  list its exclusions and check them against what is on disk.
- Keep secrets and private keys out of every backup leg that leaves the machine, or encrypt them before they go.
- Copy a live database with its own backup tool, never as plain files while it's being written.
- A backup counts once a restore from it has run in a clean environment and the result was checked.
- Why: a backup fails silently in two ways, copying what it shouldn't and not restoring what it should.

## 6. Open another project's data read-only

- When code reads another project's data (a database, a corpus, a shared folder), open it read-only: a read-only
  connection or mode, or a read-only mount. Name the target of every write explicitly.
- Why: one stray write into a shared source, or a statement run against the wrong database, quietly removes what other
  work depends on, and nobody finds out until they next read it.
- Claude Code's permission rules and sandbox limit what Claude itself can read and change, and its page notes that a
  rule won't catch a script that opens the file: [Limit access with permission rules and the
  sandbox](https://code.claude.com/docs/en/best-practices#limit-access-with-permission-rules-and-the-sandbox). This
  practice is about those scripts.

## 7. Every source is logged, and every claim cites one

- Every file a project takes in from outside gets a line in a source log: where it came from, when, and how it was
  fetched.
- Every claim a project makes (a number, a date, a deadline) cites the source it came from, the primary one where there
  is one.
- A provenance line records what ran, not what was meant to: write it from the run itself.
- Why: a claim without a source can't be checked or corrected, and a log written from intent records runs that never
  happened.

## 8. Know the way back before you deploy, and keep the last good copy

- Before a deploy or a destructive run, know the rollback and that it works: the command, where the last good copy is,
  and how long it takes.
- Never let a deploy or a run overwrite the copy you would roll back to. Export rows before deleting them.
- Why: a failed change costs as much as the slowest way back from it. Claude Code's checkpoints rewind its own edits in
  a session, not a deploy.

## 9. An alert counts once a test of it has reached a person

- Before relying on an alert, fire a test of it end to end and see it arrive where its reader will see it.
- Name the reader of every new alert: an alert nobody reads is a log line.
- Give every alert that fires a disposition: fixed, accepted, or tuned.
- Why: an alert route breaks without a sound, and a check can sit red for days with nothing reaching anyone.

## 10. Run it exactly as its real runner will

- Test a scheduled or automated job the way its runner runs it: the same interpreter, `PATH`, environment, working
  folder and user. Under cron that means cron's near-empty environment, not your shell's.
- Instructions count once someone who didn't write them has followed them literally.
- Why: what works in the shell that wrote it fails under a runner that lacks a library, a variable or a path.

## The instinct to build is itself something to watch for

- Before building a check, a guard or a component, say whose lane it is in: Claude Code's, an organization's, or the
  project's. If it isn't the project's, don't build it; use what that lane's owner provides.
- Each step can be a sound answer to the step before it (a wall, then a tool to hold the wall, then checks on the tool,
  then a log of the checks) and the whole can still drift away from the work.
- Keep the enforced set small: every check sometimes fires when it shouldn't, and each one has to be kept right
  through every change around it. Claude Code's page makes the same point about hooks and deny rules, under [Choose
  who a rule applies to](https://code.claude.com/docs/en/best-practices#choose-who-a-rule-applies-to).
- Why: what a part costs isn't building it. It's keeping it right through every update of everything it touches.

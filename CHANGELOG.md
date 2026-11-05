# Changelog

Earlier releases called the do-not-publish list the identity list, and their entries keep the words of their time.

Point releases are driven by *instance* evidence — friction
recorded in a spawned project's `records/kit_feedback.md`, or an incident recorded by a spawn or by
a project run by the kit's operator, is the evidence that advances a version. A pattern refined by
imagining its use is refined by guesswork; one refined because it failed a real job is not.

A spawn takes a release with [`patterns/local-upgrade.md`](patterns/local-upgrade.md). From v0.8.0 it
holds no kit-owned copies: it runs a release's install, pinned in `kit.pin`, and takes a later one
with `bin/kit-pin to`; a spawn made earlier moves onto an install once, and a kit-owned file it keeps
changed is a fork it declares in `kit.forks`.

A **minor** release marks a change in behavior a spawn sees. A **patch** changes nothing a spawn's hooks refuse.

## v0.13.1

Wording only, in the session rules; no code changed.

## v0.13.0

v0.13.0 is another, a minor: what a hook or check refuses changed, so a project moves onto it on purpose, with
`kit-pin to v0.13.0` from the new release's install. pre-push takes a push from a linked worktree that it refused
before, and kit-pin refuses a repository with grafts and fails a list that doesn't compile; the reply-file hook's
names, the setup prompt, the session rules and the documents that describe them changed too. What changed:
- **A push from a linked worktree.** pre-push read the do-not-publish list's pin from the worktree's own git folder,
  where none sits unless `kit-pin repin` was run there, so every push from a new worktree was refused until then.
  pre-push, `kit-pin check` and `kit-pin repin` now read and write the pin in the repository's shared git folder, which
  every worktree of it shares, as `bin/kit-history-audit` already did; a pin left in a worktree's own folder is never
  read. `kit-pin repin ci` reads CI's record, `.git/leak-pattern.ci`, from the same shared folder. In a linked worktree
  of a project still pinned to an earlier release, whose pre-push reads the worktree's own pin, `kit-pin check` says so
  and that `kit-pin to v0.13.0` or later moves it.
- **kit-pin refuses a repository with grafts,** as pre-push, pre-commit and the tree scan already do: a graft changes
  the history git shows, and no setting turns it off. `git replace --convert-graft-file` turns grafts into replace
  refs, which kit-pin ignores.
- **kit-pin check fails a list that doesn't compile.** A list that matches its pin can still fail to compile as an
  extended regex, and pre-push then refuses every push; `kit-pin check` now compiles it as pre-push's tree scan does,
  in the caller's locale, and reports the list as failing (exit 3), naming no term. kit-pin also drops every inherited
  git setting that chooses a repository, a work tree, an index or an object store, keeping only those that choose which
  configuration git reads and one that only narrows where git looks for a repository, and it turns replace refs off,
  as pre-push does.
- **The test suites.** The load check's suite runs the stub's failure ping under bash 3.2 and with the real curl
  against a listener on the loopback address; the hook and install suites gain the cases for each change here.
- **Additions to the session rules**, each on the owner's ruling. The absence rule says that Claude Code's search
  wrapper answers a `-v` under `-q` or `-l`, or with its output discarded, differently from the system grep, so a `-v`
  test calls `/usr/bin/grep` by its path too. A small or low-risk reversible call, technical or on scope or sequence,
  that has none of the reasons that send a call to the owner is the session's to make and go on, each one listed in its
  report under the heading "Calls I made:" so it can be undone, never past a relay's stop condition, the size rule's
  stops, a relay's boundary or anything another rule sends to the owner; a larger one is the drafter's, and the drafter
  may reassign an owner's-queue entry that turns out to be its call, with its reason, shown in its next Outbox, the
  owner able to pull it back. Those reasons name a call on purpose, no longer one on scope, here and in the drafting
  chat's document. A check run on a release candidate is internal until it is re-read on the published release. A
  refusal that doesn't make clear whether it is about what would be read or changed, or about how the command is
  written, is taken as about what would be read or changed, which holds for every route. A new rule keeps the work's
  history: a delete only of an exact duplicate or of something kept elsewhere, anything else kept or archived, what
  holds a secret's value removed, and an archive scanned before it is made. A report that ends the session's turn says
  so in one line, "Stopped: waiting on", then who or what. The file stands at 210 lines, its check's limit.
- **Two fixes to the setup prompt.** Where git resolves only one of a name and an email, the setup asks for and sets
  only the missing one, at user scope, and never one git already resolves at any scope; before it set both. Before
  adding the reply-file hook, it looks for a Stop hook that already files session reports and, with one there, skips
  the kit's unless the person asks for both, since each report would otherwise be filed twice, the second copy as a
  `-resend` file; its closing test checks that exactly one file appeared for its test report. Before setting a name or
  an email, it also looks for git's conditional includes and for an identity set in the environment, by name only,
  and sets nothing where it finds one; it finds a Stop hook already filing reports by asking the person for `/hooks`,
  which shows hooks from every place they come from; and its closing test checks `/hooks` again and counts every new
  file in the reply folder by its time, not its name.
- **The reply-file hook's names** (the owner's ruling). A second report under the same relay ends `#N-part2`, then
  `-part3`, and the hook files it under its own name, `…-NN-part2.md`; the session rules and the drafting chat's
  document say so. A different report under a name already taken goes to `…-new2.md`, then `-new3`, verbatim, where it
  went to `-resend2`; the same text again still writes nothing. The setup's closing test looks for a `-new` or a
  `-resend` copy. An end line under a tag the rules don't name, such as an older draft's `#13-next1` or `#13-next`, or
  with formatting marks around it, now ends a report too: the hook files it verbatim under the name the line gives and
  tells the person in a warning Claude Code shows them (a `systemMessage`, never a block); tags run together
  (`#4-direct1-part2`) are filed the same way, with the warning only where one isn't a tag the rules name. A line that
  starts like the session's own end line but can't be read (no number after `#`, a project with a `/`, no session ID)
  still files nothing, its text going with the next report where one follows, and the warning quotes it and says why.
  Before, the hook said nothing in any of these cases and filed none of them, and a report ended mid-turn under such a
  line went into the next report's file.
- **The IT document** says the setup sets only a missing name or email at user scope, and its removal steps say how to
  see the git identity and the gitleaks the setup may have set for the person, and how to remove each; both are the
  person's to keep or remove.

## v0.12.1

v0.12.1 is another, a patch: nothing a hook or check refuses changed, so a project needs no move; pre-push writes two
counts in a portable form, and the load check's stub, the reply-file hook, the deploy pattern, the setup prompt, the
session rules' reach and the documents that describe them changed. What changed:
- **The setup prompt is led by Claude Code.** It asks you once whether it should do every step itself, your Claude
  Code settings and crontab included, or show you each change to make, and every later step follows that answer; then
  it drives the whole setup, asking plain questions, one question at a time, each saying what it's for and what
  skipping it means, with a default to take, doing each step itself with your approval at Claude Code's own prompts,
  and handing you a command only where it can't, saying why. It runs `kit-pin user` itself, outside Claude Code's
  sandbox where it has to, with your approval; it offers to fetch a missing gitleaks, checked against the sha256 the
  kit pins, if you say so, or says what to install and where to get it, and waits; on WSL it keeps code, projects, the
  clone and the install in the Linux home, warning at once if it was started on the Windows side, and offers the reply
  folder on the Windows side, where a browser attaches files from; it offers to set up the daily load check, saying
  on WSL that it runs only while WSL is running; any copy it makes tests whether the destination is there first; and
  at the end it checks that it works: the daily check run as cron runs it, and, for someone who runs relays, a test
  relay for the reply-file hook and `/compact` for the compaction log. `kit-pin user` follows the first answer too,
  handed over as a command to someone who asked to be shown each change; where Claude Code's sandbox refuses the git
  identity's `git config --global` or the daily check's test run, the session retries it outside the sandbox at Claude
  Code's prompt, as it does for `kit-pin user`, or hands it over, by that answer.
- **The reply-file hook with a space in the reply folder's path.** A report that ends mid-turn is filed when the line
  before its end line names its file; the hook took that line's last word as the path, so a folder such as a Windows
  user's `/mnt/c/Users/First Last/claude-replies` on WSL never matched, and the report ran on into the next one's file.
  It now matches a line that ends with the report's own file by its whole path, a space in it included; for a path
  without a space, the match is the same as before, and a line naming any other path still files nothing.
- **The deploy pattern runs on GNU.** `patterns/atomic_deploy.sh` read its headroom with `df -P --output=avail`, which
  GNU coreutils' `df` refuses ("options -P and --output are mutually exclusive"), so a copy stopped before any transfer,
  leaving the live file untouched. It reads the space available from `df -Pk`'s fourth column with awk, the same value
  `--output=avail` gives, and a check in the kit's own tests runs it through to its smoke gate.
- **The daily check's ping link stays private.** The setup has you put `KIT_LOAD_CHECK_PING` on a crontab line of its
  own, above the check's line, where it reaches the job's environment, which only you can read; and the stub hands
  the link to curl on its standard input. v0.12.0's stub put it on curl's command line, which other users on the
  machine could read for up to ten seconds while a failure ping was sent.
- **The relay settings only for people who run relays.** The settings file's five entries, and the two optional hooks,
  belong to working through relays; the setup asks about them only after you say you'll do that, writes
  `morrowcairn-local.md` itself, never over a file already there, and, for each hook, adds it to your Claude Code
  settings when you say so, or gives you the lines to paste. Someone who runs no relays gets no settings file.
- **The session rules for people who run no relays.** The rules file says that a session which has received no relay
  skips its sections on relays, labels, reports and the handoff file, and the numbering of direct messages, and
  follows the rest. Section 1's bullet on direct messages and sections 3, 4 and 10 say so themselves; section 2 acts
  only on a relay. `docs/rules-explained.md` gives the reason.
- **The drafting chat's half, for claude.ai.** For someone who runs relays, the setup prints the install's
  `docs/drafting-chat-instructions.md`, as it is, under a short header filled from their answers, to keep in the
  account's instructions in claude.ai, its first line turning it on only in chats where they say they're working with
  the kit; a claude.ai Project is the alternative.
- **A git identity where there is none.** Where git resolves no name or email, the setup asks for them, says a public
  host shows that email and offers the host's no-reply address, and sets them for git or shows the commands; it never
  changes an identity already set.
- **The owner phrase, exactly.** The setup records the words the person gives for it as typed, each alternative too,
  since a session tells the person's own instructions from pasted text by them.
- **The README** says that the person sets the CI secret, `LEAK_PATTERN`, and that no kit step sets it; v0.12.0's
  said the setup fills it. The IT document says the setup writes the local settings file, edits Claude Code's
  settings only where the person asks, and may make one download, a missing gitleaks; its file table lists what the
  setup writes at the person's say: gitleaks' program, the daily check's copy and its crontab line, and the hooks'
  entries.
- **WSL2, measured.** On two Windows machines under WSL2, both installing v0.12.0's code: Ubuntu 24.04, where v0.12.0's
  setup prompt ran and the two Claude Code hooks passed a live test; and Ubuntu 26.04 with uutils coreutils, where a
  draft of this release's setup prompt ran end to end, the five test suites passed, and commits, pushes and both refusals worked as designed. On the Windows side (`/mnt/c`)
  file modes are lost and commits and pushes run 3 to 5 times slower, so projects stay in the Linux home. A machine
  an organization manages isn't measured yet. The README and the IT document say so in place of "not yet tested".
- **head and tail counts with `-n`.** pre-push's two `head` counts and two lines of the install suite write the count
  as `-n N`. The older form, the count straight after the command's name, is one GNU
  coreutils' manual calls obsolete, telling scripts meant for standard hosts to use `-n` instead, so another
  implementation may refuse it. What each line does is unchanged, and a check in the kit's own tests keeps the older
  form out of every shipped file.
- **A note on v0.12.0:** it also added [`patterns/practices.md`](patterns/practices.md), ten practices for the work
  Claude Code builds; its entry below didn't say so.

## v0.12.0

v0.12.0 is another, a minor: a project sees new behaviour, and moves onto it with `bin/kit-pin to v0.12.0` from the
release's install. What changed:
- **The do-not-publish list moved out of every clone,** to one file per project, `~/.config/morrowcairn/lists/<id>`,
  the id in a tracked `kit.list-id`, `~` the home folder the user database gives, never `HOME`. `to` and `migrate`
  copy a project's `.git/leak-pattern` there byte for byte, never over a list that differs, and leave the old file
  for you to delete; `kit-pin move-list` does that alone. The pin stays in `.git`.
- **Every push needs python3,** which finds the project's do-not-publish list; without it the push refuses and says why,
  and so does a push from an account the user database gives no absolute home (in a container, a user with no line in
  `/etc/passwd`). `kit-pin user` makes `~/.config/morrowcairn` at 700, and the daily load check's probe asks Claude Code
  not to save its session.
- **No list from the environment.** pre-push, and `kit-pin`'s `check` and `repin`, read the list only from its file:
  a project can no longer hand pre-push a list in `LEAK_PATTERN`. CI's tree scan still reads its repository secret.
- **A new project starts with two checks off:** the do-not-publish list (the line saying it has none, pinned) and the
  identity guard (commit one goes under the identity git resolves). A move says so and gives each one's setting; a
  project you move keeps its own list and identity.
- **Under IT's hooks path,** `to` gives the clone its own path on the stubs, which run IT's pre-commit and pre-push
  first, and a relay for each other hook IT's folder holds; a hook IT adds later makes the stub refuse every commit,
  naming it, until `to` runs again. `migrate` takes a clone with a hook manager's path, Husky's among them.
- **The session rules load through `kit-pin user`,** which links the rules file, the three skills and the two hooks'
  scripts into Claude Code's folder; a user-level `CLAUDE.md` no longer imports kit files, and the daily load check
  fails one that does. Two Claude Code hooks ship, off until your settings name them: a file per session report, and a
  compaction log.
- **Refusals say who acts:** after the first line, "You can:", "If IT manages this machine:" and "The project's
  owner:" lines where each applies; every message calls the list the do-not-publish list; a printed step that
  writes a list refuses a file already there; the sandbox asks name the list's folder; and no message points a
  commit or a push outside the sandbox.
- **[`docs/for-it.md`](docs/for-it.md),** for an organization's IT: what the kit writes, runs and sends, what is off
  by default, and how to remove it.
- **[`docs/setup-prompt.md`](docs/setup-prompt.md),** a prompt pasted into Claude Code that sets the kit up: it checks
  the tools, reads which of an organization's managed settings apply, and takes the clone, the install and the user
  level with you, editing no settings file. The README leads with it.
- **The daily load check's ping carries the kit's fixed words alone:** pass or fail, the probe's result, and on a
  failure the kind of each problem, never a value read from the machine; the report on the machine keeps the details.
- **Known gaps.** A project's own check that reads its list has no shipped entry point through the pinned install:
  it sources the install's reader, `leak-detection/read-leak-pattern.sh`, after the stub has verified the install
  and exported `KIT_INSTALL` for it. A project's hook tests run through `kit-pin.tests`, on its own machine, before
  `to` keeps a pin move, each line under `LC_ALL=C`; the CI workflows a project copies don't run them.

## v0.11.1

v0.11.1 is another, and it changes wording only: no hook, script, message or test changed, so a project on v0.11.0 can
stay there. This README, the leak-detection README and `patterns/repo-genesis.md` describe the name list as the
do-not-publish list, for terms you've agreed or are required to keep confidential, and no longer frame it around
anyone's identity. The hooks' and `kit-pin`'s messages still call it the identity list, and so do the names the
leak-detection README's later sections share with the code, until a later release renames them together. This README's
leak section also says that neither layer recognizes personal records. And the public repository's address is now
`github.com/morrowcairn/morrowcairn-kit`; the old address redirects there, so a clone made from it keeps working.

## v0.11.0

v0.11.0 is another, the first public beta, and a cut back to the kit's core: how you work with Claude Code, and best
practices for what it builds. What a spawn sees:
- **git 2.31 or later.** Both hooks and `bin/kit-pin` refuse an older git, naming the version they need: an older one
  can colour the diff gitleaks reads, and can't read merges. A project on hand copies of the hooks should move onto an
  install.
- **A merge is scanned, not refused**: its own changes are read against its first parent. Until now the only way past
  was `--no-verify`, which skips every layer.
- **The binary scan is off unless a project turns it on**: a tracked `kit.binaries` holding `scan=on`, or a tracked
  `records/reviewed_binaries.txt`, so a project relying on the scan keeps it. Off, a push carrying a binary says so on
  one line and goes through unscanned. **What that leaves unchecked:** nothing checks a binary for credentials, at
  commit, at push or in a project's CI gitleaks job, which skips a PDF even renamed `.txt`; and a name in text
  compressed inside it, as in most PDFs, isn't seen either: the identity layer
  reads only its raw bytes, which don't hold that text. **Turning the scan on is the guard**, as the going-public
  checklist does: a binary then passes only if it is reviewed, in a format the scan can read, and clean, and a PDF never
  does. A project with binaries and no reviewed list, whose binary pushes were refused before, now pushes them with
  that note, and a test that feeds the hooks binaries and expects a refusal must turn the scan on. `kit-pin check` says
  which. An older release ignores `kit.binaries`.
- **A project with no identity list says so with one pinned line**, `LEAK_PATTERN='kit:no-identity-list'`: pre-push
  then runs its credential scan only, and says so on every push; a missing list refuses, naming the line. Its cost: a
  release older than v0.11.0 reads the line as a one-row list and, once it is pinned, passes pushes with no note, so
  move a project onto v0.11.0 before writing it.
- **The push check's limit, stated**: it reads the files at each pushed tip, not each commit's, so a name added and
  removed within one push isn't caught. A project that pushes straight to a public remote runs the history check
  before each such push: `bin/kit-history-audit`, new, which reads every commit, tag and ref, its `--control` first.
  `patterns/going-public.md`, new, is the checklist before a repository goes public.
- **Hooks beside an org's**: where IT sets `core.hooksPath` for the machine, `kit-pin to` gives the clone its own hooks
  path, on the stubs, which run the org's pre-commit and pre-push first, then a project hook it kept (`<hook>.project`),
  then the kit's checks. It never overwrites a hook, and `kit-pin check` fails a kept hook that isn't executable. (A
  note added in v0.12.0: the org's other hooks stopped running in the project, and v0.12.0 runs them through relays,
  `leak-detection/README.md`.)
- **The hooks name their gitleaks config** and refuse with none; pre-commit refuses a scan that read nothing of the text
  a commit adds; under a sandbox that hides gitleaks or the install, the refusals say it may be hidden and what to let
  sandboxed commands read.
- **The daily load check reads no transcript, and is opt-in**: the probe's answer and the skill entries are the check.
  A wrapper that runs the stub with no arguments keeps working; an acknowledgment file and the check's state file are
  no longer read and can go; the report loses its sessions, no-model-turn and acknowledged lines. The probe no longer
  turns the updater off, and under an org's `managed-mcp.json` it is skipped, saying so.
- **The code patterns are examples** (`example` in the manifest): a project's edited copy passes the checked-copies
  layer. `patterns/local-upgrade.md`'s move brings a project's doctrine copies to the release's in its one commit.
- `patterns/claude-code-at-work.md`, new: one page on using Claude Code at work with the kit.
- A list whose rows are bounded by `\b` misses a term run into a digit or an underscore: bound rows by letters instead,
  `(^|[^[:alpha:]])term([^[:alpha:]]|$)`, at a project's next move.

Not in v0.11.0, though v0.10.0's note planned them: hardening the gates against the environment they start in
(dropped), Windows (after this release), and `kit-pin check`'s report of a pinned list that won't compile and of an
inherited `GIT_DIR` (a later minor).

And a lesson, the reason for the cut: the kit had grown a work-machine guard around Claude Code, toward a security
layer it isn't. The instinct to build is itself something to watch for: before building a check, say whose lane it's
in, Claude Code's, an org's or the project's.

## v0.10.2

v0.10.2 is another. The daily load check failed every session that recorded no instructions as
"can't tell", and a session that ran only local commands, such as an abandoned `/color` or
`/rename`, never records any, so one kept the check red. A session with no model turn and no
instructions record is now skipped and counted, since whether the rules loaded shaped nothing, and
every report says how many ("no model turn: N sessions skipped"). A model turn is any assistant
record but Claude Code's own API-error record, so one turn with no instructions record still fails,
and an instructions record that exists is still checked. Tests hold it, four of them red against v0.10.1.

## v0.10.1

v0.10.1 is another. The daily load check counts a transcript it can't read as "can't tell", a fail,
on every run while its session still writes, so a session a crash damaged mid-write kept the check
red, and a real miss would land on a check already red. Such a transcript can now be acknowledged
once, with its owner's OK: a row in `~/.config/morrowcairn/load-check-acknowledged.tsv` pins its
bytes through its last damaged line by sha256, with the § that records the OK (the load check's
header says how to write one). The check reads it without the unreadable lines inside those bytes,
and the rest as usual. A change to those bytes, damage after them, a transcript gone or a malformed
row fails, and every report lists the rows by count and fingerprint. With no such file the check
runs as before, its report adding "acknowledged: none". Tests hold it, each red against v0.10.0.

## v0.10.0

v0.10.0 is another. pre-push now refuses pushes v0.9.0 let through, and the CI scan no longer
reports one of them clean. What a spawn sees:
- pre-push and the CI scan read every line as text, whatever bytes it holds. In a UTF-8 locale,
  v0.9.0 dropped a line holding invalid UTF-8 before deciding, so an identity term on such a line was
  pushed, and the CI scan reported the tree clean. Each now decides by the count of matching lines
  the allowlist leaves, and names those lines only to report them, so a hit it can't name still
  refuses;
- pre-push's binary scan, the load check's stub and `tools/install-release.sh` start python3
  isolated (`python3 -I`), so a module planted on `PYTHONPATH` or in the user site no longer runs
  inside them. Under v0.9.0 such a module let pre-push clear an unreviewed binary, made a failing
  load check pass without a report, and changed an install while it was being built, leaving it off
  its own manifest;
- pre-push reads each commit's recorded author and committer identity (`git log --no-use-mailmap`),
  so a git mailmap -- a file that maps one identity to another name -- can no longer map an identity
  holding an identity term to a clean name and hide it from the metadata scan;
- both hooks force git's colour off around their credential scan (`color.ui` and `color.diff` set to
  `never` through the environment), so a forced-colour setting in any git config no longer colourises
  the diff gitleaks reads and blinds it;
- every gate handles text byte-wise and matches in the caller's locale: pre-push, the CI scan,
  pre-commit, `bin/kit-pin` and the binary scan save the locale they were started in and set
  `LC_ALL=C`, so `cut`, `awk`, `sed` and the rest read every byte, and each matcher runs in the saved
  locale, so `-i` keeps folding a non-ASCII letter's case, which `LC_ALL=C` drops. On a Mac, in a
  UTF-8 locale, BSD's `cut` stops on a line holding invalid UTF-8 and its `grep` doesn't match one;
- pre-push matches the list against the names of the refs pushed, the tag objects a push adds and
  the file names a block reports twice, under `LC_ALL=C` and in the caller's locale, and a match in
  either counts. v0.9.0 matched these once, in the caller's locale, so on a Mac a branch name or a tag
  message holding such a line beside a term would be pushed, and a block could print a file name
  holding a term (with `core.quotePath` off), as a stand-in grep that copies BSD's miss showed. On a
  Mac v0.10.0 refuses the branch name and the tag message and withholds the file name (measured, on
  GitHub's macOS runner);
- the binary scan withholds a path the list matches; v0.9.0 printed the path of every binary it
  refused or cleared, a term in it included. pre-commit's refusal of anything staged under `.local/`
  does the same, reading the list from `.git/leak-pattern`, and with no list there it lists no name;
- an install runs the hook suite; its case PY2 can exercise its user-site plant only where the python3
  first on `PATH` has its user site on. Where it is off (a virtual environment's python3),
  `tools/install-release.sh` reports the unmet precondition and installs anyway -- the isolation
  itself is `python3 -I`, which case PY1 shows -- while CI and a direct run still fail PY2, so the
  check is never skipped unseen.

The kit's own changes, which no spawn sees: each refusal above has a test that v0.9.0 fails, beside
tests for the same hit with no `LANG` and for NUL bytes and binaries git names whole; and a lint fails
on any file a release ships that starts python without `-I`, unless its allowlist names that line with
a reason. v0.10.0 adds tests for a mailmap hiding an author, forced colour, the install-time behaviour
of python's user site, the search forms on the stock `/usr/bin/grep`, run under `LC_ALL=C`, and a ref
name, a tag message and a reported file name each holding invalid UTF-8 beside the marker. GNU grep
passes those three before the fix and after; on Linux they were shown red against a stand-in grep
that copies BSD grep's miss, and on a Mac all three pass on BSD grep. A second lint fails on any grep
call in a file a release ships that neither runs the two passes nor is named in its allowlist with a
reason and a count, and a third holds each gate to the locale rule, failing a text tool before the
gate sets `LC_ALL=C`, any matcher its allowlist doesn't name with the locale it runs in, and the
caller's locale used off a named matcher; each lint has tests of its own. Tests guard the rule: a list
row holding a non-ASCII letter blocks its other case in a UTF-8 locale in the tree, CI's tree scan, an
author and a ref name, each red against the gates with `LC_ALL=C` and no caller's locale; an author
and a message line holding invalid UTF-8 beside the marker are blocked; a staged `.local/` path, a
binary's path and a kit-pin list row holding such bytes are refused or pinned as before; a binary whose
path holds the marker isn't printed, refused or cleared, nor a staged `.local/` path holding it, with
the list or without; and a red names the stream and line that held the marker. And procedure 11 of
`skills/shell-commands.md` now names the exit status an absence check needs and the forms that read
binary and non-UTF-8 files (never `grep -I`), an identity-list search among them listing or counting
files and never printing matching lines. Its grep forms run under `LC_ALL=C` on every
platform: on a Mac, BSD grep in a UTF-8 locale doesn't match ASCII text on a line holding invalid
UTF-8, with `-l`, `-c` or `-a`, where GNU grep does. Under `LC_ALL=C`, `-i` folds only ASCII
letters' case and `\b` doesn't see a non-ASCII letter as part of a word, so the procedure says what
to do for a term with one. On macOS the install smoke builds an install on stock tools
(`/bin/bash` 3.2, BSD grep and the other BSD tools, Apple's git and python3) and runs the hook suite
from it, GF included, so GF's forms run on BSD grep there; GF8 prints, counted nowhere, what the same
search names in a UTF-8 locale without `LC_ALL=C`. The other three suites run on macOS with
Homebrew's GNU coreutils, sed and findutils first on `PATH`, and BSD grep.

An independent gate suite, run against a scratch install of this release before it was tagged,
confirmed two of its fixes: a term on a line holding invalid UTF-8, in pre-push and the CI tree scan,
and a module planted on `PYTHONPATH`. The rest are measured by the kit's own tests only.

Known limitations: `bin/kit-pin` reports two cases wrong, as v0.9.0 did: `check` reports a pinned
list that doesn't compile as active, where pre-push refuses every push; and an inherited `GIT_DIR`
points `check` and `repin` at another repository's list and pin. Both fixes are planned for v0.11.0.
And the gates still trust parts of the environment they start in. An exported shell
function, a `BASH_ENV` file, or another bash, grep, git or python3 earlier on `PATH` can change what a
gate runs; and a git attribute placed where no config override reaches it (`*.git/info/attributes*`:
a `diff` attribute on a binary type, or a `-diff` line) can still make pre-push treat an unreviewed
binary as text or hide a staged credential from the credential scan. And what a gate prints doesn't
go through one route that withholds list matches: each place that names a path withholds one itself,
so a new place that prints could show a term on the terminal (printing puts nothing in a push). The next minor,
v0.11.0, addresses these, with Windows.

## v0.9.0

v0.9.0 is another, for Linux and Mac. On Linux the four suites and the user's path, from clone and
install to the planted refusals, pass on every push. A Mac is measured on GitHub's macOS runner,
which has full Xcode: the user's path, and the hooks suite an install runs, pass with PATH only the
system's folders and gitleaks' (git 2.50 and python3 3.9, Xcode's); the other three suites pass with
Homebrew's GNU tools added. A Mac with only Apple's Command Line Tools, or with neither, is
unmeasured. Windows isn't supported yet: under Git Bash five of the suites' cases fail on the kit's
own causes, and an install made with Git Bash's defaults is refused, so it waits for the next
release. What a spawn sees:
- each identity list is pinned, by its rows and its hash. pre-push refuses unless the list it reads,
  from the environment or `.git/leak-pattern`, is the one `.git/leak-pattern.pin` names, and CI's scan
  refuses unless the `LEAK_PATTERN` secret is the one the tracked `.github/leak-pattern.pin` names, so
  a list cut short or changed in place refuses. `bin/kit-pin repin local|ci` writes a pin: a first one
  with `--first`, an append on its own, any other change only with the § that holds the owner's words.
  `kit-pin check` finishes with exit 3 while pre-push would refuse every push. A project takes its pins
  in its first move onto a release that has them (`patterns/local-upgrade.md`, step 1b). The pin
  pre-push reads is always the pushed repository's own: a list from the environment can only be the
  pinned one;
- pre-push, pre-commit and the CI scan read what git sends or records: they turn git's replace refs
  off and refuse a repository with grafts, and the CI scan, which runs outside a hook, drops any git
  setting it inherits, so it scans the checkout it runs in. The hooks keep what git sets for them, so
  they work in a linked worktree, where pre-push looks for the list and its pin in that worktree's
  own git folder;
- pre-commit refuses the genesis sentinel email, `unset@invalid.local`, as it already refused the
  sentinel name, each read from the identity git will record (config, environment overrides and
  `--author` alike); another address on that reserved domain is no sentinel;
- every gate passes only from an explicit pass point: pre-commit, pre-push, the hook stub,
  `check-copies.sh`, `tools/install-release.sh`, every `kit-pin` mode and the load check's stub. Any
  other end, an exit 0 short of it or a stop on an unset variable, refuses, and a `kit-pin` mode that
  stops puts back what it wrote;
- the credential rules: the four the kit inherited are rewritten from what each detects; the kit's JWT
  rule is now `kit-jwt`, so gitleaks's default `jwt` rule runs beside it; shapes the rewrite dropped are
  caught again (a Bearer token with `=` inside it, a quoted 40-character key nested under its key, a
  private-key header whose spacing varies); each custom rule has a test of its own. The kit's config
  and the spawn config change alike;
- the scripts run on a stock Mac: each script that hashes uses `sha256sum`, else `shasum -a 256`, else
  refuses naming both; `check-copies.sh` and `tools/install-release.sh` run under bash 3.2 and BSD
  tools; `.gitattributes` keeps LF in every text file, whatever `core.autocrlf` says; a project's
  `ci/gitleaks.yml` installs gitleaks 8.30.1, checked against its sha256;
- the daily load check no longer passes its credentials to its probe: the ping URL stays out of the
  probe's environment;
- a new project copies no LICENSE: it starts with none and chooses its own. `patterns/local-upgrade.md`
  finds the Apache-2.0 file that releases through v0.8.0 copied in, and leaves the choice to the
  project's owner. The kit itself is now MIT-0;
- doctrine: compaction, rotation and the handoff file become procedure 10 of
  `skills/working-from-a-brief.md`; a search that may conclude "none found" covers ignored, hidden,
  binary and non-UTF-8 files (procedure 11 of `skills/shell-commands.md`), and its procedure 8 no
  longer excuses a config file or crontab thought free of secrets: "that may hold secrets" qualifies
  only a log; procedure 1 counts a change that leaves existing data unreadable on revert as a schema
  change; "the owner" in the doctrine is a role (whoever gives the briefs, the project's owner), not
  one person. A third triggered skill,
  `session-close` (procedure 12), closes a session on what needs a decision. Each machine's
  user-level step must link it beside `gates` and `record-stamps`, or the daily load check fails
  ("skill session-close: no user-level entry").

The kit's own changes, which no spawn sees: CI runs the four suites and the smoke test on macOS
weekly and by dispatch, never on a push, and a release dispatches them on its final commit before the
tag; Windows runs by dispatch; a smoke test of the user's path runs on Linux on every push; every CI
job has a time limit, about three times its longest measured run, and fails past it: 15 minutes for
the gitleaks job (which runs Linux's suites) and macOS's suites, 6 for the smoke tests, 5 for the CI
scan (a floor), with Windows' 90 and 30 kept for now; the load check's tests lock its probe's flags
and its environment, and wait for their stand-in ping server to answer, up to 60 seconds, reporting
one that doesn't as not ready rather than as a missing ping; the kit's own identity list lets a digit
or an underscore separate a term, with the hook suite's cases for that form, and gains a row for a
term it caught only through another row; and the kit's `CLAUDE.md` has a frame of its own and an
Environment section from measured facts.

## v0.8.0

v0.8.0 is another, and the largest: delivery by install and pin. What a spawn sees:
- the kit installs once per release, read-only, built from the release's tag by
  `tools/install-release.sh`, and a project holds no copy of what the kit owns. Its hooks are two
  stubs in `.git/hooks` that check the install against the project's tracked `kit.pin` (the release
  and the hash of its manifest) and then run the release's hooks; an install edited in place, or a
  pin that names a missing one, refuses every commit and push;
- `bin/kit-pin` moves the pin (`to`, testing before it keeps the move), checks it (`check`, which
  also says where pre-push reads the identity list), moves a project made earlier onto an install
  (`migrate`), rebuilds an install (`restore`) and verifies one (`verify`). The installer is retired;
- a kit-owned file a project keeps must equal the release's, or be declared in `kit.forks` with its
  hash and the § that rules it. A project's CI files are held to the release's `ci/` variants and its
  `.gitleaks.toml` to a spawn config without the kit's own fixture exemption (`ci/copies.txt`);
- the list reader is one file with a selftest, and the hooks refuse when it can't be used; a
  pre-push block names each hit's file and line, never the matched text;
- doctrine loads once per session, at user level, from the pinned install, with a daily load check;
  the `CLAUDE.md` template (`templates/CLAUDE.md`) imports none, and the record templates hold no kit
  history. `patterns/local-spawn.md` makes a project from an install; `patterns/local-upgrade.md` is
  the move onto one;
- the size procedure caps its count at the estimate's lower end plus 2, a project's own bar reports
  a conflict rather than reconciling it, and numbered relays gain the end line and the numbering
  cases.

## v0.7.0

v0.7.0 is another, with two changes a spawn sees:
- pre-push and the installer read `.git/leak-pattern` as data, never as shell: blank lines,
  full-line comments and one `LEAK_PATTERN='...'` line, or its `export` form. A list in any other
  shape refuses every push. v0.6.0 ran the file, so an apostrophe in a term could run the rest as a
  command or quietly change the list, and a second assignment dropped every term of the first;
- `patterns/local-spawn.md` stops at the first use of an empty or unset `SRC` or `DST`, where
  `cd ""` used to stay put and the copy landed in whatever folder the shell was in.

## v0.6.0

v0.6.0 is another, with four changes a spawn sees:
- pre-push's metadata layer refuses an identity term in the author, committer or message of any
  commit the push adds, in a tag object it adds, or in the name of a ref it pushes;
- the first doctrine arrives: two files every session loads through the CLAUDE.md template's import
  lines, and two that load when a task matches them. A spawn made before them adds the two import
  lines by hand once; the upgrade plan shows them as a `REVIEW` line;
- the manifest gives every tracked file a class, and the kit's own tests fail on a file without one;
- the upgrade's apply step takes a path with spaces whole, where it cut it at the first space, and
  the upgrade pattern says how to take releases that arrive as snapshots (each one kept as a tagged
  commit in one repository).

## v0.5.0

v0.5.0 is another: pre-push clears a reviewed MP4 or WebM that is structurally plain and free of
matches in its strings, where v0.4.1 refused every video on format.

## v0.4.1

v0.4.1 is one:
- the upgrade step's test run now tests the staged upgrade, where for a release that changed the
  installer it could not pass;
- the installer's report reads `.git/leak-pattern` as pre-push does;
- the leak-detection README says binaries are checked at push only.

## v0.4.0

v0.4.0 is another, with three changes a spawn sees:
- pre-push clears a binary that is reviewed by blob id, structurally plain, and free of matches in
  its strings, where v0.3.0 refused every binary; and a push that carries one still has its text
  scanned;
- both hooks run a project's own checks from `hook-checks/<hook>/`, after their own;
- the installer refuses to replace a `core.hooksPath` that points elsewhere.

## v0.3.0

v0.3.0 is another, though small: it has one new stop. The upgrade plan now stops on a kit-owned file
the spawn deleted that the kit has since changed, where v0.2.1's plan printed "left absent" and let
the upgrade through.

## v0.2.1

From its tag's message: hook tests travel with a project and document tests stay in the kit;
`kit-manifest.txt`; `patterns/local-upgrade.md`; local-spawn takes an inventory, names the branch
and writes the README; the setup text matches the split secret policy.

## v0.2.0

v0.2.0 is one: hooks run from the tracked folder via `core.hooksPath`, and pre-commit refuses cases
that used to pass.

## v0.1.1

From its tag's message: a credential canary fixture, so both scanners have proof that they go red
first.

## v0.1.0

From its tag's message: the first release, a project-genesis kit of the records machinery, the
patterns and two-layer leak detection.

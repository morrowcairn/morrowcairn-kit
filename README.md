# Morrowcairn

**Beta.** It runs daily on one operator's machine and projects, and on CI's Linux and macOS runners; elsewhere it may
meet something it hasn't seen, and a release may change more than a stable kit's would.

**What it is, and isn't.** Morrowcairn is a way of working with Claude Code, and best practices for what Claude Code
builds: records, session rules, and leak checks for a project's git repository. It isn't a security layer, and it
doesn't change how Claude Code works. Anthropic leads on Claude Code; on a work machine, your org's settings lead. For
using it at work, see [`patterns/claude-code-at-work.md`](patterns/claude-code-at-work.md).

**Install.** You need git 2.31 or later, gitleaks on `PATH`, python3, and `sha256sum` or `shasum`, on Linux or macOS (on
Windows, inside WSL2; the kit doesn't run on native Windows).
1. Clone this repository and check out the release's tag: `git clone <this repository's URL> morrowcairn`, then `cd
   morrowcairn` and `git checkout v0.11.1`.
2. Build the release's read-only install: `tools/install-release.sh v0.11.1`. It runs the release's own hook suite on the
   staged install first, and puts the install in `~/.local/share/morrowcairn/releases/v0.11.1` (or under
   `$KIT_INSTALL_ROOT`).
3. Make a project from it: follow the install's copy of [`patterns/local-spawn.md`](patterns/local-spawn.md), whose
   procedure pins the project to the release and puts its hooks in before commit one; then
   [`patterns/repo-genesis.md`](patterns/repo-genesis.md) for its identity and commit one, and the identity list and its
   pin as local-spawn says.

The session rules, `skills/` and `.claude/skills/`, load from the install once your user-level Claude Code setup imports
them: [`skills/README.md`](skills/README.md) says what loads and where the import lines live. No shipped document yet
gives that wiring step by step.

A cairn is a waymarker built for the next traveler.

Morrowcairn is a **project-genesis kit**: the record-keeping machinery, script patterns, and
triggered doctrine that let a project accumulate hard-won operational knowledge *and actually
receive it again* at the moment it applies.

**Status: v0.11.1.** The scaffolding half is here, and the first doctrine with it. More families arrive as the extraction pass reaches them;
see [`skills/README.md`](skills/README.md).

---

## The two-artifact theory

Most "lessons learned" documents fail the same way: the knowledge is written down, and then the
next person — or the next agent — writes the bug anyway. Not because the document was wrong, but
because **nothing surfaced the relevant rule at the moment the relevant code was being written.**
That is a delivery failure, not a content failure, and it needs two different artifacts to fix:

1. **`records/` — machinery that generates *native* doctrine.** A decisions log, an incident log,
   and a followup queue, with entry schemas that force the parts you will want later (the causal
   story, the alternatives rejected, the retirement condition). Projects that keep these produce
   their own doctrine as a byproduct of working.
2. **`patterns/` and `skills/` — delivery of *inherited* doctrine.** Patterns are copy-paste
   skeletons that embody a rule structurally, so using the template *is* following the rule.
   Skills are triggered documents that load when the task context matches.

`patterns/` is the stronger of the two and it is deliberately first. **Scaffolding that makes the
right thing the default beats doctrine that asks someone to remember.** A skill you forget to read
fails silently; a template with the guard already in it fails only if you delete the guard.

## The project grows around the hole

The observation this kit exists for. A sibling project inherited half of this machinery — it kept a
decisions log and never started an incident log. Months later, a doctrine extraction needed exactly
the incident history that was never recorded, and it wasn't recoverable.

But the missing half had done more than go missing. The project had **ratified a working regime that
assumed its absence**, routing findings into one-line ledger rows with no promotion path to anything
durable. A missing record-keeping surface does not stay a gap. **It becomes a shape the process
adapts to** — and by then adding the surface back means amending the process, not just creating a
file.

That is why this is a *genesis* kit. The machinery is cheap at commit one and expensive at month six.

## Prune posture

**The rules in this kit are removable.** Doctrine accumulated by appending corrections overfits to
its own error history: each rule locally correct, globally distorting, because a correction written
after one incident generalizes into a standing tax everywhere.

So every rule that ships here carries a **"Would revisit if:"** retirement condition — the thing that
would make it obsolete — and a **provenance line** in a separable appendix. A rule whose provenance
no longer traces to anything real is a removal candidate. When a rule misfires, **prefer deleting it
to adding an exception clause.** Exception accretion is how doctrine becomes scar tissue.

## As-if-public

This repository is developed as though it were already public, from commit one.

**Commit history is part of an artifact's value.** A scaffold whose history has to be squashed or
withheld has lost the thing that makes a scaffold credible — you cannot show your work by hiding it.
So the history must be publishable *as history*, which means sanitization discipline applies from
the first commit, not from the publish decision. Retrofitting costs a rewritten history or a
withheld one.

**Leak discipline runs both directions.** The standard question is *what could leak out of this
repo*. A project must also ask **what could leak in** — an inherited config file, a borrowed
credential, a copied absolute path, an author string on commit one. Both are the same discipline
applied to the same artifact, and stating only the outward half is how the inward half gets skipped.

See [`patterns/repo-genesis.md`](patterns/repo-genesis.md) — the commit identity is configured and **verified
by reading it back** before the first commit exists, because that failure window is one command wide
and opens before any documentation has been read.

## Layout

```
CLAUDE.md              the kit's own conventions for its sessions (it stays in the kit)
templates/             a project's CLAUDE.md template: standing conventions, TODO blocks for project specifics
kit-manifest.txt       the class of every tracked file: stays in the kit, the spawn's once copied, or kit-owned
records/               the native-doctrine machinery: decisions, incidents, followups, kit feedback
patterns/              copy-paste skeletons that embody a rule structurally; claude-code-at-work.md, the note for an org's machine
leak-detection/        pre-commit + pre-push hooks, their list reader, the stub a project runs, and the tree scan CI runs
bin/                   kit-pin: pins a project to an installed release, moves the pin, checks it; the history check; the load check
tools/                 install-release.sh: builds a release's read-only install, which projects run from
tests/                 regression tests for the hooks, the install and the pin, and the kit's own documents (plain bash)
.github/workflows/     credential scan (ships complete) + marker scan against a secret (fail-closed mechanism)
skills/                doctrine every session loads (imported once per machine, from the pinned install), its index and provenance
.claude/skills/        doctrine that loads when a task matches it
```

*Directories, not files: the previous version listed every file by name and went stale in the same
commit that added two of them. A hand-maintained inventory is a promise to update it that nobody
kept — reported from the first spawned instance, and fixed here.*

**§ numbers.** Where a kit file cites "decisions log §N", it means the kit's own development decisions log, which isn't
published; `records/decisions_log.md` here is the template a project starts its own log from.

**The daily load check is opt-in.** Nothing in an install schedules it. A machine that wants it copies
`bin/kit-load-check-stub` to a folder of its own, outside the install, and gives it a daily line (cron, say). The
stub verifies the whole install against the pin line in the user-level `CLAUDE.md`, then runs `bin/kit-load-check`,
which checks the user-level skill entries and asks one headless `claude -p` for every import's canary; it reads no
transcript. Under an org's `managed-mcp.json` it skips that probe and says so.

## Leak detection, and one warning that matters

Two layers, and they ship differently **by necessity**:

- **Credential shapes ship complete** — `.gitleaks.toml` carries real rules and needs no
  configuration.
- **The do-not-publish list ships as mechanism only.** The do-not-publish list, called the identity list
  in v0.11.0's messages, is private to each clone, untracked. It holds terms you've agreed or are required to
  keep confidential: a client's or a matter's name, a research participant's details, a data partner your
  agreement says you won't name, an unreleased product's codename, a private server's address. Most projects
  don't need one; a project without one says so in a single pinned line. The pre-push hook reads it.
  **It reads the contents of the files at each pushed tip**, the binary
  files any new commit adds where the project turns the binary scan on, and the metadata the push adds (author and committer fields, commit
  messages, tag objects, the names of the refs pushed): not file names, or the text of a file that a
  later commit removed.
  `.github/workflows/leak-scan.yml` reads a repository secret named `LEAK_PATTERN`, which the setup fills with
  only terms that aren't confidential themselves, such as an IP-address pattern, or with the line saying the
  project keeps no list. Each list is pinned, by its rows and its hash: pre-push checks the
  local list against `.git/leak-pattern.pin`, untracked beside it, and CI's scan checks the secret
  against the tracked `.github/leak-pattern.pin`. Both **fail closed when their pattern is unset, or
  isn't the one its pin names**, so a list cut short or changed in place refuses instead of scanning
  for less. What each layer reads, and how a list is changed and repinned, is in
  [`leak-detection/README.md`](leak-detection/README.md), "Layers, honestly ranked" and "Changing the list."

Neither layer recognizes personal records, such as account numbers or medical details, so keep raw records out of
the repository entirely ([`leak-detection/README.md`](leak-detection/README.md), "What neither layer catches").

> ⚠ **Do not commit your do-not-publish list to this repository.** The pattern *is* the list — the
> exact strings you are trying to keep out of a public repo. Committing it publishes them. If CI
> tells you `LEAK_PATTERN` is unset, the fix is `gh secret set LEAK_PATTERN`, never editing a
> pattern into the workflow file. If it tells you the secret doesn't match its pin, set the secret
> back to the list the pin names; repin (`bin/kit-pin repin ci`) only for a change you meant to make.

Failing closed is the correct behavior, not a gap: an adopter who pushes without setting a pattern,
or with one that isn't the pinned list, gets a hard error rather than a green scan that checked
nothing, or less. **A check that cannot fail is worse than no check, because it ends the search.**

Hooks are per-clone and **do not survive `git clone`**. A project gets them back from `bin/kit-pin`
(`restore` or `to`, [`patterns/local-spawn.md`](patterns/local-spawn.md)); a clone of the kit itself
runs `git config core.hooksPath leak-detection`. The CI workflows are the only clone-surviving layer,
and for the do-not-publish list's terms they check nothing.

## Versioning

**v0.11.1.** Point releases are driven by *instance* evidence — friction
recorded in a spawned project's `records/kit_feedback.md`, or an incident recorded by a spawn or by
a project run by the kit's operator, is the evidence that advances a version. A pattern refined by
imagining its use is refined by guesswork; one refined because it failed a real job is not.

A spawn takes a release with [`patterns/local-upgrade.md`](patterns/local-upgrade.md). From v0.8.0 it
holds no kit-owned copies: it runs a release's install, pinned in `kit.pin`, and takes a later one
with `bin/kit-pin to`; a spawn made earlier moves onto an install once, and a kit-owned file it keeps
changed is a fork it declares in `kit.forks`.

A **minor** release marks a change in behavior a spawn sees. v0.2.0 is one: hooks run from the
tracked folder via `core.hooksPath`, and pre-commit refuses cases that used to pass. v0.3.0 is
another, though small: it has one new stop. The upgrade plan now stops on a kit-owned file the
spawn deleted that the kit has since changed, where v0.2.1's plan printed "left absent" and let
the upgrade through. v0.4.0 is another, with three changes a spawn sees:
- pre-push clears a binary that is reviewed by blob id, structurally plain, and free of matches in
  its strings, where v0.3.0 refused every binary; and a push that carries one still has its text
  scanned;
- both hooks run a project's own checks from `hook-checks/<hook>/`, after their own;
- the installer refuses to replace a `core.hooksPath` that points elsewhere.

v0.5.0 is another: pre-push clears a reviewed MP4 or WebM that is structurally plain and free of
matches in its strings, where v0.4.1 refused every video on format.

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

v0.7.0 is another, with two changes a spawn sees:
- pre-push and the installer read `.git/leak-pattern` as data, never as shell: blank lines,
  full-line comments and one `LEAK_PATTERN='...'` line, or its `export` form. A list in any other
  shape refuses every push. v0.6.0 ran the file, so an apostrophe in a term could run the rest as a
  command or quietly change the list, and a second assignment dropped every term of the first;
- `patterns/local-spawn.md` stops at the first use of an empty or unset `SRC` or `DST`, where
  `cd ""` used to stay put and the copy landed in whatever folder the shell was in.

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
  Mac (run 39506413437) v0.10.0 refuses the branch name and the tag message and withholds the file
  name (measured);
- the binary scan withholds a path the list matches; v0.9.0 printed the path of every binary it
  refused or cleared, a term in it included. pre-commit's refusal of anything staged under `.local/`
  does the same, reading the list from `.git/leak-pattern`, and with no list there it lists no name;
- an install runs the hook suite; its case PY2 can exercise its user-site plant only where the python3
  first on `PATH` has its user site on. Where it is off (a virtual environment's python3),
  `tools/install-release.sh` reports the unmet precondition and installs anyway -- the isolation
  itself is `python3 -I`, which case PY1 shows -- while CI and a direct run still fail PY2, so the
  check is never skipped unseen.

The kit's own changes, which no spawn sees: each refusal above has a case that v0.9.0 fails (ML1 and
ML2 for the line, PY1 and PY2 for the binary scan, LS13 for the stub, IR13 and IR14 for the
installer), beside cases for the same hit with no `LANG` (ML3, ML4) and for NUL bytes and binaries
git names whole (NB, NC, ND); and a lint, PL1, fails on any file a release ships that starts python
without `-I`, unless its allowlist names that line with a reason. v0.10.0 adds cases for a mailmap
hiding an author (MP), forced colour (CL, CP), the install-time PY2 behaviour (IR15, IR16), the
search forms on the stock `/usr/bin/grep`, run under `LC_ALL=C` (GF), and a ref name, a tag message
and a reported file name each holding invalid UTF-8 beside the marker (MD14, MD15, L9). GNU grep
passes those three before the fix and after; on Linux they were shown red against a stand-in grep
that copies BSD grep's miss, and on a Mac (run 39506413437) all three pass on BSD grep. A second lint, GP1,
fails on any grep call in a file a release ships that neither runs the two passes nor is named in
its allowlist with a reason and a count (GP0 and GP0b check the lint itself), and a third, LG1, holds
each gate to the locale rule, failing a text tool before the gate sets `LC_ALL=C`, any matcher its
allowlist doesn't name with the locale it runs in, and the caller's locale used off a named matcher
(LG0 and LG0b check it). Cases guard the rule: a list row holding a non-ASCII letter blocks its other
case in a UTF-8 locale in the tree, CI's tree scan, an author and a ref name (ML5, ML6, MD18, MD19,
each red against the gates with `LC_ALL=C` and no caller's locale); an author and a message line
holding invalid UTF-8 beside the marker are blocked (MD16, MD17); a staged `.local/` path, a binary's
path and a kit-pin list row holding such bytes are refused or pinned as before (C4b, B15, RP13); a
binary whose path holds the marker isn't printed, refused or cleared (B16, B17), nor a staged `.local/`
path holding it, with the list or without (C4c to C4f); and L9b's red names the stream and line that
held the marker. And procedure 11 of
`skills/shell-commands.md` now names the exit status an absence check needs and the forms that read
binary and non-UTF-8 files (never `grep -I`), an identity-list search among them listing or counting
files and never printing matching lines (pinned by P8). Its grep forms run under `LC_ALL=C` on every
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
  path, on the stubs, which run the org's hook first, then a project hook it kept (`<hook>.project`), then the kit's
  checks. It never overwrites a hook, and `kit-pin check` fails a kept hook that isn't executable.
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

A **patch** changes nothing a spawn's hooks refuse. v0.4.1 is one:
- the upgrade step's test run now tests the staged upgrade, where for a release that changed the
  installer it could not pass;
- the installer's report reads `.git/leak-pattern` as pre-push does;
- the leak-detection README says binaries are checked at push only.

v0.10.1 is another. The daily load check counts a transcript it can't read as "can't tell", a fail,
on every run while its session still writes, so a session a crash damaged mid-write kept the check
red, and a real miss would land on a check already red. Such a transcript can now be acknowledged
once, with its owner's OK: a row in `~/.config/morrowcairn/load-check-acknowledged.tsv` pins its
bytes through its last damaged line by sha256, with the § that records the OK (the load check's
header says how to write one). The check reads it without the unreadable lines inside those bytes,
and the rest as usual. A change to those bytes, damage after them, a transcript gone or a malformed
row fails, and every report lists the rows by count and fingerprint. With no such file the check
runs as before, its report adding "acknowledged: none". Cases LA0 to LA6, each red against v0.10.0,
hold it.

v0.10.2 is another. The daily load check failed every session that recorded no instructions as
"can't tell", and a session that ran only local commands, such as an abandoned `/color` or
`/rename`, never records any, so one kept the check red. A session with no model turn and no
instructions record is now skipped and counted, since whether the rules loaded shaped nothing, and
every report says how many ("no model turn: N sessions skipped"). A model turn is any assistant
record but Claude Code's own API-error record, so one turn with no instructions record still fails,
and an instructions record that exists is still checked. Cases LT1 to LT6 hold it; LT2, LT2b, LT4 and
LT5 are red against v0.10.1.

v0.11.1 is another, and it changes wording only: no hook, script, message or test changed, so a project on v0.11.0 can
stay there. This README, the leak-detection README and `patterns/repo-genesis.md` describe the name list as the
do-not-publish list, for terms you've agreed or are required to keep confidential, and no longer frame it around
anyone's identity. The hooks' and `kit-pin`'s messages still call it the identity list, and so do the names the
leak-detection README's later sections share with the code, until a later release renames them together. This README's
leak section also says that neither layer recognizes personal records. And the public repository's address is now
`github.com/morrowcairn/morrowcairn-kit`; the old address redirects there, so a clone made from it keeps working.

## License

Morrowcairn is released under the MIT No Attribution license (MIT-0); see LICENSE. You may use, copy,
modify and distribute it, in whole or in part, without attribution. If it helped you, a mention of
Morrowcairn is appreciated, never required.

It comes as is, with no warranty of any kind, including that it works, that it fits your purpose or
that it infringes no one's rights, and with no liability for its use; LICENSE states the terms. The
kit's LICENSE covers the kit only: a project made from it chooses its own license.

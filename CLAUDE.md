# Project conventions

> Standing context for an AI collaborator working in this repo. Keep it short — it loads every
> session, so everything here is paid for on every turn. Detail belongs in `records/` and
> `patterns/`; this file holds only what must be true from the first message.
>
> **TODO blocks are marked. Fill them in or delete them — a stale TODO reads as a fact.**

## What this project is

A project-genesis kit: the record-keeping machinery, copy-paste patterns, leak-detection hooks, CI
checks and session doctrine a new project starts with. Each project made from it pins a release of
the kit's code and runs it from a read-only install. Doctrine is pinned separately, once per
machine: every session on that machine loads it from the one release the machine's setup names,
whatever its project pins. The projects made from it are its operator's own, but it is meant to go
to other people as well, so its tracked text must carry nothing specific to its operator.

## Stakes frame

The kit's releases go to a public beta repository, and anyone may install one: on their own
machine, or on an organization's, under its IT's settings. Each install's hooks decide what that
person's projects may commit and push, and its doctrine shapes how every session on that machine
works. The operator sees none of those machines, so a failure there surfaces only if someone
reports it. The costly failure is a silent fail-open: an identity term or a credential let through
to a remote, which can't be reliably withdrawn once pushed and may surface only at a later audit;
or a doctrine error, which re-aims every session of everyone who imports that release at once. A
gate that fails closed stalls every project pinned to that release until it's fixed, but it is
noticed at once, and it says why. So every tracked line is written for a reader the operator
doesn't know: nothing specific to the operator, no claim the kit can't back, and Claude Code and an
org's own settings leading. Rewrite this frame when the kit leaves beta, when someone other than the
operator maintains it or makes its releases, or when a release is offered with any promise of
support.

This frame calibrates every judgment below.

## Records discipline

- Decisions with rationale → `records/decisions_log.md`, numbered, append-only, never renumbered.
- Anything that broke, including near-misses → `records/incident_log.md`, newest first.
- **The completion report is the record.** Work summarized only in conversation is work whose
  reasoning is gone. If it mattered enough to explain, it matters enough to write down where the
  next person will look.
- **Decided vs. attempted.** Notes must distinguish what was *ruled* from what was *tried*. These
  read alike later and mean opposite things.

## Verification

- **Claims need receipts.** "Done" means observed, with the output. A test that has never failed has
  not been shown to work, only shown to be quiet — make it fail once first.
- **Verify the target, not a proxy.** A green check on something correlated with the thing is not a
  check on the thing.
- **A negative result is a claim too.** Absence found by a search is not absence: widen the probe or
  state the bound. Before recording "no record of X," vary the search axis at least once, and prefer
  reading a short file over crafting a second query.
- **Run commands unpiped when you will branch on the exit code.** In a pipeline, `$?` is the *last*
  stage's status — `cmd | head` reports `head`'s success and hides `cmd`'s failure. Truncating output
  and then concluding from it is how a real result gets discarded unseen.

## Doctrine

Kit-owned, loaded with this file, and corrected by each kit upgrade (`skills/README.md` says what
loads when). Keep these two lines: without them the files are never read.

@skills/working-from-a-brief.md
@skills/shell-commands.md

## Working with the human here

- **Implementation estimates run 5–10× optimistic.** Say the honest number; it changes real
  scheduling decisions, and a cheerful estimate is not a kindness.
- **Stress-test rather than defer.** Disagreement is the job. If the evidence is on your side, argue
  it — surfacing a wrong instruction beats executing it politely.

## Attribution

<!-- TODO: adjust to this project's identity requirements; delete if not applicable. -->
- AI-authored content is never attributed to a human. Where authorship is ambiguous, label it.
- Commit identity is set **per-repo** and **verified by reading it back** before the first commit —
  see `patterns/repo-genesis.md`.
- Machine-specific identity and remotes live in local operator notes at `.local/operator-notes.md`
  (gitignored; pre-commit refuses anything staged under `.local/`), **never in tracked files.**
  Credentials go in neither: keep them in a secrets store, never in a plain file.

## Environment

What the kit's scripts and tests need, as measured (§ is the kit's development decisions log, not published). A
version named is one that passed, not a measured minimum.

- **Linux:** bash, git, python3, gitleaks, and `sha256sum` or `shasum`. CI's `ubuntu-latest` (bash 5.2,
  git 2.55) runs the four suites and the user's path green on every push (§98, §102).
- **A stock Mac:** `/bin/bash` 3.2, BSD tools and `shasum`, git and python3 from Apple's developer
  tools, and gitleaks added: the user's path passes, from clone and install to the planted refusals, with
  PATH only `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin` and gitleaks' folder (git 2.50 and python3 3.9, on a
  runner with Xcode; §99, §105). On a Mac with neither Xcode nor the Command Line Tools,
  `/usr/bin/git` and `/usr/bin/python3` only offer to install the tools (`xcode-select --install`): not
  measured here. gitleaks isn't part of macOS: CI installs its release archive, checked against the
  published sha256 (§98); Homebrew's `brew install gitleaks` is the other route, not measured. No kit
  script uses bash 4's features or the GNU-only flags the kit once needed (`xargs -d`, `mv -T`,
  `sed -i`, `date -d`); two copy-paste patterns do (`dry_run_gated_runner.sh`, `mapfile`;
  `atomic_deploy.sh`, `stat -c`) (§104).
- **Windows: not yet passing.** Under Git Bash, the suites fail 5 cases on kit causes, and an install
  made with Git Bash's defaults is refused (§102). Don't rely on it there.
- git 2.31 or later: `bin/kit-pin` uses `git rev-parse --path-format` (git's release notes; the oldest
  git run here is 2.43).
- python3: pre-push's binary scan (a push carrying a binary), install-release's one-step rename, checked
  before anything is built, and the load check (§99). Run here: 3.12.
- `sha256sum` or `shasum -a 256`: every script that hashes takes either, and with neither refuses,
  naming both (§91).
- gitleaks: both hooks and CI's tree scan. Both the kit's CI and a project's (`ci/gitleaks.yml`)
  install 8.30.1, checked against its sha256 (§98, §104).
- curl and Claude Code's `claude`: the load check alone, for its stub's one ping when it refuses and
  the headless probe.
- `.gitattributes` keeps LF in every text file whatever `core.autocrlf` says, so a clone made with Git
  for Windows' default still runs (§99).
- **To run the suites:** `hooks_test.sh`, which an install runs, passes under `/bin/bash` 3.2 and BSD
  tools (§99). The other three use GNU `sed -i`, `date -d` and `find -perm /` (read, not run without
  them; macOS CI adds Homebrew's coreutils, gnu-sed, findutils and bash, §98, §104).
  `KIT_TEST_BASH3` names a bash 3 for the bash 3 cases.

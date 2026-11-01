# Morrowcairn

A cairn is a waymarker built for the next traveler.

**Beta.** It runs daily on one operator's Linux machine and projects. Elsewhere it may meet something it hasn't seen,
and a release may change more than a stable kit's would.

**What it is, and isn't.** Morrowcairn is a project-genesis kit: a way of working with Claude Code, and best practices
for what Claude Code builds. It gives a project, from its first commit, records, session rules, and leak checks for its
git repository, and the script patterns and triggered doctrine that let it build up hard-won operational knowledge *and
actually receive it again* at the moment it applies. It isn't a security layer, and it doesn't change how Claude Code
works. Anthropic leads on Claude Code; on a work machine, your org's settings lead. For using it at work, see
[`patterns/claude-code-at-work.md`](patterns/claude-code-at-work.md); for the IT that manages the machine,
[`docs/for-it.md`](docs/for-it.md) says what the kit writes, runs and sends, what is off by default, and how to turn
each part off or remove it.

**Install.** You need git 2.31 or later, gitleaks on `PATH`, python3, and `sha256sum` or `shasum`. *Where it runs:*
Linux, and macOS, where this release passed on a GitHub-hosted runner. On Windows, only inside WSL2: on two Windows
machines, Ubuntu 24.04 and 26.04 under WSL2, both installing v0.12.0's code, the setup ran end to end, v0.12.0's setup
prompt on the 24.04 laptop and a draft of this release's on the 26.04 desktop, where the five test suites passed too;
keep your projects in the Linux home, since on the Windows side files lose their modes and commits and
pushes run 3 to 5 times slower. Not yet tried on a machine an organization manages. Native Windows waits until someone
needs it.

The usual way is the setup prompt: paste [`docs/setup-prompt.md`](docs/setup-prompt.md)'s prompt into Claude Code, and
Claude Code leads. It asks you once whether it should do every step itself, your Claude Code settings and crontab
included, or show you each change to make, and then drives the whole setup: plain questions one at a time, each with a
default, steps 1, 2 and 4 below taken itself, with your approval at Claude Code's own prompts, a command handed to you
only where it can't, saying why, and at the end it checks that it works. It checks those tools, reads which of your
organization's managed settings apply, keeps your code in the Linux home on WSL, says what a new project starts with,
and offers to set up the daily load check. If you say you'll run work through relays, it writes the kit's settings
file, and adds the two optional hooks to your Claude Code settings only when you say so. By hand, the steps are:
1. Clone this repository and check out the release's tag:
   `git clone https://github.com/morrowcairn/morrowcairn-kit morrowcairn`, then `cd morrowcairn` and
   `git checkout v0.12.1`.
2. Build the release's read-only install: `tools/install-release.sh v0.12.1`. It runs the release's own hook suite on the
   staged install first, and puts the install in `~/.local/share/morrowcairn/releases/v0.12.1` (or under
   `$KIT_INSTALL_ROOT`, to keep installs elsewhere).
3. Make a project from it: follow the install's copy of [`patterns/local-spawn.md`](patterns/local-spawn.md), whose
   procedure pins the project to the release and puts its hooks in before commit one; then
   [`patterns/repo-genesis.md`](patterns/repo-genesis.md) for its identity and commit one. A new project starts with no
   do-not-publish list (the one line saying so, pinned) and no identity guard; local-spawn says how to turn on each.
4. Load the session rules on your machine, once: `~/.local/share/morrowcairn/releases/v0.12.1/bin/kit-pin user v0.12.1`
   links the rules file every session loads, `rules/morrowcairn.md`, the three triggered skills and the two optional
   hooks' scripts into Claude Code's folder, writes the kit's user pin, and changes no settings file.
   [`docs/rules-explained.md`](docs/rules-explained.md) says why each rule is there;
   [`skills/README.md`](skills/README.md) says what loads and how.

**Off by default.** Each is turned on where you keep it; [`docs/for-it.md`](docs/for-it.md) lists each, and what each
writes.
- *The do-not-publish list:* the project's list at its place, over the line saying it has none
  ([`patterns/local-spawn.md`](patterns/local-spawn.md)).
- *The identity guard:* repo-genesis's sentinel identity in the clone before commit one
  ([`patterns/repo-genesis.md`](patterns/repo-genesis.md), step 1a).
- *The binary-file check:* a tracked `kit.binaries` holding `scan=on`.
- *The session-report hook* (a file per report): your Claude Code settings naming it, once `kit-pin user` has linked
  it, and its folder set in `~/.claude/rules/morrowcairn-local.md`.
- *The compaction-log hook* (a line per compaction): the same, and its log's path set in that file.
- *The daily load check:* a line in your own scheduler (a crontab line, say) that runs a copy of its stub once a day
  (below); the setup prompt offers to set it up itself, with your approval, or shows you the line.
- *CI:* the kit's `ci/` workflows, copied into the project.

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

So every procedure in the kit's triggered skills carries a **"Would revisit if:"** retirement condition — the thing
that would make it obsolete — and a **provenance line** in a separable appendix,
[`skills/PROVENANCE.md`](skills/PROVENANCE.md). The rules every session loads,
[`rules/morrowcairn.md`](rules/morrowcairn.md), are kept short and carry neither; their reasons are in
[`docs/rules-explained.md`](docs/rules-explained.md), section by section. A rule whose provenance or reason no longer
traces to anything real is a removal candidate. When a rule misfires, **prefer deleting it
to adding an exception clause.** Exception accretion is how doctrine becomes scar tissue.

## What's public, and what isn't

The kit is developed in a private repository. The public repository holds each release's files, without the working
history behind them: a release there is one commit whose tree is the release's tagged tree.

**Leak discipline runs both directions.** The standard question is *what could leak out of this
repo*. A project must also ask **what could leak in** — an inherited config file, a borrowed
credential, a copied absolute path, an author string on commit one. Both are the same discipline
applied to the same artifact, and stating only the outward half is how the inward half gets skipped.

See [`patterns/repo-genesis.md`](patterns/repo-genesis.md): before the first commit exists, a new project **reads back**
the identity git will record, after setting a local one where the one git resolves is wrong for it, because that
failure window is one command wide and opens before any documentation has been read. Its identity guard, which refuses
a commit made under a placeholder identity until then, is an opt-in.

## Layout

```
CLAUDE.md              the kit's own conventions for its sessions (it stays in the kit)
templates/             a project's CLAUDE.md template: standing conventions, TODO blocks for project specifics
kit-manifest.txt       the class of every tracked file: stays in the kit, the spawn's once copied, or kit-owned
records/               the native-doctrine machinery: decisions, incidents, followups, kit feedback
patterns/              copy-paste skeletons that embody a rule structurally; claude-code-at-work.md, the note for an org's machine; practices.md, ten building practices, read on demand
leak-detection/        pre-commit + pre-push hooks, their list reader, the stub a project runs, and the tree scan CI runs
bin/                   kit-pin: pins a project to an installed release, moves the pin, checks it; the history check; the load check
tools/                 install-release.sh: builds a release's read-only install, which projects run from
tests/                 regression tests for the hooks, the install and the pin, and the kit's own documents (plain bash)
.github/workflows/     the kit's own CI: the credential scan, the do-not-publish scan against a secret, the suites
ci/                    the workflows a project copies to turn its own CI on
rules/                 the rules every session loads (kit-pin user links them at user level), and a settings example
skills/                the doctrine's index and its provenance appendix
.claude/skills/        doctrine that loads when a task matches it
claude-hooks/          two opt-in Claude Code hooks: a file per session report, a compaction log
docs/                  for an organization's IT; why each rule is there; the drafting chat's half; the setup prompt
```

*Directories, not files: the previous version listed every file by name and went stale in the same
commit that added two of them. A hand-maintained inventory is a promise to update it that nobody
kept — reported from the first spawned instance, and fixed here.*

**The daily load check is opt-in.** Nothing in an install schedules it. A machine that wants it copies
`bin/kit-load-check-stub` to a folder of its own, outside the install, and gives it a daily line (cron, say). The
stub verifies the whole install against the kit's user pin (`~/.config/morrowcairn/user.pin`, which `kit-pin user`
writes), then runs `bin/kit-load-check`, which checks the user-level rules and skill entries and asks one headless
`claude -p` for the rules file's canary; it reads no transcript. Under an org's `managed-mcp.json` it skips that probe
and says so.

## Leak detection, and one warning that matters

Two layers, and they ship differently **by necessity**:

- **Credential shapes ship complete** — `.gitleaks.toml` carries real rules and needs no
  configuration.
- **The do-not-publish list ships as mechanism only.** The do-not-publish list, called the identity list in earlier
  releases' messages, is one file per project outside every repository, `~/.config/morrowcairn/lists/<id>`, the id in
  the project's tracked `kit.list-id`; no clone holds it. It holds terms you've agreed or are required to
  keep confidential: a client's or a matter's name, a research participant's details, a data partner your
  agreement says you won't name, an unreleased product's codename, a private server's address. Most projects
  don't need one; a project without one says so in a single pinned line. The pre-push hook reads it.
  **It reads the contents of the files at each pushed tip**, the binary
  files any new commit adds where the project turns the binary scan on, and the metadata the push adds (author and committer fields, commit
  messages, tag objects, the names of the refs pushed): not file names, or the text of a file that a
  later commit removed.
  `.github/workflows/leak-scan.yml` reads a repository secret named `LEAK_PATTERN`, which you set
  yourself (`gh secret set LEAK_PATTERN`; no kit step sets it), with only terms that aren't confidential
  themselves, such as an IP-address pattern, or with the line saying the project keeps no list. Each list is
  pinned, by its rows and its hash: pre-push checks the
  local list against `.git/leak-pattern.pin`, untracked in the clone, and CI's scan checks the secret
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

A **minor** release (v0.12.0, say) changes what a project sees: a hook may refuse what it passed before, or a step may
work differently, so a project moves onto it on purpose, with `bin/kit-pin to` from the new release's install
([`patterns/local-upgrade.md`](patterns/local-upgrade.md) moves a project made before installs). A **patch** (v0.11.1,
say) changes nothing a project's hooks refuse, so a project can stay on the release it has. What each release changed
is in [`CHANGELOG.md`](CHANGELOG.md).

## License

Morrowcairn is released under the MIT No Attribution license (MIT-0); see LICENSE. You may use, copy,
modify and distribute it, in whole or in part, without attribution. If it helped you, a mention of
Morrowcairn is appreciated, never required.

It comes as is, with no warranty of any kind, including that it works, that it fits your purpose or
that it infringes no one's rights, and with no liability for its use; LICENSE states the terms. The
kit's LICENSE covers the kit only: a project made from it chooses its own license.

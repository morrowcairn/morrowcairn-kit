# The kit, for an organization's IT

For an IT reviewer deciding whether to allow the kit on a machine the organization manages. It says what the kit
writes, runs and sends, what it needs, how it sits beside IT's own controls, what is off by default, and how to turn
each part off or remove it. Each statement was measured on this release's code; one that wasn't is marked **not yet
tested**. The last section lists the questions left for IT.

## What the kit is, and isn't

A set of git hooks and command-line tools for one person's projects, plus a rules file and three skills that shape how
that person's Claude Code sessions work. The hooks check what a commit or a push carries: credential shapes, and the
terms on a project's do-not-publish list, if it keeps one. It is not a security product, and it changes nothing about
Claude Code itself. The kit is built for organization-managed machines: everything beyond the commit and push checks
is off by default. The checks that stay on have deliberately no setting to turn them off: each turns off by
removing the hook stubs that run it (below).

## What it needs

- bash, git 2.31 or later, python3, gitleaks 8.30.1, and `sha256sum` or `shasum -a 256`; curl too where the person
  runs the daily load check (its stub's ping).
- No administrator rights. Nothing in it calls `sudo`. Beyond short-lived files in the system's temporary folder,
  which the hooks and tools remove as each run ends (read from the code, not traced), it writes only in the person's
  home folder and their projects.
- Claude Code, for the rules and skills; the hooks run without it.
- Linux or macOS. On macOS, the kit's test suites and its install path passed on a GitHub-hosted macOS runner on this
  release's code. **Native Windows is not supported**; Windows runs it inside WSL2 (below, **not yet tested**).

## What it writes

Outside a project, every file and folder, with its mode and what writes it:

| Path (`~` is the home folder) | Mode | Written by |
|---|---|---|
| `~/.local/share/morrowcairn/releases/<release>/`, one per release installed | read-only: folders 555 (the top 500), files 444 or 555 | `tools/install-release.sh`, when the person installs a release |
| `~/.config/morrowcairn/` | 700 where the kit makes it; an existing folder keeps its mode | whichever of `kit-pin to`, `migrate`, `move-list` and `user` runs first |
| `~/.config/morrowcairn/lists/` | 700 | `kit-pin to`, `migrate` and `move-list`, the first time |
| `~/.config/morrowcairn/lists/<id>`, one project's do-not-publish list, plain text | 600 | the person; `kit-pin` copies an older project's list there on a move; a new project's setup writes the one line saying it has none |
| `~/.config/morrowcairn/user.pin`, the release the user-level rules come from | the person's default (umask) | `kit-pin user` |
| links in Claude Code's folder (`~/.claude/rules/morrowcairn.md`, `~/.claude/skills/gates`, `record-stamps`, `session-close`, `~/.claude/hooks/morrowcairn-reply-file`, `morrowcairn-compaction-log`) | links into the read-only install | `kit-pin user` |
| `~/.local/state/morrowcairn/load-probe/` | the person's default | the daily load check, only if the person runs it |
| the file `KIT_LOAD_CHECK_REPORT` names: the daily check's last report | the person's default | the daily load check, only where the person sets that variable |
| `~/.claude/rules/morrowcairn-local.md`, this machine's settings for the rules file and the two hooks | the person's default | the person, from the kit's example; the kit never writes it |
| the reply folder that file names (`[reply folder]`): one file per session report, `<project>-<label>-<session>-<NN>.md`, the report's text as the session wrote it, unmasked, so it can hold work content | files 600, never overwritten; the folder 700 where the hook makes it | the reply-file hook (a Claude Code Stop hook), only once the person names it in their own settings |
| the compaction log that file names (`[compaction log]`): one line per compaction, the time, the session ID and what triggered it | 600; its folder 700 where the hook makes it | the compaction-log hook (a PostCompact hook), the same way |

For the list's folder, `~` is the home folder the system's user database gives for the person, never the `HOME`
variable. The user pin and Claude Code's folder follow the usual variables (`XDG_CONFIG_HOME`, `CLAUDE_CONFIG_DIR`)
where they are set. An install builds in a staging folder beside it, then renames it into place. `kit-pin user`
changes no Claude Code settings file; the two hooks it links run only once the person names them in their own settings.

Inside each project: `kit.pin` and `kit.list-id` (tracked: the release, and a random id that names the project's list,
which says nothing about the project); two stubs, `.git/hooks/pre-commit` and `pre-push` (755); the list's pin,
`.git/leak-pattern.pin` (600). Where IT sets a hooks path for the machine (below), also relays beside the stubs, a
`.kit-hooks` file there naming the paths they run, and the clone's own `core.hooksPath`, pointing at that folder.

Git settings the kit sets, every one in the project's clone (`git config --local`), none at user or system scope:
- `core.hooksPath`: set by `kit-pin to` to the clone's own `.git/hooks`, only where IT sets a hooks path at system or
  global scope; unset by `kit-pin migrate` where the clone had a hooks path of its own (a hook manager's, as Husky
  sets), whose hooks the relays then run.
- `user.name` and `user.email`: only when the person turns the identity guard on (its placeholder), then the identity
  they set and read back.
A new project's `git init` writes git's own defaults; the kit sets no other key.

The rules file has each Claude Code session keep records of its work: a handoff file where the project keeps its
handoffs (asking the project's owner first if that is a tracked repository an organization owns), the project's
decisions log (a new project's is `records/decisions_log.md`, in its repository), its label in Claude Code's own memory
folder for the project, and, only where `morrowcairn-local.md` names them, one line per sized task in the
`[relay log]` and each question for the owner in the `[owner's queue]`.

## What it runs, and when

- **No scheduled job.** Nothing the kit installs runs on a schedule. The daily load check runs only if the person
  schedules it.
- **At commit** (the pre-commit stub): it checks the install against the project's pin, runs IT's own pre-commit hook
  first where IT sets a hooks path, then gitleaks over the staged text.
- **At push** (the pre-push stub): the same install check and IT's hook first, then gitleaks over the commits pushed,
  the do-not-publish list over the pushed tree and metadata, and, where a project turns it on, a check of the binary
  files pushed.
- **`kit-pin`**, only when the person runs it: it pins a project to a release, moves the pin, or checks it.

## What reaches the network

- pre-push runs `git ls-remote` against the remote being pushed to, the same one git is already talking to.
- To install or update: the person clones the kit's public repository from github.com, and fetches it for a new
  release; `tools/install-release.sh` then lists that clone's remote's tags, to check the release it installs.
- `bin/kit-history-audit`, a check run by hand before a repository goes public, lists its named remote's refs
  (`--remote none` skips it).
- The daily load check, if the person runs it: one headless Claude Code call on the person's own account, and, only
  where the person sets a monitoring URL, one request to it on each run, to its `/fail` route when the check fails.
  The request carries the kit's fixed words alone: pass or fail; the probe's result (pass, fail, or skipped under an
  org's `managed-mcp.json`); and, on a failure, the kind of each problem. It carries no value read from the machine:
  no path, release, file or skill name, and never the probe's answer; where the install holds files its manifest
  doesn't list, it says only how many. The report on the machine keeps the details.
- CI, if a project copies the kit's workflow files: GitHub-hosted runners, and a gitleaks download from github.com
  checked against its sha256.
Nothing else in the kit's code opens a network connection. gitleaks scans locally (**not yet tested** here: it is
gitleaks' own behaviour).

## Beside IT's own controls

- **IT's git hooks.** Where IT sets `core.hooksPath` at the system or global level, `kit-pin to` gives the project's
  clone its own hooks path, on the kit's stubs. The stubs run IT's pre-commit and pre-push hooks first, and a relay
  runs each other hook IT's folder held when `kit-pin to` ran. Three hooks no relay can carry (`push-to-checkout`,
  `proc-receive`, `fsmonitor-watchman`) are named by `kit-pin check`. If IT adds a hook to its folder later, or moves
  its hooks path, the stub refuses every commit until `kit-pin to` runs again, and the refusal says so, naming the hook
  or the path and the step to run, so no IT hook is skipped quietly.
- **Identity.** The kit sets no commit identity: commits go under the one git resolves, IT's where IT sets it.
- **Signing.** The kit neither sets nor checks commit signing (**not yet tested** with IT-required signing on).
- **Backups and data-loss tools.** The do-not-publish list is plain text at rest, in one known folder,
  `~/.config/morrowcairn/lists/`, outside every repository, so IT can exclude it from backups or point a scanner at it.
- **Claude Code's sandbox.** Under a sandbox read block, the hooks need three folders readable: the install folder,
  gitleaks' folder, and the do-not-publish list's folder, `~/.config/morrowcairn/lists/` (the first two measured on an
  earlier release, **not yet tested** on this one; the list's, read from the code). By Claude Code's sandboxing
  documentation, sandboxed commands read the whole machine except the folders it or a policy denies, so this matters
  only where a policy denies reads there. The kit's refusals split the fix: where the block is the person's own
  setting, they add the folders with `sandbox.filesystem.allowRead` in their user settings; where it is IT's, they ask
  IT to allow reading them, rather than changing it in their own settings. The kit adds nothing to managed settings.
- **Where enforcement belongs.** The hooks are a safety net on the person's machine: the person can skip them or remove
  them (below). Enforcement belongs on the server, such as the hosting service's own push protection, where IT has it.

What it refuses: a commit or push carrying a credential shape; a push carrying a listed term, or one whose list is
missing or doesn't match its pin; anything staged under a project's `.local/` folder; a project's first commit before
its instructions file is written; a git older than 2.31; a missing gitleaks; an install that doesn't match its pin; an
IT hook the clone doesn't relay.

## Off by default, and how each is turned on

- **The do-not-publish list.** A new project starts with the one line saying it has none, pinned; pushes say the
  do-not-publish check is off and still scan for credentials. To turn it on: write the list at the project's place
  and repin it.
- **The identity guard.** Off: commits go under the identity git resolves. To turn it on: set the guard's placeholder
  identity in the project's clone; every commit is then refused until a real identity is set and read back.
- **The binary-file check.** To turn it on: commit a `kit.binaries` file holding `scan=on`.
- **The two Claude Code hooks** (a file per session report; a compaction log). To turn them on: name them in the
  person's Claude Code settings, with their folders in `~/.claude/rules/morrowcairn-local.md`.
- **The daily load check.** To turn it on: copy the install's `bin/kit-load-check-stub` to a folder of the person's
  own, outside the install, and schedule that copy to run once a day (the setup prompt shows the line).
- **CI.** To turn it on: copy the kit's `ci/` workflow files into the project and set its repository secret.

## How to turn it off, or remove it

- **One project:** delete `.git/hooks/pre-commit` and `pre-push` (and, under an IT hooks path, the relays and
  `.kit-hooks`, then `git config --local --unset core.hooksPath`); put back each hook of the project's own that `kit-pin
  to` kept as `.git/hooks/<hook>.project`, under its own name (a `.project` file whose third line calls it the kit's
  relay goes with the relays); where `kit-pin migrate` unset the clone's own hooks path
  (a hook manager's), set it back to the path the second line of `.kit-hooks` names; delete the list's pin,
  `.git/leak-pattern.pin`; remove `kit.pin` and `kit.list-id`; and, where the person turned the identity guard on,
  unset the identity in the clone, `git config --local --unset user.name` and `git config --local --unset
  user.email`, so its commits go under the identity git resolves (IT's, where IT sets one).
- **One check:** each check turns off by removing from the project the hook stubs that run it (`pre-commit` runs the
  commit's checks, `pre-push` the push's). There is deliberately no quieter switch, no setting and no environment
  variable. `--no-verify` (below) skips the hooks openly, in the command itself, where a permission prompt, a reviewer
  or a log can see it. The hooks no longer read a list from the environment: that route was removed because it let a
  check run, and report a pass, against whatever list it was handed. The do-not-publish check alone also stays off
  under the one pinned line saying the project has none (above), and every push says so.
- **The list:** delete `~/.config/morrowcairn/lists/<id>`; with it gone, that project's pushes refuse until it is back.
- **CI:** where a project copied the kit's workflows, delete in a commit the files it copied for them
  (`.github/workflows/gitleaks.yml`, `.github/workflows/leak-scan.yml`, the scan they run,
  `leak-detection/scan-tree.sh`, and CI's pin, `.github/leak-pattern.pin`); then delete the repository's
  `LEAK_PATTERN` secret (in the repository's settings, or `gh secret delete LEAK_PATTERN`) and, where there is one,
  the clone's untracked copy of its value, `.git/leak-pattern.ci`. `.gitleaks.toml` can stay: the hooks read it, and
  without it they use the install's copy of the same rules. No commit refuses for a copy removed: the hooks check a
  copy only where the project holds one.
- **The user level:** where the person turned the two Claude Code hooks on, first remove their entries in the person's
  Claude Code settings, and the reply files and compaction log that `~/.claude/rules/morrowcairn-local.md` names. Then,
  in every case, remove `morrowcairn-local.md` itself (the setup prompt has every person copy it in), the links in
  `~/.claude` named above, and `~/.config/morrowcairn/user.pin`.
- **The daily load check:** remove its scheduled line and the copy of `bin/kit-load-check-stub` that line runs, from
  the person's own folder; then `~/.local/state/morrowcairn/` and the report file `KIT_LOAD_CHECK_REPORT` names.
- **A release:** `chmod -R u+w` its install folder, then delete it. A project pinned to it refuses until it moves.
- **Last:** `~/.config/morrowcairn/`, empty once its lists and the user pin are gone, and the person's clone of the
  kit's public repository.
- `git commit --no-verify` and `git push --no-verify` skip the hooks; the kit can't prevent that.

## On Windows: WSL2

**Not yet tested**: a rehearsal on a Windows machine under WSL2 is planned before this release's first use at work.
- Install WSL2 (not WSL1) and a Linux distribution; inside it, the tools above and Claude Code.
- Keep projects in WSL's own file system, under the Linux home, not under `/mnt/c`.
- Use WSL's git on those projects, never Git for Windows on the same repository.
- The list then lives in the Linux home's `~/.config/morrowcairn/lists/`, inside the distribution.
- Inside WSL, Claude Code reads the Linux managed-settings location, unless the organization's Windows policy turns on
  `wslInheritsWindowsSettings` or it uses server-managed settings: check that the policy reaches WSL.
- The rehearsal has to confirm: the kit's test suites pass there; a project made there commits and pushes through its
  hooks; the home folder the kit reads is WSL's; and the projects' file modes and line endings survive.

## Open questions for IT

- **The list at rest.** The list is plain text in a file only the person can read. Whether that is acceptable, or IT
  wants it on an encrypted volume, out of backups or under a data-loss scanner, is IT's call; the kit offers no
  encrypted store.
- **Turning a check off.** An organization that forbids client-side hooks has to remove the stubs (above); the kit
  offers no quieter switch, by design.
- **Managed settings.** Whether IT's Claude Code settings, set by device policy or in the Claude admin console, allow
  user-level rules, skills and hooks is IT's. Claude Code's managed-settings documentation names two that reach the
  kit. `allowManagedHooksOnly`, which restricts which hooks run, stops the kit's two Claude Code hooks, since the person
  names them in their own settings.
  `strictPluginOnlyCustomization`, which blocks skills, agents, hooks and MCP servers from user and project sources,
  stops the kit's three skills where it locks skills, and its two hooks where it locks hooks; the kit has no agents or
  MCP servers. The daily load check doesn't see a lock on skills: it checks that the skills are linked, not that they
  load, since its probe asks only for the rules file's canary, so a lock on skills goes unnoticed by it. Neither
  setting names rules files, so the rules file still loads under both (read from that documentation,
  **not yet tested**). The kit ships no plugin. The git hooks are git's, and run under both.
- **Review before install.** Whether IT reviews the kit before it is installed is for the organization to decide.

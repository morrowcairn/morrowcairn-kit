# Claude Code at work, with this kit

One page for anyone who uses Claude Code on an organization's machine. "Your org" is the organization; "your IT" is
whoever manages the machine.

## What the kit is, and isn't

The kit is a way of working with Claude Code, and best practices for what it builds: records, session rules, and leak
checks for your projects' git repositories. It isn't a security layer, and it doesn't change how Claude Code works.
Anthropic leads on Claude Code; your org's settings lead on your machine.

## Your account, your connectors, your records

- Sign in with your org's Claude account, never a personal one.
- In that account, connect only work services: no personal email, files or calendar.
- By default, Claude Code keeps your session transcripts and its auto memory on your machine, in `~/.claude`:
  transcripts for 30 days (sessions run in Claude Desktop or Cowork have no age limit by default). If your org wants
  them kept longer or shorter, somewhere else, or out of your backups, its settings and backup rules decide.
- Your IT's managed settings win over anything the kit does. When one blocks something the kit needs, the kit's checks
  refuse and say what's missing rather than quietly skipping; take it to your IT rather than working around it.

## What the kit needs from the machine

- git 2.31 or newer. The kit's hooks and `bin/kit-pin` refuse an older one, naming the version they need.
- gitleaks on `PATH`, and python3: every push uses it to find the project's do-not-publish list, and a push that carries
  a binary uses it to scan that file.
- If Claude Code's sandbox blocks reads outside your working folder, its sandboxed commands need to read three
  folders: the kit's release folder (`~/.local/share/morrowcairn/releases`), gitleaks' folder (`~/.local/bin` for a
  user without admin rights) and the do-not-publish lists' folder (`~/.config/morrowcairn/lists`). Without the first
  two, the hooks refuse every commit; without the third, they refuse every push, because they can't find the
  project's list file. If the block is your own setting, add the folders with `sandbox.filesystem.allowRead` in your
  user settings. If it's your IT's, ask your IT to add them rather than overriding it in your own settings. A
  project's own settings don't count under the block.
- Where your IT sets git's hooks path for the whole machine, the kit gives each project a hooks path of its own, and its
  hooks still run your org's hooks first, then the project's own, then the kit's checks: pre-commit and pre-push through
  the kit's own two, each other hook your IT's folder holds when the project is pinned through a relay, but
  `push-to-checkout`, `proc-receive` and `fsmonitor-watchman`, which no relay can carry (`kit-pin check` names any your
  IT has). A hook your IT adds later makes every commit refuse, naming it, until `kit-pin to` runs again. Tell your IT:
  a project-level hooks path can look like stepping around theirs.
- A new project starts with no do-not-publish list: the one line saying so, pinned, at the list's place outside the
  repository; a project that has one writes it there and repins it (`patterns/local-spawn.md`).

## On Windows: WSL2

- Use WSL2, not WSL1: Claude Code's sandbox runs on WSL2, and not on WSL1 or native Windows.
- Run Claude Code and git inside WSL, and keep your projects in WSL's own file system, under your Linux home, not
  under `/mnt/c`: the kit is tested on Linux and macOS file systems only.
- Use WSL's git on those projects, never Git for Windows on the same repository.
- The kit doesn't run on native Windows.
- For your IT: inside WSL, Claude Code reads the Linux managed-settings location, unless your org's Windows policy turns
  on `wslInheritsWindowsSettings` or your org uses server-managed settings. An org that manages Claude Code should
  check that its policy reaches WSL.

*Checked against Claude Code's documentation (setup, sandboxing, managed settings) in October 2026, the transcripts line
included.*

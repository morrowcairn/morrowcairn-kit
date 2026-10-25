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
- Transcripts, memory and backups are your org's side: they stay where your org keeps them, under its rules.
- Your IT's managed settings win over anything the kit does. When one blocks something the kit needs, the kit's checks
  refuse and say what's missing rather than quietly skipping; take it to your IT rather than working around it.

## What the kit needs from the machine

- git 2.31 or newer. The kit's hooks and `bin/kit-pin` refuse an older one, naming the version they need.
- gitleaks on `PATH`, and python3 for a push that carries a binary.
- If Claude Code's sandbox blocks reads outside your working folder, its sandboxed commands must be allowed to read two
  folders: the kit's release folder (`~/.local/share/morrowcairn/releases`) and gitleaks' folder (`~/.local/bin` for a
  user without admin rights). Without them the hooks can't see their install or gitleaks, and refuse every commit. Add
  them with `sandbox.filesystem.allowRead` in your user settings where your IT's settings allow it, or ask your IT to
  add them to its managed settings; a project's own settings don't count under the block.
- Where your IT sets git's hooks path for the whole machine, the kit gives each project a hooks path of its own, and its
  hooks still run your org's hooks first, then the project's own, then the kit's checks. Tell your IT: a project-level
  hooks path can look like stepping around theirs.
- A project with no identity list says so with one pinned line, or every push is refused
  (`leak-detection/README.md`, Setup).

## On Windows: WSL2

- Use WSL2, not WSL1: Claude Code's sandbox runs on WSL2, and not on WSL1 or native Windows.
- Run Claude Code and git inside WSL, and keep your projects in WSL's own file system, under your Linux home, not
  under `/mnt/c`: the kit is tested on Linux and macOS file systems only.
- The kit doesn't run on native Windows.
- For your IT: inside WSL, Claude Code reads the Linux managed-settings location, unless your org's Windows policy turns
  on `wslInheritsWindowsSettings` or your org uses server-managed settings. An org that manages Claude Code should
  check that its policy reaches WSL.

*Checked against Claude Code's documentation (setup, sandboxing, managed settings) on 2026-10-25.*

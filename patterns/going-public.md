# Pattern: going-public

**Before a repository is made public, or given a public remote, every step below is done.**

## The failure this prevents

A private repository was checked one push at a time; going public shows all of its history at once. That can't be
taken back: a forge keeps old objects reachable after a force-push, and forks and caches keep what they saw.

## The checklist

Run from the repository's top folder, with the release it pins:

```bash
REL=$(sed -n 's/^release=//p' kit.pin)
INST="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/${REL:?}"
```

1. **An owner, the hooks and CI.** A named owner answers for the repository; `"$INST/bin/kit-pin" check` passes, so the
   leak hooks run on this clone; and a CI leak check (`ci/gitleaks.yml`, `ci/leak-scan.yml`) runs on the forge.
2. **A real identity list.** `kit-pin check` says the identity scan is active, not that identity checks are off: a
   project going public needs a real, pinned list in `.git/leak-pattern`, never the reserved line
   `kit:no-identity-list` (`leak-detection/README.md`, Setup).
3. **The binary scan on.** Commit `kit.binaries` holding the one line `scan=on`; `kit-pin check` then says the binary
   scan is on, and every push checks the binaries it adds. The binaries already in the history were never checked
   while the scan was off, so check every branch and tag once:

   ```bash
   for tip in $(git for-each-ref --format='%(refname)' refs/heads refs/tags); do
       ( . "$INST/leak-detection/read-leak-pattern.sh" && read_leak_pattern "$(git rev-parse --git-dir)/leak-pattern" \
         && LEAK_PATTERN=$LP_VALUE python3 -I "$INST/leak-detection/scan-binaries.py" "$tip" ); echo "$tip: exit $?"
   done
   ```

   Exit 0 clears a tip's binaries; 1 names each file it refuses (re-encode or strip it, or review it and add the line
   it prints to `records/reviewed_binaries.txt`); 2 means the scan couldn't run, or, when it says none were found,
   that the tip's history holds no binary.
4. **The full history.** gitleaks over every ref's history, with the project's rules (`.gitleaks.toml`, or else
   `"$INST/leak-detection/spawn.gitleaks.toml"`): `gitleaks git --no-banner --redact --config .gitleaks.toml
   --log-opts=--all`, exit 0. Then the identity list over every commit, tag and ref, its control first:
   `"$INST/bin/kit-history-audit" --control`, then `"$INST/bin/kit-history-audit" --remote origin`, exit 0 each
   (`leak-detection/README.md`, Before a repository goes public). **Run both again whenever the list grows**: a term
   added later may already sit in the history, where no push reads it again.
5. **A licence its owner chose.** The owner reads `LICENSE` and decides: keep it, change it, or publish with none,
   which gives nobody permission to reuse the work. A `LICENSE` the kit copied in at spawn (releases up to v0.8.0
   copied Apache-2.0) was nobody's choice (`patterns/local-upgrade.md`, A LICENSE the kit copied in). If an earlier
   commit carried a different licence file and the history goes public with it, the owner decides before publishing
   whether that matters. No command judges this step; record the owner's decision where the project records
   decisions.
6. **Anything found is fixed first.** A hit in the history means rewriting it before going public, not after.
7. **The forge's own checks.** Turn on its secret scanning and push protection where it offers them.

## Would revisit if:

- a step can't be run as written on a project going public, or a project went public and something this list
  should have caught came out later.

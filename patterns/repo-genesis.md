# Pattern: repo-genesis

**Config before content. Identity verified before commit one.**

## The failure this prevents

A reflexive `git init && git add -A && git commit` bakes whatever identity happens to be configured
globally into **line one of a history you have committed to preserving**. Author metadata is part of
history, permanently and unrewritably in practice — rewriting it means force-pushing over every
downstream clone, and by the time anyone notices, there usually are some.

**The failure window is one command wide and it opens before any documentation has been read.** That
is precisely why this is a pattern and not a note in a README: the moment of exposure precedes the
moment anyone would consult a README.

Consequence class scales with the project. On an ordinary repo a wrong author is untidy. On a repo
developed under a separated or pseudonymous identity, **a wrong author on commit one is
identity-piercing**, and no later discipline recovers it.

## The sequence

```bash
git init -b main                            # 1. empty repo, no commits yet; the branch named, not defaulted
git config --local user.name  UNSET-SEE-REPO-GENESIS   # 1a. SENTINEL: pre-commit refuses every
git config --local user.email unset@invalid.local      #     commit while this is the identity
"$INST/bin/kit-pin" to "$REL"               # 1b. hooks on before anything can be committed (patterns/local-spawn.md)

git config --local user.name  "<name>"      # 2. identity, LOCAL scope — never --global
git config --local user.email "<email>"     #    (a noreply address if the mailbox is private)

git config --local user.name                # 3. READ IT BACK. This is the load-bearing step.
git config --local user.email

# 4. governance files first — .gitignore, leak-scan config, hooks; a LICENSE once one is chosen (local-spawn)
# 5. THEN the first commit
```

**Step 3 is the pattern.** Steps 1–2 are what everyone already does; setting config and *assuming it
took* is the same class of error as a green check that never ran. `--local` can silently no-op
outside a repo, a typo'd key name writes a config entry that nothing reads, and a global override you
forgot about can win. The read-back costs one second and is the only thing that converts an intention
into a verified state.

**Use `--local`, never `--global`.** Local scope means an identity chosen for this repo cannot leak
into unrelated work on the same machine, and unrelated work cannot leak into this repo.

**Steps 1a–1b make the pattern enforced, not just documented.** The failure window opens before any
documentation has been read, which is as much an argument against *documenting* the fix as for the
fix. So the placeholder identity goes in at `git init`, and `leak-detection/pre-commit` refuses any
commit whose author or committer is still `UNSET-SEE-REPO-GENESIS`. A reflexive `git commit` before
step 2 now fails closed instead of writing a guessed author into line one. This clause comes from a
spawned instance, which invented it after finding the machine's ambient identity was wrong for it.

## Verify after the first commit, too

```bash
git log -1 --pretty='%an <%ae>'
```

Cheap, and it catches the case where the config was right but a hook, a wrapper, or a `-c` override
supplied something else.

## Keep the identity out of the template

**This pattern stays generic.** The specific name, email, credential, and remote for any given
project belong in that machine's local convention — an untracked config file, a project `CLAUDE.md`,
an operator briefing — **never hardcoded into a public template.** A template that ships someone's
identity has turned a reusable pattern into a leak, which inverts the thing the pattern is for.

## Identity criticality belongs to the destination, not to the pattern

How much a wrong author *costs* varies enormously — untidy on a private local project, and
identity-piercing on a repo published under a separated identity. **What does not vary is the
verify step.** Its value was never solely about identity: it is the habit of confirming a configured
state instead of assuming one, and a habit skipped whenever stakes are low is not available when
stakes are high.

Run it either way. Where the identity chosen is simply the machine default, record *that it was a
choice* in the project's decisions log — a later reader cannot otherwise distinguish "considered and
fine" from "never thought about."

## Would revisit if:

Git gains a first-class per-repo identity prompt that fails closed on an unset author, making the
read-back redundant. Until then, silence on step 2 is indistinguishable between "set correctly" and
"not set at all," and only step 3 tells them apart.

---

*Provenance: adopted at this kit's own genesis, which is this pattern's first live execution. A
genesis template whose own genesis did not follow it would ship a live counter-example inside the
product.*

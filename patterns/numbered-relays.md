# Pattern: numbered relays

**Optional.** For an operator who runs several agent sessions at once and carries briefs to them by
hand from a separate drafting session. Skip it otherwise; nothing loads it until a project adopts it
with a line in its own `CLAUDE.md`.

1. Give each live session a label that no other live session in the project has. A color works. Set
   it inside the session where the tool allows, so the session can see it.
2. Head every relayed brief: `Relay <project> <label> #N (session <ID prefix>)`. Number per session,
   from #1, across days.
3. The session records its label and its ID prefix in the project's shared notes, one line per
   label. A session that takes a label overwrites that label's line. A relabeled session removes its
   old line.
4. Every reply from a session that has received a relay starts with
   `Last relay received: <project> <label> #N (session <ID prefix>)`.
5. The drafting side numbers each relay after the highest it has sent that session, never at or below
   the highest the session's last echo names (a relay the echo lists as received and waiting
   included). A relay it sent that the echo names neither way, or a skipped number, means a relay was
   lost. Say so, name the missing number, and act on nothing that depended on it until it is resent.
6. A relay naming another project, or a session ID that isn't yours: stop, say so, and take no label
   from it. A wrong label beside your own session ID is a slip: say so, keep your label, and act.
7. A relay pasted while the session is still working waits: the session finishes and reports the work
   in hand first, names the new relay in that report's first line as received and waiting, then starts
   it. An identical copy of a waiting relay is the same relay: act on it once, and say so.
8. Every relay ends with the fixed line `End of relay <project> <label> #N`, matching its header.
   Check it before acting on any of the relay. If it is missing or doesn't match, act on nothing, say
   the relay arrived cut off, and quote the last line received: a cut at a clean break between items
   looks complete without it.
9. The numbering cases:
   - A number the session has already received, or one lower than the last: a duplicated or misrouted
     relay. Stop, say so, quote the last number received, and act on nothing until the drafting side
     confirms. The exceptions are the resend of a relay the session reported lost or cut off, and an
     identical copy of one received and still waiting (item 7).
   - A session whose first relay carries a number above #1 is a new session, not one that lost the
     earlier ones: it says so, and the drafting side restarts its numbering at #1 under the new ID.
   - A relay revised after the session received it takes the next number and opens with
     `Supersedes #N`; an identical resend of a lost or cut-off relay keeps its number. The session acts
     on the latest only, and reports anything it already did under the one superseded.

## Would revisit if:

The tool shows each session its own label and carries briefs between sessions itself.

*Provenance: `skills/PROVENANCE.md`, the numbered-relays line.*

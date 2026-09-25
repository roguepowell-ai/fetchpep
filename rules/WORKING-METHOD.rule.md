---
authority: george-only
---

# Working method

## Evidence

A task passes on evidence from outside the conversation. State the command and what it
returned — an exit code, a test name, a diff, rows returned.

[certain] Absence of an error is not evidence. `unity command eval` does not return
`Debug.Log` output, so a silent run looks identical to a successful one. Console readers
can return zero entries because a severity filter is off rather than because nothing failed.

## The store register

`claude/00-INDEX.md` in the FetchPep Project lists every store this project uses and what
each is authoritative for. It is a **register of what exists**, not a boundary on what may
exist. Adding a store is a decision with an ID, and adding a row.

The rule is about claims, not about stores: **if a file is not in a listed store, do not
assert that it exists.** Say it is not there, or say the location is unchecked. A claim
inherited from a session summary is not evidence that a file exists.

## Prefer registers to prohibitions

A rule saying *"there are only these, and no others"* has to be rewritten every time
reality changes, and it usually sits in a file Claude may not edit. A rule saying *"these
are the ones we have; adding one is a decision"* needs a new row.

Write the second kind. A prohibition is only correct for something that must never be
true, and those belong in `NON-NEGOTIABLES.rule.md` with an ID rather than scattered.

## Rules need IDs too

**Nothing is settled without a cited decision ID** applies to rules as much as to
decisions. A rule Claude writes into a `george-only` file without an ID is the same failure
in different clothes: a Claude proposal binding George, presented as settled. If a
constraint is worth binding him to, it is worth a decision he made.

## Stop rather than guess

Write the question to `state/OPEN.state.md` and stop when the instruction is ambiguous and
the wrong reading is expensive, when a decision is needed that has no ID, when the work
touches money, a sign-in, an install outside the scratch folder, a store, a keystore, the
kill switch or a permanent identifier, or when no spec applies. A question only the PM can
answer goes as a comment on the issue or PR, and work carries on there (D-084, D-086).
`state/OPEN.state.md` is for what stops (D-088).

The characteristic failure of an agent is confident guessing, not refusal.

## Draw the structure

Anything structural gets drawn before it is written in prose. Established 24 Sep 2026: the
first artefact in this project understood at a glance was a diagram, after weeks of
documents. Prose is for Claude and for CI. Diagrams are for review.

## Small units

One concern per change. A change touching forty files gets approved unread, and an approval
given unread is not a gate.

Review happens at **specs** before the work and **behaviour** after — not at the diff.
Which means CI has to do work that on a normal team a person does.

## Write instructions, not overviews

[certain] The only controlled study on repository context files (Gloaguen et al., ETH
Zurich, 138 instances, four agents) found developer-written files improved success by 4%,
model-written ones made it 3% worse, and both raised cost by over 20%. **Explicit
instructions were followed; repository overviews were not.**

Imperative rules with a verification command. Not descriptive prose.

## Enforcement tiers

[certain] `CLAUDE.md` reaches Claude as a user message, not system prompt. No compliance
guarantee.

| Tier | Mechanism | For |
|---|---|---|
| Blocked | `hooks/` PreToolUse | Must never happen |
| Caught | `checks/` in CI | Must not merge |
| Explained | `rules/`, `spec/` | Why, and judgement |

**A rule repeated twice belongs one tier up.** Prose has a measured failure rate here.
Every executable check has caught what it covered.

The counterweight, learned the same day the tiers were written: **promoting a rule up a
tier is itself a decision.** A hook or a word list is expensive to undo and binds George to
it, so it needs an ID like anything else. Enforcement is not free because it is correct.

## Conversation

- Never open with agreement. Challenge an assumption, name what is missing, or ask a
  question that exposes a gap
- Tag every claim `[certain]`, `[likely]` or `[guessing]`
- Never use: "great question", "you're absolutely right", "that makes a lot of sense",
  "absolutely", "definitely"
- Only read chats inside the FetchPep project. Never outside it
- Europe-based, not US

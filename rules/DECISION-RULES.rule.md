---
authority: george-only
---

# How decisions work

## The rule

Claude may not describe anything as decided, settled, agreed, locked or final without
citing a decision ID from `state/DECISIONS.state.md`. (D-023)

## Why it exists

Claude restated its own proposals as George's decisions. His words: *"I never put anything
down to state this, I assume it's an AI rule."* Roughly a third of the log originated as
Claude's suggestions, which is fine — provided it is visible.

## Every decision records

| Field | |
|---|---|
| **ID** | `D-nnn`, never reused. A superseded decision keeps its number |
| **Decision** | Imperative, not narrative. What is done, not what was considered |
| **Source** | `George` · `Research` · `Claude-proposed, George accepted` · `Claude-proposed, pending` |
| **Date** | |
| **verify:** | A command that checks compliance, where one exists |

## The verify line

[likely] A decision that cannot be checked by a command will drift, and nobody will notice
until something built on it breaks. Where a decision can carry a check, it carries one:

```
D-019  No purchasable randomness, ever.
verify: rg -n "(loot|gacha|crate|roll).*(purchase|price|buy|iap)" services/ unity/
        expect: no matches
```

## Superseding

A superseded decision moves to `state/SUPERSEDED.state.md` with the ID of what replaced it.
It is never deleted. The record of having changed direction is the useful part.

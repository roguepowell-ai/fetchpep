---
authority: claude-writes
---

# Superseded

Decisions no longer in force. Kept, never deleted — the record of having changed direction
is the useful part.

| ID | Was | Replaced by | Why |
|---|---|---|---|
| — | **Godot 4 + GDScript as the engine** | D-033 | [certain] Godot's C# mobile export remains experimental: runtime reflection failures on iOS under NativeAOT trimming, and roughly 26s Android cold start. The original decision has no recoverable ID — see `state/DECISIONS.state.md` |
| D-046 | **Separate accounts** — web and game do not share sign-in | D-054 | Replaced by George's own statement of the identity model: steward and members each have their own login; one age-verified steward per fold; members by invite |
| D-047 | **Game sign-in is Nakama's own** — Apple, Game Center, Google Play Games, device | D-054 | Members have their own logins and join by invite, which a device-level Nakama sign-in did not describe. Methods open — O-47 |
| D-048 | **The creature and its tag stay after an erasure request** | D-056 | George chose the Housekeeping board's rule: the animal stays, the name is dropped, the credit becomes the fold, full removal on request |

## Format

Never reuse a superseded ID. A decision that comes back gets a new number and a note
pointing at the old one.

---
authority: claude-proposes
paths: ["services/nakama/**"]
---

# Nakama — realtime

Routes to `spec/ENCOUNTERS.spec.md`. Does not restate it.

## Server authority

Encounters are **server-authoritative and client-deterministic**. The server issues a seed
and a table version; the client replays the same roll for presentation only. A client that
can compute a different outcome is a client that can choose one.

Encounter tables are served as **versioned data, never compiled into the build**. A build
that contains the tables is a build that can be read.

## Two-stage roll

Fixed probability selects the tier. Weight within the tier selects the result. The two
stages are separate so a tier's contents can change without moving its probability.

## Never

- No purchasable randomness, in any form, ever. See the decision log before proposing
  anything adjacent to it.
- Chat is disabled server-side, not hidden in the client.
- The Nakama console is not exposed.

## Scaling

[certain] Open-source Nakama does not cluster. It scales vertically, then by sharding on
region. Anything that assumes horizontal scale is wrong.

---
authority: claude-proposes
---

# Product

> **Partly written.** The shape below is on record, with decision IDs. The rest of what
> belongs here was worked out in planning conversation and never written down — see
> `state/OPEN.state.md` O-18.

## Two experiences, not one build — D-045, D-046

Inkfold is **two separate experiences** joined by a single one-way handoff. They are built,
deployed and signed into separately. Treating them as one pipeline is a mistake this file
exists to prevent — it was made on 24 Sep and corrected the same day.

```
  THE WEBSITE — creature creation              THE GAME — mobile app
  outside the app                               Unity, iOS and Android
  ┌──────────────────────────────┐             ┌──────────────────────────────┐
  │ its own accounts             │             │ its own accounts — Nakama     │
  │ draw on paper, photograph,   │             │ D-047                         │
  │ submit, screen, build the    │             │ explore the world map         │
  │ creature                     │             │ encounter creatures           │
  │ owns submissions, originals  │             │ creatures are permanent       │
  │ and screening — D-052        │             │ fixtures                      │
  └──────────────┬───────────────┘             └──────────────────────────────┘
                 │   publish once, one way only                 ▲
                 └──────────────────────────────────────────────┘
                     sprite + catalogue record + maker's tag
                     no shared sign-in · nothing flows back
```

## The game — D-045

**The core is exploring and encounters.** Players move through the world map — world,
continent, country, area, locality, fold (D-053) — and meet creatures there.

The game does not create creatures. It receives them. It never holds a submitted photograph
or a maker's real name: makers are credited by a tag, which may be auto-generated (D-048).

The word *region* is not used anywhere in the game (D-051). The instance players share is
a shard in code and appears to players only by its name.

## The website — creature creation

People draw on paper, photograph the drawing and submit it on the website. Screening
happens there, including rejecting any drawing that shows a name or signature (D-050).
Accepted drawings are built into creatures and published to the game. The detail belongs
in `spec/SCREENING.spec.md`, which is still a placeholder.

## Where the two meet

Only the publish. The game's `directory.catalogue` receives the sprite reference, the tag,
the credited place and provenance. See `spec/DATA-MODEL.spec.md`.

The web side's throughput still matters to the game: without published creatures there is
nothing to encounter. That is what O-1 measures.

## What is on record

Members and stewards, one age-verified adult steward per fold with up to eight invited
members. No chat, no friends, no follows. Quests come from NPCs. Private folds are never
drawn. The pilot is a single shard and ships free.

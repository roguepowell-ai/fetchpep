---
authority: claude-proposes
---

# Places

> **Partly written.** The kinds of place are on record (D-053). How the world map is built
> from them was worked out in planning conversation and never written down — see
> `state/OPEN.state.md` O-18.

## What belongs here

The place hierarchy and how the world map is built from it.

## Kinds of place — D-053

`directory.place_kind`, from the root down. The enum itself is in
`spec/DATA-MODEL.spec.md`.

| Kind | How it comes to exist |
|---|---|
| `world` | One row, the root |
| `continent` | Seeded |
| `country` | Seeded |
| `area` | Seeded — admin areas, counties, states |
| `locality` | Created lazily, on the first claim inside it |
| `custom` | Made by someone — a private map |
| `fold` | The leaf. One household's place |

**Not decided:** where a `custom` map sits in the tree — what its parent is. Open as O-45.

**The game has no regions** (D-051). No map area is called one, in the schema or on screen.

## What is on record

A self-referencing table using Postgres `ltree` for ancestry. It is a tree — connected,
acyclic, one parent per node. A place with two parents makes it a DAG and breaks `ltree`.
`parent_id` is the column name.

The kind names are deliberately the game's own: `fold` is in the schema by George's
design. An earlier line here said the schema should avoid brand vocabulary; D-053
supersedes it.

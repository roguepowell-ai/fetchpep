---
authority: claude-writes
---

# Session log

What changed, and why. Newest first. One entry per working session.

## 2026-09-24

**Contract rebuilt against published evidence.**

- Researched agent-context practice and Unity-with-agents practice. Headline: the only
  controlled study on repository context files found overviews are ignored while explicit
  instructions are followed, and that context files raise inference cost over 20%
- `CLAUDE.md` rewritten as a directory. Always-load files became `@imports` so they survive
  a compaction; path routes moved to `.claude/rules/` with `paths:` frontmatter; destructive
  rules moved into the root file
- `hooks/guard-write.mjs` written — the enforcement tier. Five smoke tests pass
- Six CI checks written. `router-links.check.sh` caught a real bug in the router on first
  run: scoped rule paths were bare filenames that would not resolve
- FetchPep Project populated. It had zero documents

**Corrections logged.**

- **A prohibition was written into a `george-only` file with no decision ID.** "Two stores,
  and no others" generalised one factual correction into a permanent constraint binding
  George, sourced from Claude's inference. It was also **false** — the Inkfold design
  system is a third store and had been read earlier the same day. Replaced by a store
  register in `claude/00-INDEX.md`, and two rules added: prefer registers to prohibitions,
  and rules need IDs like decisions do. A term ban added for the same reason was removed

- `com.unity.pipeline` was given as `[certain]`. It is `0.x-exp` and changes monthly
- GameCI licence activation was presented as reliable. It fails in roughly three runs in ten
- Force Text serialization was presented as something to set. It has been Unity's default
  for years
- Nested `CLAUDE.md` files were designed in as load-bearing. They do not survive a
  compaction
- **An external copy of the repository was described as existing. It does not.** The claim
  came from a session summary and was restated as fact without being checked, then written
  into three Project documents before being corrected. This is the failure the evidence
  rule exists to prevent, committed while writing the evidence rule. The lesson, stated
  once: a claim inherited from a summary is not evidence

---
authority: claude-writes
---

# hooks/

The enforcement tier.

[certain] `CLAUDE.md` reaches Claude as a user message after the system prompt, not as part
of the system prompt, so it carries no compliance guarantee. An instruction is a request.
A hook is a refusal.

## What is here

| File | Fires on | Blocks |
|---|---|---|
| `guard-write.mjs` | `PreToolUse` — Write, Edit, MultiEdit, NotebookEdit | Edits to `authority: george-only` files · any edit to Unity asset YAML · any change touching `guid:` or `fileID:` · banned terms |

## Wiring

`.claude/settings.json`, checked into the repo so it applies to every clone:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "node hooks/guard-write.mjs" }
        ]
      }
    ]
  }
}
```

Node rather than bash-plus-`jq`, because the build machine is Windows and Node is already
in the toolchain. `jq` is not.

## Protocol

The hook reads one JSON object on stdin carrying `tool_name` and `tool_input`.

- **exit 0** — allow
- **exit 2** — block, and stderr is fed back to Claude as the reason

The refusal text matters. Claude reads it and acts on it, so each one says what was
refused *and* what to do instead. A block with no remedy produces a retry loop.

## Design rules for anything added here

1. **Fail open on the guard's own errors.** A hook that cannot parse its input exits 0. A
   broken guard must not become a broken session.
2. **Block, do not fix.** A hook that silently rewrites the edit hides the violation and
   teaches nothing.
3. **Name the file and the rule.** `BLOCKED` on its own is a mystery.
4. **One tier up after two repeats.** A rule restated twice in prose belongs here.

## What does not belong here

Judgement. Hooks are for things that are wrong regardless of context. Anything needing a
reason lives in `rules/` and is caught by `checks/` instead.

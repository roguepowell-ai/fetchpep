---
authority: george-only
paths: ["unity/**/*.unity", "unity/**/*.prefab", "unity/**/*.asset", "unity/**/*.meta"]
---

# Unity — asset files

These files are readable and **not safely editable**. `hooks/guard-write.mjs` refuses to
write them; this explains the refusal.

## Why

`.unity` and `.prefab` are YAML, so they look editable. Every cross-reference inside them
resolves through a `guid` or `fileID`. [certain] Change an existing GUID and every
reference to that asset breaks — silently, with no error, and with nothing in the diff that
says what went wrong.

## Rules

1. **Never alter an existing GUID.**
2. **Move an asset and its `.meta` together.** `git mv` both, or use the Editor. One
   without the other orphans the asset.
3. **Never restructure the YAML.** Route the change through a live Editor, via the Unity
   CLI or by hand. If no Editor is reachable, stop and say so rather than editing the file.
4. The only permitted direct edit is a single line, containing no `fileID:` or `guid:`,
   whose value is a plain scalar, with `git diff` confirming nothing else moved.

## Merging

[certain] Configure **UnityYAMLMerge** as the git mergetool for `.unity` and `.prefab`. A
plain three-way text merge silently breaks scenes.

## Serialization

Confirm Project Settings → Editor → **Asset Serialization: Force Text** and **Version
Control Mode: Visible Meta Files**. [certain] Force Text has been Unity's default for
years — verify rather than assume it needs setting.

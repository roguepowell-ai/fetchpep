---
authority: claude-proposes
paths: ["unity/**/*.cs", "unity/**/*.asmdef"]
---

# Unity — C# and the live Editor

Routes to `spec/ENCOUNTERS.spec.md` and `spec/DESIGN.spec.md`. Does not restate them.

## Architecture

Game logic lives in **plain C# classes**. MonoBehaviour is a thin shell that forwards to
them. Data lives in ScriptableObjects. [likely] The reason is verification, not elegance:
EditMode tests over pure C# are the only check that runs without entering Play Mode and
triggering a domain reload. Logic inside a MonoBehaviour can only be tested the slow way,
and the slow way is the one that gets skipped.

One **assembly definition per feature folder**. Smaller compile domains mean shorter
recompiles, which means shorter waits between writing and knowing.

## The live Editor

`unity status` must report `ready` before any `unity command`. If it does not, the Editor
is closed, compiling, or in Safe Mode.

[certain] **Domain reload breaks the connection.** Entering Play Mode triggers one, which
regenerates the Pipeline bearer token — a client holding the old one gets 401 until it
restarts. A domain reload also kills any in-flight `unity command eval`. After entering or
leaving Play Mode, re-check `unity status` before assuming anything.

[certain] **Safe Mode blocks the Pipeline package from loading.** A compile error therefore
removes the Editor connection at the exact moment it is needed to diagnose the error. The
recovery is the CLI and CI, not the Editor: `unity test`, or read the compile output.

## unity command eval

[certain] It takes a **method body**, not a file. No `using` directives, no class
declaration. `Debug.Log` output does **not** come back — `return` the data you want to see.
It runs on the main thread and blocks the Editor while it does.

## Preferring Editor scripts

[likely] For anything repeated or structural, generating an Editor script and running it is
more reliable than driving the Editor command by command. It costs more tokens and fails
less often, which is the right trade for anything that touches more than one object.

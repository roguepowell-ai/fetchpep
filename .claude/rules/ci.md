---
authority: claude-proposes
paths: [".github/workflows/**"]
---

# CI

## Two systems, not one

**GitHub Actions + GameCI** compiles and tests on every push. Minutes, Linux runners. This
is the inner loop.

**Unity Build Automation** produces signed device builds. Slow, licensed, release path only.

[certain] Do not build iOS on GitHub Actions. macOS runners bill at 10x minutes and would
duplicate what Build Automation already does with the Apple credentials.

## Licence

Three secrets: `UNITY_LICENSE` (the full `.ulf` contents), `UNITY_EMAIL`, `UNITY_PASSWORD`.
`UNITY_SERIAL` is Professional-only.

[certain] The `.alf` to `license.unity3d.com` route is withdrawn for Personal licences. Any
guide describing an `activation.yml` workflow is out of date. Activate in Unity Hub and
copy the `.ulf` file.

## Flakiness is a design problem

[certain] GameCI licence activation fails in roughly **three runs in ten** with an open,
unresolved issue. Use `--retries`, and **separate a licence failure from a test failure** in
the job output. A red build that sometimes means nothing is a red build that gets ignored,
and an ignored CI is worse than none.

## Cache and exit codes

Cache `Library/` or every job re-imports every asset — a three-minute run becomes fifteen.

`unity test` exit codes: **0** passed · **8** tests failed · **6** no verdict produced.
Never pass `-quit` with `-runTests`; Unity exits before results are written.

---
authority: george-only
---

# Language

Enforced by `hooks/guard-write.mjs` before the write and `checks/banned-terms.check.sh`
after it. `checks/banned-terms.txt` is the list; this file is the reasoning.

## Banned

The list is banned outright, in code, comments, specs, copy and conversation. Not softened,
not used "just to explain" — the whole point is that the vocabulary does not exist here.

One term was removed from the list because it is too common in ordinary English to grep for
without constant false positives. (D-029) Do not re-add it without reading that decision.

**This is the rule with the worst compliance record in the project.** One banned term had
to be corrected twice, the second time after it had already been agreed. That history is
why enforcement sits in a hook rather than in prose.

## Vocabulary

- **fold** — never `homestead`, never `holding` (D-024)
- **locality**, **region**
- **fold out** / **fold back in**
- **Court-run** — anything the monarchy runs
- **members**, **stewards** (D-020)

## Naming

**Inkfold** is the product. **FetchPep** is the internal codename. (D-034)

Codename: git remote, GCP project ID, Terraform state, VM and CI job names.
Product name: bundle identifier, app display name, store listings, domain, support email,
public asset paths, all in-game copy.

Test: if a user, a store reviewer or a crash report could see the string, it says Inkfold.

## Tone

Sentence case, plain words. Uppercase tracking only for labels the system assigns.

Say what survives before what happened. No urgency language — no countdowns, no "now", no
"last chance". Progress counts steps, not time. Luck is never a number. Rejections never
shame, never specify, and never cost a slot.

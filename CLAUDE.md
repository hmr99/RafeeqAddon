# Rafeeq (رفيق) - WoW: Forever addon

All-in-one quest/leveling helper for WoW: Forever (Interface 16001, Midnight-era addon API with
secret values). Owner: Humaid. Talk to him in Arabic; code, commits and CurseForge text in English.

## Layout
- `Rafeeq/` - the addon (TOC load order in `Rafeeq/Rafeeq.toc`). Data comes from the optional
  dependency QuestieDB (`LibQuestieDB`, `QuestDB`, `NpcDB`, `ItemDB`, `ObjectDB`), wrapped in `Core/Data.lua`.
- `tests/` - client emulator + scripted play session. `python3 tests/run.py --qdb ../QuestieDB`.
- `scripts/bump.py` - version + changelog. `scripts/upload-curseforge.sh` - used by CI.
- `.github/workflows/` - `ci.yml` (tests on push), `release.yml` (tag `v*` -> tests -> GitHub release -> CurseForge).

## Agents
- `rafeeq-tester` - play-test, fix bugs test-first, propose ideas.
- `rafeeq-releaser` - gate, bump, tag, publish.

## Rules
- Blizzard limits (do not try to work around): no combat logic in macros, no NPC positions beyond
  nameplate range, secret values in combat, protected actions blocked in combat.
- Arabic text: shape with `ns.Shaper.Shape` after formatting, draw with `ns.ARABIC_FONT`, never in chat.
- Language is the player's choice (first-run picker, options tabs, tracker header button).

## Release policy (set by Humaid)
- **Bug fixes ship without asking.** When a fix passes both emulator runs, merge it and publish a
  release right away (patch bump). Tell Humaid afterwards in the daily report.
- **New features and changes in behaviour need Humaid's OK before they ship.** Study, propose and
  wait. Only after he approves may a feature be merged to `main`.
- Everything on `main` is therefore approved and releasable. A release that also carries an
  unreleased approved feature gets a minor bump instead of a patch.
- Release channel: **beta** (versions `X.Y.Z-betaN`) until Humaid says Rafeeq is out of beta.
- Baseline: v0.3.0 was uploaded to CurseForge by hand and has no git tag; the first automated
  release must be newer than 0.3.0.
- Never release a build that fails either emulator run. If CI fails after tagging, fix forward with
  the next patch; do not delete published files.

# Feedback log

## 2026-11-21

Tests: 21/21 with QuestieDB, 21/21 without (2 scenarios added today).

- **QA (static review)** - `Rafeeq/Modules/Navigation.lua` - bug - arrival/drift banner stayed on screen
  when the arrow cleared itself at <8 yd, and re-targeting the same spot gave no arrival alert
  (`arrivedKey` written as a global before its local declaration). Fixed:
  [PR #1](https://github.com/hmr99/RafeeqAddon/pull/1). Release v0.4.0-beta1 prepared on main
  (commit 981dc39); tag push was blocked for the automated session, so the tag is still pending.
- **QA (new scenarios)** - `arrow: walk onto the point, banner expires, same spot again` and
  `leaked globals (end of session)`.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not granted); nothing triaged.
- **Upstream** - QuestieDB contract still 4 (min supported 1), matches `RequireContract(4)`.
  Forever 1.60.1 API notes: no removals or secret-value changes in APIs Rafeeq uses; Rafeeq does
  not parse creature GUIDs (obfuscated in Beta 5).

## 2026-11-22

Tests: 28/28 with QuestieDB, 28/28 without (1 scenario added today). Latest release: v0.7.0-beta1.

- **QA (new scenario)** - `nameplate marks: turn-in NPC, quest givers, language switch`: finisher
  of a completed quest gets the turn-in mark with no stale progress, quest giver gets the `!` mark,
  skipping the quest and turning off "show available quests" remove it, marks survive en/ar switch.
  Passed first time; no bug. [PR #2](https://github.com/hmr99/RafeeqAddon/pull/2) (tests only, merged).
- **QA (static review)** - `Rafeeq/Modules/Nameplates.lua` (new in v0.7.0): secret check before any
  compare, instance lock, CVars only out of combat, rebuild throttled to 0.5 s. No bug found.
  Risk the emulator cannot prove: whether `IsQuestFlaggedCompleted` is already true at
  `QUEST_TURNED_IN` on Forever (a just-turned-in quest could briefly show as available).
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 9921e9b: contract 4 (min supported 1), matches `RequireContract(4)`.
  Forever hotfixes Nov 11/13 are gameplay only; no new API change notes after 1.60.1.
- **Housekeeping** - branch deletion is blocked by the session proxy; `test/nameplate-turnin-givers`
  and `fix/nav-banner-arrival` are merged and can be deleted by hand.

## 2026-11-23

Tests: 31/31 with QuestieDB, 31/31 without (1 scenario added today). Latest release: v0.9.4-beta1.

- **QA (static review vs QuestieDB docs/api.md)** - `Rafeeq/Core/Data.lua` - bug - the contract check
  looked only at `pcall`'s status, but `RequireContract` returns `false, message` and does not raise,
  so an outdated QuestieDB (contract < 4) was accepted with no "update QuestieDB" warning. Fixed:
  [PR #3](https://github.com/hmr99/RafeeqAddon/pull/3), shipped in
  [v0.9.4-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.9.4-beta1) (CurseForge HTTP 200, file 9767977).
- **QA (new scenario)** - `old QuestieDB (contract too low) is refused with a warning` (failed before the fix).
- **QA (static review)** - v0.9.x changes in Navigation/Tracker/GPSBridge/Guide: guarded APIs, pcall on
  CVar and super-track calls, no new globals. Risk: `keepDiamond` re-takes the super-track every second,
  so a player who super-tracks a Blizzard quest by hand gets it taken back while Rafeeq's waypoint is set.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB e3c3bc4: contract 4 (min supported 1), matches `RequireContract(4)`.
  No Forever API change notes after 1.60.1.
- **Housekeeping** - branch deletion still blocked by the proxy: `fix/qdb-contract-check` can be deleted by hand.

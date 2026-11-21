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

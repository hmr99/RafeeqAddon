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

## 2026-11-24

Tests: 32/32 with QuestieDB, 32/32 without (1 scenario added today). Latest release: v0.9.5-beta1.

- **QA (new scenario)** - `macro maker: mage with a nearly full macro list` (other class + full macro
  list) - bug - with room for fewer than three macros, Rafeeq said "slots are full" once per macro and
  then "Macros saved: RF_ST, RF_AOE, RF_CD" although only one was made. Fixed: save in a fixed order
  (RF_ST first), one message. [PR #4](https://github.com/hmr99/RafeeqAddon/pull/4), shipped in
  [v0.9.5-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.9.5-beta1) (CurseForge HTTP 200, file 9786073).
- **QA (static review)** - `Rafeeq/Modules/Macros.lua`: no protected call in combat, bodies capped at 255.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 47a4756 (1.1.5): contract 4 (min supported 1), matches `RequireContract(4)`.
  No Forever API change notes after 1.60.1.
- **Housekeeping** - branch deletion blocked by the proxy: `fix/macro-full-message` can be deleted by hand.

## 2026-11-25

Tests: 33/33 with QuestieDB, 33/33 without (1 scenario added today). Latest release: v0.9.6-beta1.

- **QA (new scenario)** - `merchant: low-gold player, greys pay for the repair; empty bags stay quiet`
  (low gold + empty bags) - bug - `Rafeeq/Modules/QoL.lua`: the repair check ran before the staggered
  grey sales finished, so a player whose greys covered the bill got "Not enough gold to repair".
  Fixed: retry the repair after the sales (vendor still open), report a shortfall only then.
  [PR #5](https://github.com/hmr99/RafeeqAddon/pull/5), shipped in
  [v0.9.6-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.9.6-beta1) (CurseForge HTTP 200, file 9805754).
- **QA (static review)** - `QoL.lua` vendor/repair path: no protected calls, `tryRepair` is a local
  (no new global), shift-skip kept.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 4377c98 (1.1.6): contract 4 (min supported 1), matches `RequireContract(4)`.
  No Forever API change notes after 1.60.1 (Nov 11/13 hotfixes are gameplay only).
- **Housekeeping** - branch deletion blocked by the proxy: `fix/repair-after-greys` can be deleted by hand.

## 2026-11-26

Tests: 34/34 with QuestieDB, 34/34 without (1 scenario added today). Latest release: v0.9.7-beta1.

- **QA (new scenario)** - `other races: Horde orc and Skyborne get the quests their race can take`
  (Horde orc + Horde Skyborne in Durotar, orc in Elwynn) - bug - `Rafeeq/Core/Data.lua`: Forever's
  Skyborne race masks use bits 32/33, the client's `bit.band` is 32-bit, so a Skyborne character was
  offered no race-limited quest at all (0 in Durotar vs 22+ for an orc). Fixed: race bit tested with
  plain arithmetic; `Data:Init` resets the race/class/faction caches. Emulator `bit.band` now wraps
  to 32 bits like the client.
  [PR #6](https://github.com/hmr99/RafeeqAddon/pull/6), shipped in
  [v0.9.7-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.9.7-beta1) (CurseForge HTTP 200, file 9823172).
- **QA (static review)** - `Data.lua`: no new globals, no protected or combat-time calls, `hasBit` local.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 498734b (1.1.6): contract now 5 (adds `Support.Get("PetFood")`, additive),
  min supported 1, so `RequireContract(4)` still passes. No Forever API change notes after 1.60.1.
- **Housekeeping** - branch deletion blocked by the proxy: `fix/skyborne-race-mask` and
  `fix/repair-after-greys` can be deleted by hand.
- **Humaid (request, approved)** - integrate with MapWise 3.0.11 - feature - studied the MapWise code
  (no documented API; `MapWiseAPI` namespace). Bridge: "guide me" -> MapWise quest/point route, Rafeeq
  arrow steps aside; one owner for the user waypoint; pins follow canvas resizes. AzerothGPS hand-off
  retired on his call. [PR #7](https://github.com/hmr99/RafeeqAddon/pull/7), shipped in
  [v0.10.0-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.10.0-beta1) (CurseForge HTTP 200, file 9832863).
  Tests 36/36 both modes. Not provable in the emulator: real MapWise planning timing, its marker in game.

## 2026-11-27

Tests: 37/37 with QuestieDB, 37/37 without (1 scenario added today). Latest release: v0.10.1-beta1.

- **QA (new scenario)** - `dungeon run + far-away quest: the arrow names the real reason` (Teldrassil
  quest tracked from Elwynn; dungeon entry with its own map and no position; quest finished in
  combat; walk out to the turn-in) - bug - `Rafeeq/Modules/Navigation.lua`: when no quest point shares
  the player's continent, `Data:Nearest` returned nil, so the arrow said "Your position is unknown
  here" with no zone. Fixed: aim at a quest point when the player's position is known, so it says
  "Target is on another continent" and names the zone. Emulator maps now carry a continent.
  [PR #8](https://github.com/hmr99/RafeeqAddon/pull/8), shipped in
  [v0.10.1-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.10.1-beta1) (CurseForge HTTP 200, file 9841154).
- **QA (static review)** - `Navigation.lua` Recompute: no new globals, no protected or combat-time
  calls; instance behaviour (no position) unchanged.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 5c145e3: contract 5, min supported unchanged, `RequireContract(4)` passes.
  No Forever API change notes after 1.60.1.
- **Housekeeping** - branch deletion blocked by the proxy: `fix/other-continent-arrow` can be deleted by hand.

## 2026-11-28

Tests: 38/38 with QuestieDB, 38/38 without (1 scenario added today). Latest release: v0.10.2-beta1.

- **QA (new scenario)** - `abandon the tracked quest: arrow, card and pins let go of it` (arrow + guide
  card on a quest, then abandon it from the log) - bug - `Rafeeq/Modules/Navigation.lua`: the target
  was cleared on `QUEST_TURNED_IN` only, so after abandoning the tracked quest the arrow kept guiding
  to it and the guide card kept showing it. Fixed: clear on `QUEST_REMOVED` and refresh the card.
  [PR #9](https://github.com/hmr99/RafeeqAddon/pull/9), shipped in
  [v0.10.2-beta1](https://github.com/hmr99/RafeeqAddon/releases/tag/v0.10.2-beta1) (CurseForge HTTP 200, file 9863251).
- **QA (static review)** - `Navigation.lua` OnInit: no new globals, no protected or combat-time calls;
  Guide refresh wrapped in pcall.
- **GitHub issues** - none open, no new comments.
- **CurseForge comments** - page could not be read (fetch permission not answered); nothing triaged.
- **Upstream** - QuestieDB 593e1d5: contract 5, `RequireContract(4)` passes. No Forever API change
  notes after 1.60.1.
- **Housekeeping** - branch deletion blocked by the proxy: `fix/abandon-clears-arrow` can be deleted by hand.

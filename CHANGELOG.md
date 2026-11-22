# Changelog

## v0.8.1-beta1 - 2026-11-22
- Fixed: with AzerothGPS routing, Rafeeq's straight-line arrow and drift alert could contradict AzerothGPS's road directions when its arrow window was off - Rafeeq's arrow now steps aside whenever AzerothGPS has the route

## v0.8.0-beta1 - 2026-11-22
- New: road routes with AzerothGPS (optional) - every Rafeeq target becomes an AzerothGPS stop, so you get a route that follows the roads and its turn-by-turn arrow; Rafeeq's arrow steps aside and the step-by-step card moves under AzerothGPS's arrow (option: Road route via AzerothGPS)

## v0.7.0-beta1 - 2026-11-22
- New: quest marks on nameplates - skull with progress on mobs you must kill, a bag on mobs that drop what you need, ! and ? on quest givers and turn-ins
- New: optional glow on quest mobs - choose the style (soft, ring, pulse), colour and strength in /rf
- Rafeeq turns on enemy and friendly NPC nameplates and sets nameplate range to 41 yards (can be turned off)
- Options window now uses two columns

## v0.6.1-beta1 - 2026-11-22
- New: Blizzard's in-world diamond marker sits on the arrow's target and moves with it when you track another quest or reach a closer objective (option: In-world diamond marker - it turns on showInGameNavigation for you)
- Fixed: release notes containing a semicolon could not be uploaded to CurseForge (v0.6.0-beta1 was published on GitHub only)

## v0.6.0-beta1 - 2026-11-22
- New: Blizzard's in-world diamond marker now sits on the arrow's target and moves with it - track another quest, or reach a closer objective, and the diamond follows (option: In-world diamond marker; turns on showInGameNavigation for you)

## v0.5.0-beta1 - 2026-11-21
- New: step-by-step card under the arrow - Kill / Collect (and who drops it) / Use / Turn in, with a 3D model of the mob or the item icon and live progress, in English or Arabic
- New: inside the objective area the arrow stops steering and says you are there (and hints that targets may be inside a cave or building)
- Map and minimap pins are clearer: coloured rings per objective type, and overlapping pins merge into one with a count
- Arabic multi-line text now wraps in the right order

## v0.4.1-beta1 - 2026-11-21
- Fixed: the arrow could show a stale 'Turn left/right' hint when the quest has no location data or your position is unknown - it now says why there is no direction
- Fixed: quest pins only appeared on the exact zone map - they now show on any map that contains them (city, zone and continent maps)
- The arrow names the target's zone when it is not the zone you are in (e.g. 'Hidden Enemies - Durotar')

## v0.4.0-beta1 - 2026-11-21
- New: auto-run guidance - the arrow says which way to turn, alerts you on arrival and warns when you run off course (all optional)
- Fixed: arrival banner could stay on screen after the arrow cleared
- Fixed: re-targeting the same spot did not announce arrival again

## v0.3.0 - 2026-11-20
- Language is now your choice: first-run picker, options tabs and a quick switch on the tracker header
- Fixed: tracker could error after a level-up while showing the time-to-level line
- Grey items are sold one by one so no sale is dropped
- Optional guild-bank repairs

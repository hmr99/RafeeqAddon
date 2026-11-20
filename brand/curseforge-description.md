# Rafeeq - your quest & leveling companion

**Rafeeq** (رفيق, "companion") helps you level from 1 to 60 without wasting time: it tells you what to do next, what is right next to you, and points you there. The full interface is available in **English or Arabic**, and you can switch at any time.

> **Beta:** Rafeeq is new. Please report bugs in the comments and say what you were doing when they happened.

## Features

### Smart quest tracker
- XP reward next to every quest, plus the total XP waiting in quests that are ready to turn in.
- Tells you when turning those quests in will level you up.
- Time to next level and XP per hour.
- Quest colors by difficulty. Click a quest to collapse it, right-click to open it in the quest log.

### Finish what is nearby
- **Nearby**: your active quests whose objectives are within 150 yards. Do them now and stop running back and forth.
- **Available**: the best new quests in your zone, sorted by distance and how close they are to your level. Click **Do it** to get guided there, or **Skip** to hide the quest.
- Knows which quests you have completed and which are in your log.

### Guide arrow and map pins
- Shift-click a quest to start the arrow. It points to the nearest objective, then to the quest giver once the quest is complete.
- The arrow turns green when you face your target and red when the target is behind you.
- Kill, loot, turn-in and new-quest pins on the world map and the minimap.

### Auto macro maker (`/rf macro`)
- Builds three macros from the spells you know:
  - **RF_ST**: single target.
  - **RF_AOE**: AoE.
  - **RF_CD**: every spell with a cooldown over 7 seconds.
- Spells are in priority order, and the game itself skips any line that is on cooldown.
- You can edit the macros before saving.

### Quality of life
- Sells grey items and repairs automatically at vendors. Guild-bank repairs are optional. Hold **Shift** while opening a vendor to skip both.
- Keeps the spells on your action bars at their highest rank after you train.
- Reminds you to visit your class trainer when you level up.
- Accepts and turns in quests automatically. It never picks a reward for you and never turns in a quest that costs gold. Hold **Shift** while talking to an NPC to pause it.

### English or العربية
- You choose the language the first time you log in.
- Switch at any time with the button on the tracker header or the tabs in `/rf`.
- Arabic text is fully shaped, so the letters connect correctly.

## Requirements
- **QuestieDB** (recommended, separate download). It provides the quest, NPC and item locations used by the map pins, the arrow and the suggestions. Without it, the tracker, automation, macros and quality-of-life features still work.

## Commands
| Command | What it does |
|---|---|
| `/rf` | Options |
| `/rf macro` | Macro maker |
| `/rf lang` | Switch language |
| `/rf arrow` | Hide the arrow |
| `/rf unskip` | Bring back skipped quests |
| `/rf toggle` / `/rf reset` / `/rf scale 1.1` | Tracker visibility, position and size |

## Limits set by Blizzard
Addons follow Blizzard's combat rules:
- Macros cannot check debuffs or stacks.
- Addons cannot see where a mob is beyond nameplate range.
- Enemy names on nameplates are hidden from addons during combat.

Rafeeq works inside these rules.

## Credits
- Location data: [QuestieDB](https://github.com/Questie/QuestieDB) by the Questie team.
- Fonts: Noto Naskh Arabic and Noto Sans (SIL Open Font License).

# Taverners Quest & Leveling Companion

WoW Forever quest tracker and leveling reference.

## Features
- Reads active quests and objective completion from the live quest log.
- Suggests leveling zones by character level and faction using Wowhead Forever world-map level ranges.
- Integrates the full Forever QuestieDB catalogue when installed, with all quest names, objective text, structured creature/object/item/spell objectives and prerequisite links.
- Shows quest starter NPCs/objects and their known spawn areas/coordinates from QuestieDB.
- Hooks Questie's public ready and quest-update APIs so the Companion refreshes with Questie quest progress.
- Retains a curated 249-record dungeon quest pack as a fallback/reference when QuestieDB is unavailable.
- Adds an Active Quest Route tab that collects known creature/object spawn points for current quests from QuestieDB, grouped by area and sorted by coordinates.
- Separates the quest data pack from the UI so the catalogue can be expanded independently.
- Registers with TavernersCore for the Guild Hall dashboard.

Install TavernersCore, Questie and QuestieDB, then place this folder in `Interface/AddOns/TavernersQLCompanion`. Restart the client after installing new addons. Use `/tquest` or `/tqlc`.

## Full quest catalogue and map markers
The All Quests tab reads the public `LibQuestieDB.Quest` API and searches the active Forever QuestieDB dataset. QuestieDB supplies quest, NPC, object and item facts; Questie itself remains responsible for world/minimap pins, its full quest tracker, eligibility rules and objective-location visualization. The Companion does not copy or replace Questie's map engine. Questie and QuestieDB are optional TOC dependencies, so the addon still loads without them and falls back to its curated dungeon index.

Install matching current Questie and QuestieDB releases together. Their public provider API is versioned; live-client compatibility testing is still required.

## Data sources
- [Wowhead Forever — Every Dungeon Quest](https://www.wowhead.com/forever/guide/dungeons/every-dungeon-quest-location)
- [Wowhead Forever — World Map zone level ranges](https://www.wowhead.com/forever/classicplus-world-map-outro)

The bundled 249-record dungeon list is a curated fallback, not the full database. With QuestieDB installed, the All Quests tab uses the much larger Forever dataset; some entries can still have incomplete objective coordinates or uncertain availability. Questie handles map pin rendering where the source data supports it. Check unusual prerequisites in game.

Interface target 16001. Live-client API testing is still required.

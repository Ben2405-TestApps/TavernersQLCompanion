# Taverners Quest & Leveling Companion

WoW Forever quest tracker and leveling reference.

## Features
- Reads active quests and objective completion from the live quest log.
- Suggests leveling zones by character level and faction using Wowhead Forever world-map level ranges.
- Includes a starter index of 30 dungeon quests with giver locations, coordinates and known prerequisites.
- Separates the quest data pack from the UI so the catalogue can be expanded independently.
- Registers with TavernersCore for the Guild Hall dashboard.

Install TavernersCore, then place this folder in `Interface/AddOns/TavernersQLCompanion`. Use `/tquest` or `/tqlc`.

## Data sources
- [Wowhead Forever — Every Dungeon Quest](https://www.wowhead.com/forever/guide/dungeons/every-dungeon-quest-location)
- [Wowhead Forever — World Map zone level ranges](https://www.wowhead.com/forever/classicplus-world-map-outro)

The current dataset is a curated starter selection, not a complete quest database or route optimiser. Some quest details may change during Forever updates. Verify unusual prerequisites in game.

Interface target 16001. Live-client API testing is still required.

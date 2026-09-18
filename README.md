# QuestRec

**Version:** 0.5.0

Quest and gear upgrade recommendations for World of Warcraft Classic Era, based on real character data pulled from the game client.

## What it does

You are level 24. Three quests are available. Each offers a choice of item rewards. Which one actually makes your character stronger?

This tool answers that. An in-game addon reads your level, class, spec, and equipped gear. A backend scores every available reward against what you are currently wearing. A dashboard shows you the ranked list.

Toggle between three goals:
- **Gear:** rank by stat upgrade over what you have equipped
- **XP:** rank by experience reward
- **Gold:** rank by gold plus vendor value of item rewards

## Status

Phase 1 in progress. See `docs/PRD.md` for full requirements and build phases.

| Phase | Scope | Status |
|---|---|---|
| 1 | Addon foundation | In progress: identity and spec done, equipment next |
| 2 | Backend foundation | Not started |
| 3 | Game data integration | Not started |
| 4 | Recommendation engine | Not started |
| 5 | Dashboard | Not started |
| 6 | Polish and docs | Not started |

## Repository layout

```
addon/          Lua addon for Classic Era
backend/        Node.js and Express API
dashboard/      Web frontend
docs/           PRD, architecture notes, decisions
```

## Scope

**In v1:** Classic Era. Quest rewards, dungeon and raid quest rewards, auction house listings. One character at a time, switchable.

**Not in v1:** Dungeon and raid boss drops (blocked, no API publishes loot tables). PvP gear. Profession gear. Retail. WoW Forever.

## Attribution

Game data is sourced from the Blizzard Battle.net API. Blizzard Entertainment is the source of that data and does not endorse or sponsor this project.

See `docs/PRD.md` for the full backlog and the reasoning behind each cut.

## Privacy

The addon sends data only when you trigger it. There is no background streaming, no telemetry, and no data collection while you are logged out.

## Getting started

Nothing to run yet. Phase 1 begins with the addon.

## License

MIT. See `LICENSE`.

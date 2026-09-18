# QuestRec Addon

Lua addon for World of Warcraft Classic Era. Reads your character data and hands it to you as a copyable string.

The addon cannot contact the backend. WoW addons run sandboxed with no network access, so you copy the export string and paste it into the dashboard. See D008 in `docs/DECISIONS.md`.

## Install

Copy the `QuestRec` folder into your WoW Classic addons directory:

```
World of Warcraft/_classic_era_/Interface/AddOns/QuestRec/
```

Restart the game client, or type `/reload` if already running. Enable the addon at the character select screen under AddOns.

## Commands

| Command | What it does |
|---|---|
| `/qr` | Show current character snapshot in chat |
| `/qr export` | Open the copyable export popup |
| `/qr talents` | Talent tab diagnostic |

## What it reads

- Character name and realm
- Level, class, specialization
- All 19 equipment slots
- Quest log: active and available quests

## What it does not do

- No background streaming. Data sends only when you trigger it.
- No data collection while logged out.
- No combat logging, no chat logging, no position tracking.

## Status

Phase 1, in progress.

- Done: character identity (name, realm, level, class), talent-derived spec
- Next: equipment read across all 19 slots, then the export popup

`/qr export` is not wired up yet.

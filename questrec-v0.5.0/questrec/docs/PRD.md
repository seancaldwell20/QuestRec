# QuestRec

Quest and gear upgrade recommendations for World of Warcraft Classic Era.

**Version:** 0.5.0
**Project Status:** Phase 1 in progress
**Owner:** Sean

One version number covers the PRD, the decision log, the addon, and the snapshot bundle. If their numbers match, they are the same generation. If one is behind, it is stale.

| Version | What changed |
|---|---|
| 0.5.0 | Renamed to QuestRec, dropping the Blizzard trademark from the title and URL per API Terms of Use 2.m. Slash command is now `/qr`. D011 added. |
| 0.4.0 | Blizzard Developer API Terms of Use read and applied. 30-day data TTL, attribution footer, privacy policy, app registration. D010 added. Project naming flagged against the trademark clause. |
| 0.3.0 | Talent tab signature verified on a live client. Spec keyed by tab ID, not localized name. `PLAYER_ALIVE` dropped from the event list. |
| 0.2.0 | Copy-paste export replaced HTTP POST (Constraint 1). Blizzard add-on policy checked, `QUEST_LOG_UPDATE` removed. D008 and D009 added. |
| 0.1.0 | Optimization mode became a UI toggle. Boss drops deferred, instance quest rewards kept. GitHub dropped for Project storage. D001 through D007. |

---

## Overview

A three-tier application that helps World of Warcraft Classic players optimize their leveling by recommending the best quests and gear upgrades based on real character data.

### Core Problem
While leveling in WoW Classic, players face decision paralysis: Which quest should I do next? Will the reward actually help my character? What gear is worth buying from the auction house?

### Solution
An in-game addon collects character data, a backend API analyzes it against quest and gear databases, and a web dashboard displays actionable recommendations.

---

## Scope (v1)

### In Scope
- WoW Classic Era only (not Retail; WoW Forever comes later)
- Quest recommendations: available quests within a configurable level band, default plus or minus 2 levels
- Dungeon and raid quest rewards: quests that send you into an instance and award a guaranteed item on turn-in
- Gear auction house lookups: recommend AH items that would be upgrades
- Optimization mode toggle: rank by gear upgrade, XP, or gold
- Character data captured: level, class, specialization (after level 10), equipped gear
- Character switching: one active character at a time, switchable by name and realm
- UI model: on-demand recommendations (not real-time streaming)
- Trigger points: quest accept event, user button click, manual refresh

### Out of Scope (v1)
- Dungeon and raid boss drop tables (blocked, see Risk 1 and Future Backlog)
- Cross-character comparison (no shared bank, no alt gear planning)
- Reputation grinding paths
- WoW Forever support (scales post-Nov 4 launch)
- Auction house price prediction
- Profession-crafted gear

Everything above stays on the backlog rather than being ruled out. See Future Backlog.

**The dungeon and raid split matters.** A quest that says "clear Deadmines, turn in for item X" is a quest reward. It comes from the quest API, the item is guaranteed, and it works in v1. A quest that says "Mr. Smite drops item Y at 14 percent" needs a loot table, which no API publishes. Quest rewards ship in v1. Boss drops wait.

---

## Configuration

Two tiers of setting. Optimization mode is a visible control you flip mid-session. Everything else is a config value with a sensible default that becomes editable in a later phase.

### Optimization mode (UI control, v1)

A three-way toggle in the dashboard header. It changes which scoring function runs and re-ranks the whole list.

| Mode | Ranks by | Use case |
|---|---|---|
| Gear | Stat upgrade over currently equipped | Default. You want your character stronger. |
| XP | Raw XP reward | You want to hit the next level fast. |
| Gold | Gold reward plus vendor value of item rewards | You are saving for a mount or bags. |

Switching mode does not refetch character data. It re-scores what the backend already returned, so the list updates immediately.

**Known limitation.** No API publishes how long a quest takes to complete. So XP and Gold modes rank by raw reward value, not by reward per hour. A quest worth 900 XP that takes 40 minutes of travel will outrank one worth 600 XP that takes 5 minutes. Time estimates and route optimization are in the backlog.

### Config values (defaults in v1, editable later)

| Setting | Default | Notes |
|---|---|---|
| `levelBandBelow` | 2 | How many levels below the player to include |
| `levelBandAbove` | 2 | How many levels above the player to include |
| `statWeights` | Auto-derived from class and spec | Hardcoded table in v1, editable in a later phase |
| `lootSources` | `["quest", "auction"]` | `dungeon` and `raid` drops added once Risk 1 clears |
| `maxRecommendations` | 5 per source | Caps dashboard clutter |

The addon reads class and spec directly from the game client. You never enter them manually.

---

## Architecture

### Three-Tier System

**Tier 1: Addon (Lua)**
- Collects data only when player is logged in
- On-demand export: triggered by a slash command
- Packages character level, class, spec, equipped items, and quests into a JSON string
- Displays that string in a copyable popup. The addon cannot transmit it (see Constraint 1)
- Fully self-contained. It has no concept of the backend and cannot tell whether it is running

**Tier 2: Backend API (Node.js/Express on Replit)**
- Receives character snapshots from addon
- Validates data and timestamps
- Queries Blizzard Battle.net API for quest and item details
- Runs recommendation logic
- Exposes REST endpoints for dashboard
- Stores character state history in database

**Tier 3: Web Dashboard (React on Replit)**
- Displays current character state
- Shows recommended quests and rewards
- Shows recommended AH gear upgrades
- Triggers manual recommendation requests
- Provides real-time feedback

### Tech Stack
- **Addon:** Lua (WoW API)
- **Backend:** Node.js + Express
- **Database:** Replit built-in (PostgreSQL or SQLite)
- **Frontend:** React or vanilla JS
- **Version Control:** Claude Project knowledge base (v1); revisit when code needs to run on Replit
- **Hosting:** Replit (backend, frontend, database)

### Data Flow
1. Player types `/qr export` in game
2. Addon builds a snapshot in memory: level, class, spec, gear, quest IDs
3. Addon opens a popup containing the serialized snapshot, pre-selected for copying
4. Player presses Ctrl+C, alt-tabs to the dashboard, and pastes into the import box
5. Dashboard POSTs the pasted payload to `/api/character/snapshot`
6. Backend validates it, queries the Blizzard API for quest and item details, scores, and stores
7. Dashboard displays the ranked recommendations

Steps 1 through 3 happen entirely in memory, with no file write and no `/reload`. The snapshot is current as of the moment you run the command.

---

## Addon Specification

### Data Collection
- Character name and realm (forms the unique character key)
- Character level
- Character class
- Character specialization: derived, not read directly. Classic Era has no `GetSpecialization`. Loop `GetNumTalentTabs()`, call `GetTalentTabInfo(i)` for each, and take the tree with the most `pointsSpent`. Null below level 10. Ties resolve to the lower tab index.
- Specialization is identified by talent tab ID, not name. `GetTalentTabInfo` returns `id, name, description, icon, pointsSpent, background, previewPointsSpent, isUnlocked` on Classic Era 1.15.9, verified against a live client. The id is stable across locales (302 is Affliction everywhere); the name is localized and is display text only. The payload carries both, and the backend keys off the id, for the same reason class uses `classToken` rather than the localized class name.
- Equipped items (19 slots: head, neck, shoulder, chest, waist, legs, feet, wrist, hands, finger1, finger2, trinket1, trinket2, back, main_hand, off_hand, ranged, shirt, tabard)
- Active quest ID (if any)
- List of available quests

### Character Switching
The addon identifies the character by `characterName + realmName`. When you log into a different character, the addon sends a snapshot under that new key. The backend stores each character separately. The dashboard shows one character at a time, with a switcher to change which one you are viewing.

No cross-character logic in v1. Each character is an independent record.

### Events to Monitor
- **PLAYER_LOGIN:** Initialize the addon and print a load confirmation
- **PLAYER_ALIVE:** Not handled. Talent data is unreliable at PLAYER_LOGIN, but reading on demand at export time sidesteps the timing problem entirely, so there is nothing to cache.
- **QUEST_ACCEPTED:** Mark the in-memory snapshot stale so the next export is fresh

`QUEST_LOG_UPDATE` is deliberately not handled. It fires on every objective tick, and doing real work in it risks the frame rate problems that Blizzard's add-on policy point 3 calls out. Quest state is read at export time instead.

There is no backend reachability check and nothing to clean up at logout, because the addon holds no connection.

### Export Format (JSON)
```json
{
  "characterName": "string",
  "realmName": "string",
  "level": 1-60,
  "class": "Warrior|Paladin|Hunter|Rogue|Priest|Druid|Shaman|Mage|Warlock",
  "spec": "string|null",
  "equipment": {
    "head": {"itemID": 1234, "itemName": "...", "itemLevel": 10},
    "neck": {...},
    ...
  },
  "activeQuestID": 1234,
  "availableQuestIDs": [1234, 5678, ...],
  "timestamp": "2026-09-17T15:30:00Z"
}
```

### User Interactions
- `/qr`: print the current character snapshot to chat, for a quick sanity check
- `/qr export`: open the copyable export popup. This is the main command.
- `/qr gear`: print equipped items and their item IDs to chat

All output is local. No command contacts the backend.

---

## Backend API Specification

### Endpoints

**POST /api/character/snapshot**
Receive character data from addon, store, and return recommendations.
- Request: Character JSON (see above)
- Response: `{characterID, recommendations: {quests: [...], gear: [...]}, timestamp}`
- Side effect: Stores snapshot in database

**GET /api/recommendations/:characterID**
Fetch latest recommendations for a character.
- Response: `{quests: [...], gear: [...], timestamp}`

**GET /api/character/:characterID**
Fetch current character state.
- Response: Full character snapshot

**GET /api/quests/:questID**
Fetch quest details from Blizzard API cache.
- Response: `{questID, name, objectives, rewards: {items: [...], money: 100, xp: 1000}}`

**GET /api/items/:itemID**
Fetch item details from cache.
- Response: `{itemID, name, itemLevel, armor, dps, stats: {str: 5, agi: 2, ...}, classRestriction}`

**GET /api/characters**
List all characters the addon has reported, for the dashboard switcher.
- Response: `[{characterID, characterName, realmName, class, level, lastSeenAt}, ...]`

**GET /api/quests/instance?level=25&class=Warrior**
Return dungeon and raid quests in the level band, flagged with their instance name and group requirement.
- Response: `{quests: [{questID, name, instanceName, instanceType: "dungeon"|"raid", rewards: [...]}]}`

**Deferred endpoints** (blocked on Risk 1, spec'd so the shape is settled):
- `GET /api/loot/dungeons?level=&class=` returns boss drop tables
- `GET /api/loot/raids?level=&class=` returns raid drop tables

### Database Schema

**Characters**
- id (UUID, primary key)
- character_name (string)
- realm_name (string)
- class (string)
- created_at (timestamp)
- last_snapshot_at (timestamp)

**Character_Snapshots**
- id (UUID, primary key)
- character_id (UUID, foreign key)
- level (integer)
- spec (string, nullable)
- equipment (JSON)
- active_quest_id (integer, nullable)
- available_quest_ids (JSON array)
- timestamp (timestamp)
- recommendations (JSON, stored for quick retrieval)

**Quest_Cache** (optional, for Blizzard API caching)
- quest_id (integer, primary key)
- name (string)
- rewards (JSON)
- last_updated (timestamp)

**Loot_Sources**
Maps every item to where it comes from, so one query answers "where do I get this".
- id (UUID, primary key)
- item_id (integer)
- source_type (enum: quest, instance_quest, dungeon_drop, raid_drop, auction, vendor)
- source_name (string, for example "Deadmines" or "Onyxia's Lair")
- source_level_min (integer)
- source_level_max (integer)
- drop_rate (float, nullable; null for guaranteed quest rewards)
- last_updated (timestamp)

v1 populates `quest`, `instance_quest`, and `auction`. The `dungeon_drop` and `raid_drop` types exist in the schema but stay empty until Risk 1 clears. Building them into the enum now avoids a migration later.

The Characters table already supports switching. Each `characterName + realmName` pair is one row. No schema change needed for multi-character.

### Blizzard API Integration
- Cache quest and item data to avoid hitting API limits
- Refresh cache every 24 hours or on-demand
- Handle 404s gracefully if quest/item doesn't exist in WoW Classic
- **Thirty-day maximum TTL, required by the API Terms of Use section 2.r.** A scheduled purge deletes any cached row older than 30 days. Refreshing is not sufficient on its own; rows that stop being refreshed must be deleted, not left to go stale. This is a data protection obligation tied to players' right to withdraw, not a performance tuning choice.
- Rate limit: 36,000 calls per hour (section 2.q). Exceeding it can get API access suspended.
- The Battle.net account needs an Authenticator attached before API access is granted.
- The Application must be registered with Blizzard at `develop.battle.net` before the key is used. Keys may not be used for unregistered applications.

---

## Dashboard Specification

### Layout
- **Top bar:** Character switcher dropdown (name and realm), optimization mode toggle (Gear / XP / Gold), action buttons
- **Left panel:** Character info (level, class, spec, equipped items with icons)
- **Center panel:** Current active quest or "No active quest"
- **Right panel:** Ranked recommendations, each card labeled with its source and whether it needs a group
- **Source filter:** Toggle chips for Quest, Instance Quest, Auction so you can narrow the list
- **Attribution footer:** Names Blizzard as the source of the game data, worded so it does not imply endorsement or affiliation. Required by API Terms of Use section 2.m.

The mode toggle re-ranks instantly from data already in the browser. It does not hit the backend or the addon.

The character switcher only changes which character you are viewing. It never merges or compares data across characters.

### Recommendation Algorithm

The optimization mode picks the scoring function. The source determines the candidate pool and the acquisition factor.

**Gear mode:**
```
score = (candidateWeightedStats - equippedWeightedStats) × acquisitionFactor
```
- `weightedStats` applies the class and spec stat weights from config
- Items the character cannot equip (wrong armor type, class restriction, level requirement) score zero and drop out
- Candidates that do not beat the equipped item in that slot drop out

**XP mode:**
```
score = questXpReward × acquisitionFactor
```
- Auction house items score zero here. Buying gear grants no XP, so the AH source is hidden in this mode.

**Gold mode:**
```
score = (questGoldReward + vendorValueOfItemRewards) × acquisitionFactor
```
- Vendor value comes from the item's sell price, available in the item API
- Auction house items score negative here (they cost gold), so the AH source is hidden in this mode

**Acquisition factor (v1 sources):**

| Source | Factor | Reason |
|---|---|---|
| Quest reward | 1.0 | Guaranteed, solo-achievable |
| Dungeon or raid quest reward | 0.8 | Guaranteed, but needs a group to complete |
| Auction house | 0.9 | Guaranteed but costs gold |

These numbers are a starting point. Tune them once you see real output.

**Candidate pools (v1):**
1. **Quests:** available quests within the level band
2. **Instance quests:** quests that require a dungeon or raid, flagged separately so the group requirement is visible
3. **Auction house:** listings in the level band that would upgrade a slot (Gear mode only)

Results merge into one ranked list, capped at `maxRecommendations` per source, with the source labeled on each card.

**Deferred:** dungeon and raid boss drops add two more pools with a `dropRate` multiplier in the acquisition factor. The scoring function already accommodates this. Only the data is missing.

### UI Components
- **Character Card:** Shows level, class, spec, portrait
- **Equipped Gear Display:** Icon grid showing all 19 equipped items
- **Quest Card:** Quest name, level, rewards preview, "Details" button
- **Gear Card:** Item name, itemLevel, stats, "Equip" link to AH
- **Action Buttons:** "Refresh Recommendations", "Check AH", "Settings"
- **Detail Panels:** Expandable quest/item details on click

### Interactions
- Click quest card: expand to show full quest text and all rewards
- Click gear card: compare stats side-by-side to current item
- "Refresh" button: trigger new character snapshot from addon
- Manual character upload: allow pasting JSON if addon disconnects

---

## Build Phases

### Phase 1: Addon Foundation (Weeks 1-2)
**Goal:** Addon can collect and export character data
- Set up Lua project structure in the WoW AddOns folder, mirrored to the Project
- Implement character data collection functions
- Build the JSON serializer and the copyable export popup
- Create the `/qr` command set
- Test data collection on WoW Classic Era
- **Deliverable:** `/qr export` produces a valid JSON payload you can copy out of the game

### Phase 2: Backend Foundation (Weeks 2-3)
**Goal:** Backend can receive and store character data
- Set up Node.js/Express on Replit
- Create POST /api/character/snapshot endpoint
- Set up database and character schema
- Implement basic GET endpoints
- **Deliverable:** Backend receives addon data and stores it in database

### Phase 3: Game Data Integration (Week 3)
**Goal:** Backend enriches character data with game data
- Register the Application at `develop.battle.net` and attach an Authenticator to the Battle.net account. Both are prerequisites, not paperwork.
- Integrate Blizzard Battle.net API client for quests, items, and auction data
- Verify Classic Era namespace coverage endpoint by endpoint (Risk 3)
- Implement the 30-day purge job alongside the cache, not after it (D010)
- Flag which quests require a dungeon or raid, from quest metadata
- Implement caching layer
- **Deliverable:** Backend can answer "what quests and auction items exist for a level 25 Warrior"

### Phase 4: Recommendation Engine (Week 4)
**Goal:** Backend computes upgrade recommendations
- Build all three scoring functions: Gear, XP, Gold
- Implement class and spec stat weight tables
- Apply acquisition factors per source
- Merge, rank, and cap results
- Return scores for all three modes in one payload, so the UI toggle re-ranks without a refetch
- **Deliverable:** Backend returns one ranked list, switchable across three modes

### Phase 5: Dashboard (Weeks 4-5)
**Goal:** Web UI displays recommendations
- Set up React/vanilla JS frontend on Replit
- Implement character info display
- Implement recommendation panels
- Add action buttons
- **Deliverable:** Dashboard displays character state and recommendations

### Phase 6: Polish & Documentation (Week 5-6)
**Goal:** Production-ready tool
- Error handling across all tiers
- Addon/backend resilience (offline mode, retries)
- Documentation (setup, usage, architecture) kept in the Project alongside the code
- User guide for in-game addon commands
- Publish a privacy policy governing use of Blizzard data, consistent with Blizzard's own (API Terms of Use section 2.o)
- Implement data deletion on request (section 11.c)
- **Deliverable:** Fully functional, documented tool ready to showcase

---

## Success Criteria

- Addon collects character data from WoW Classic on demand, with no background streaming
- Switching characters in game produces a separate record, selectable in the dashboard
- Backend receives, stores, and enriches data with game data
- Dashboard shows one ranked list spanning quest, instance quest, and auction sources
- Toggling between Gear, XP, and Gold re-ranks the list instantly
- Every recommendation names its source, whether it needs a group, and why it beats the currently equipped item
- All code and docs stored in the Claude Project, with a dated snapshot bundle per phase
- Tool runs entirely on Replit, no local infrastructure needed
- Can be demoed to friends without additional setup

---

## Assumptions & Constraints

- WoW Classic API data is stable and available via Blizzard endpoints
- Replit database is sufficient for single-user data (scales to Databricks later)
- Player accepts a manual copy and paste each time gear or level changes materially
- Character data goes stale between exports. Acceptable, per D002.
- Every tier must comply with Blizzard policy: the addon under the UI Add-On Development Policy, the backend and dashboard under the Developer API Terms of Use. New features get checked before they are built. See D009 and D010.

---

## Risks

**Constraint 1: The addon physically cannot send data anywhere. This is settled, not a risk.**
WoW addons run in a sandbox with no filesystem access, no system commands, and no network calls. The only I/O available is the add-on's own SavedVariables file, written at logout or `/reload` and read back only at login or `/reload`.

This is why every character-export addon on CurseForge uses a copy-a-string workflow. It is not a stylistic choice by their authors, it is the only option.

**Decision: copy-paste export in v1.** The addon builds the payload in memory and shows it in a popup. The player copies it into the dashboard. No local software, no `/reload`, nothing for a friend to install beyond the addon itself.

The rejected alternative was a local companion process watching SavedVariables. It is more automated on paper, but it requires every user to run a second program, and SavedVariables only flushes on `/reload`, so it is actually slower than copy-paste. See the v2 backlog.

**Risk 1: Dungeon and raid boss drop tables are not in the Blizzard API. Deferred, not solved.**
The Blizzard Game Data API exposes items, quests, and auction listings. It does not expose which boss drops which item, or at what rate.

**Decision: v1 ships without boss drops.** Dungeon and raid quest rewards stay in, because those come from the quest API and the item is guaranteed on turn-in. Boss drops move to the backlog with the blocker attached.

This keeps Phase 3 unblocked. Options to revisit later, in rough order of preference:
- A community-maintained dataset published under a permissive license
- Addon-side loot logging (record what actually drops as you play, build the table over time)
- An existing loot-database addon's data files, if licensing permits

The scoring function already has a slot for a `dropRate` multiplier, so adding drops later is a data problem, not a rewrite.

**Risk 2: Auction house data is stale by design.**
Blizzard publishes AH data in periodic batches, not live. Recommendations will lag actual listings. The dashboard should show the snapshot timestamp so you know how old the data is.

**Risk 3: WoW Classic API coverage may differ from Retail.**
Classic uses separate namespaces. Some endpoints available for Retail may be thinner or absent for Classic Era. Verify endpoint by endpoint during Phase 3 rather than assuming parity.

**Risk 4: XP and Gold modes rank by raw value, not efficiency.**
No API exposes quest completion time. A high-XP quest that takes a long walk will outrank a fast one. Acceptable for v1. Fixing it needs either community time data or self-logged completion times.

---

## Open Questions

1. Should the addon cache recommendations locally or always fetch fresh?
2. Should recommendations show a confidence score, or just the rank?
3. Should the tool track which recommendation you acted on, to improve future scoring?
4. What is the fallback behavior when the Blizzard API is unavailable? Serve stale cache, or show an error?
5. Resolved by Constraint 1. The addon never contacts the backend, so it needs no auth. The open version of this question is whether the dashboard import box needs any validation beyond JSON schema checking.

---

## Future Backlog

Not in v1. Revisit after the core loop works.

**Blocked on data availability:**
- **Dungeon and raid boss drops.** Blocker: no API publishes loot tables or drop rates. Needs a licensed community dataset, self-logged drop data, or an existing addon's data files. The scoring function already reserves a `dropRate` multiplier, so this is a data problem, not a rewrite.
- **Reward-per-hour ranking.** Blocker: no API publishes quest completion time. Needs community timing data or self-logged completion times.

**Not blocked, just not v1:**
- **Automated export (v2).** Replace copy-paste with a local companion process that watches SavedVariables and POSTs to the backend. Costs every user a second program to install and run, and requires a `/reload` to flush. Worth revisiting only if the manual paste becomes the main friction in daily use.
- **PvP gear:** honor rewards, battleground quest rewards, PvP set pieces
- **Reputation paths:** which factions to grind for gear at a given level
- **Profession-crafted gear:** what your professions can make that beats current gear
- **Cross-character view:** shared bank awareness, alt gear planning
- **WoW Forever support:** after the Nov 4 launch, add its namespace and new zones
- **Retail support:** significantly different itemization, treat as a separate track
- **Stat weight editor:** UI for overriding the default class and spec weights
- **Blended optimization mode:** weight gear, XP, and gold together instead of picking one
- **Route optimization:** order the recommended quests by travel distance

---

## Code Storage

The Claude Project knowledge base is the source of truth for v1. Code and docs live there as uploaded files, readable from any chat in the Project.

| Item | Where it lives |
|---|---|
| `PRD.md`, `DECISIONS.md` | Project knowledge base |
| Addon Lua source | Project knowledge base, mirrored from the live AddOns folder |
| Backend source | Project knowledge base until Phase 2, then Replit |
| Dashboard source | Project knowledge base until Phase 5, then Replit |

**What this costs.** No version history, no diffs, no rollback. Mitigation: generate a dated zip snapshot at the end of each phase and keep it outside the Project.

**Where it breaks.** The addon only runs from `Interface/AddOns/`, and the backend only runs on Replit. Neither reads from a Claude Project. So the Project holds the reference copy while the running copy lives elsewhere, and the two drift unless you re-upload after every change.

**Revisit trigger.** Phase 2, when the backend needs to run on Replit. Replit imports from a Git remote, not from a Project. At that point either wire up a repo or accept manual copying between Replit and the Project.

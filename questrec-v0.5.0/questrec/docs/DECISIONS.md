# Decision Log

**Version:** 0.5.0

Running record of architectural decisions and why they were made. Append, do not rewrite.

Version number matches the PRD, the addon, and the snapshot bundle of the same generation.

---

## D001: Three-tier architecture (addon, backend, dashboard)

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Character data lives in the game client. Quest and item data lives in Blizzard's API. Neither can reach the other directly.

**Decision.** Three separate tiers. The addon reads the client. The backend joins that with Blizzard data and scores it. The dashboard displays results.

**Consequences.** Each tier ships and fails independently. The addon works with the backend down. The tradeoff is three codebases instead of one.

---

## D002: On-demand data collection, no background streaming

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Continuous streaming means constant network traffic and constant data collection while playing.

**Decision.** The addon sends data only on explicit triggers: quest accepted, user command, manual refresh.

**Consequences.** Recommendations can be stale between triggers. Acceptable, since character gear changes infrequently. No data leaves the machine while logged out.

---

## D003: WoW Classic Era only in v1

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Retail, Classic Era, and WoW Forever have different itemization, different APIs, and different namespaces.

**Decision.** Classic Era only. WoW Forever launches November 4 and shares much of the Classic codebase, so it should port with modest effort.

**Consequences.** Retail support is a separate track, not a config flag.

---

## D004: Dungeon and raid boss drops deferred; instance quest rewards kept

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Blizzard's Game Data API publishes items, quests, and auction listings. It does not publish loot tables or drop rates.

**Decision.** Split the two. Quest rewards from dungeon and raid quests stay in v1, because the quest API returns them and the item is guaranteed on turn-in. Boss drops move to the backlog.

**Consequences.** v1 covers a meaningful slice of instance loot without needing a loot table. The scoring function reserves a `dropRate` multiplier so drops slot in later without a rewrite. The `Loot_Sources` enum already includes `dungeon_drop` and `raid_drop` to avoid a migration.

---

## D005: Optimization mode is a UI toggle, not a config value

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Ranking by gear upgrade is the default goal, but not always the goal. Sometimes you want to hit the next level, or save for a mount.

**Decision.** A three-way toggle in the dashboard header: Gear, XP, Gold. Each runs a different scoring function. The backend returns scores for all three in one payload, so switching re-ranks in the browser without a refetch.

**Consequences.** Slightly larger response payload. Instant mode switching. Blended weighting across modes stays in the backlog.

---

## D006: Character identity is name plus realm

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Character names are unique per realm, not globally.

**Decision.** The composite key `characterName + realmName` identifies a character. Each is an independent record.

**Consequences.** Multi-character support requires no schema change. Cross-character features (shared bank, alt planning) would need a new account-level grouping, which is backlog.

---

## D007: Claude Project is the source of truth, not GitHub

**Date:** 2026-09-17
**Status:** Accepted, with a known expiry

**Context.** GitHub is not reachable from this chat surface, and setting up a repo added friction at the point where the actual work is learning Lua and getting an addon to load.

**Decision.** The Claude Project knowledge base holds code and docs for now. Dated zip snapshots at each phase boundary stand in for version history.

**Consequences.** No diffs, no rollback, no branch. Acceptable while the codebase is a few scaffolding files.

The decision has a built-in expiry. The addon runs only from the WoW AddOns folder. The backend runs only on Replit, which imports from a Git remote rather than from a Project. From Phase 2 onward the running copy and the stored copy are different places, and they drift unless manually re-synced. Revisit at Phase 2.

**Supersedes:** the GitHub repo layout in D001-era planning.

---

## D008: Copy-paste export, because the addon sandbox forbids anything else

**Date:** 2026-09-17
**Status:** Accepted

**Context.** The PRD assumed the addon would POST JSON to the backend. It cannot. WoW addons run sandboxed with no network access, no filesystem access, and no system commands. The only I/O is their own SavedVariables file, flushed at `/reload` or logout.

**Decision.** The addon builds the payload in memory and shows it in a copyable popup. The player pastes it into the dashboard, which calls the backend.

**Consequences.** A manual paste whenever gear or level changes materially. In exchange: no local software, no `/reload`, and a snapshot that is current the instant you run the command. The rejected companion-process alternative would have broken the "runs entirely on Replit, no local infrastructure" success criterion and would have been slower, since SavedVariables only flushes on reload.

Automated export moves to the v2 backlog.

**Supersedes:** the HTTP POST data flow in D001-era planning.

---

## D009: Addon design checked against Blizzard's add-on policy before Phase 1

**Date:** 2026-09-17
**Status:** Accepted

**Context.** Account safety was a precondition for installing anything.

**Decision.** Checked the design against all eight points of Blizzard's UI Add-On Development Policy. The addon reads the player's own character data through sanctioned APIs and displays it. No automation, no client modification, no chat traffic, no addon-channel messages.

**Consequences.** Two design constraints follow from policy point 3, which forbids negatively impacting realms or other players:
- `QUEST_LOG_UPDATE` is not handled, because it fires constantly and heavy work there risks frame rate problems.
- No use of `SendAddonMessage` or any chat channel.

Policy point 8 stands as an accepted risk: Blizzard reserves the right to disable any add-on functionality at its discretion.

---

## D010: Blizzard policy compliance is a standing constraint on every tier, not a one-time addon check

**Date:** 2026-09-18
**Status:** Accepted

**Context.** D009 checked the addon against Blizzard's UI Add-On Development Policy. That policy governs the addon only. The backend runs under a separate, binding agreement: the Blizzard Developer API Terms of Use, last updated October 1, 2019. Nobody had read it.

**Decision.** Treat Blizzard policy as a standing constraint across all three tiers. Two documents apply, and they are not the same:

| Tier | Governing document |
|---|---|
| Addon | UI Add-On Development Policy (8 points, checked in D009) |
| Backend and dashboard | Blizzard Developer API Terms of Use |

Any new feature gets checked against whichever applies before it is built, not after.

**Consequences.** Six requirements from the API Terms of Use land directly on the current design.

**1. Thirty-day maximum data TTL (section 2.r).** Data pulled from the API may be retained no longer than 30 days. This is a data protection requirement tied to players' right to withdraw, not a caching suggestion. The PRD's "refresh every 24 hours" satisfies the refresh half but says nothing about deletion. `Quest_Cache` and `Loot_Sources` need a purge job that deletes rows older than 30 days, not just a `last_updated` column.

**2. Attribution required, trademarks forbidden in the title (section 2.m).** The dashboard must clearly and conspicuously identify Blizzard as the source of the data, in a way that does not imply endorsement or affiliation. Separately, the Application may not carry Blizzard trademarks in its title or URL. "WoW" is a Blizzard trademark, which puts both the project name and the repository name in question. Open, see below.

**3. Privacy policy required (section 2.o).** A posted privacy policy governing use of the Data, consistent with Blizzard's own. Required even for a personal tool once anyone else uses it.

**4. Application must be registered (section 2).** The API key may only be used for Applications registered with Blizzard at the time the key is requested. Registration is a Phase 3 prerequisite, not paperwork to backfill.

**5. API key confidentiality (section 2.l).** Already handled. `.env` is gitignored and `.env.example` carries no values.

**6. Deletion on request (section 11.c).** If anyone asks that their data stop being used, all copies must be deleted. Matters once friends are using it.

The rate limit of 36,000 calls per hour was already in the PRD and is confirmed by section 2.q. Blizzard also requires an Authenticator on the Battle.net account before API access is granted.

**Open question raised by this decision.** Whether to rename the project and repository to drop "WoW". Section 2.m is explicit that the Application shall not contain Blizzard trademarks as part of its title or URL. Common community practice is looser than the written terms. Sean's call, but the terms are unambiguous and the cost of renaming now is far lower than later.

---

## D011: Renamed to QuestRec, resolving the trademark question in D010

**Date:** 2026-09-18
**Status:** Accepted

**Context.** D010 flagged that API Terms of Use section 2.m forbids Blizzard trademarks in an Application's title or URL, and "WoW" is a Blizzard trademark. That left the project name and repository name open.

**Decision.** The project, addon, and repository are named QuestRec. The addon folder and TOC are `QuestRec/QuestRec.toc`, SavedVariables is `QuestRecDB`, and the slash command is `/qr` with `/questrec` as an alias.

**What the rename does not cover.** Section 2.m restricts titles and URLs, not descriptive text. Naming the game a tool is built for is nominative use and is necessary to describe the tool at all. So "recommendations for World of Warcraft Classic Era" stays in the README and PRD body, and the install path `Interface/AddOns/` under the World of Warcraft directory obviously stays, because it is the user's filesystem. Scrubbing every mention of the game would make the documentation useless without improving compliance.

**Consequences.** Anyone running the old addon has a stale `WoWRecommender` folder to delete. Its SavedVariables file is orphaned but harmless. The repository keeps its commit history through GitHub's rename, which also leaves a redirect from the old URL.

**Supersedes:** the open question in D010.

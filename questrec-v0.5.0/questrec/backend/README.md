# Backend API

Node.js and Express API. Receives character snapshots from the addon, enriches them with Blizzard game data, scores recommendations, and serves the dashboard.

## Setup

```
npm install
cp ../.env.example .env
```

Fill in `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET`. Register an application at https://develop.battle.net to get them.

```
npm run dev
```

## Layout

```
src/routes/     HTTP endpoints
src/services/   Blizzard API client, caching
src/scoring/    Gear, XP, and Gold scoring functions
```

## Status

Phase 2, not yet implemented.

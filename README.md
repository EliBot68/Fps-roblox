# Rival Clash – README

## Table of Contents
1. Overview
2. Core Features
3. Project Structure
4. Data Persistence
5. Security & Anti-Cheat
6. Development Phases
7. Assets Needed
8. How to Run in Roblox Studio
9. Performance Guidelines
10. Monetization Strategy
11. Community Features
12. Technical Requirements
13. Architecture Overview
14. Data Model & Schemas
15. Match Lifecycle & Event Flow
16. Security Hardening Checklist
17. Anti-Cheat Strategy (Detailed)
18. Performance Budgets
19. Testing & Quality Strategy
20. CI/CD & Release Management
21. Logging, Telemetry & Monitoring
22. Branching & Versioning
23. Localization & Accessibility
24. Future Roadmap (Extended Phases)
25. KPIs & Metrics
26. Contribution Guidelines
27. License
28. Support
29. Glossary

## Overview
**Rival Clash** is a fast-paced competitive PvP arena game built in Roblox. Players join short matches (2–6 minutes) in small teams, use weapons to eliminate opponents, and earn rank points based on performance. Between matches, players can customize their loadouts and buy cosmetic upgrades. The goal is to provide quick, exciting gameplay with strong replayability.

## Core Features
- **Matchmaking System**  
  Groups players into balanced teams and starts matches automatically when enough players are in the lobby.

- **Server-Authoritative Combat**  
  All weapon firing, hit detection, and damage calculation is handled by the server to prevent cheating.

- **Weapons System**  
  Support for multiple weapons (starting with a basic rifle), each with unique stats like fire rate, damage, and accuracy.

- **Ranking & Progression**  
  Player skill rating (ELO) adjusts after each match. Higher ranks unlock cosmetic rewards and exclusive weapons.

- **Lobby Area**  
  Central hangout area where players can wait for matches, access shops, view leaderboards, and practice in training areas.

- **Cosmetics Store**  
  Players can purchase skins, trails, weapon camos, and other visual upgrades using in-game currency or Robux.

- **Kill Streaks & Rewards**  
  Multi-kill streaks provide temporary power-ups and bonus currency for skilled players.

- **Daily Challenges**  
  Complete specific objectives to earn extra currency and exclusive cosmetic items.

## Project Structure

```
RivalClash/
├── ServerScriptService/
│   ├── Core/
│   │   ├── Matchmaker.server.lua        # Handles player queues and match creation
│   │   ├── Combat.server.lua            # Validates shots, damage, and hit detection
│   │   ├── RankManager.server.lua       # Calculates and saves player ELO
│   │   ├── DataStore.server.lua         # Saves player stats, rank, and cosmetics
│   │   └── AntiCheat.server.lua         # Monitors for suspicious player behavior
│   ├── Economy/
│   │   ├── CurrencyManager.server.lua   # Handles currency rewards and spending
│   │   └── ShopManager.server.lua       # Manages cosmetic purchases
│   └── Events/
│       ├── DailyChallenges.server.lua   # Tracks and rewards daily objectives
│       └── KillStreakManager.server.lua # Handles kill streak bonuses
├── ReplicatedStorage/
│   ├── RemoteEvents/
│   │   ├── MatchmakingEvents/
│   │   │   ├── RequestMatch
│   │   │   └── LeaveQueue
│   │   ├── CombatEvents/
│   │   │   ├── FireWeapon
│   │   │   ├── ReportHit
│   │   │   └── RequestReload
│   │   ├── ShopEvents/
│   │   │   ├── PurchaseItem
│   │   │   └── EquipCosmetic
│   │   └── UIEvents/
│   │       ├── UpdateStats
│   │       └── ShowLeaderboard
│   ├── Shared/
│   │   ├── WeaponConfig.lua             # Weapon stats and configurations
│   │   ├── GameConfig.lua               # Global game settings
│   │   └── Utilities.lua                # Helper functions
│   ├── Weapons/
│   │   ├── AssaultRifle/                # AK-47 style weapon
│   │   ├── SMG/                         # Submachine gun
│   │   ├── Sniper/                      # High-damage precision weapon
│   │   └── Pistol/                      # Secondary weapon
│   └── Cosmetics/
│       ├── WeaponSkins/
│       ├── PlayerTrails/
│       └── Accessories/
├── StarterGui/
│   ├── MainHUD/                         # In-game UI (health, ammo, timer)
│   ├── LobbyUI/                         # Lobby interface and menus
│   ├── ShopUI/                          # Cosmetics store interface
│   └── LeaderboardUI/                   # Rankings and statistics
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── CombatClient.lua             # Client-side weapon handling
│       ├── UIManager.lua                # UI state management
│       └── SoundManager.lua             # Audio effects and music
├── Workspace/
│   ├── Lobby/                           # Central player hub with shops
│   │   ├── SpawnPoints/
│   │   ├── Shop/
│   │   ├── Leaderboards/
│   │   └── TrainingArea/                # Practice shooting range
│   ├── Arenas/                          # Folder containing map models
│   │   ├── Factory/                     # Industrial-themed map
│   │   ├── Rooftops/                    # Urban cityscape map
│   │   └── Desert/                      # Desert outpost map
│   └── Lighting/                        # Lighting presets for different maps
└── README.md
```

## Data Persistence
Player stats, rank, owned cosmetics, and daily challenge progress are saved between sessions using Roblox **DataStoreService** with backup systems (retry + exponential backoff + circuit breaker for failures) to prevent data loss. Critical writes batched and throttled.

## Security & Anti-Cheat
- All critical actions (damage, currency changes, rank changes) validated server-side.
- Clients treated as untrusted sources; deterministic server recomputation.
- Anti-cheat monitors:
  - Unrealistic fire rates / reload cycles
  - Impossible positions / teleport spikes / speed thresholds
  - Abnormal accuracy / headshot ratio outliers
  - Currency mutation outside controlled paths
  - Tampered remote payload sizes / invalid enums

## Development Phases

Legend: [x] complete, [~] partial / in progress, [ ] not started

### Phase 1: MVP (Minimum Viable Product)
- [x] Basic matchmaker for 2–6 player matches
- [x] Server-authoritative assault rifle with realistic mechanics
- [ ] Simple arena map with balanced spawn points (placeholder only, not built)
- [~] Basic HUD showing health, ammo, and match timer (health/ammo stats via ScreenGui; match timer pending)

### Phase 2: Core Systems
- [~] ELO ranking system with skill-based matchmaking (ELO + tiers done; matchmaking now sorts by Elo for team balance; full bucket system pending)
- [x] Data persistence for player stats and progress (schema v2, retries)
- [x] Kill/death tracking and match statistics (basic K/D; richer per-match stats pending)
- [x] Basic anti-cheat implementation (plus extended heuristics & anomaly score scaffold)

### Phase 3: Weapon Variety
- [x] Add SMG with high fire rate, low damage
- [x] Add sniper rifle with high damage, slow fire rate
- [x] Add pistol as secondary weapon
- [~] Implement weapon switching and dual-wielding (switching done; dual-wield not implemented)

### Phase 4: Economy & Progression
- [x] Currency system (earn on kills, wins, streaks) (client updates currency via remote)
- [~] Cosmetics store with weapon skins and player accessories (server purchase logic; UI + cosmetic visuals pending)
- [x] Daily challenges with rotating objectives (kill & win hooks active)
- [ ] Rank-based rewards and unlocks (no gating logic yet)

### Phase 5: Content Expansion
- [ ] Additional maps with unique layouts and themes
- [~] Kill streak rewards and power-ups (streak currency rewards present; power-up effects not implemented)
- [ ] Seasonal events and limited-time cosmetics
- [~] Spectator mode and replay system (camera target cycling + replay event log scaffold; full replay playback pending)

### Phase 6: Competitive Features
- [ ] Ranked seasons with placement matches
- [~] Tournament mode for organized competitions (single-elim bracket scaffold; no persistence/UI)
- [~] Clan system and team battles (in-memory clans + membership persistence; battles pending)
- [ ] Advanced statistics and performance analytics

### Phase 7: Live Ops & Analytics
- [~] Real-time metrics dashboards (in-memory counters & logs only)
- [x] Feature flag system for controlled rollouts
- [ ] A/B testing framework (MemoryStore variant gating not built)
- [ ] Crash / error aggregation & alerting

### Phase 8: Scalability & Cross-Server
- [ ] Cross-server party matchmaking (MemoryStore queues)
- [ ] Global announcements (MessagingService broadcast)
- [ ] Session migration / seamless teleport fallback
- [ ] Sharded leaderboards & caching layer

### Phase 9: Esports & Integrity
- [~] Enhanced anti-cheat heuristics + anomaly scoring (heuristics + anomaly score accumulator; action ladder pending)
- [ ] Match recording metadata logs (fire & elimination events collected in memory)
- [ ] Admin review tooling & replay proto
- [~] Tournament seeding & bracket automation (ELO seeding + progression basic)

### Phase 10: Continuous Improvement
- [ ] Predictive balancing (collect weapon performance stats)
- [ ] Player retention cohort analysis
- [ ] Dynamic difficulty assist (new player protections)
- [ ] Automated regression test suite expansion

## Assets Needed
- **Weapon Models**: Realistic but Roblox-appropriate weapon designs
- **Arena Maps**: Varied layouts for different gameplay styles
- **UI Assets**: Modern, clean interface elements
- **Cosmetic Items**: Weapon skins, player trails, and accessories
- **Sound Effects**: Weapon sounds, hit markers, and ambient audio
- **Particle Effects**: Muzzle flashes, bullet tracers, and explosion effects

## How to Run in Roblox Studio
1. Open the Rival Clash project folder in Roblox Studio
2. Ensure all scripts are placed in their specified locations
3. Configure the game settings in `ReplicatedStorage/Shared/GameConfig.lua`
4. Start Play Test in **Server + Multiple Clients** mode to simulate real gameplay
5. Test matchmaking by having multiple clients join the queue
6. Verify that combat, ranking, and data persistence work as expected

## Performance Guidelines
- Target 60 FPS on mid-range devices (90+ on high-end, 30+ on low-end mobile)
- Max per-frame RemoteEvents per client: < 20 during combat bursts
- Max weapon Fire Remote payload: < 120 bytes
- Raycasts per shot: 1 ( + optional verification ray )
- DataStore writes per player per session: <= 6 average

## Monetization Strategy
- **Premium Battle Pass**: Seasonal cosmetic rewards
- **Cosmetic Store**: Direct purchase of skins and accessories
- **Currency Boosters**: Temporary increased earnings
- **Early Access**: New weapons and maps for premium players

## Community Features
- In-game chat with profanity filtering
- Report system for inappropriate behavior
- Friends list and party system for team play
- Community-created cosmetics program

## Technical Requirements
- **Server Memory**: Optimized for 16-20 concurrent players per server
- **Data Storage**: Efficient use of DataStore quotas
- **Network**: Minimized latency for competitive gameplay
- **Mobile Support**: Touch controls and UI scaling
- **Resilience**: Graceful degradation when DataStore or MessagingService budget exceeded

## Architecture Overview
Layers:
1. Client Presentation (UIManager, HUD, input capture)  
2. Client Prediction (optional recoil & local fire animation)  
3. Transport (RemoteEvents segmented by domain)  
4. Server Domain Logic (Matchmaker, Combat, Rank, Economy)  
5. Persistence (DataStore wrapper + in-memory caches + flush scheduler)  
6. Observability (logging facade, metric sinks, audit records)  
7. Anti-Cheat (rate limiting, heuristics, anomaly flags)  

Patterns:
- ModuleScript singletons for stateless utility
- Event-driven architecture (BindableEvents internally, RemoteEvents externally)
- Data Oriented tables for hot loops (combat validation)
- Dependency inversion via lightweight service locator table

## Data Model & Schemas
PlayerProfile:
```
{
  UserId: number,
  Elo: number,
  TotalKills: number,
  TotalMatches: number,
  Currency: number,
  OwnedCosmetics: { [cosmeticId]: true },
  Daily: { Challenges: { [challengeId]: progress }, ResetAt: number }
}
```
MatchRecord (ephemeral):
```
{
  MatchId: string,
  StartedAt: number,
  EndedAt: number?,
  Players: { [userId]: { Kills: number, Deaths: number, Score: number } },
  Map: string,
  WinnerTeam: string?
}
```
TelemetryEvent (log line): `{ t=timestamp, type="Fire", p=userId, w=weaponId, pos=vector3Serialized }`

## Match Lifecycle & Event Flow
States: Lobby -> Countdown -> Active -> PostMatch -> Cleanup -> Lobby.
Primary events:
- Client: RequestMatch -> Server: QueueJoinAck
- Server: MatchStarted -> Clients: LoadoutLock + Teleport/Spawn
- Client: FireWeapon -> Server: ValidateFire -> (if hit) DamageApplied -> Client HUD Update
- Server: MatchEnded -> RankAdjust -> ProfileSaveDeferred -> Return to Lobby

## Security Hardening Checklist
- [ ] Validate all remote argument counts / types
- [ ] Clamp vector magnitudes (origin/direction)
- [ ] Monotonic server timestamps only (reject client time deltas)
- [ ] Fire rate token-bucket per weapon
- [ ] Index-based weapon reference (no free-form string trust)
- [ ] Economy operations behind server-only API (no direct Remote)
- [ ] Hash + sign sensitive audit batches before persistence (optional future)

## Anti-Cheat Strategy (Detailed)
Heuristics buckets:
- Temporal: fire cadence variance, reload overlap
- Spatial: delta position speed, vertical impulse anomalies
- Accuracy: moving accuracy > static threshold, head ratio outlier
Actions ladder:
1. Flag -> log
2. Soft shadow ban (segregated matchmaking) (future)
3. Session kick
4. Persistent ban (manual review)
Data collected hashed & truncated to respect privacy.

## Performance Budgets
| System | Budget | Notes |
|--------|--------|------|
| Per shot validation | < 1 ms server | Raycast + table updates |
| Match start setup | < 250 ms | Spawn & teams |
| Data save batch | < 50 ms | Async; fallback queue |
| Heartbeat anti-cheat loop | < 2 ms | Avoid heavy math |

Memory Targets (approx):
- Player profile: < 1 KB serialized
- Active match state per player: < 0.5 KB

## Testing & Quality Strategy
Test pyramid:
- Unit: Utilities, ELO formulas
- Integration: Match start -> end flow, fire/damage cycle
- Load Simulation: synthetic clients firing at configured RPS
- Security: fuzz remote argument counts/types
Automation:
- Pre-commit lint & static analysis (Luau type annotations future)
- Nightly soak test: 100 bot sessions (local harness)

## CI/CD & Release Management
Pipeline Stages:
1. Lint & Static Checks
2. Unit Test Run (future automated harness)
3. Package & Deploy to Staging Place
4. Automated Smoke (spawn, queue, fire)
5. Manual QA Gate
6. Promote to Production
Feature Flags for gradual rollout (per-user hashing modulo bucketing).

## Logging, Telemetry & Monitoring
Channels:
- Structured log (JSON-like) for combat & economy
- Metric counters: ShotsFired, ValidHits, Kills, MatchStarts, DataSaveFailures
- Gauges: ActiveMatches, QueueSize
- Histograms: FireValidationLatency, MatchDuration
Alert thresholds: DataSaveFailureRate > 5% in 5 min window -> alert.

## Branching & Versioning
- Main: stable
- Develop (optional): integration
- Feature/*: isolated work
- Release/*: staging hardening
- Hotfix/*: production patches
Versioning: `MAJOR.MINOR.PATCH` (gameplay-impacting schema bump increments MINOR).

## Localization & Accessibility
- All UI text routed through localization table keys
- Color contrast ratio >= 4.5:1 core HUD
- Optional reduced motion toggle (disables camera recoil intensity)
- Scalable UI anchors for mobile & console

## Future Roadmap (Extended Phases)
See Phases 7–10 plus potential Phase 11 (UGC & Marketplace Integration), Phase 12 (AI-driven coaching tips), Phase 13 (Advanced Replay & Share System).

## KPIs & Metrics
- D1 Retention (% of new players returning next day)
- Avg Match Completion Rate
- Shots Fired -> Valid Hit Ratio
- ELO Distribution Curve (variance target stable)
- Average Queue Time (goal < 10s off-peak, < 25s peak)
- Crash/Error Rate per 100 Sessions
- Monetization: ARPDAU (if applicable later)

## Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-weapon`)
3. Commit your changes (`git commit -am 'Add new weapon system'`)
4. Push to the branch (`git push origin feature/new-weapon`)
5. Create a Pull Request

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support
For bug reports and feature requests, please open an issue on GitHub or contact the development team.

## Glossary
- ELO: Rating system indicating player skill
- RPS: Requests (Remote events) per second
- UGC: User Generated Content
- KPI: Key Performance Indicator
- HUD: Heads-Up Display
- QoS: Quality of Service

---

**Author:** EliBot68 & Development Team  
**Version:** 0.3 (Enterprise Roadmap Expansion)  
**Target Platform:** Roblox PC + Mobile + Console  
**Last Updated:** August 2025
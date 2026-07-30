---
layout: project
title: "legacy-core"
repo: "sarumc/legacy-core"
repo_url: "https://github.com/sarumc/legacy-core"
description: "The heart of all features"
language: "PHP"
stars: 0
updated: "2026-07-16T12:32:52Z"
topics: [common-feature, pocketmine-mp]
readme_sha: "4cc6188eb3d1d08dc9c9297e49c645939d669b56"
sync_status: "new"
archived: true
lang: en
---



Foundation plugin for the SaruMC network. Every other plugin depends on it.

---

## Architecture

```
src/saru/core/
├── Core.php              # Plugin entry point + service registry
│
├── database/             # REST API communication (SaruMC Go backend)
│   ├── RestApi.php       #   Domain interface: addBananas(), applyBan(), …
│   ├── RestApiClient.php #   Guzzle implementation with X-API-Key auth
│   ├── RestClient.php    #   Low-level HTTP client
│   └── exception/        #   RestException, RestConnectionException, …
│
├── orchestrator/         # Minestrate server-provisioning client
│   ├── ClientInterface.php
│   ├── MinestrateClient.php
│   ├── exceptions/       #   AuthenticationException, RateLimitException, …
│   ├── models/           #   Server, ServerHealth, ServerList, ServerState, …
│   ├── valueObjects/     #   CreateServerOptions, ListServersOptions
│   └── tasks/            #   HeartbeatScheduler, HeartbeatTask
│
├── command/
│   ├── CommandLoader.php #   Registers commands, permissions, packet hooks
│   ├── CommandListener.php
│   ├── args/             #   RankArgument, TargetPlayerArgument
│   ├── cosmetics/        #   /disguise, /undisguise
│   ├── player/           #   /lobby, /msg, /ping, /profile, /settings
│   └── staff/            #   /rank
│
├── events/               # PocketMine event listeners
│   ├── Event.php
│   ├── PlayerListener.php
│   ├── ProjectileListener.php
│   └── ScoreboardUpdateEvent.php
│
├── games/                # Minigame lifecycle management
│   ├── Game.php          #   Abstract base: WAITING → STARTING → RUNNING → STOPPED
│   ├── GameManager.php   #   Singleton: launch/stop/tick/heartbeat
│   └── GameState.php     #   Enum
│
├── network/              # Cross-server player aggregation
│   ├── Network.php       #   Player counts via health checks, transfers
│   └── NetworkListener.php
│
├── player/               # Player model
│   ├── CustomPlayer.php  #   Extends PMMP Player: rank, bananas, sanctions, …
│   ├── ERank.php         #   Rank enum: Guest → Admin (permissions, hierarchy)
│   ├── CustomPermissions.php
│   ├── PlayerMessageType.php
│   └── Scoreboard.php    #   Scoreboard base class
│
├── translation/          # Multi-language (en/fr/es)
│   └── TranslationManager.php
│
└── utils/
    ├── Emotes.php        #   Bedrock emote UUIDs
    ├── Internet.php      #   Geolocation (ip-api.com JSON)
    ├── PlayerUtils.php   #   Sanction permission checks
    └── Unicode.php       #   Controller button glyphs
```

## Features

### REST API — `database/`

Domain methods — no generic `executeSelect`/`executeInsert`/`executeChange`. Each operation maps 1:1 to an HTTP endpoint.

```php
$api = Core::getInstance()->getApi();

// Players
$api->findPlayersByUuid('abc-def');
$api->createPlayer('uuid', 'Steve', 'en');
$api->getPlayerSummary(42);

// Bananas
$api->getBananas(42);        // int
$api->addBananas(42, 10);    // POST /players/42/delta
$api->removeBananas(42, 5);  // POST /players/42/delta (negative delta)

// Sanctions
$api->isBanned(42);          // GET /bans?player_id=42&active=true
$api->applyBan(42, 2, 'CHEAT', 'Hacks', '2026-12-31 23:59:59');
$api->removeBan(42);         // POST /players/42/bans/deactivate

// Friends, Settings, Hosts, Language, Rank — all explicit
```

### Orchestrator — `orchestrator/`

Minestrate server provisioning — create/destroy game servers, heartbeats, health monitoring.

```php
$orch = Core::getInstance()->getOrchestrator();

$server = $orch->createServer(new CreateServerOptions(game: 'bedwars', players: 8));
$orch->recordHeartbeat($server->id);
$orch->deleteServer($server->id);
```

### Network — `network/`

Cross-server player aggregation via per-container health checks.

```php
Network::getNetworkPlayerCount();   // local + all healthy remotes
Network::getLocalPlayerCount();     // this server only
Network::getRemotePlayerCount();    // summed from orchestrator health checks
Network::transferToGameServer($player, 'server-id');
Network::broadcastLocalized('key', params: ['arg']);
```

### Games — `games/`

```php
$game = new MyBedWarsGame($map);
GameManager::getInstance()->launch($game);   // provisions Minestrate server
GameManager::getInstance()->tick();           // called every server tick
GameManager::getInstance()->heartbeat();      // called every 30s
```

### Commands

| Command | Permission | Description |
|---------|-----------|-------------|
| `/disguise <nickname> [player]` | `disguise.command` | Disguise as another player |
| `/undisguise` | `disguise.command` | Remove disguise |
| `/lobby` | — | Transfer to lobby server |
| `/msg <player> <message>` | — | Private message |
| `/ping` | — | Check latency |
| `/profile [player]` | — | View player profile |
| `/rank <player> [rank]` | `rank.command` | Get/set player rank |
| `/settings <key> [value]` | — | Manage settings |

### Ranks

```
Guest → Booster → VIP → MVP → Monkey → Partner
                                            ↓
                       Helper → Moderator → Team → Admin
```

Permissions cascade: each rank defines its command permissions in `ERank::getPermissions()`.
Sanction checks use hierarchy level — same-rank staff cannot sanction each other.

### Translations

3 languages: `en`, `fr`, `es`. JSON files in `resources/lang/`. 3-tier fallback: requested → `en` → any.

```php
TranslationManager::translate('greeting', 'fr', ['Steve']);
// "Bonjour Steve !"
```

---

## Development

```bash
composer install                              # install deps
composer lint                                 # PHP syntax check
composer cs                                   # code style (dry-run)
composer cs-fix                               # auto-fix style
composer phpstan                              # static analysis (level 5)
composer test                                 # run tests
```

### Quality gates

```
lint → php-cs-fixer → phpstan (level 5) → phpunit (60 tests)
```

All must pass before merge. CI enforces this on PHP 8.2 + 8.3.

### Testing

```bash
vendor/bin/phpunit --no-configuration --bootstrap vendor/autoload.php tests/
```

60 tests, 115 assertions. Covers:
- `RestApiClient` — 25 tests (HTTP mocking with Guzzle MockHandler)
- `ERank` — 14 tests (permissions, hierarchy, staff, VIP)
- `GameState` — 10 tests (lifecycle transitions)
- `TranslationManager` — 11 tests (load, translate, fallback, params)

---

## Configuration

```yaml
# resources/config.yml
db_type: "rest"

database:
  rest:
    host: "api.saru.mc"
    port: 8080
    api_key: ""

minestrate:
  host: "orchestrator.saru.mc"
  token: ""
```

---

## CI/CD

| Workflow | Trigger | Steps |
|----------|---------|-------|
| **CI** | push/PR to `main`, `dev` | composer validate, lint, cs, phpstan, phpunit (PHP 8.2 + 8.3) |
| **Release** | tag push | PHAR build, Doxygen docs, GitHub Release |

---

## Dependencies

- `guzzlehttp/guzzle` ^7.0 — HTTP client
- `cortexpe/commando` — command framework (pinned)
- PHP >= 8.2 with extensions: mysqli, igbinary, openssl, zlib, curl

---
layout: project
title: "legacy-horus"
repo: "sarumc/legacy-horus"
repo_url: "https://github.com/sarumc/legacy-horus"
description: "An autonomous moderator for pocketmine 5.0"
language: "PHP"
stars: 0
updated: "2026-07-16T12:20:31Z"
topics: [anticheat, moderator-tools, pocketmine-mp]
readme_sha: "fe677007282d54423164550045da9dcf394da614"
sync_status: "new"
archived: true
lang: en
---



Anti-cheat & moderation plugin for SaruMC. Depends on `Core`.

Named after the falcon god — watching every player. 👀

## Anti-Cheat (29 checks)

### Combat (12)
| Check | Description |
|-------|-------------|
| Reach A | Distance exceeds ping-adjusted limit |
| Reach B | Horizontal distance + target behavior analysis |
| KillAura A | Multiple entities hit in same tick |
| KillAura B | Hits without arm-swing animation |
| AutoClicker A | CPS > 20 |
| AutoClicker B | High CPS over 10-second window |
| AutoClicker C | CPS spikes between ticks |
| AutoClicker D | Quick return to high CPS after dip |
| AutoClicker E | Inhumanly consistent click variance |
| Criticals A | Fake crits — on ground or ascending |
| Scaffold A | Fast block placement while moving on edges |
| Velocity A | AntiKnockback — canceled damage velocity |

### Movement (10)
| Check | Description |
|-------|-------------|
| Fly A | Ascending/hovering without ground |
| Fly B | Large vertical jumps without damage |
| Speed A | Horizontal speed > vanilla limit |
| Speed B | Strafe — instant >90° direction change |
| Timer A | Packets faster than 20 TPS |
| NoFall A | Fall damage avoided via fake ground |
| Glide A | Near-zero descent while falling |
| NoClip A | Phasing through solid blocks * |
| Jesus A | Walking on water/lava surface |
| AirJump A | Positive Y velocity while in air |

\* Throttled to every 4th move event.

### Packet (5)
| Check | Description |
|-------|-------------|
| BadPackets A | Pitch > 91°, yaw > 361°, out-of-world positions |
| BadPackets B | >4 auth/move packets per tick |
| BadPackets C | Self-damage or attacker >8 blocks away |
| BadPackets D | >15 inventory actions per 200ms |
| BadPackets E | Glide without elytra, spoofed input flags |

### World (1)
| Check | Description |
|-------|-------------|
| Nuker A | >8 blocks broken per second * |

\* Throttled to every 2nd break event.

### Misc (1)
| Check | Description |
|-------|-------------|
| ChatFilter | AntiSpam, AntiLink, Cooldown, AntiBadwords |

Each check has configurable max violations. On exceed: ban + kick.

## Moderation Commands (8)

| Command | Description |
|---------|-------------|
| `/ban <player> [days] [reason]` | Ban a player |
| `/unban <player>` | Unban by name |
| `/mute <player> [minutes] [reason]` | Mute a player |
| `/unmute <player>` | Unmute by name |
| `/kick <player> [reason]` | Kick from server |
| `/warn <player> [reason]` | Warn a player |
| `/report <player> [reason]` | Report a player |
| `/rank <player> <rank>` | Set player rank |

All commands use Commando arguments, `Database::getProvider()`, and go through
`PlayerUtils::canApplySanction()` for hierarchy checks.

## Architecture

```
horus/
├── check/
│   ├── Check.php              # Base: fail(), getMaxViolations(), onEvent(), onPacket()
│   ├── CheckManager.php       # Registry of all 29 checks
│   ├── combat/                # Reach, KillAura, AutoClicker, Criticals, Scaffold, Velocity
│   ├── movement/              # Fly, Speed, Timer, NoFall, Glide, NoClip, Jesus, AirJump
│   ├── packet/badpackets/     # A-E: invalid packets, spam, self-damage, container, flags
│   ├── world/nuker/           # Fast block break
│   └── misc/ChatFilter.php
├── command/
│   ├── CommandLoader.php      # Registers all 8 commands
│   └── lists/                 # Ban, Unban, Mute, Unmute, Kick, Warn, Report, Rank
├── listener/
│   ├── SessionListener.php    # PreLogin ban cache, Join session create, Quit cleanup
│   └── PlayerListener.php     # Routes events+packets to CheckManager
├── player/
│   ├── PlayerSession.php      # Per-player: violations, click data, hit data
│   ├── PlayerSessionManager.php
│   └── data/                  # ClickData, HitData tracking
├── task/async/                # Banwords file watcher
└── utils/                     # ChatUtils, MathUtils (stddev, kurtosis, skewness), TimeUtils
```

## Performance

- **Ban cache**: in-memory UUID→ban map, no per-login DB query
- **NoClipA**: throttled to every 4th move event
- **NukerA**: throttled to every 2nd break event

## Dependencies

- `Core` plugin — `saru\core\database\Database`, `CustomPlayer`, `PlayerUtils`, `TranslationManager`
- `CortexPE/Commando` — command framework

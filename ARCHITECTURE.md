# Top Down Adventure — Architecture

## Project Overview

A top-down action shooter built in Godot 4.6. The player navigates a tiled level, aims with mouse or gamepad, shoots enemies using a data-driven weapon system, and throws grenades. Currently a prototype with movement, shooting, impact effects, enemy combat, health/damage, camera feedback, pathfinding AI, ammo, and a basic HUD.

**Engine:** Godot 4.6 (Forward Plus renderer, Jolt Physics, Direct3D 12)
**Resolution:** 1280×960 display, 640×480 internal (2× scale)
**Main scene:** `scenes/main.tscn`

---

## Directory Structure

```
top-down-adventure/
├── assets/
│   ├── Art/
│   │   ├── Tileset/
│   │   ├── crosshair.png
│   │   ├── impact.png
│   │   ├── hitimpact.png
│   │   ├── laser.png
│   │   └── muzzleflash.png
│   ├── Characters/
│   │   ├── Slime1/           # Attack, Death, Hurt, Idle, Run, Walk
│   │   ├── Slime2/
│   │   ├── Slime3/
│   │   └── Temp/             # Player sprites
│   └── Sounds/
├── resources/
│   ├── anim_data.tres        # Player DirectionalAnimData
│   ├── weapons/
│   │   ├── weapon_default.tres
│   │   └── weapon_slow.tres
│   ├── ammo/                 # AmmoType resources
│   ├── pickups/              # PickupData resources (pickup_ammo_*.tres)
│   ├── tilesets/
│   │   └── grassy.tres
│   └── impacts/
│       ├── flesh_impact.tres
│       └── rock_impact.tres
├── scenes/
│   ├── player/
│   │   └── Player.tscn
│   ├── weapons/
│   │   └── grenade.tscn
│   ├── impacts/
│   │   ├── impactFX.tscn
│   │   └── stone.tscn
│   ├── main.tscn
│   ├── enemy.tscn
│   ├── bullet.tscn
│   └── MuzzleFlash.tscn
└── scripts/
    ├── character_base.gd          # Shared base for Player and EnemyBase
    ├── player.gd                  # extends CharacterBase
    ├── directional_anim_data.gd   # formerly PlayerAnimation
    ├── animation_state.gd
    ├── animation_entry.gd         # @tool: in-editor animation preview button
    ├── camera_controller.gd
    ├── debug_draw.gd              # Autoload: DebugDraw
    ├── audio_pool.gd              # Autoload: AudioPool
    ├── hit_stop.gd                # Autoload: HitStop
    ├── input_manager.gd           # Autoload: InputManager
    ├── impact_fx.gd
    ├── impact_fx_data.gd
    ├── muzzleflash.gd
    ├── pickup.gd                  # Area2D pickup; grants ammo on player contact
    ├── pickup_data.gd             # Resource: scene, ammo_type, texture, sound
    ├── swipe_fx.gd                # Melee swing visual effect (AnimatedSprite2D)
    ├── enemy/
    │   ├── enemy_base.gd          # extends CharacterBase
    │   ├── enemy_patrol_base.gd   # extends EnemyBase — patrol/spotted/returning FSM
    │   ├── enemy_debug_overlay.gd # top_level Node2D; draws detection radii, LKP, path
    │   ├── behaviors/
    │   │   ├── enemy_behavior.gd                    # base: execute(enemy, delta)
    │   │   ├── idle_behavior.gd
    │   │   ├── chase_player_behavior.gd
    │   │   ├── move_to_point_behavior.gd
    │   │   ├── rotate_toward_player_behavior.gd
    │   │   ├── navigate_to_player_behavior.gd
    │   │   ├── navigate_to_point_behavior.gd
    │   │   └── navigate_to_spotted_target_behavior.gd
    │   └── types/
    │       └── enemy_slime.gd     # extends EnemyPatrolBase
    ├── ui/
    │   ├── hud.gd
    │   ├── heart.gd
    │   └── weapon_display.gd
    └── weapons/
        ├── weapon_data.gd         # Resource (pure config); extends WeaponData
        ├── weapon.gd              # RefCounted (runtime instance); created from WeaponData
        ├── melee_weapon_data.gd   # extends WeaponData — melee config (swings, los_mask)
        ├── melee_weapon.gd        # extends Weapon — windup/active/recovery combo chain
        ├── swing_data.gd          # Resource: arc_range, arc_angle, damage, timing, FX
        ├── bullet.gd
        ├── bullet_trail.gd
        ├── ammo_type.gd
        ├── grenade.gd
        └── grenade_data.gd
```

---

## Scene Hierarchy

### `main.tscn` (root)

```
Node2D
├── Ground (TileMapLayer)          # group: ground_tilemap — used for camera bounds
├── NavigationRegion2D             # Baked nav mesh for enemy pathfinding
├── ySort (Node2D)                 # Y-sorted depth; group: ysort
│   ├── 2ndFloor (TileMapLayer)
│   ├── Walls (TileMapLayer)
│   ├── Player (Player.tscn)       # group: player
│   └── Enemy × N (enemy.tscn)
└── HUD (CanvasLayer)              # group: hud
    ├── HBoxContainer              # Heart containers
    ├── WeaponDisplay
    └── Crosshair (Node2D)         # group: crosshair
```

### `Player.tscn`

```
CharacterBody2D (player.gd)
├── AnimatedSprite2D
├── WallCollision (CollisionShape2D)
├── Muzzle (Marker2D)
│   └── LaserSight (Line2D)        # Reparented based on anim entry
├── MuzzleBehind (Marker2D)
└── Camera2D (camera_controller.gd)
```

### `enemy.tscn`

```
CharacterBody2D (EnemySlime / EnemyBase subclass)
├── AnimatedSprite2D
├── CollisionShape2D
└── NavigationAgent2D              # Required for patrol/navigate behaviors
```

---

## Autoload Singletons

| Name | Script | Responsibility |
|---|---|---|
| `AudioPool` | `scripts/audio_pool.gd` | Round-robin `AudioStreamPlayer2D` pool. `play(stream, position, ignore_pause)` swaps stream and sets `PROCESS_MODE_ALWAYS` when `ignore_pause` to survive `HitStop` pauses. |
| `HitStop` | `scripts/hit_stop.gd` | Pauses the scene tree for a real-time duration. Multiple concurrent `request(duration)` calls are merged — tree stays paused until the longest expires. Uses `Time.get_ticks_usec` and real-time timers (ignore_time_scale) internally. Emits `ended`. |
| `InputManager` | `scripts/input_manager.gd` | Tracks active input device (gamepad vs MKB). Emits `input_mode_changed(is_gamepad)`. Filters joypad axis noise below `STICK_DEADZONE = 0.2`. |
| `DebugDraw` | `scripts/debug_draw.gd` | Global `add_line` / `add_circle` with TTL fade. Auto-parents to `hud` CanvasLayer. Skips `queue_redraw` when empty. |

---

## Core Systems

### 1. Character Hierarchy

```
CharacterBase (character_base.gd)   — health, damage, death, hit flash, knockback, weapons, animation data
├── Player (player.gd)              — input, camera, aim, laser, crosshair, invulnerability, ammo
└── EnemyBase (enemy/enemy_base.gd) — contact damage, knockback scale, behavior API, move_speed
    └── EnemyPatrolBase             — patrol/spotted/returning FSM, LOS detection, waypoints
        └── EnemySlime              — overrides _spotted_behavior()
```

**`CharacterBase`** holds the shared contract:
- `max_health`, `_health`, `health_changed` signal
- `take_damage(amount, knockback_direction, impact_position, shot_id)` — hit flash, knockback accumulation, health decrement, death check
- `die()` — disables physics/collision, virtual `_on_die()` for subclass cleanup
- `_on_take_damage(same_shot, knockback_direction, impact_position)` — virtual hook
- `weapons: Array[Weapon]`, `anim_data: DirectionalAnimData`, `_facing: Vector2`
- `has_ammo(w: Weapon) -> bool` — returns `true` by default; Player overrides

### 2. Player Controller (`scripts/player.gd`)

**Aiming:** Mouse (get_global_mouse_position) or gamepad right stick. Device switches via `InputManager.input_mode_changed`. Aim assist scans an `Area2D` (physics-layer filtered, no per-frame group scan) for enemies within `weapon.aim_assist_angle`, applies exponential decay lerp.

**Shooting:**
- SINGLE/BURST: fires on press, buffered for `fire_buffer_window` seconds if cooldown not yet elapsed
- AUTO: fires each tick while held
- `_fire_held` corrected on `HitStop.ended` in case release was missed during pause

**Ammo:** Player holds `_ammo: Dictionary` (AmmoType → int). `has_ammo(w)` gates all fire paths. `ammo_changed(ammo_type, current)` signal emitted on consumption. `add_ammo(ammo_type, amount)` for pickups.

**Contact damage:** After `move_and_slide`, iterates slide collisions; calls `take_damage` if collider is `EnemyBase` with `contact_damage > 0`.

**Camera:** Spring shake in impact direction (exponential damping) + zoom punch. Both use `TWEEN_PAUSE_PROCESS` to survive `HitStop`.

### 3. Animation System (`DirectionalAnimData`)

Three resource classes compose the lookup:

| Class | Role |
|---|---|
| `AnimationEntry` | One direction: animation name, flip, muzzle offset, bullet-behind flag |
| `AnimationState` | Groups N `AnimationEntry` objects for one logical state (idle, walk, death…) |
| `DirectionalAnimData` | Array of `AnimationState`; O(1) Dictionary cache; `get_entry(state, dir_index)` |

`direction_to_index(Vector2, direction_count) -> int` is static on `DirectionalAnimData`, used by both Player and EnemyBase.

### 4. Weapon System

The weapon system separates configuration from runtime state so the same `.tres` resource file can safely be shared across multiple enemies without mutable-state collisions.

**`WeaponData`** (`Resource`) — pure configuration, no runtime state. Assigned in the Inspector.

| Property | Description |
|---|---|
| `fire_mode` | SINGLE / AUTO / BURST |
| `ammo_type` | `AmmoType` resource; `null` = infinite |
| `pellet_count` / `spread_angle` | Shotgun-style multi-pellet |
| `bullet_trail_scene` | `PackedScene` for `BulletTrail` |
| `grenade_data` | If set, `fire()` throws a grenade instead of bullets |
| `aim_assist_angle/range/strength` | Per-weapon gamepad aim assist |
| `fire_shake_strength` | Camera shake on fire |
| `suppress_wall_impacts` | Skip wall impact FX (e.g. shotgun) |

**`Weapon`** (`RefCounted`) — per-character runtime instance. Created by `WeaponData.create_instance()` in `CharacterBase._ready()`. Holds `_cooldown`, `_burst_remaining`, `_shot_counter`, and the `fired` signal. Exposes data properties as read-through getters so call sites are unchanged.

`CharacterBase` exports `weapons: Array[WeaponData]` (config) and maintains `_weapon_instances: Array[Weapon]` (one per slot, created at ready). `fire(muzzle, direction, shooter)` takes the shooter explicitly — no stored `owner_node` on the instance.

**`MeleeWeaponData`** extends `WeaponData` — adds `swings: Array[SwingData]`, `los_mask`, `debug_draw_arc`. `create_instance()` returns a `MeleeWeapon`.

**`MeleeWeapon`** extends `Weapon` — holds swing state machine (WINDUP / ACTIVE / RECOVERY / IDLE), `_shooter` stored on `fire()` for use by tick helpers.

Shot ID system: each `fire()` call increments a counter. All pellets from one shot share the same `shot_id`. Same-shot hits on a body accumulate knockback only — no repeated flash/sound/impact FX.

### 5. Grenade System

**`GrenadeData`** (`Resource`) — all configuration grouped by export groups: Fuse, Explosion, Bounce, Radius Indicator, Pre-Explode.

**`Grenade`** (`CharacterBody2D`) — thrown projectile:
- `init(data, direction, speed, thrower, shot_id)` called **before** `add_child`
- Physics: `move_and_collide` with exponential velocity decay and bounce friction
- Fuse countdown with pre-explode flash (lerped rate) and radius indicator (`GrenadeRadius` top-level Node2D)
- Settle clinks: N extra bounce FX as speed decays to `stop_speed`
- Explosion: `PhysicsShapeQueryParameters2D` circle query, falloff curve sampling, LOS raycast per target, optional self-damage override
- Damage fires after `damage_delay` seconds so FX plays before HitStop freezes

### 6. Enemy Behavior System

#### Behavior Objects (`scripts/enemy/behaviors/`)

```gdscript
class EnemyBehavior extends RefCounted:
    func execute(enemy: EnemyBase, delta: float) -> void
```

`EnemyBase._active_behavior` is set by the coroutine API and called each `_physics_process`. Knockback takes velocity priority over behavior.

Built-in behaviors: `IdleBehavior`, `ChasePlayerBehavior`, `MoveToPointBehavior`, `RotateTowardPlayerBehavior`, `NavigateToPlayerBehavior`, `NavigateToPointBehavior`, `NavigateToSpottedTargetBehavior`.

#### `EnemyBase` Behavior API

```gdscript
# Awaitables (return Signal — await in _run_behavior)
run_behavior(b: EnemyBehavior, duration: float) -> Signal
navigate_toward_player(duration: float) -> Signal
rest(duration: float) -> Signal

# Immediate
face(direction: Vector2) -> void
shoot_weapon(index: int, target_pos: Vector2) -> void
is_alive() -> bool
get_player() -> CharacterBase       # cached via "player" group
player_position() -> Vector2
```

`_run_behavior()` is a virtual async method started detached in `_ready`. Subclasses override it to define behavior sequences using `await`.

#### `EnemyPatrolBase` FSM

Three states: `PATROL → SPOTTED → RETURNING → PATROL`.

```
PATROL:   navigate waypoints (loop or bounce); _navigate_interruptible breaks on player spotted
SPOTTED:  run _spotted_behavior() loop; navigate toward player (or LKP when not visible)
RETURNING: navigate back to waypoint[0] or _patrol_origin; resume spotted if player reappears
```

Key details:
- `_can_see_player()`: range check + LOS raycast (excludes self + player)
- Two ranges: `sight_range` (unalerted) and `alerted_sight_range` (SPOTTED/RETURNING)
- `_last_known_pos` updated every physics frame while player is visible (not just per loop)
- Exit SPOTTED when: `_should_return()` (too far from path) OR `_at_last_known_pos()` (reached LKP, player gone)
- Always navigates back to patrol path after exiting SPOTTED

#### `EnemyDebugOverlay`

`top_level = true` Node2D (escapes ysort). Toggled via `EnemyBase.show_debug`. Draws:
- Cyan circle: unalerted `sight_range`
- Orange circle: `alerted_sight_range` (when different)
- Yellow dots + lines: waypoint path with current target highlighted
- Red dot + line: last known player position (LKP)
- State label centred above enemy

### 7. Melee System (`scripts/weapons/melee_weapon.gd`)

**`MeleeWeapon`** extends `Weapon`. Each attack runs through four states: `WINDUP → ACTIVE → RECOVERY → IDLE`.

**`SwingData`** (`Resource`) — one entry per combo step:

| Property | Description |
|---|---|
| `windup_time / active_time / recovery_time` | Phase durations |
| `arc_range / arc_angle` | Hit detection circle radius and cone half-angle |
| `damage / knockback_force` | Per-swing values |
| `move_scale / rotation_scale` | Multiplier applied to player move speed and aim-steer speed during swing |
| `swing_sound / swipe_fx_scene` | Audio and visual FX |

**Combo chain:** During ACTIVE or RECOVERY, another `fire()` call sets `_pending_swing = true`. When the current ACTIVE window ends, the next swing starts immediately if pending. Up to `swings.size()` consecutive hits; after the last swing the chain resets.

**Hit detection:** `_do_arc_query` runs every tick while ACTIVE. A `CircleShape2D` centered on the muzzle returns all overlapping bodies; the cone angle test (`_swing_direction.angle_to(to_body)`) and optional LOS raycast (`los_mask`) filter the results. Bodies are tracked in `_hit_set` to prevent double-hits per swing.

**Integration with Player:** `player_movement` applies `swing_move_scale()` to SPEED. `_update_aim` applies `swing_rotation_scale()` as an exponential-decay lerp coefficient so the aim can't snap freely while swinging. `can_switch()` returns false during WINDUP.

### 8. Projectile System (`scripts/weapons/bullet.gd`)

`Area2D`. Manual cast-motion physics via cached `PhysicsShapeQueryParameters2D`. Shot ID deduplication prevents multi-pellet hits triggering multiple flash/sound/FX on the same target. `BulletTrail` (`Line2D`, `top_level = true`) follows bullet and detaches at impact with final point added.

### 9. Impact Effect System

**`ImpactFXData`** (`Resource`): `scene`, `animation_name`, `sound`, `offset`, `scale`. `spawn(position, process_mode)` parents to `current_scene`.

### 10. Ammo System

**`AmmoType`** (`Resource`): `max_capacity`, `icon`. Shared `.tres` instance = shared pool between weapons. Player initialises `_ammo` dict from all equipped weapons at `_ready`. Enemies have infinite ammo (`has_ammo` base returns `true`).

### 11. Pickup System

**`PickupData`** (`Resource`): `scene`, `ammo_type`, `pickup_sound`, `pickup_texture`, `offset`, `scale`. `spawn(position, amount)` instances the pickup scene into `ysort` group.

**`Pickup`** (extends Area2D): `body_entered` triggers `player.add_ammo(data.ammo_type, amount)`, plays sound, and calls `queue_free`. Configured with a `preset_pickup_data` export so pickups can be dropped at runtime without requiring a separate scene per ammo type.

### 12. HUD

Connects to `player.health_changed`, `player.weapon_changed`, `player.ammo_changed` signals via `"player"` group. Hearts: `Heart` nodes in `HBoxContainer`, value 0–2. Weapon display: icon texture. Ammo display: count per `AmmoType`.

---

## Input Map

| Action | Keyboard/Mouse | Gamepad |
|---|---|---|
| `move_left/right/up/down` | WASD | Left Stick |
| `shoot` | LMB | RT |
| `aim_*` | — | Right Stick |
| `weapon_next/prev` | Scroll | Y Button |

---

## Engineering Philosophy

**Fail loudly on bad setup.** Missing scene dependencies crash immediately with a clear `assert` message. A null guard is only appropriate when the absent value is a genuinely valid runtime state (e.g. optional audio stream, optional impact fx).

**init() before add_child.** Nodes that need data at `_ready` time (Grenade, BulletTrail) receive it via an `init()` call before being added to the scene tree.

**Single velocity setter.** `EnemyBase._physics_process` is the only place that assigns `velocity` — behavior objects write to it via `execute()`, knockback takes priority. This prevents coroutine/physics races.

---

## Current State

| Area | Status |
|---|---|
| Player movement & aiming | Complete |
| Mouse + gamepad input switching | Complete |
| Weapon system (single/auto/burst/shotgun) | Complete |
| Grenade system | Complete |
| Ammo system | Complete |
| Bullet trails | Complete |
| Aim assist (gamepad) | Complete |
| Impact effects | Complete |
| 8-directional animation | Complete |
| Camera shake, zoom, spring | Complete |
| Player health, damage, death, invulnerability | Complete |
| Hit stop | Complete |
| Enemy base (health, damage, death, knockback) | Complete |
| Enemy directional animations | Complete (via DirectionalAnimData) |
| Enemy behavior system (coroutine + behavior objects) | Complete |
| Enemy patrol / LOS / spotted / return | Complete |
| Enemy pathfinding (NavigationAgent2D) | Complete |
| Enemy weapons | Implemented, not configured |
| HUD (health, weapon icon) | Basic |
| Ammo HUD | Implemented, needs wiring |
| Melee combat (MeleeWeapon, SwingData) | Implemented — windup/active/recovery, combo chain, arc query, LOS |
| Multiple room / level design | Single test room |
| Game states (menu, pause, game over) | Not implemented |
| Audio bus / mixing | Not implemented |
| Save / load | Not implemented |

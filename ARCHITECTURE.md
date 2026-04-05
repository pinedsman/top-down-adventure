# Top Down Adventure — Architecture

## Project Overview

A top-down action shooter built in Godot 4.6. The player fights through an infinite sequence of rooms, each containing enemy waves. A persistent outer scene (`game.tscn`) manages room loading and wave sequencing; room scenes are loaded and freed dynamically. The game features a data-driven weapon system, melee combos, dash, ranged/melee enemies, and camera feedback.

**Engine:** Godot 4.6 (Forward Plus renderer, Jolt Physics, Direct3D 12)
**Resolution:** 1280×960 display, 640×480 internal (2× scale)
**Main scene:** `scenes/game.tscn`

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
│   ├── rooms/                # RoomData, WaveSetData, WaveData, EnemyEntry resources
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
│   ├── game.tscn             # Persistent outer scene — always loaded
│   ├── enemy.tscn
│   ├── bullet.tscn
│   └── MuzzleFlash.tscn
└── scripts/
    ├── character_base.gd          # Shared base for Player and EnemyBase
    ├── player.gd                  # extends CharacterBase
    ├── dash_data.gd               # Resource: dash speed/duration/cooldown/steering
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
    ├── pickup.gd
    ├── pickup_data.gd
    ├── swipe_fx.gd
    ├── enemy/
    │   ├── enemy_base.gd
    │   ├── enemy_patrol_base.gd
    │   ├── enemy_debug_overlay.gd
    │   ├── behaviors/
    │   │   ├── enemy_behavior.gd
    │   │   ├── idle_behavior.gd
    │   │   ├── chase_player_behavior.gd
    │   │   ├── move_to_point_behavior.gd
    │   │   ├── rotate_toward_player_behavior.gd
    │   │   ├── navigate_to_player_behavior.gd
    │   │   ├── navigate_to_point_behavior.gd
    │   │   └── navigate_to_spotted_target_behavior.gd
    │   └── types/
    │       ├── enemy_slime.gd     # extends EnemyPatrolBase — melee charger
    │       └── enemy_grunt.gd     # extends EnemyPatrolBase — ranged burst shooter
    ├── room/
    │   ├── coroutine_guard.gd     # RefCounted: version-stamped cancellable waits
    │   ├── enemy_entry.gd         # Resource: enemy_scene, point_cost, weight
    │   ├── flag_group.gd          # Resource: incompatible flag set
    │   ├── player_state.gd        # Resource: transient health/weapon snapshot
    │   ├── room_data.gd           # Resource: scene, flags, incompatible_flags
    │   ├── room_flag.gd           # Resource: flag_id, enabled, description
    │   ├── room_manager.gd        # Node: spawns/tracks enemies, runs waves
    │   ├── wave_data.gd           # Resource: point_budget, spawn_pool, escalation_curve
    │   ├── wave_mode_manager.gd   # Node (game.tscn child): orchestrates room/wave loop
    │   ├── wave_overlay.gd        # CanvasLayer: fade/splash screens
    │   └── wave_set_data.gd       # Resource: ordered Array[WaveData]
    ├── ui/
    │   ├── hud.gd
    │   ├── heart.gd
    │   └── weapon_display.gd
    └── weapons/
        ├── weapon_data.gd
        ├── weapon.gd
        ├── weapon_slot_data.gd    # Resource: weapon_data + input_action string
        ├── melee_weapon_data.gd
        ├── melee_weapon.gd
        ├── swing_data.gd
        ├── bullet.gd
        ├── bullet_trail.gd
        ├── ammo_type.gd
        ├── grenade.gd
        └── grenade_data.gd
```

---

## Scene Hierarchy

### `game.tscn` (persistent outer scene — always loaded)

```
Node2D
├── WaveModeManager (wave_mode_manager.gd)   # orchestrates room/wave loop
│   └── RoomContainer (Node2D)              # room scenes instantiated here
├── Player (Player.tscn)                    # group: player — persists across rooms
└── HUD (CanvasLayer)                       # group: hud
    ├── HBoxContainer                       # Heart containers
    ├── WeaponDisplay
    ├── Crosshair (Node2D)                  # group: crosshair
    └── WaveOverlay (wave_overlay.gd)       # fade/splash CanvasLayer
```

### Room scene (loaded/freed per room)

```
Node2D (room root)
├── Ground (TileMapLayer)        # group: ground_tilemap — tilemap bounds fallback
├── NavigationRegion2D
├── CameraBounds (Area2D)        # group: camera_bounds — RectangleShape2D child
├── ySort (Node2D)               # group: ysort — player reparented here on room load
│   ├── 2ndFloor (TileMapLayer)
│   ├── Walls (TileMapLayer)
│   └── Enemy × N               # group: enemies — spawned at runtime
├── SpawnPoint × N (Marker2D)    # group: spawn_points
├── PlayerSpawn (Marker2D)       # group: player_spawn
└── ExitDoorBlocker × N          # group: exit_door_blocker — freed on room clear
```

### `Player.tscn`

```
CharacterBody2D (player.gd)
├── AnimatedSprite2D
├── WallCollision (CollisionShape2D)
├── Muzzle (Marker2D)
│   └── LaserSight (Line2D)
├── MuzzleBehind (Marker2D)
└── Camera2D (camera_controller.gd)   # group: camera
```

### `enemy.tscn`

```
CharacterBody2D (EnemySlime / EnemyGrunt)
├── AnimatedSprite2D
├── CollisionShape2D
└── NavigationAgent2D
```

---

## Autoload Singletons

| Name | Script | Responsibility |
|---|---|---|
| `AudioPool` | `scripts/audio_pool.gd` | Round-robin `AudioStreamPlayer2D` pool. `play(stream, position, ignore_pause)` swaps stream and sets `PROCESS_MODE_ALWAYS` when `ignore_pause` to survive `HitStop` pauses. |
| `HitStop` | `scripts/hit_stop.gd` | Pauses the scene tree for a real-time duration. Multiple concurrent `request(duration)` calls are merged — tree stays paused until the longest expires. Uses `Time.get_ticks_usec` and real-time timers internally. Emits `ended`. |
| `InputManager` | `scripts/input_manager.gd` | Tracks active input device (gamepad vs MKB). Emits `input_mode_changed(is_gamepad)`. Filters joypad axis noise below `STICK_DEADZONE = 0.2`. |
| `DebugDraw` | `scripts/debug_draw.gd` | Global `add_line` / `add_circle` with TTL fade. Auto-parents to `hud` CanvasLayer. Skips `queue_redraw` when empty. |

---

## Core Systems

### 1. Character Hierarchy

```
CharacterBase (character_base.gd)   — health, damage, death, hit flash, knockback, weapons, animation data
├── Player (player.gd)              — input, camera, aim, laser, crosshair, invulnerability, ammo, dash
└── EnemyBase (enemy/enemy_base.gd) — contact damage, knockback scale, behavior API, move_speed
    └── EnemyPatrolBase             — patrol/spotted/returning FSM, LOS detection, waypoints
        ├── EnemySlime              — overrides _spotted_behavior(): charge-melee
        └── EnemyGrunt              — overrides _spotted_behavior(): approach, burst fire, reposition
```

**`CharacterBase`** holds the shared contract:
- `max_health`, `_health`, `health_changed` signal
- `take_damage(amount, knockback_direction, impact_position, shot_id)`
- `die()` — disables physics/collision, virtual `_on_die()`
- `weapons: Array[WeaponData]`, `_weapon_instances: Array[Weapon]` (created at ready)
- `anim_data: DirectionalAnimData`, `_facing: Vector2`
- `has_ammo(w: Weapon) -> bool` — returns `true` by default; Player overrides

### 2. Player Controller (`scripts/player.gd`)

**Aiming:** Mouse or gamepad right stick. Aim assist scans an `Area2D` for enemies within `weapon.aim_assist_angle`.

**Shooting (primary weapon):** SINGLE/BURST/AUTO modes via `_weapon_index` slot. `_fire_held` corrected on `HitStop.ended`. Primary fire is blocked while any melee slot is actively swinging (`_slot_blocking_fire()`).

**Weapon Slots:** `@export var weapon_slots: Array[WeaponSlotData]` — each slot pairs a `WeaponData` with an `input_action` string. At `_ready`, one `Weapon` instance is created per slot into `_slot_instances`. Slots fire independently from the primary weapon via `_unhandled_input`. See §4 Weapon System.

**Dash:** Triggered by `dash` action. `DashData` resource configures speed, duration, cooldown, invincibility, and steering. During a dash, `_apply_dash_steering()` decomposes movement input into lateral (perpendicular to dash) and medial (counter-dash only) components, scaled by `DashData.control_curve` sampled at dash progress. The player regains more steering control as the dash nears completion.

**Ammo:** Player holds `_ammo: Dictionary` (AmmoType → int). `has_ammo(w)` gates all fire paths.

**Contact damage:** After `move_and_slide`, iterates slide collisions; calls `take_damage` if collider is `EnemyBase` with `contact_damage > 0`.

**Camera:** Spring shake in impact direction (exponential damping) + zoom punch. Both use `TWEEN_PAUSE_PROCESS` to survive `HitStop`.

**State persistence:** `save_to_state() -> PlayerState` and `restore_from_state(state)` snapshot/restore health, weapons, and ammo for room transitions.

### 3. Animation System (`DirectionalAnimData`)

| Class | Role |
|---|---|
| `AnimationEntry` | One direction: animation name, flip, muzzle offset, bullet-behind flag |
| `AnimationState` | Groups N `AnimationEntry` for one logical state (idle, walk, death…) |
| `DirectionalAnimData` | Array of `AnimationState`; O(1) Dictionary cache; `get_entry(state, dir_index)` |

`direction_to_index(Vector2, direction_count) -> int` is static on `DirectionalAnimData`.

### 4. Weapon System

Separates configuration (`WeaponData` Resource) from runtime state (`Weapon` RefCounted) so the same `.tres` can be shared across multiple characters.

**`WeaponData`** (`Resource`) — pure configuration.

| Property | Description |
|---|---|
| `fire_mode` | SINGLE / AUTO / BURST |
| `ammo_type` | `AmmoType` resource; `null` = infinite |
| `pellet_count / spread_angle` | Shotgun-style multi-pellet |
| `bullet_trail_scene` | `PackedScene` for `BulletTrail` |
| `grenade_data` | If set, `fire()` throws a grenade |
| `aim_assist_angle/range/strength` | Per-weapon gamepad aim assist |
| `fire_shake_strength` | Camera shake on fire |
| `suppress_wall_impacts` | Skip wall impact FX |
| `bullet_collision_mask` | Physics layer mask applied to spawned bullets' hit detection |

**`Weapon`** (`RefCounted`) — runtime instance created by `WeaponData.create_instance()`. Holds `_cooldown`, `_burst_remaining`, `_shot_counter`, `fired` signal. Data properties read-through to `WeaponData`.

**`WeaponSlotData`** (`Resource`) — pairs a `WeaponData` with an `input_action` string. `Player.weapon_slots: Array[WeaponSlotData]` supports any number of dedicated slots (e.g. melee on `"melee"` action, grenade on `"grenade"` action). Slot weapons fire independently from primary weapon scrolling.

**`MeleeWeaponData`** extends `WeaponData` — adds `swings: Array[SwingData]`, `los_mask`, `debug_draw_arc`. `create_instance()` returns a `MeleeWeapon`.

**`MeleeWeapon`** extends `Weapon` — see §7 Melee System.

Shot ID system: each `fire()` call increments a counter. All pellets from one shot share the same `shot_id`. Same-shot hits accumulate knockback only.

### 5. Grenade System

**`GrenadeData`** (`Resource`) — all configuration grouped by export groups: Fuse, Explosion, Bounce, Radius Indicator, Pre-Explode.

**`Grenade`** (`CharacterBody2D`) — thrown projectile with fuse, bounce, explosion radius, LOS per-target, optional self-damage. `init(data, direction, speed, thrower, shot_id)` called before `add_child`.

### 6. Enemy Behavior System

#### `EnemyBase` Behavior API

```gdscript
run_behavior(b: EnemyBehavior, duration: float) -> Signal
navigate_toward_player(duration: float) -> Signal
rest(duration: float) -> Signal
face(direction: Vector2) -> void
shoot_weapon(index: int, target_pos: Vector2) -> void
is_alive() -> bool
player_position() -> Vector2
```

`_run_behavior()` is a virtual async method started detached in `_ready`. Subclasses override to define sequences using `await`.

#### `EnemyPatrolBase` FSM

Three states: `PATROL → SPOTTED → RETURNING → PATROL`.

- `PATROL`: navigate waypoints; `_navigate_interruptible` breaks when player spotted
- `SPOTTED`: run `_spotted_behavior()` loop; navigate toward player or LKP when not visible
- `RETURNING`: navigate back to origin; resume SPOTTED if player reappears

`_navigate_interruptible(target, timeout)` is a frame-by-frame nav loop with an optional timeout. Subclasses can extend it with a `stop_condition` callable.

#### `EnemyGrunt` (`scripts/enemy/types/enemy_grunt.gd`)

Ranged burst shooter. `_spotted_behavior()` sequence:
1. `_navigate_to_shoot_range()` — approach until within `shoot_range`
2. Wind up (`wind_up` seconds), then `_fire_burst()` — N shots with random arc spread; each shot bypasses weapon cooldown so `shot_interval` is authoritative
3. Post-burst pause (`post_burst_wait_min/max`)
4. Randomly reposition (`reposition_chance`) or fire again; always reposition if player not visible

Key exports: `shoot_range`, `preferred_distance`, `shot_count`, `arc_angle`, `wind_up`, `shot_interval`, `post_burst_wait_min/max`, `reposition_chance`, `reposition_angle_min/max`, `reposition_wait_min/max`.

#### `EnemyDebugOverlay`

`top_level = true` Node2D. Draws sight radii, waypoint path, LKP, state label.

### 7. Melee System (`scripts/weapons/melee_weapon.gd`)

**`MeleeWeapon`** extends `Weapon`. Each attack: `WINDUP → ACTIVE → RECOVERY → IDLE`.

**`SwingData`** (`Resource`):

| Property | Description |
|---|---|
| `windup_time / active_time / recovery_time` | Phase durations |
| `arc_range` | Ellipse major axis (forward reach) |
| `arc_angle` | Cone half-angle for arc clipping |
| `arc_width` | Ellipse minor axis (lateral reach); `0` = circular (arc_range for both axes) |
| `damage / knockback_force` | Per-swing values |
| `move_scale / rotation_scale` | Speed multipliers during swing |
| `swing_sound / swipe_fx_scene` | Audio and visual FX |

**Hit detection:** `_do_arc_query` runs every tick while ACTIVE. A `CircleShape2D` (radius = `max(arc_range, arc_width)`) returns overlapping bodies. Each candidate is filtered by:
1. Cone angle test: `_swing_direction.angle_to(to_body) <= arc_angle`
2. Ellipse test: `(fd/arc_range)² + (sd/arc_width)² <= 1.0` where `fd`/`sd` are forward/side dot products
3. Optional LOS raycast (`los_mask`)

Bodies are tracked in `_hit_set` to prevent double-hits per swing.

**Combo chain:** During ACTIVE or RECOVERY, another `fire()` sets `_pending_swing = true`. Next swing starts immediately when current ACTIVE ends. Resets after `swings.size()` hits.

**Integration with Player:** `_slot_blocking_fire()` returns `true` while any slot's `MeleeWeapon.is_swinging()` is true, gating primary weapon fire. `player_movement` applies `swing_move_scale()`. `_update_aim` applies `swing_rotation_scale()` as exponential-decay lerp coefficient.

### 8. Projectile System (`scripts/weapons/bullet.gd`)

`Area2D`. Manual cast-motion physics via cached `PhysicsShapeQueryParameters2D`. `hit_mask` property (set from `WeaponData.bullet_collision_mask`) applied to all three queries (`_cast_query`, `_rest_query`, `_hit_query`). Shot ID deduplication prevents multi-pellet hits triggering multiple flash/sound/FX on the same target. `BulletTrail` follows bullet and detaches at impact.

### 9. Camera System (`scripts/camera_controller.gd`)

Extends `Camera2D`. **Bounds** are read from an `Area2D` node in the `"camera_bounds"` group that has a `CollisionShape2D` child with a `RectangleShape2D`. Fallback: uses the `"ground_tilemap"` TileMapLayer extents.

`refresh_limits(room_root: Node = null)` re-reads bounds, filtering by ancestor to avoid stale nodes from freed room scenes. Called by `WaveModeManager` after each room load.

**Shake:** Spring-style directional shake via `Tween` with `TWEEN_PAUSE_PROCESS`. **Zoom punch:** zoom-in/out tween also with `TWEEN_PAUSE_PROCESS`, both survive `HitStop`.

### 10. Impact Effect System

**`ImpactFXData`** (`Resource`): `scene`, `animation_name`, `sound`, `offset`, `scale`. `spawn(position, process_mode)` parents to `current_scene`.

### 11. Ammo System

**`AmmoType`** (`Resource`): `max_capacity`, `icon`. Shared `.tres` instance = shared pool between weapons using the same type. Player initialises `_ammo` from all equipped weapons at `_ready`. Enemies have infinite ammo.

### 12. Pickup System

**`PickupData`** (`Resource`): `scene`, `ammo_type`, `display_name`, `pickup_sound`, `pickup_texture`, `offset`, `scale`. `spawn(position, amount) -> Pickup` instances into `ysort` group.

**`Pickup`** (extends `Interactable`): Player-initiated via `interact(player)`. Calls `player.add_ammo`, plays sound, frees itself. `get_prompt_text(player)` returns `"<name> x<amount>"` or `"<name> Full"` based on current ammo.

### 13. Weapon Ability System

**`WeaponAbility`** (`Resource`) — base class for custom weapon behaviour. Virtual hooks:

| Hook | When called |
|---|---|
| `can_execute(shooter, weapon) -> bool` | Before firing/charging starts. Return `false` to block. |
| `on_fire_prevented(shooter, weapon)` | When `can_execute` returned `false`. |
| `on_charge_cancelled(shooter, weapon)` | When charge is cancelled before firing. |
| `execute(shooter, weapon, charge)` | On fire; `charge` is 0–1. |

**`HealAbility`** extends `WeaponAbility`. `can_execute` blocks when shooter is at full health. `execute` calls `character.heal(heal_amount)`. `on_fire_prevented` plays a denial sound. `on_charge_cancelled` refunds one ammo.

If `WeaponData.ability` is set, `_fire_with_charge` routes to `ability.execute()` instead of spawning bullets/grenades.

---

### 14. Charge Weapon System

Enabled when `WeaponData.charge_time > 0.0`. Three modes via `ChargeMode` enum:

| Mode | Behaviour |
|---|---|
| `HOLD_TO_CHARGE_FIRE_ON_RELEASE` | Release button fires (or cancels if not full and `fire_on_partial_charge` is false). |
| `HOLD_TO_CHARGE_AUTOFIRE` | Fires automatically when full; hold is optional. |
| `AUTO_CHARGE` | Charges on its own; fires automatically when full. Button input ignored. |

**Charge state on `Weapon`:** `_is_charging`, `_charge` (0–1), `_charge_muzzle`, `_charge_direction`, `_charge_shooter`. `start_charge` / `release_charge` / `cancel_charge` / `_execute_charge_fire`.

**Charge FX:** `WeaponData.charge_fx_scene` spawned as a child of the muzzle while charging; `WeaponData.charge_loop_sound` played via `AudioStreamPlayer2D` on the muzzle.

**Charge bar UI:** `ChargeBar` (CanvasLayer in HUD) follows the player via `get_viewport().get_canvas_transform()`. Polled every frame by `hud.gd` via `player.get_charging_weapon()`.

**Movement/aim slow:** `WeaponData.charge_move_speed_scale` and `charge_turn_speed_scale` (both 0–1) applied in `player.gd` while charging.

**Blocking:** `WeaponData.blocks_other_weapons` / `blocks_dash` — while charging, `is_blocking()` / `is_blocking_dash()` return `true`. `Player._slot_blocking_fire()` checks all slot instances; primary fire and dash are gated behind it.

---

### 15. Wave/Room System

The game runs an infinite loop of rooms with enemy waves. A persistent outer scene (`game.tscn`) contains `WaveModeManager`; room scenes are loaded into `RoomContainer` and freed on completion.

#### Scene groups contract

| Group | Who uses it |
|---|---|
| `"player"` | WaveModeManager (find persistent player to reparent) |
| `"ysort"` | WaveModeManager (reparent destination), RoomManager (spawn target), Weapon (bullet/grenade parent) |
| `"player_spawn"` | WaveModeManager (position player on room load) |
| `"camera"` | WaveModeManager (call `refresh_limits`) |
| `"camera_bounds"` | CameraController (read room rect) |
| `"spawn_points"` | RoomManager (random enemy spawn positions; occupancy-checked before use) |
| `"reward_spawn"` | WaveModeManager (wave reward pickup positions; `Node2D` markers placed by designers) |
| `"enemies"` | Added to spawned enemies; debug kill-all uses this |
| `"exit_door_blocker"` | RoomManager.unlock_exit() — freed on room clear |
| `"interactable"` | Player (scans for nearby interactables each frame) |

#### Resources

| Resource | Key fields |
|---|---|
| `RoomData` | `scene: PackedScene`, `flags: Array[RoomFlag]`, `incompatible_flags: Array[FlagGroup]` |
| `WaveSetData` | `waves: Array[WaveData]` |
| `WaveData` | `point_budget`, `spawn_pool: Array[EnemyEntry]`, `guaranteed_spawns`, `escalation_curve: Curve` |
| `EnemyEntry` | `enemy_scene: PackedScene`, `point_cost: int`, `weight: float` |
| `RoomFlag` | `flag_id: String`, `enabled: bool`, `description: String` |
| `FlagGroup` | `flags: Array[String]` — incompatible flag set |
| `PlayerState` | Transient snapshot: `health`, `weapons`, `weapon_index`, `ammo` |

#### `WaveModeManager` (`scripts/room/wave_mode_manager.gd`)

Regular Node child of `game.tscn`. Owns `rooms: Array[RoomData]` and `wave_sets: Array[WaveSetData]` as separate pools. Each run iteration pairs them by `_run_index % pool.size()` — since index never resets, the run is infinite even with small pools.

**Loop per room:**
1. `_pick_room()` + `_pick_wave_set()` by modulo index
2. Validate incompatible flags (`push_error` and abort on conflict)
3. Free previous room scene, instantiate new one into `RoomContainer`
4. Reparent persistent player into new room's `ysort` node; position at `player_spawn`
5. Call `camera.refresh_limits(room_scene)`
6. Create `RoomManager`, call `room_manager.init(room_data, wave_set.waves, room_scene)`
7. Run `_run_wave_sequence`: fade in → "Wave N" splash → per-wave spawn+clear loop → "Wave Complete" → spawn rewards → wait for pickup → fade out → unlock exit → advance index → repeat

**Wave rewards:** After the last wave completes, `_spawn_wave_rewards()` finds all `Node2D` nodes in the `"reward_spawn"` group that are descendants of the current room scene. They are sorted left-to-right; up to 3 are used. Assignment: 1 marker = health only; 2 markers = health + weapon; 3+ markers = weapon | health | weapon. `_wait_for_one_reward_pickup(rewards)` connects to `tree_exiting` on each reward; whichever is picked up first triggers cleanup of the rest and unblocks the coroutine. Exports: `reward_health_pickup: PickupData`, `reward_health_amount: int`, `reward_weapon_pool: Array[WeaponData]`.

#### `RoomManager` (`scripts/room/room_manager.gd`)

Added as a child of the room scene root at runtime. Public API:
- `init(room_data, waves, room_root)` — stores refs, creates `CoroutineGuard`, applies flags
- `wave_count() -> int`
- `run_wave(index)` — spawns enemies with escalation delay, awaits all dead, emits `wave_cleared`
- `unlock_exit()` — frees `exit_door_blocker` nodes in this room

**Flag application:** For each `RoomFlag`, finds nodes in group `flag.flag_id` that are descendants of `_room_root`, sets `visible` and `process_mode`.

**Enemy spawning:** `_build_spawn_list` fills guaranteed spawns then budget-weighted random picks. `_spawn_enemy(scene) -> bool` (async) waits until a spawn point has no living enemy within `SPAWNER_CLEAR_RADIUS = 24.0` pixels, then instantiates into `ysort`, adds to `"enemies"` group, connects `tree_exited` → `_on_enemy_removed`. Returns `false` if the `CoroutineGuard` version changed (wave cancelled) while waiting for a free spawner.

**Escalation delay:** `wave.escalation_curve.sample(progress)` if set; else `lerpf(2.0, 0.3, progress)` — faster spawning as wave fills.

#### `WaveOverlay` (`scripts/room/wave_overlay.gd`)

`CanvasLayer`. All visuals driven by named `AnimationPlayer` animations (`fade_in`, `fade_out`, `wave_intro`, `wave_complete`). Script only sets `WaveLabel.text` and calls `_anim.play(name)`. Artists edit animations without touching code. Same label is reused for all messages.

#### `CoroutineGuard` (`scripts/room/coroutine_guard.gd`)

`RefCounted`. Version counter incremented on `start()` / `cancel()`.
- `wait(duration) -> bool` — awaits a timer, returns `true` only if version unchanged
- `snapshot() -> int` — captures current version without waiting
- `is_valid(version) -> bool` — checks whether a snapshot is still current; used by `_spawn_enemy` to bail out of frame-by-frame spawner waits without a timer

### 16. HUD

Connects to `player.health_changed`, `player.weapon_changed`, `player.ammo_changed`, `player.interactable_focused` via the `"player"` group. Lives in `game.tscn` (persistent — not recreated per room).

**InteractPrompt** (`scripts/ui/interact_prompt.gd`, CanvasLayer child of HUD): shown/hidden by `_on_interactable_focused`. Follows the interactable's world position each frame via `get_viewport().get_canvas_transform()`.

**ChargeBar** (`scripts/ui/charge_bar.gd`, CanvasLayer child of HUD): polled every frame — visible when `player.get_charging_weapon()` is non-null. Follows the player's world position via canvas transform. Offset `ABOVE_OFFSET = Vector2(0, -28)` positions it above the player.

---

## Input Map

| Action | Keyboard/Mouse | Gamepad |
|---|---|---|
| `move_left/right/up/down` | WASD | Left Stick |
| `shoot` | LMB | RT |
| `dash` | Space / Shift | LB |
| `melee` | RMB (or configurable) | — |
| `aim_*` | — | Right Stick |
| `weapon_next/prev` | Scroll | Y Button |

Slot `input_action` strings are set per `WeaponSlotData` resource — no hardcoded bindings in code.

---

## Engineering Philosophy

**Fail loudly on bad setup.** Missing scene dependencies crash immediately with a clear `assert`. Null guards only where absent value is a genuinely valid runtime state.

**init() before add_child.** Nodes that need data at `_ready` time (Grenade, BulletTrail, RoomManager) receive it via `init()` before being added to the scene tree.

**Single velocity setter.** `EnemyBase._physics_process` is the only place that assigns `velocity`. Behavior objects write to it via `execute()`; knockback takes priority. This prevents coroutine/physics races.

**Rooms and waves are independent data pools.** `RoomData` owns physical layout; `WaveSetData` owns enemy config. `WaveModeManager` pairs them by index, enabling mix-and-match without duplicating either.

---

## Current State

| Area | Status |
|---|---|
| Player movement & aiming | Complete |
| Dash with steering control | Complete |
| Mouse + gamepad input switching | Complete |
| Weapon system (single/auto/burst/shotgun) | Complete |
| Dedicated weapon slots (WeaponSlotData) | Complete |
| Grenade system | Complete |
| Ammo system | Complete |
| Bullet trails | Complete |
| Per-weapon bullet collision mask | Complete |
| Aim assist (gamepad) | Complete |
| Impact effects | Complete |
| 8-directional animation | Complete |
| Camera shake, zoom, spring | Complete |
| Camera bounds via Area2D | Complete |
| Player health, damage, death, invulnerability | Complete |
| Hit stop | Complete |
| Melee combat (combo chain, arc query, LOS) | Complete |
| Melee ellipse hitbox (arc_width) | Complete |
| Enemy base (health, damage, death, knockback) | Complete |
| Enemy directional animations | Complete |
| Enemy behavior system (coroutine + behavior objects) | Complete |
| Enemy patrol / LOS / spotted / return | Complete |
| Enemy pathfinding (NavigationAgent2D) | Complete |
| EnemyGrunt (ranged burst, reposition) | Complete |
| Wave/room system (infinite run loop) | Complete |
| Room flags (conditional scene elements) | Complete |
| Wave overlay (fade/splash screens) | Complete |
| Player state persistence across rooms | Complete |
| Camera look-ahead (mouse + gamepad) | Complete |
| Weapon pickup sound, dryfire sound, swap sound | Complete |
| Interact prompt UI (follows interactable world pos) | Complete |
| Weapon ability system (`WeaponAbility` resource) | Complete |
| Heal ability (`HealAbility`) | Complete |
| Charge weapon system (hold/auto/fire-on-release) | Complete |
| Charge bar UI | Complete |
| Blocking system (`is_blocking`, `is_blocking_dash`) | Complete |
| Ammo pickups as interactables | Complete |
| Wave reward spawning (3 pickups, designer-placed markers) | Complete |
| Spawner occupancy check (no enemy on top) | Complete |
| HUD (health, weapon icon, ammo, interact prompt) | Complete |
| Enemy weapons (non-grunt) | Implemented, not configured |
| Game states (menu, pause, game over) | Not implemented |
| Audio bus / mixing | Not implemented |
| Save / load | Not implemented |

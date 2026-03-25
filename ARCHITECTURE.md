# Top Down Adventure — Architecture

## Project Overview

A top-down action shooter built in Godot 4.6. The player navigates a tiled level, aims with mouse or gamepad, and shoots enemies using a data-driven weapon system. Currently a prototype with movement, shooting, impact effects, enemy combat, health/damage, camera feedback, and a basic HUD.

**Engine:** Godot 4.6 (Forward Plus renderer, Jolt Physics, Direct3D 12)
**Resolution:** 1280×960 display, 640×480 internal (2× scale)
**Main scene:** `scenes/main.tscn`

---

## Directory Structure

```
top-down-adventure/
├── assets/
│   ├── Art/
│   │   ├── Tileset/          # Ground, wall, prop, plant, shadow tiles
│   │   ├── crosshair.png
│   │   ├── impact.png        # Shared impact sprite sheet
│   │   ├── hitimpact.png
│   │   ├── laser.png
│   │   └── muzzleflash.png
│   ├── Characters/
│   │   ├── Slime1/           # Attack, Death, Hurt, Idle, Run, Walk
│   │   ├── Slime2/
│   │   ├── Slime3/
│   │   └── Temp/             # Player sprites (Idle, Walk, Death, Hit)
│   └── Sounds/
│       ├── handgun_shoot.mp3
│       ├── impact.mp3
│       ├── rock_impact.mp3
│       └── slime_death.mp3
├── resources/
│   ├── anim_data.tres        # Player animation configuration
│   ├── weapon_default.tres   # Handgun weapon definition
│   ├── tilesets/
│   │   └── grassy.tres       # Tileset with custom impact_fx_data
│   └── impacts/
│       ├── flesh_impact.tres
│       └── rock_impact.tres
├── scenes/
│   ├── player/
│   │   └── Player.tscn
│   ├── impacts/
│   │   ├── impactFX.tscn     # Generic impact effect
│   │   └── stone.tscn        # Stone impact variant
│   ├── main.tscn
│   ├── enemy.tscn
│   ├── bullet.tscn
│   └── MuzzleFlash.tscn
└── scripts/
    ├── player.gd
    ├── enemy.gd
    ├── player_animation.gd
    ├── animation_state.gd
    ├── animation_entry.gd
    ├── debug_draw.gd         # Autoload: DebugDraw
    ├── audio_pool.gd         # Autoload: AudioPool
    ├── hit_stop.gd           # Autoload: HitStop
    ├── input_manager.gd      # Autoload: InputManager
    ├── impact_fx.gd
    ├── impact_fx_data.gd
    ├── muzzleflash.gd
    └── weapons/
        ├── weapon.gd
        └── bullet.gd
```

---

## Scene Hierarchy

### `main.tscn` (root)

```
Node2D
├── Ground (TileMapLayer)          # Base ground layer; group: ground_tilemap
│                                  # Used to compute camera bounds
├── ySort (Node2D)                 # Y-sorted for correct depth ordering; group: ysort
│   ├── 2ndFloor (TileMapLayer)    # Elevated tile layer
│   ├── Walls (TileMapLayer)       # Wall tiles with collision
│   ├── Player (Player.tscn)       # group: player
│   └── Enemy × N (enemy.tscn)
└── HUD (CanvasLayer)              # group: hud
    ├── HBoxContainer              # Heart containers
    ├── WeaponDisplay              # Current weapon icon
    └── Crosshair (Node2D)         # group: crosshair — follows mouse cursor
```

### `Player.tscn`

```
CharacterBody2D
├── AnimatedSprite2D               # 8-directional idle/walk/hit/death animations
├── WallCollision (CollisionShape2D, CapsuleShape2D)
├── Muzzle (Marker2D)              # Bullet spawn origin (foreground shots)
│   └── LaserSight (Line2D)        # Reparented here when shooting forward
├── MuzzleBehind (Marker2D)        # Bullet spawn origin (behind-player shots)
│   └── LaserSight (Line2D)        # Reparented here when shooting backward
└── Camera2D                       # Follows player; limits from ground tilemap
```

> `LaserSight` is dynamically reparented between `Muzzle` and `MuzzleBehind` each frame
> based on `_currentAnimEntry.bullet_behind_player`, so it always originates from the
> correct muzzle point without z-index hacks.

### `enemy.tscn`

```
CharacterBody2D
├── AnimatedSprite2D               # idle_down, death_down animations (Slime1)
└── CollisionShape2D
```

### `bullet.tscn`

```
Area2D
├── CollisionShape2D (CircleShape2D)
├── VisibleOnScreenNotifier2D
└── Sprite2D
```

### `impactFX.tscn`

```
Node2D
└── AnimatedSprite2D               # impact_flesh, impact_rock variants
```

---

## Autoload Singletons

| Name | Script | Responsibility |
|---|---|---|
| `AudioPool` | `scripts/audio_pool.gd` | Single round-robin pool of `AudioStreamPlayer2D` nodes shared across all streams. `play(stream, position, ignore_pause)` swaps the stream and plays. `ignore_pause = true` sets `PROCESS_MODE_ALWAYS` so the player fires through a `HitStop` pause. |
| `HitStop` | `scripts/hit_stop.gd` | Pauses the scene tree for a real-time duration. Multiple concurrent `request(duration)` calls are merged — the tree stays paused until the longest request expires. Emits `ended` when unpausing. |
| `InputManager` | `scripts/input_manager.gd` | Tracks active input device (gamepad vs MKB). Switches on any joypad event (button or stick above deadzone) or any keyboard/mouse event. Emits `input_mode_changed(is_gamepad)`. |
| `DebugDraw` | `scripts/debug_draw.gd` | Global `add_line` / `add_circle` with TTL-based fade. Auto-parents to the `hud` CanvasLayer. Skips `queue_redraw` when empty. |

---

## Core Systems

### 1. Player Controller (`scripts/player.gd`)

`CharacterBody2D`. Central node combining movement, aiming, shooting, health, camera feedback, and animation.

**Movement**
- WASD / left stick at `SPEED = 100` units/sec via `Input.get_vector`.
- During `_is_hit`, normal input is blocked and velocity is set to `_knockback_velocity`, which lerps toward zero each frame.

**Aiming**
- Mouse: `get_global_mouse_position() - global_position`, normalised. Updated only when mouse has moved.
- Gamepad: right stick vector, updated only above zero (deadzone handled by `InputManager`).
- Device switches handled via `InputManager.input_mode_changed` signal: crosshair shown for MKB, `LaserSight` shown for gamepad.

**Camera**
- Limits derived from `ground_tilemap` group extents × `tile_set.tile_size` (supports non-square tiles).
- On hit: spring shake in the impact direction (exponential damping), plus a fast zoom-in / slow zoom-out tween. Both use `TWEEN_PAUSE_PROCESS` to run through `HitStop` pauses.

**Health & Damage** (`take_damage(amount, knockback_direction, impact_position)`)
1. Ignored if `_invulnerable`.
2. Decrements `_health`, emits `health_changed`.
3. Plays hurt sound (bypasses hit stop via `ignore_pause`).
4. Starts `_is_hit` state for `hit_duration` seconds (blocks shooting, plays hit animation, applies knockback).
5. Sets `_invulnerable` for `invulnerability_duration` seconds (blinking sprite).
6. White flash tween (`TWEEN_PAUSE_PROCESS`).
7. Spawns `hit_impact_fx` at the contact point (`PROCESS_MODE_ALWAYS`).
8. Camera shake + zoom.
9. `HitStop.request(hit_stop_duration)`.
- On `_is_hit` expiry: if `_health <= 0`, calls `die()`.
- `die()`: disables physics/input/collision, cancels blink, plays death animation and death sound.

**Shooting**
- SINGLE mode: fires on press event in `_unhandled_input`, gated by `not _is_hit`.
- AUTO mode: fires each `_tick_weapon` frame while `_fire_held` and `not _is_hit`.
- Weapon switching: `weapon_next` / `weapon_prev` actions cycle `_weapon_index`.
- `_fire_held` is corrected on `HitStop.ended` in case the release event was missed during a pause.

**Contact Damage**
- After `move_and_slide`, iterates `get_slide_collision_count()`. If any collider is an `Enemy` with `contact_damage > 0`, calls `take_damage` with the collision contact point.

### 2. Animation System

Three resource classes compose the animation lookup:

| Class | File | Role |
|---|---|---|
| `AnimationEntry` | `animation_entry.gd` | Data for one direction: animation name, flip, muzzle offset, bullet z-order flag |
| `AnimationState` | `animation_state.gd` | Groups 8 `AnimationEntry` objects for one logical state (idle, walk, hit, death) |
| `PlayerAnimation` | `player_animation.gd` | Array of `AnimationState`; primary API is `get_entry(state, direction) -> AnimationEntry` |

`PlayerAnimation` builds a `Dictionary` cache (`state_name → AnimationState`) in `_init` and lazily on first `get_entry`/`has_state` call (handles resources loaded from disk before `states` is populated). Lookups are O(1).

`direction_to_index(Vector2) -> int` is a static method on `PlayerAnimation`, available to enemies and any future directional system.

**`AnimationEntry` fields:**

| Field | Type | Description |
|---|---|---|
| `animationIndex` | String | Animation name on `AnimatedSprite2D` |
| `flip` | bool | Horizontal flip for mirrored directions |
| `muzzle_offset` | Vector2 | Muzzle position for this direction |
| `bullet_behind_player` | bool | Whether bullet and laser should originate from `MuzzleBehind` |

`AnimationEntry` is a `@tool` resource with a live muzzle preview and a "Preview Animation" button for in-editor testing.

### 3. Weapon System (`scripts/weapons/weapon.gd`)

Data-driven `Resource`. Multiple weapons can be assigned to `player.weapons: Array[Weapon]`.

| Property | Description |
|---|---|
| `fire_mode` | SINGLE, AUTO, or BURST |
| `fire_rate` | Seconds between shots |
| `damage` | Damage per bullet |
| `bullet_speed` | px/sec (overwrites bullet scene export at spawn) |
| `knockback_force` | Pre-scaled knockback magnitude passed to `take_damage` |
| `bullet_range` | Max travel distance; 0 = infinite |
| `bullet_range_fx` | `ImpactFXData` spawned when the bullet expires at max range |
| `hud_icon` | `Texture2D` shown in the weapon HUD slot |
| `bullet_scene` | Projectile `PackedScene` |
| `shoot_sound` | `AudioStream` played via `AudioPool` |
| `muzzle_flash_scene` | `PackedScene` parented to the muzzle |

`Weapon.fire(muzzle, direction, behind_player)` checks cooldown, plays sound via `AudioPool`, spawns the muzzle flash (z_index adjusted for behind-player), and spawns the bullet into the `ysort` group node.

### 4. Projectile System (`scripts/weapons/bullet.gd`)

`Area2D`. Manual cast-motion physics each frame using `PhysicsShapeQueryParameters2D` (all three query objects cached in `_ready`). Bullets added to the `ysort` group for correct depth sorting.

**Collision flow:**
1. Cast motion in aim direction. If range is finite, clamp motion at remaining range.
2. If hit: get rest info for exact surface point and normal.
3. Skip if collider is `owner_node` (friendly fire prevention).
4. Call `body.take_damage(damage, direction * knockback_force, impact_pos)`.
5. Determine impact data: TileMapLayer → cell custom data `"impact_fx_data"` → `ImpactFXData`; other bodies → `body.impact_fx_data`; fallback → bullet's own `impact_fx_data`.
6. `data.spawn(impact_pos)` — `ImpactFXData` instantiates and plays the effect.
7. `queue_free()`.

If range is reached without a hit, spawns `range_fx` (if set) and frees.

### 5. Impact Effect System

**`ImpactFXData` (`scripts/impact_fx_data.gd`)** — `Resource`:

| Property | Description |
|---|---|
| `scene` | `PackedScene` to instantiate (`ImpactFX` node) |
| `animation_name` | Animation to play on the `AnimatedSprite2D` |
| `sound` | Optional `AudioStream` played via `AudioPool` |
| `offset` | Sprite position adjustment |
| `scale` | Sprite scale multiplier |

`ImpactFXData.spawn(position, process_mode)` instantiates `scene`, sets `process_mode` (callers pass `PROCESS_MODE_ALWAYS` when the effect must survive a `HitStop` pause), parents to `current_scene`, positions, and calls `play_impact(self)`.

**`ImpactFX` (`scripts/impact_fx.gd`)** — applies data, plays animation and sound, `queue_free()`s on `animation_finished`. Audio respects `ignore_pause` based on its own `process_mode`.

### 6. Enemy (`scenes/enemy.tscn` + `scripts/enemy.gd`)

`CharacterBody2D`. Minimal implementation.

| Property | Description |
|---|---|
| `max_health` | Starting health |
| `contact_damage` | Damage dealt to player on collision |
| `knockback_scale` | 0–1 scalar dampening incoming knockback (for large/heavy enemies) |
| `impact_fx_data` | Hit effect read by `bullet.gd` |
| `death_sound` | Played via `AudioPool` on death |

- `take_damage(amount, knockback_direction, _impact_position)`: clamps health at 0 implicitly via die check, applies knockback scaled by `knockback_scale`, white flash tween (`TWEEN_PAUSE_PROCESS`).
- `die()`: disables physics/collision, plays `"death_down"`, `queue_free()`s on animation end.

No pathfinding or AI yet. Death animation is hardcoded to `"death_down"`.

### 7. HUD (`scripts/ui/hud.gd`, `scripts/ui/heart.gd`, `scripts/ui/weapon_display.gd`)

`CanvasLayer`. Connects to `player.weapon_changed` and `player.health_changed` signals in `_ready` (found via `"player"` group).

- **Hearts:** `Heart` control nodes in an `HBoxContainer`. Each heart has a `value` (0 = empty, 2 = full) and cycles through `heartImages`. `_update_max_hp` adds/removes hearts to match `max_health`. `_update_hp` fills hearts from left to right.
- **Weapon display:** Sets `$WeaponIcon.texture` from `weapon.hud_icon`.

---

## Input Map

| Action | Keyboard/Mouse | Gamepad | Deadzone |
|---|---|---|---|
| `move_left` | A | Left Stick X− | 0.2 |
| `move_right` | D | Left Stick X+ | 0.2 |
| `move_up` | W | Left Stick Y− | 0.2 |
| `move_down` | S | Left Stick Y+ | 0.2 |
| `shoot` | LMB | RT (axis 5) | 0.2 |
| `aim_left` | — | Right Stick X− | 0.2 |
| `aim_right` | — | Right Stick X+ | 0.2 |
| `aim_up` | — | Right Stick Y− | 0.2 |
| `aim_down` | — | Right Stick Y+ | 0.2 |
| `weapon_next` | Scroll Up | Y Button | 0.5 |
| `weapon_prev` | Scroll Down | — | 0.5 |

---

## Resource Dependency Graph

```
weapon_default.tres (Weapon)
  ├── bullet.tscn
  │     └── flesh_impact.tres (ImpactFXData)
  │           └── impactFX.tscn
  ├── bullet_range_fx → (optional ImpactFXData)
  ├── MuzzleFlash.tscn
  └── handgun_shoot.mp3

anim_data.tres (PlayerAnimation)
  └── AnimationState[] → AnimationEntry[]

grassy.tres (TileSet)
  └── cell custom data "impact_fx_data" → rock_impact.tres (ImpactFXData)
        └── stone.tscn
```

---

## Engineering Philosophy

**Fail loudly on bad setup.** Missing scene dependencies (wrong group name, unassigned export, missing node path) should crash immediately with a clear `assert` message, not silently no-op. Silent failures let broken configurations go unnoticed and make bugs harder to trace. A null guard is only appropriate when the absent value is a genuinely valid runtime state (e.g. an optional audio stream, an optional impact fx).

---

## Current State & Known Gaps

| Area | Status |
|---|---|
| Player movement & aiming | Complete |
| Mouse + gamepad input switching | Complete |
| Weapon & bullet system | Complete (2 weapons) |
| Impact effects (flesh + rock) | Complete |
| 8-directional animation (idle/walk/hit/death) | Complete |
| Camera with level bounds | Complete |
| Camera shake & zoom on hit | Complete |
| Player health, damage, death | Complete |
| Player invulnerability + blink | Complete |
| Hit stop | Complete |
| Enemy health, damage, death | Basic |
| Enemy knockback dampening | Complete |
| Enemy AI / pathfinding | Not implemented |
| Enemy directional animations | Not implemented (death hardcoded to `death_down`) |
| Melee combat | Not implemented |
| HUD (health hearts, weapon icon) | Basic |
| Level design | Single test room |
| Game states (menu, pause, game over) | Not implemented |
| Player dash/jump | Assets present, not wired |
| Audio bus / mixing | Not implemented |
| Save / load | Not implemented |

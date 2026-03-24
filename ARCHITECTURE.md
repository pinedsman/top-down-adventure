# Top Down Adventure — Architecture

## Project Overview

A top-down action shooter built in Godot 4.6. The player navigates a tiled level, aims with mouse or gamepad, and shoots enemies using a data-driven weapon system. Currently a prototype with movement, shooting, impact effects, and basic enemy combat.

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
│   │   └── Temp/             # Player sprites (Idle, Walk, Death, Jump, Dash)
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
    ├── player_animation.gd
    ├── animation_state.gd
    ├── animation_entry.gd
    ├── debug_draw.gd         # Autoload singleton
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
├── ySort (Node2D)                 # Y-sorted for correct depth ordering
│   ├── 2ndFloor (TileMapLayer)    # Elevated tile layer
│   ├── Walls (TileMapLayer)       # Wall tiles with collision
│   ├── Player (Player.tscn)
│   └── Enemy × 5 (enemy.tscn)
└── HUD (CanvasLayer)              # group: hud
    └── Crosshair (Node2D)         # group: crosshair — follows mouse cursor
        └── Sprite2D
```

### `Player.tscn`

```
CharacterBody2D
├── AnimatedSprite2D               # 8-directional idle/walk/death animations
├── WallCollision (CollisionShape2D, CapsuleShape2D)
├── Muzzle (Marker2D)              # Bullet spawn origin (foreground shots)
├── MuzzleBehind (Marker2D)        # Bullet spawn origin (behind-player shots)
├── LaserSight (Line2D)            # Gamepad aiming visualizer (custom shader)
└── Camera2D                       # Follows player; limits from ground tilemap
```

### `enemy.tscn`

```
CharacterBody2D
├── AnimatedSprite2D               # idle_down, death_down animations (Slime1)
└── WallCollision (CollisionShape2D)
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

## Core Systems

### 1. Player Controller (`scripts/player.gd`)

`CharacterBody2D`. Handles movement, aiming, shooting, camera, and animation updates.

- **Movement:** WASD / left gamepad stick at 100 units/sec.
- **Aiming:** Mouse position (screen-space) or right gamepad stick. The system detects which input device is active and switches automatically — showing the crosshair UI node for mouse and the `LaserSight` Line2D for gamepad.
- **Camera:** `Camera2D` limits are computed from the `ground_tilemap` group's `TileMapLayer` extents, converted from tile coordinates using `ground.tile_set.tile_size` (supports non-square tiles).
- **Animation:** Calls `anim_data.get_entry(state, direction)` once per frame and caches the result as `_currentAnimEntry`. Both `Muzzle` and `MuzzleBehind` positions are updated from `_currentAnimEntry.muzzle_offset` each frame.
- **Shooting:** Delegates to `Weapon.fire()`, passing either `Muzzle` or `MuzzleBehind` depending on `_currentAnimEntry.bullet_behind_player`, plus the aim direction.

### 2. Animation System

Three resource classes compose the animation lookup:

| Class | File | Role |
|---|---|---|
| `AnimationEntry` | `animation_entry.gd` | Data for one direction: animation name, flip, muzzle offset, bullet z-order flag |
| `AnimationState` | `animation_state.gd` | Groups 8 `AnimationEntry` objects for one logical state (idle, walk) |
| `PlayerAnimation` | `player_animation.gd` | Array of `AnimationState`; primary API is `get_entry(state, direction) -> AnimationEntry` |

The active `PlayerAnimation` instance is stored in `anim_data.tres`. Eight directions are indexed 0–7 (up, up-right, right, down-right, down, down-left, left, up-left). State is determined by whether the player's velocity is non-zero.

**`AnimationEntry` fields:**

| Field | Type | Description |
|---|---|---|
| `animationIndex` | String | Animation name on `AnimatedSprite2D` |
| `flip` | bool | Horizontal flip for mirrored directions |
| `muzzle_offset` | Vector2 | Muzzle position for this direction |
| `bullet_behind_player` | bool | Whether bullet should spawn behind the player sprite |

`AnimationEntry` is a `@tool` resource. Setting `muzzle_offset` in the Inspector live-previews the muzzle position in the editor. A "Preview Animation" button plays the animation and applies the flip/offset in-editor without entering Play mode.

### 3. Weapon System (`scripts/weapons/weapon.gd`)

Data-driven `Resource` class. `weapon_default.tres` is the only current weapon.

| Property | Default | Description |
|---|---|---|
| `fire_mode` | AUTO (1) | SINGLE, AUTO, or BURST |
| `fire_rate` | 0.1 s | Minimum seconds between shots |
| `damage` | 10.0 | Damage per bullet |
| `bullet_speed` | 400.0 | Bullet speed in px/sec (overrides bullet scene export) |
| `bullet_scene` | bullet.tscn | Projectile to instantiate |
| `muzzle_flash_scene` | MuzzleFlash.tscn | Visual effect |
| `shoot_sound` | handgun_shoot.mp3 | Audio stream |
| `audio_pool_size` | 4 | Number of pooled `AudioStreamPlayer2D` nodes for overlapping shots |

`Weapon.fire(muzzle, direction, behind_player)` checks the cooldown, spawns a bullet at the muzzle position, plays the muzzle flash, and plays the shoot sound. The `behind_player` flag is forwarded to the muzzle flash (sets `z_index = -1`) so the flash renders behind the player sprite when shooting upward.

**Audio pool:** On first fire, `audio_pool_size` `AudioStreamPlayer2D` nodes are created and added to the scene root. Subsequent shots round-robin through the pool, so rapid fire plays overlapping audio without spawning new nodes per shot. The pool is rebuilt automatically if the scene changes and nodes are freed.

### 4. Projectile System (`scripts/weapons/bullet.gd`)

`Area2D`. Uses `move_and_collide` / CastMotion each physics frame. Speed defaults to 400 px/sec but is overwritten by `Weapon.bullet_speed` at spawn time. Bullets are added as children of the `ySort` Node2D so they depth-sort correctly with other world objects.

**Collision flow:**
1. Cast motion in the aim direction.
2. If a collider is found, skip it if it is the `owner_node` (friendly fire prevention).
3. Call `take_damage(damage)` on the collider if the method exists.
4. Determine the impact effect to spawn:
   - If the collider is a `TileMapLayer`, read its `get_cell_tile_data()` custom layer `"impact_fx_data"` → `ImpactFXData`.
   - Otherwise, read `collider.impact_fx_data` property (e.g., on enemies).
   - Fall back to the bullet's own `impact_fx_data` resource.
5. Instantiate `impactFX.tscn`, apply the `ImpactFXData` offset/scale, and add to the scene tree.
6. `queue_free()` itself.

### 5. Impact Effect System

**`ImpactFXData` (`scripts/impact_fx_data.gd`)** — `Resource`:

| Property | Description |
|---|---|
| `animation_name` | Animation to play on `impactFX.tscn` |
| `audio_stream` | Optional sound to play |
| `offset` | Sprite position adjustment |
| `scale` | Sprite scale multiplier |

**`ImpactFX` (`scripts/impact_fx.gd`)** — applies the data resource, plays the animation and sound, then `queue_free()`s when the animation finishes.

Two preconfigured resources:
- `flesh_impact.tres` — animation `"impact_flesh"`, scale 0.1, offset (0, 3)
- `rock_impact.tres` — animation `"impact_rock"`, default scale/offset

### 6. Enemy (`scenes/enemy.tscn` + `enemy.gd` in scene)

Minimal implementation. `CharacterBody2D` with:
- `max_health = 100.0`, `health` property.
- `take_damage(amount)` — reduces health; calls `die()` at 0.
- `die()` — plays death animation and `slime_death.mp3`, disables collision and physics, then `queue_free()`s on animation end.

No pathfinding or AI yet.

### 7. Debug Draw (`scripts/debug_draw.gd`) — Autoload

Global singleton registered as `DebugDraw`. Provides `add_line(from, to, color, ttl)` and `add_circle(center, radius, color, ttl)`. Shapes auto-parent to the `hud` group's `CanvasLayer` and are removed after their TTL expires. Not active in shipped builds.

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

---

## Resource Dependency Graph

```
weapon_default.tres
  ├── bullet.tscn
  │     └── flesh_impact.tres
  ├── MuzzleFlash.tscn
  └── handgun_shoot.mp3

anim_data.tres
  └── AnimationState[] → AnimationEntry[]

grassy.tres (tileset)
  └── cell custom data "impact_fx_data" → rock_impact.tres
```

---

## Engineering Philosophy

**Fail loudly on bad setup.** Missing scene dependencies (wrong group name, unassigned export, missing node path) should crash immediately with a clear `assert` message, not silently no-op. Silent failures let broken configurations go unnoticed and make bugs harder to trace. A null guard is only appropriate when the absent value is a genuinely valid runtime state (e.g. an optional audio stream).

---

## Current State & Known Gaps

| Area | Status |
|---|---|
| Player movement & aiming | Complete |
| Mouse + gamepad input switching | Complete |
| Weapon & bullet system | Complete |
| Impact effects (flesh + rock) | Complete |
| 8-directional animation | Complete |
| Camera with level bounds | Complete |
| Enemy health & death | Basic |
| Enemy AI / pathfinding | Not implemented |
| Melee combat | Not implemented |
| Level design | Single test room |
| UI / HUD (health, ammo) | Not implemented |
| Player dash/jump | Assets present, not wired |
| Game states (menu, pause, gameover) | Not implemented |

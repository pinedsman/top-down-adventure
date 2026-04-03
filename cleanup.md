# Cleanup — Prioritized Action List

---

## 1. `scripts/room/room_config.gd` — Dead code [Architecture]

`RoomConfig` was replaced by the `RoomData` + `WaveSetData` separation. `WaveModeManager` no longer references it. The file still exists and the class is registered, causing confusion about which pairing mechanism to use.

**Fix:** Delete `room_config.gd`.

---

## 2. `scripts/enemy/types/enemy_grunt.gd:47` — Direct access to internal Weapon field [Architecture]

```gdscript
_weapon_instances[0]._cooldown = 0.0
```

`_cooldown` is a private implementation detail of `Weapon`. Direct mutation bypasses any future logic added to `Weapon.fire()` / `Weapon.tick()`. If `_weapon_instances` is empty (grunt configured without a weapon) this also crashes.

**Fix:** Add `func reset_cooldown() -> void: _cooldown = 0.0` to `weapon.gd`. Guard with a bounds/null check before calling it. Call `_weapon_instances[0].reset_cooldown()`.

---

## 3. `scripts/room/wave_mode_manager.gd:46-59` — WaveModeManager directly reparents and positions the player [Architecture]

The manager reaches into the scene tree, finds the player by group, reparents it, and sets its `global_position`. This is a cross-cutting responsibility. If the player scene changes structure (or there are multiple players), this silently breaks.

**Fix:** Add `func enter_room(ysort: Node, spawn_position: Vector2) -> void` to `player.gd`. WaveModeManager calls that method instead of performing the reparent/position inline. The player owns its own scene transitions.

---

## 4. `scripts/enemy/types/enemy_grunt.gd:43-55` — `_navigate_to_shoot_range` duplicates `_navigate_interruptible` [Architecture]

Both methods are frame-by-frame nav loops with the same structure (await physics_frame, update nav target, set velocity). The only difference is the stop condition. This will diverge over time.

**Fix:** Add a `stop_condition: Callable` parameter to `_navigate_interruptible` in `EnemyPatrolBase`, defaulting to `Callable()` (no extra condition). `_navigate_to_shoot_range` becomes a one-liner calling `_navigate_interruptible` with a distance check callable. Delete the duplicate loop in `EnemyGrunt`.

---

## 5. `scripts/player.gd:50-53` — `_slot_instances` can contain null, propagating null checks throughout [Architecture]

```gdscript
if slot.weapon_data == null:
    _slot_instances.append(null)
    continue
```

This pads `_slot_instances` with nulls to keep indices aligned with `weapon_slots`. Every subsequent iteration (`_tick_weapon`, `_on_take_damage`, `_unhandled_input`) needs a null guard. The alignment isn't actually used anywhere — slots are looked up by index only in `_unhandled_input`, which reads `weapon_slots[i]` directly.

**Fix:** Skip null-data slots entirely at construction:
```gdscript
if slot.weapon_data == null:
    continue
```
Store `(slot, instance)` pairs instead of a parallel array, or attach the slot data reference to the instance. Remove all `if instance != null` guards.

---

## 6. `scripts/player.gd:418-419,442,478,488` — `_active_melee_slot()` called multiple times per physics frame [Performance]

`_active_melee_slot()` iterates `_slot_instances` on each call. It is called up to 5 times in a single physics frame (`_physics_process`, `_update_aim`, `player_movement`, `player_animation`, `_draw`). With more slots this becomes noticeable.

**Fix:** Call it once at the top of `_physics_process`, store the result in a local, pass it to the methods that need it — or cache it as `_cached_active_melee` that is refreshed once per frame.

---

## 7. `scripts/room/room_manager.gd:102-103` — `.filter()` allocation on every enemy death [Performance]

```gdscript
func _on_enemy_removed() -> void:
    _living_enemies = _living_enemies.filter(func(e): return is_instance_valid(e))
```

Creates a new Array on every enemy removal. With `tree_exited`, the dead node is still technically the caller — it can be identified. More importantly, `_wait_for_wave_clear` (line 106-111) also calls `.filter()` inside its polling loop, causing per-frame allocation until the wave ends.

**Fix:** In `_spawn_enemy`, store a reference alongside the lambda so `_on_enemy_removed` can call `_living_enemies.erase(enemy)` directly (capturing `enemy` in the closure). Remove the redundant `.filter()` from `_wait_for_wave_clear` — if `_on_enemy_removed` is reliable, just check `.is_empty()`.

---

## 8. `scripts/enemy/enemy_patrol_base.gd:147-158` — `_can_see_player()` fires a physics raycast every frame, unthrottled [Performance]

Called in `_physics_process` (line 42) and inside `_navigate_interruptible`'s per-frame loop. With 10+ enemies in a wave, this is 10+ raycasts per frame purely for visibility checks, plus the same number from the `_run_behavior` coroutine loop.

**Fix:** Throttle the LOS check to every N physics frames (e.g. 3–5) using a frame counter. Cache the last result between checks. The sight range distance check (cheap) can still run every frame to early-out before the raycast.

---

## 9. `scripts/room/wave_mode_manager.gd:70-73` — Room/wave selection strategy is hardcoded [Data-Driven]

```gdscript
func _pick_room() -> RoomData:
    return rooms[_run_index % rooms.size()]

func _pick_wave_set() -> WaveSetData:
    return wave_sets[_run_index % wave_sets.size()]
```

Cycling by modulo is baked in. Weighted random, curated sequences, and difficulty scaling can't be configured without subclassing.

**Fix:** Make these `func _pick_room() -> RoomData` and `func _pick_wave_set() -> WaveSetData` virtual (document as overridable). Alternatively, expose a `selection_mode: SelectionMode` enum (`SEQUENTIAL`, `RANDOM`, `WEIGHTED`) with the logic in a `match` block so a designer can switch modes from the Inspector without writing code.

---

## 10. `scripts/enemy/types/enemy_grunt.gd:33` — Magic number `500.0` for shoot direction target [Data-Driven]

```gdscript
shoot_weapon(0, global_position + dir * 500.0)
```

`500.0` is a hardcoded large offset to approximate "fire infinitely in this direction." It is semantically a shoot distance, affects nothing gameplay-wise beyond approximating a direction, but is invisible to designers.

**Fix:** Add `@export var shoot_target_distance: float = 500.0` to `EnemyGrunt`, or replace the entire pattern with a `shoot_weapon_direction(index, dir)` helper on `EnemyBase` that takes a direction vector directly and avoids the `target_pos` arithmetic at the call site.

---

## 11. `scripts/enemy/types/enemy_grunt.gd:62` — Hardcoded reposition navigation timeout [Data-Driven]

```gdscript
await _navigate_interruptible(target, 2.0)
```

The 2-second timeout is invisible to designers. If a room is large, repositioning cuts off early.

**Fix:** Add `@export var reposition_timeout: float = 2.0` to `EnemyGrunt`.

---

## 12. `scripts/player.gd:419` — Cryptic local variable name `_sm` [Naming]

```gdscript
var _sm := _active_melee_slot()
```

`_sm` is a private-field naming convention applied to a local variable. The name itself is an unexplained abbreviation.

**Fix:** Rename to `active_melee`.

---

## 13. `scripts/player.gd:213` — Local variable `_swinging_melee` uses field naming convention [Naming]

```gdscript
var _swinging_melee := _active_melee_slot()
```

The `_` prefix signals "private field" in GDScript convention. This is a local variable.

**Fix:** Rename to `swinging_melee`.

---

## 14. `scripts/weapons/melee_weapon.gd:145,146` — Cryptic single-letter variable names `fd`, `sd` [Naming]

```gdscript
var fd := to_body.dot(fwd)
var sd := to_body.dot(side)
```

**Fix:** Rename to `forward_dist` and `side_dist`.

---

## 15. `scripts/enemy/types/enemy_grunt.gd:43` — Method name says "navigate to" when it means "approach until within" [Naming]

`_navigate_to_shoot_range` sounds like it navigates to the edge of shoot range. It actually approaches the player and stops when within `shoot_range` — a subtle but meaningful distinction.

**Fix:** Rename to `_approach_to_shoot_range`. (Moot if fixed under issue #4.)

---

## 16. `scripts/weapons/bullet.gd:67` — Generic variable name `result` [Naming]

```gdscript
var result = space.cast_motion(_cast_query)
```

`result` says nothing about what was returned.

**Fix:** Rename to `cast_result` or `motion_fraction`.

---

## 17. `scripts/character_base.gd` — `weapons` export is ambiguous between data and instances [Naming]

The class exports `weapons: Array[WeaponData]` (config resources) and maintains `_weapon_instances: Array[Weapon]` (runtime). Calling the data array `weapons` implies it contains live weapon objects.

**Fix:** Rename the export to `weapon_data_slots: Array[WeaponData]` (or `equipped_weapon_data`). Update all references in `player.gd`, `enemy_base.gd`, and `character_base.gd`.

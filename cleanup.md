# Cleanup — Prioritized Action List

---

## 1. `weapon.gd:39-40` — Mutable instance state on a shared Resource [Architecture]

`owner_node` and `_ysort` are `var` fields on `Weapon`, which is a `Resource`. Resources are shared by reference — if the same `.tres` file is referenced by two enemies, the second `_connect_weapon` call overwrites `owner_node` for both. `_ysort` has the same issue.

**Fix:** Move `owner_node` and `_ysort` out of the Resource. Pass the owner explicitly to `fire()` (already available as `muzzle.get_parent()`). Fetch ysort once at the call site in `_spawn_bullet` / `_spawn_grenade` rather than caching it on the resource.

---

## 2. `grenade.gd:40-41` — Grenade acquires Camera2D directly from `owner_node` [Architecture]

```gdscript
_camera = owner_node.get_node("Camera2D") as CameraController
assert(_camera != null, "Grenade: owner_node has no Camera2D child named 'Camera2D'")
```

A world projectile reaches into its thrower's scene tree to grab a specific node by name. This is a layering violation: it breaks the moment an enemy throws a grenade, or the player scene is refactored. Camera shake is a cross-cutting concern.

**Fix:** Add a `camera` group to the Camera2D and use `get_tree().get_first_node_in_group("camera")` in `_ready`, or route explosion shake through an autoload (e.g. extend `HitStop` to include a shake request, or add a `CameraController` autoload reference).

---

## 3. `enemy_base.gd:65-68` — Null crash in `_on_die()` fallback path [Architecture]

```gdscript
# line 58: if anim_data != null and anim_data.has_state("death"):
#   ... handles it ...
# line 66 (fallback):
var dir_index := DirectionalAnimData.direction_to_index(_facing, anim_data.direction_count)
```

The outer null check guards the happy path, but the `else`/fallback (line 66) reads `anim_data.direction_count` unconditionally — crashing if `anim_data` is null.

Additionally, line 67's hardcoded `dir_names` array (`["up", "up", "right", "down", "down", "down", "left", "up"]`) is a parallel data structure that duplicates animation naming. If names change, this silently breaks with no assertion.

**Fix:** Add `if anim_data == null: queue_free(); return` before line 66. Better yet, require all enemies to use `DirectionalAnimData` and remove the string-concatenation fallback entirely.

---

## 4. `melee_weapon.gd:121-126` — Two heap allocations per physics tick while swinging [Performance]

```gdscript
func _do_arc_query() -> void:
    var shape := CircleShape2D.new()        # allocated every frame
    var query := PhysicsShapeQueryParameters2D.new()  # allocated every frame
```

`_do_arc_query` is called every `tick()` during `SwingState.ACTIVE`. Both objects are recreated from scratch each frame. Only `shape.radius` and `query.transform` change between calls.

**Fix:** Add `_arc_shape: CircleShape2D` and `_arc_query: PhysicsShapeQueryParameters2D` as class-level vars, initialize them lazily on first `_start_swing`, and update only `shape.radius` and `query.transform` each tick.

---

## 5. `pickup.gd:1,10` — `body_entered` connected on a Node2D root [Architecture]

```gdscript
extends Node2D       # line 1
...
self.body_entered.connect(_on_player_entered)  # line 10
```

`body_entered` is a signal on `Area2D`. `Node2D` has no such signal; this connection silently fails unless the scene root happens to be an `Area2D`. If the script class is `Node2D`, the scene root must be an `Area2D` — the script type and scene root type are mismatched.

**Fix:** Change `extends Node2D` to `extends Area2D`, or connect via `$Area2D.body_entered` with the signal on the child area node.

---

## 6. `animation_entry.gd:6` — `animationIndex` is camelCase and misnamed [Naming]

```gdscript
@export var animationIndex: String = ""
```

GDScript convention is `snake_case`. The field is a `String` (animation name), not an integer index. All call sites use it as a name passed to `sprite.play()`.

**Fix:** Rename to `animation_name`. Call sites: `player.gd:144,346`, `enemy_base.gd:62,148`, `animation_entry.gd:25,27`.

---

## 7. `hud.gd:29-30` — Group lookup repeated inside signal handler [Architecture]

```gdscript
func _on_weapon_changed(weapon: Weapon) -> void:
    ...
    var player = get_tree().get_first_node_in_group("player")  # second lookup
    _on_ammo_changed(weapon.ammo_type, player.get_ammo(weapon.ammo_type))
```

`_ready` already retrieves the player but discards the reference. Every weapon-change event pays for an O(n) group scan.

**Fix:** Store `var _player: Player` in `_ready` and reuse it in all handlers. Also eliminates the untyped `var player` local.

---

## 8. `player.gd:83-85` — No-op `pass` branch [Readability]

```gdscript
if not has_ammo(weapon):
    pass
elif weapon.can_fire():
    weapon.fire(...)
else:
    _fire_buffer = fire_buffer_window
```

The `if not has_ammo` branch does nothing. It exists only to make the `elif` chain work but is misleading.

**Fix:** Invert:
```gdscript
if has_ammo(weapon):
    if weapon.can_fire():
        weapon.fire(...)
    else:
        _fire_buffer = fire_buffer_window
```

---

## 9. `hud.gd:38-42` — Half-heart state is never used [Data-Driven]

```gdscript
heart.value = 2 if (i < health) else 0
```

Each heart node has a `value` range implying 0/1/2 (empty/half/full), but the logic only ever sets 0 or 2 — the half-heart state is dead. If `health = 2.5`, the third heart shows empty rather than half-full.

**Fix:**
```gdscript
heart.value = 2 if (i + 1 <= health) else (1 if (i < health) else 0)
```

---

## 10. `directional_anim_data.gd:33-38` — Dead method that bypasses cache [Performance / Readability]

```gdscript
func get_entry_for_state(state_name: String) -> AnimationEntry:
    for state in states:           # O(n) linear scan
        if state.state_name == state_name:
            ...
    return null
```

No call sites found in the codebase. The method duplicates `get_entry(state, 0)` logic but ignores the O(1) `_cache` dictionary.

**Fix:** Remove `get_entry_for_state`. If needed, replace with `get_entry(state_name, 0)`.

---

## 11. `hud.gd:18,38,44` — camelCase parameter names and type mismatch [Naming]

- `_on_health_changed(health:float, maxHealth:float)` — `maxHealth` should be `max_health`
- `_update_hp(health:int)` — takes `int` but `health_changed` emits `float`; should be `float`
- `_update_max_hp(max_hp: int)` — same, should be `float`

**Fix:** Rename `maxHealth → max_health`, change parameter types to `float`.

---

## 12. `pickup.gd:14` — camelCase parameter name [Naming]

```gdscript
func set_pickup_data(newData:PickupData):
```

**Fix:** `new_data: PickupData`. Also add `-> void` return type.

---

## 13. `player.gd:258` — Public method that is only called internally [Naming]

```gdscript
func update_laser_visibility() -> void:
```

Not referenced from any other file. Exposing it as public is misleading.

**Fix:** Rename to `_update_laser_visibility`.

---

## 14. `directional_anim_data.gd:6` — Stray semicolon [Readability]

```gdscript
@export var direction_count: int = 8;
```

**Fix:** Remove the trailing `;`.

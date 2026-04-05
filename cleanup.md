# Cleanup — Prioritized Action List

---

## 1. `scripts/ui/hud.gd:18` — HUD directly reads private player field by hardcoded slot index [Architecture]

```gdscript
_heal_weapon = player._slot_instances[1]
```

`_slot_instances` is a private implementation detail of `Player`. Accessing it from HUD by index 1 couples the UI to a specific weapon loadout — if the heal weapon moves to slot 0, or the player starts without a slot weapon, this silently breaks or crashes. `_on_ammo_changed` (line 56) then branches on `_heal_weapon.data.ammo_type` to decide which UI element to update, spreading this assumption further.

**Fix:** Emit a dedicated signal from Player when heal ammo changes, or add a public `get_slot_weapon(index) -> Weapon` accessor. The HUD should never reach into `_slot_instances` directly.

---

## 2. `scripts/player.gd:161–180` — `weapon_next` and `weapon_prev` are identical 9-line blocks [Architecture]

The only difference is `+1` vs `-1` in the index arithmetic. Every future change (e.g. adding a wrap-around sound, cancelling charge on switch) must be made twice.

**Fix:** Extract to `_switch_weapon(delta: int) -> void`. Both event handlers call `_switch_weapon(1)` / `_switch_weapon(-1)`.

---

## 3. `scripts/weapons/heal_ability.gd:27` — `on_charge_cancelled` casts to `Player`, breaking the `WeaponAbility` abstraction [Architecture]

```gdscript
func on_charge_cancelled(_shooter: Node, _weapon: Weapon) -> void:
    var character := _shooter as Player
```

Every other hook in `WeaponAbility` casts to `CharacterBase`. This one casts to `Player`, so the ability silently does nothing if attached to an enemy weapon. The `take_ammo` call should go through `CharacterBase` or the ability should not refund ammo at all (let the caller handle it).

**Fix:** Cast to `CharacterBase` and call a method defined there, or move the refund logic to the caller.

---

## 4. `scripts/player.gd:217–226` — `_on_take_damage` iterates `_slot_instances` twice [Architecture]

```gdscript
for inst: Weapon in _slot_instances:
    if inst.is_charging() and inst.data.damage_cancels_charge:
        inst.cancel_charge()
for instance in _slot_instances:
    instance.interrupt()
```

Two separate loops over the same array in the same function; can be a single pass.

**Fix:** Merge into one loop: check charge-cancel and call `interrupt()` in the same iteration.

---

## 5. `scripts/weapons/weapon.gd:309–311` — `_get_ysort()` does a full group scan on every shot, every pellet [Performance]

```gdscript
func _get_ysort(muzzle: Marker2D) -> Node:
    var ysort := muzzle.get_tree().get_first_node_in_group("ysort")
```

Called once per pellet per shot (shotguns: once per pellet). The ysort node never changes between shots. This is a tree-wide O(n) scan repeated unnecessarily.

**Fix:** Cache the result on the first call: `if _ysort_cache == null: _ysort_cache = ...`. Or pass it as a parameter from the `Player`/`EnemyBase` level where it's already known.

---

## 6. `scripts/room/room_manager.gd:90–95` — Spawn points array rebuilt on every `_spawn_enemy` call [Performance]

```gdscript
func _spawn_enemy(scene: PackedScene) -> bool:
    var spawn_points: Array[Node2D] = []
    for node in get_tree().get_nodes_in_group("spawn_points"):
        if _room_root.is_ancestor_of(node):
            spawn_points.append(node as Node2D)
```

Spawn points don't change during a wave. This performs a full group scan (+ ancestor check) for every enemy spawned.

**Fix:** Build and store `_spawn_points: Array[Node2D]` once in `init()`.

---

## 7. `scripts/player.gd:648–665` — `_update_interactable` does a full group scan + LOS raycast every physics frame [Performance]

`get_nodes_in_group("interactable")` is an O(n) tree traversal. With many interactables in the room, this runs 60× per second with a raycast per candidate.

**Fix:** Use an `Area2D` (radius = `interact_radius`) on the player with `body_entered`/`body_exited` to maintain a small candidate list. `_update_interactable` then only iterates that local list and fires the raycast only when the nearest candidate changes.

---

## 8. `scripts/player.gd:305` — `_update_aim` calls `_active_melee_slot()` again after it was already cached [Performance]

```gdscript
var _swinging_melee := _active_melee_slot()
```

`_cached_active_melee` is set at the top of `_physics_process` (line 92) for exactly this purpose. `_update_aim` ignores it and calls the slot-iteration again.

**Fix:** Replace `_active_melee_slot()` on line 305 with `_cached_active_melee`.

---

## 9. `scripts/enemy/enemy_base.gd:132` — `velocity.length()` uses sqrt for a threshold comparison [Performance]

```gdscript
var state := "walk" if (velocity.length() > 1 && ...) else "idle"
```

**Fix:** `velocity.length_squared() > 1.0` — identical semantics, no sqrt.

---

## 10. `scripts/player.gd:283` — `$AnimatedSprite2D` fetched by path every frame in `_tick_hit_state` [Performance]

```gdscript
var sprite := $AnimatedSprite2D
sprite.visible = fmod(...)
```

Called every frame while the player is invulnerable. Node-path lookup should be cached.

**Fix:** Cache as `@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D` and reuse in all methods that access it (`_tick_hit_state`, `_on_die`, `player_animation`).

---

## 11. `scripts/ui/hud.gd:55–68` — `_on_ammo_changed` contains layered branching that encodes weapon-slot semantics in the UI [Data-Driven]

The handler separately identifies "is this the heal weapon's ammo type?" vs "is this the current weapon's ammo type?" using ammo-type identity comparisons. The HUD is reconstructing slot logic that Player already tracks.

**Fix:** Instead of one generic `ammo_changed` signal, emit separate signals or include an enum tag indicating which UI slot to update (`PRIMARY`, `SECONDARY`, etc.). The HUD does a direct lookup rather than reverse-engineering which weapon an ammo type belongs to.

---

## 12. `scripts/player.gd:450` — `update_laser_visibility` is public when it should be private [Naming]

Called only from `_on_input_mode_changed` within the same class.

**Fix:** Rename to `_update_laser_visibility`.

---

## 13. `scripts/player.gd:533,559` — `player_movement` and `player_animation` use a redundant prefix [Naming]

The `player_` prefix is noise inside the `Player` class. The names also lack the `_` prefix that conventionally marks private/internal GDScript methods.

**Fix:** Rename to `_process_movement` and `_process_animation` (or `_tick_movement` / `_tick_animation` to match the `_tick_*` pattern already used in this file).

---

## 14. `scripts/ui/hud.gd:3–6` — `@onready` vars are untyped; `hbox` is especially unclear [Naming]

```gdscript
@onready var ammo_text = $BottomContainer/AmmoText
@onready var hbox = $HBoxContainer
```

No type annotations; `hbox` gives no indication of what it holds or why.

**Fix:** Add explicit types (`Label`, `HBoxContainer`, etc.). Rename `hbox` to `_heart_container`.

---

## 15. `scripts/player.gd:56` — `dash_particle` is untyped [Naming]

```gdscript
@onready var dash_particle = $DashParticle
```

**Fix:** Add the concrete particle node type (e.g. `GPUParticles2D` or `CPUParticles2D`).

---

## 16. `scripts/weapons/weapon.gd:210` — `_fire_single` is misleading — it's also called inside burst fire [Naming]

"Single" implies `FireMode.SINGLE`, but this method fires one shot regardless of mode and is the shared implementation used by both single and burst.

**Fix:** Rename to `_fire_shot`.

---

## 17. `scripts/weapons/melee_weapon.gd:163–165` — `fd`, `sd` are unexplained abbreviations [Naming]

```gdscript
var fd := to_body.dot(fwd)
var sd := to_body.dot(side)
```

**Fix:** Rename to `forward_dist` and `side_dist`.

---

## 18. `scripts/weapons/bullet.gd:83` — `result` for `cast_motion` return is a generic name [Naming]

```gdscript
var result = space.cast_motion(_cast_query)
```

`cast_motion` returns a `[safe_fraction, unsafe_fraction]` array. The name `result` hides this.

**Fix:** Rename to `motion_fractions` or `cast_result`.

---

## 19. `scripts/ui/hud.gd:70` — `_update_hp` parameter typed as `int` but the signal sends `float` [Naming / Correctness]

```gdscript
func _update_hp(health:int):
```

`health_changed` emits `float`. GDScript will silently truncate.

**Fix:** Change the parameter type to `float`.

---

## 20. `scripts/weapons/dropped_weapon.gd:44` — `get_prompt_text` shows `x-1` when magazine is infinite [Correctness]

```gdscript
return "%s x%d" % [weapon_data.weapon_name, saved_magazine]
```

If `saved_magazine == -1` (infinite-ammo weapon), the prompt reads e.g. `"Pistol x-1"`.

**Fix:** Check `saved_magazine < 0` and display `"∞"` or omit the count.

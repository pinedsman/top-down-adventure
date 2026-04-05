extends Node

# Use this to manage dev console commands.

var _bindings: Dictionary = {}  # key name (String) -> command (String)

func _ready() -> void:
	Console.add_command("bind", bind_key, ["key", "command"], 2, "Bind a key to a console command.")
	Console.add_command("unbind", unbind_key, ["key"], 1, "Remove a key binding.")
	Console.add_command("binds", list_binds, 0, 0, "List all key bindings.")
	Console.add_command("give_ammo", give_ammo, 0, 0, "Refill all ammo and magazines for the player.")
	Console.add_command("damage_player", damage_player, 0, 0, "Deal 1 point of damage to the player.")
	Console.add_command("kill_enemies", kill_enemies, 0, 0, "Kill all enemies in the current scene.")
	Console.add_command("give_weapon", give_weapon, ["weapon_name"], 1, "Give the player a weapon by resource name (e.g. weapon_shotgun).")
	Console.console_opened.connect(_on_console_opened)
	Console.console_closed.connect(_on_console_closed)
	_load_bindings()


func _on_console_opened() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_process_unhandled_input(false)


func _on_console_closed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_name := OS.get_keycode_string(event.get_physical_keycode_with_modifiers()).to_lower()
	if _bindings.has(key_name):
		Console._on_text_entered(_bindings[key_name])
		get_viewport().set_input_as_handled()


func bind_key(key: String, command: String) -> void:
	var keycode := OS.find_keycode_from_string(key.capitalize())
	if keycode == KEY_NONE:
		Console.print_error("Unknown key: '%s'" % key)
		return
	_bindings[key.to_lower()] = command
	_save_bindings()
	Console.print_line("Bound '%s' -> %s" % [key, command])


func unbind_key(key: String) -> void:
	if _bindings.erase(key.to_lower()):
		_save_bindings()
		Console.print_line("Unbound '%s'" % key)
	else:
		Console.print_warning("No binding for '%s'" % key)


func list_binds() -> void:
	if _bindings.is_empty():
		Console.print_line("No bindings set.")
		return
	for key in _bindings:
		Console.print_line("  %s  ->  %s" % [key, _bindings[key]])


func _save_bindings() -> void:
	var file := FileAccess.open("res://keybinds.cfg", FileAccess.WRITE)
	if not file:
		Console.print_error("Could not save keybinds.")
		return
	for key in _bindings:
		file.store_line("%s=%s" % [key, _bindings[key]])


func _load_bindings() -> void:
	var file := FileAccess.open("res://keybinds.cfg", FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		var sep := line.find("=")
		if sep > 0:
			_bindings[line.left(sep)] = line.substr(sep + 1)


func give_ammo() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		return
	for ammo_type in player._ammo:
		player._ammo[ammo_type] = ammo_type.max_capacity
		player.ammo_changed.emit(ammo_type, ammo_type.max_capacity)
	for inst in player._weapon_instances + player._slot_instances:
		inst.refill_magazine()
		if inst.data.use_weapon_ammo:
			player.weapon_magazine_changed.emit(inst, inst.magazine_ammo())
		else:
			player.ammo_changed.emit(inst.data.ammo_type, player.get_ammo(inst.data.ammo_type))
	Console.print_line("Ammo refilled.")


func give_weapon(weapon_name: String) -> void:
	var path := "res://resources/weapons/%s.tres" % weapon_name
	var data := load(path) as WeaponData
	if data == null:
		Console.print_error("No WeaponData found at: %s" % path)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.give_weapon(data)
		Console.print_line("Gave weapon: %s" % weapon_name)


func damage_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.take_damage(1.0, Vector2.from_angle(randf() * TAU))


func kill_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("die"):
			enemy.die()

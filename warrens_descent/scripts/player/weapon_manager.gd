extends Node3D

signal ammo_changed(current: int, max_ammo: int)
signal weapon_switched(weapon_name: String)
signal fired()

var weapons: Array[Node] = []
var current_weapon_index: int = 0
var current_weapon: Node = null

var total_shots_fired: int = 0
var total_shots_hit: int = 0


func _ready() -> void:
	# Collect weapon children
	for child in get_children():
		if child.has_method("fire"):
			weapons.append(child)
			child.visible = false

	if weapons.size() > 0:
		current_weapon = weapons[0]
		current_weapon.visible = true
		_emit_weapon_info()


func _process(_delta: float) -> void:
	if not current_weapon:
		return

	# Weapon switching
	if Input.is_action_just_pressed("weapon_1") and weapons.size() > 0:
		_switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2") and weapons.size() > 1:
		_switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_3") and weapons.size() > 2:
		_switch_weapon(2)

	# Firing
	if current_weapon.has_method("is_auto") and current_weapon.is_auto():
		if Input.is_action_pressed("fire"):
			_try_fire()
	else:
		if Input.is_action_just_pressed("fire"):
			_try_fire()

	# Reload
	if Input.is_action_just_pressed("reload") and current_weapon.has_method("reload"):
		current_weapon.reload()
		_emit_ammo_info()


func _try_fire() -> void:
	if current_weapon and current_weapon.has_method("fire"):
		if current_weapon.fire():
			fired.emit()
			_emit_ammo_info()


func _switch_weapon(index: int) -> void:
	if index == current_weapon_index or index >= weapons.size():
		return
	if current_weapon:
		current_weapon.visible = false
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.visible = true
	_emit_weapon_info()


func _emit_weapon_info() -> void:
	if current_weapon and current_weapon.has_method("get_weapon_name"):
		weapon_switched.emit(current_weapon.get_weapon_name())
	_emit_ammo_info()


func _emit_ammo_info() -> void:
	if current_weapon and current_weapon.has_method("get_ammo_info"):
		var info = current_weapon.get_ammo_info()
		ammo_changed.emit(info.x, info.y)


func add_ammo(amount: int) -> void:
	if current_weapon and current_weapon.has_method("add_ammo"):
		current_weapon.add_ammo(amount)
		_emit_ammo_info()


func add_ammo_all(amount: int) -> void:
	for weapon in weapons:
		if weapon.has_method("add_ammo"):
			weapon.add_ammo(amount)
	_emit_ammo_info()


func get_accuracy() -> float:
	if total_shots_fired == 0:
		return 0.0
	return float(total_shots_hit) / float(total_shots_fired) * 100.0


func record_shot(hit: bool) -> void:
	total_shots_fired += 1
	if hit:
		total_shots_hit += 1

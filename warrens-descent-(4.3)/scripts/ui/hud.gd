extends CanvasLayer

var player: CharacterBody3D = null
var weapon_manager: Node = null

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_name_label: Label = $WeaponNameLabel
@onready var crosshair: ColorRect = $Crosshair
@onready var dash_bar: ProgressBar = $DashBar
@onready var fps_label: Label = $FPSLabel
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var death_screen: Control = $DeathScreen


func _ready() -> void:
	# Find player after a frame
	await get_tree().process_frame
	_connect_player()

	if death_screen:
		death_screen.visible = false
	if damage_overlay:
		damage_overlay.modulate.a = 0.0


func _process(_delta: float) -> void:
	# FPS counter
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Dash bar
	if player and dash_bar:
		dash_bar.value = player.get_dash_cooldown_percent() * 100.0

	# Fade damage overlay
	if damage_overlay and damage_overlay.modulate.a > 0.0:
		damage_overlay.modulate.a = move_toward(damage_overlay.modulate.a, 0.0, _delta * 3.0)

	# Death screen restart
	if death_screen and death_screen.visible:
		if Input.is_anything_pressed():
			get_tree().reload_current_scene()


func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player.health_changed.connect(_on_health_changed)
		player.player_died.connect(_on_player_died)

		weapon_manager = player.get_node_or_null("WeaponHolder/WeaponManager")
		if weapon_manager:
			weapon_manager.ammo_changed.connect(_on_ammo_changed)
			weapon_manager.weapon_switched.connect(_on_weapon_switched)

			# Initial values
			if weapon_manager.current_weapon:
				_on_weapon_switched(weapon_manager.current_weapon.get_weapon_name())
				var info = weapon_manager.current_weapon.get_ammo_info()
				_on_ammo_changed(info.x, info.y)

		_on_health_changed(player.health)


func _on_health_changed(new_health: int) -> void:
	if health_bar:
		health_bar.value = new_health
	if health_label:
		health_label.text = str(new_health)
	# Flash damage overlay
	if damage_overlay and new_health < (player.max_health if player else 100):
		damage_overlay.modulate.a = 0.4


func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, reserve]


func _on_weapon_switched(wep_name: String) -> void:
	if weapon_name_label:
		weapon_name_label.text = wep_name


func _on_player_died() -> void:
	if death_screen:
		death_screen.visible = true

extends CanvasLayer

var player = null
var weapon_manager = null
var pneuma_flash_timer: float = 0.0
var pneuma_pulse_timer: float = 0.0
var pneuma_color_dirty: bool = false
var last_pneuma: float = 100.0

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_name_label: Label = $WeaponNameLabel
@onready var crosshair: ColorRect = $Crosshair
@onready var dash_bar: ProgressBar = $DashBar
@onready var fps_label: Label = $FPSLabel
@onready var speed_label: Label = $SpeedLabel
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var death_screen: Control = $DeathScreen
@onready var pneuma_bar: ProgressBar = $PneumaBar
@onready var pneuma_label: Label = $PneumaBar/PneumaLabel


func _ready() -> void:
	await get_tree().process_frame
	_connect_player()

	if death_screen:
		death_screen.visible = false
	if damage_overlay:
		damage_overlay.modulate.a = 0.0
	if health_bar:
		var health_style: StyleBoxFlat = StyleBoxFlat.new()
		health_style.bg_color = Color(0.85, 0.2, 0.2)
		health_bar.add_theme_stylebox_override("fill", health_style)


func _process(delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if player and dash_bar:
		dash_bar.value = player.get_dash_cooldown_percent() * 100.0

	if damage_overlay and damage_overlay.modulate.a > 0.0:
		damage_overlay.modulate.a = move_toward(damage_overlay.modulate.a, 0.0, delta * 3.0)

	if death_screen and death_screen.visible:
		if Input.is_anything_pressed():
			get_tree().reload_current_scene()

	# Pneuma denial flash
	if pneuma_flash_timer > 0.0:
		pneuma_flash_timer -= delta
		if pneuma_bar:
			var style: StyleBoxFlat = pneuma_bar.get("theme_override_styles/fill") as StyleBoxFlat
			if not style:
				style = StyleBoxFlat.new()
				pneuma_bar.add_theme_stylebox_override("fill", style)
			style.bg_color = Color(0.9, 0.15, 0.15)
		pneuma_color_dirty = true
	elif pneuma_color_dirty and player:
		_update_pneuma_bar_color(player.current_pneuma / maxf(player.max_pneuma, 0.001))
		pneuma_color_dirty = false

	# Pneuma low pulse (below 20%)
	if player and pneuma_bar:
		var pct: float = player.current_pneuma / maxf(player.max_pneuma, 0.001)
		if pct <= 0.2 and pct > 0.0:
			pneuma_pulse_timer += delta * 4.0
			pneuma_bar.modulate.a = 0.7 + sin(pneuma_pulse_timer) * 0.3
		elif pct <= 0.0:
			pneuma_bar.modulate.a = 0.4
		else:
			pneuma_bar.modulate.a = 1.0
			pneuma_pulse_timer = 0.0


func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player.health_changed.connect(_on_health_changed)
		player.player_died.connect(_on_player_died)
		player.speed_changed.connect(_on_speed_changed)
		last_pneuma = player.current_pneuma
		player.pneuma_changed.connect(_on_pneuma_changed)
		player.pneuma_denied.connect(_on_pneuma_denied)
		_on_pneuma_changed(player.current_pneuma, player.max_pneuma)

		weapon_manager = player.get_node_or_null("WeaponHolder/WeaponManager")
		if weapon_manager:
			weapon_manager.ammo_changed.connect(_on_ammo_changed)
			weapon_manager.weapon_switched.connect(_on_weapon_switched)

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
	if damage_overlay and player and new_health < player.max_health:
		damage_overlay.modulate.a = 0.4


func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, reserve]


func _on_weapon_switched(wep_name: String) -> void:
	if weapon_name_label:
		weapon_name_label.text = wep_name


func _on_speed_changed(speed: float) -> void:
	if speed_label:
		speed_label.text = "SPEED: %d" % speed


func _on_pneuma_changed(current: float, maximum: float) -> void:
	if not pneuma_bar:
		return
	pneuma_bar.max_value = maximum
	pneuma_bar.value = current
	if pneuma_label:
		pneuma_label.text = "%d / %d" % [int(current), int(maximum)]

	# Detect gain and show floating text
	var gained: float = current - last_pneuma
	if gained > 0.0:
		_spawn_floating_text("+%d" % int(gained))
	last_pneuma = current

	_update_pneuma_bar_color(current / maxf(maximum, 0.001))


func _update_pneuma_bar_color(percent: float) -> void:
	if not pneuma_bar:
		return
	var style: StyleBoxFlat = pneuma_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		pneuma_bar.add_theme_stylebox_override("fill", style)
	if percent <= 0.15:
		style.bg_color = Color(0.9, 0.15, 0.15)  # Red
	elif percent <= 0.30:
		style.bg_color = Color(0.9, 0.6, 0.15)  # Orange
	else:
		style.bg_color = Color(0.4, 0.75, 1.0)  # Light blue


func _on_pneuma_denied() -> void:
	pneuma_flash_timer = 0.2


func _spawn_floating_text(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(pneuma_bar.position.x + pneuma_bar.size.x + 10, pneuma_bar.position.y)
	add_child(label)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


func _on_player_died() -> void:
	if death_screen:
		death_screen.visible = true

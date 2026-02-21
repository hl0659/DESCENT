extends Area3D

enum PickupType { HEALTH, AMMO }

@export var pickup_type: PickupType = PickupType.HEALTH
@export var health_amount: int = 25
@export var ammo_amount: int = 15
@export var respawn_time: float = 10.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.2
@export var rotate_speed: float = 2.0

var base_y: float = 0.0
var time: float = 0.0
var is_active: bool = true

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	base_y = global_position.y
	body_entered.connect(_on_body_entered)
	time = randf() * TAU  # Randomize starting phase


func _process(delta: float) -> void:
	if not is_active:
		return
	time += delta
	# Bob up and down
	if mesh:
		mesh.position.y = sin(time * bob_speed) * bob_height
		mesh.rotate_y(rotate_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if not body.is_in_group("player"):
		return

	match pickup_type:
		PickupType.HEALTH:
			if body.has_method("heal"):
				if body.health >= body.max_health:
					return  # Don't pick up if full health
				body.heal(health_amount)
		PickupType.AMMO:
			var wm = body.get_node_or_null("WeaponHolder/WeaponManager")
			if wm and wm.has_method("add_ammo_all"):
				wm.add_ammo_all(ammo_amount)

	_deactivate()


func _deactivate() -> void:
	is_active = false
	visible = false
	if collision:
		collision.set_deferred("disabled", true)

	await get_tree().create_timer(respawn_time).timeout
	_reactivate()


func _reactivate() -> void:
	is_active = true
	visible = true
	if collision:
		collision.set_deferred("disabled", false)

extends Area3D

@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var speed: float = 18.0
var damage: int = 10
var alive_timer: float = 0.0


func setup(dir: Vector3, spd: float, dmg: int) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	alive_timer += delta
	if alive_timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

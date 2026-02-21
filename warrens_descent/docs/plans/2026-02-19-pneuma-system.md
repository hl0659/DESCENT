# Pneuma System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add the Pneuma resource system — a movement fuel earned by killing enemies — with HUD, audio feedback, pickups, double jump, and a slide rework.

**Architecture:** Pneuma state lives on `player_controller.gd` with signals for HUD binding. A new `pneuma_pickup.gd` extends the existing `pickup.gd` pattern with magnetism behavior. HUD bars move to top-of-screen with the health bar (red) stacked above the pneuma bar (light blue). Slide gets reworked for camera lowering and hold-to-slide with delayed friction.

**Tech Stack:** Godot 4.6, GDScript. Procedural audio via `SfxGenerator`. All gameplay values are `@export` for inspector tuning.

---

## Decisions Log

These were confirmed with the project owner before planning:

| Question | Answer |
|----------|--------|
| Dash cooldown (spec says 0.5s, current is 1.0s) | Match spec: 0.5s |
| Wall stick/slide before wall jump | No wall stick — just add Pneuma cost |
| Dash speed (spec says 20, current is 25) | Keep 25 for now |
| Slide Pneuma cost | No cost — slide is always free |
| Pneuma orb implementation | Extend existing pickup system |
| `drops_pneuma` default on EnemyBase | Default `true` |
| HUD bar placement | Move both to top of screen, wider, health (red) above pneuma (light blue) |
| Slide rework | Lower POV during slide, maintain speed for ~1s then reduce, hold button to stay in slide |

---

## Task 1: Add Pneuma Resource Pool to Player Controller

**Files:**
- Modify: `scripts/player/player_controller.gd`

**Step 1: Add Pneuma exports and state variables**

Add after the Health export group (after line 33):

```gdscript
@export_group("Pneuma")
@export var max_pneuma: float = 100.0
@export var pneuma_per_dash: float = 20.0
@export var pneuma_per_double_jump: float = 15.0
@export var pneuma_per_wall_jump: float = 10.0
```

Add signals (after `signal speed_changed` on line 7):

```gdscript
signal pneuma_changed(current: float, maximum: float)
signal pneuma_denied()
```

Add state variable (after `is_dead` on line 46):

```gdscript
var current_pneuma: float = 100.0
```

**Step 2: Add Pneuma spend/gain API**

Add to player_controller.gd after the `get_dash_cooldown_percent()` function:

```gdscript
func can_spend_pneuma(amount: float) -> bool:
	return current_pneuma >= amount


func spend_pneuma(amount: float) -> bool:
	if current_pneuma < amount:
		pneuma_denied.emit()
		return false
	current_pneuma -= amount
	pneuma_changed.emit(current_pneuma, max_pneuma)
	return true


func gain_pneuma(amount: float) -> void:
	current_pneuma = minf(current_pneuma + amount, max_pneuma)
	pneuma_changed.emit(current_pneuma, max_pneuma)
```

**Step 3: Initialize Pneuma on ready**

In `_ready()`, after `health = max_health` (line 60):

```gdscript
current_pneuma = max_pneuma
```

**Step 4: Gate dash behind Pneuma**

In `_physics_process`, replace the dash input check (line 153):

```gdscript
# Old:
if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
    _start_dash(wish_dir)

# New:
if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
    if spend_pneuma(pneuma_per_dash):
        _start_dash(wish_dir)
```

**Step 5: Gate wall jump behind Pneuma**

In the jump handling block, wrap the wall jump call (line 144-145):

```gdscript
# Old:
elif is_on_wall():
    _wall_jump()

# New:
elif is_on_wall():
    if spend_pneuma(pneuma_per_wall_jump):
        _wall_jump()
```

**Step 6: Update dash cooldown to match spec**

Change the default value of `dash_cooldown` from 1.0 to 0.5:

```gdscript
@export var dash_cooldown: float = 0.5
```

**Step 7: Verify**

Open the project in Godot, run the movement playground. Confirm:
- Dash consumes 20 Pneuma (check via print or inspector)
- Wall jump consumes 10 Pneuma
- When Pneuma is insufficient, dash/wall jump do nothing
- Base movement (sprint, jump, bhop, air strafe) still works at 0 Pneuma
- Dash cooldown feels faster (0.5s vs old 1.0s)

**Step 8: Commit**

```bash
git add scripts/player/player_controller.gd
git commit -m "feat: add pneuma resource pool, gate dash and wall jump"
```

---

## Task 2: Add Double Jump

**Files:**
- Modify: `scripts/player/player_controller.gd`

**Step 1: Add double jump exports**

Add to the "Advanced Movement" export group (after `bhop_friction_scale` on line 29):

```gdscript
@export var double_jump_force: float = 8.0
```

**Step 2: Add double jump state variable**

Add after the other state vars (near line 40):

```gdscript
var has_double_jumped: bool = false
```

**Step 3: Add double jump logic to the jump block**

Replace the jump input handling block (lines 137-150) with:

```gdscript
if not is_sliding:
    if Input.is_action_just_pressed("jump"):
        if is_on_floor() or coyote_timer > 0.0:
            velocity.y = jump_velocity
            coyote_timer = 0.0
            has_double_jumped = false
            if jump_sound:
                jump_sound.play()
        elif is_on_wall():
            if spend_pneuma(pneuma_per_wall_jump):
                _wall_jump()
                has_double_jumped = false
        elif not has_double_jumped:
            if spend_pneuma(pneuma_per_double_jump):
                velocity.y = double_jump_force
                has_double_jumped = true
                if jump_sound:
                    jump_sound.play()
    elif Input.is_action_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
        has_double_jumped = false
        if jump_sound:
            jump_sound.play()
```

Key points:
- `has_double_jumped` resets on ground touch, wall jump
- Double jump only fires if airborne, not on wall, and hasn't already double jumped
- Costs 15 Pneuma, fails silently (with denied signal) if insufficient

**Step 4: Reset double jump on floor in landing detection**

In the landing detection block (around line 110), add the reset:

```gdscript
if is_on_floor() and not was_on_floor:
    has_double_jumped = false
    if land_sound:
        land_sound.play()
```

**Step 5: Verify**

Run the playground. Confirm:
- Single jump from ground works with no Pneuma cost
- While airborne, pressing jump again performs a double jump (costs 15 Pneuma)
- Only one double jump per airborne period
- Double jump resets on ground touch
- Double jump resets after wall jump
- At 0 Pneuma, double jump fails but single jump still works

**Step 6: Commit**

```bash
git add scripts/player/player_controller.gd
git commit -m "feat: add double jump gated by pneuma"
```

---

## Task 3: Rework Slide Mechanic

**Files:**
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/player/camera_effects.gd`

The slide rework changes it from a timed duration to a hold-to-slide with: POV lowers, speed is maintained for ~1s, then friction kicks in. Player stays low until button is released.

**Step 1: Update slide exports**

Replace existing slide exports:

```gdscript
# Old:
@export var slide_speed: float = 14.0
@export var slide_friction: float = 4.0
@export var slide_duration: float = 0.6

# New:
@export var slide_speed: float = 14.0
@export var slide_friction: float = 8.0
@export var slide_maintain_time: float = 1.0
```

**Step 2: Update slide state variable**

The existing `slide_timer` now counts time *in* the slide (counting up) rather than time remaining (counting down). Replace:

```gdscript
# The slide_timer var already exists. Its meaning changes:
# It now tracks how long the player has been sliding (counts up from 0).
```

**Step 3: Rework slide start**

Replace `_start_slide()`:

```gdscript
func _start_slide() -> void:
	is_sliding = true
	slide_timer = 0.0
	var horiz: Vector3 = Vector3(velocity.x, 0, velocity.z).normalized()
	velocity.x = horiz.x * slide_speed
	velocity.z = horiz.z * slide_speed
```

**Step 4: Rework slide processing**

Replace `_process_slide()`:

```gdscript
func _process_slide(delta: float) -> void:
	slide_timer += delta
	if slide_timer > slide_maintain_time:
		# After maintain period, apply friction to slow down
		velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, slide_friction * delta)
```

**Step 5: Change slide trigger and exit to hold-based**

In `_physics_process`, replace the slide input check and add exit logic:

```gdscript
# Slide START (replace existing slide block):
if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not is_dashing:
    var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
    if horiz_speed > 3.0:
        _start_slide()

# Slide END (add after slide start, before move_and_slide):
if is_sliding and not Input.is_action_pressed("slide"):
    is_sliding = false
```

**Step 6: Remove slide_timer countdown from `_update_timers`**

Remove the slide timer block from `_update_timers()`:

```gdscript
# DELETE this block:
if slide_timer > 0.0:
    slide_timer -= delta
    if slide_timer <= 0.0:
        is_sliding = false
```

**Step 7: Add slide also exits if player leaves the floor**

In the slide exit logic:

```gdscript
if is_sliding and (not Input.is_action_pressed("slide") or not is_on_floor()):
    is_sliding = false
```

**Step 8: Add slide camera lowering to camera_effects.gd**

Add a new export group and variable to `camera_effects.gd`:

```gdscript
@export_group("Slide")
@export var slide_camera_offset: float = -0.6
@export var slide_camera_speed: float = 12.0
```

Add state var:

```gdscript
var slide_offset: float = 0.0
```

Add a `_process_slide_camera(delta)` function:

```gdscript
func _process_slide_camera(delta: float) -> void:
	var target: float = 0.0
	if player.get("is_sliding"):
		target = slide_camera_offset
	slide_offset = move_toward(slide_offset, target, slide_camera_speed * delta)
	position.y += slide_offset
```

Call it from `_process()` after `_process_landing(delta)`:

```gdscript
_process_slide_camera(delta)
```

**Step 9: Verify**

Run the playground. Confirm:
- Pressing slide while running lowers the camera smoothly
- Speed is maintained for ~1 second
- After 1 second, the player starts slowing down
- Releasing the slide button at any time raises the camera and exits slide
- Leaving the ground exits slide
- Camera transition in/out feels smooth (not instant snap)

**Step 10: Commit**

```bash
git add scripts/player/player_controller.gd scripts/player/camera_effects.gd
git commit -m "feat: rework slide to hold-based with POV lowering and delayed friction"
```

---

## Task 4: Add Pneuma Audio to SfxGenerator

**Files:**
- Modify: `scripts/audio/sfx_generator.gd`

**Step 1: Add all Pneuma sound functions**

Add the following static functions to `sfx_generator.gd`:

```gdscript
static func pneuma_pickup() -> AudioStreamWAV:
	# Bright chime, satisfying ping
	return _make_wav(0.15, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 20.0)
		var chime: float = sin(t * TAU * 880.0) * 0.4
		var harmonics: float = sin(t * TAU * 1320.0) * 0.25
		var ping: float = sin(t * TAU * 1760.0) * exp(-t * 40.0) * 0.3
		return (chime + harmonics + ping) * envelope * 0.65
	)


static func pneuma_denied() -> AudioStreamWAV:
	# Dull buzz/error tone
	return _make_wav(0.2, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 12.0)
		var buzz: float = sin(t * TAU * 90.0)
		var grit: float = sin(t * TAU * 90.0 * 3.0) * 0.3
		return (buzz * 0.6 + grit) * envelope * 0.5
	)


static func pneuma_low_loop() -> AudioStreamWAV:
	# Subtle heartbeat/breathing pulse — short loop
	var wav: AudioStreamWAV = _make_wav(0.8, func(t: float, _d: float) -> float:
		# Double-beat heartbeat pattern
		var beat1: float = sin(t * TAU * 45.0) * exp(-pow((t - 0.1), 2.0) * 800.0)
		var beat2: float = sin(t * TAU * 40.0) * exp(-pow((t - 0.28), 2.0) * 800.0)
		return (beat1 + beat2) * 0.35
	)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(44100.0 * 0.8)
	return wav


static func pneuma_empty() -> AudioStreamWAV:
	# Hollow empty sound on attempted action
	return _make_wav(0.25, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 10.0)
		var hollow: float = sin(t * TAU * 65.0) * 0.4
		var rattle: float = sin(t * 3417.0) * sin(t * 1719.0) * exp(-t * 25.0)
		return (hollow + rattle * 0.3) * envelope * 0.4
	)


static func dash_whoosh() -> AudioStreamWAV:
	# Whoosh + subtle resource spend
	return _make_wav(0.18, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 15.0)
		var freq: float = 200.0 + t * 1200.0
		var whoosh: float = sin(t * TAU * freq) * 0.3
		var air: float = sin(t * 9731.0) * sin(t * 6419.0) * 0.5
		var spend: float = sin(t * TAU * 300.0) * exp(-t * 40.0) * 0.2
		return (whoosh + air + spend) * envelope * 0.55
	)


static func double_jump_burst() -> AudioStreamWAV:
	# Air burst + subtle spend
	return _make_wav(0.12, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 28.0)
		var burst: float = sin(t * TAU * (200.0 + t * 600.0)) * 0.35
		var air: float = sin(t * 7731.0) * sin(t * 4419.0) * 0.45
		var pop: float = sin(t * TAU * 400.0) * exp(-t * 60.0) * 0.3
		return (burst + air + pop) * envelope * 0.5
	)
```

**Step 2: Commit**

```bash
git add scripts/audio/sfx_generator.gd
git commit -m "feat: add pneuma audio cues to sfx generator"
```

---

## Task 5: Wire Pneuma Audio into Player Controller

**Files:**
- Modify: `scripts/player/player_controller.gd`

**Step 1: Add AudioStreamPlayer nodes in `_ready()`**

After the existing audio node setup (after `land_sound` block, around line 80):

```gdscript
var dash_sound: AudioStreamPlayer = null
var double_jump_sound: AudioStreamPlayer = null
var pneuma_denied_sound: AudioStreamPlayer = null
var pneuma_low_sound: AudioStreamPlayer = null
```

Move these to the var declarations section (near top, around line 55). Then in `_ready()`:

```gdscript
dash_sound = AudioStreamPlayer.new()
dash_sound.stream = SfxGenerator.dash_whoosh()
dash_sound.volume_db = -4.0
add_child(dash_sound)

double_jump_sound = AudioStreamPlayer.new()
double_jump_sound.stream = SfxGenerator.double_jump_burst()
double_jump_sound.volume_db = -4.0
add_child(double_jump_sound)

pneuma_denied_sound = AudioStreamPlayer.new()
pneuma_denied_sound.stream = SfxGenerator.pneuma_denied()
pneuma_denied_sound.volume_db = -2.0
add_child(pneuma_denied_sound)

pneuma_low_sound = AudioStreamPlayer.new()
pneuma_low_sound.stream = SfxGenerator.pneuma_low_loop()
pneuma_low_sound.volume_db = -10.0
add_child(pneuma_low_sound)
```

**Step 2: Play denied sound on pneuma_denied signal**

Connect in `_ready()`:

```gdscript
pneuma_denied.connect(_on_pneuma_denied)
```

Add handler:

```gdscript
func _on_pneuma_denied() -> void:
	if pneuma_denied_sound:
		pneuma_denied_sound.play()
```

**Step 3: Play dash sound when dashing**

In `_start_dash()`, add after `dash_started.emit()`:

```gdscript
if dash_sound:
    dash_sound.play()
```

**Step 4: Play double jump sound**

In the double jump branch (where `has_double_jumped = true`), replace the jump_sound with:

```gdscript
if double_jump_sound:
    double_jump_sound.play()
```

**Step 5: Handle low Pneuma loop**

Add to `_physics_process`, after the speed_changed emit at the end:

```gdscript
# Low pneuma audio loop
var pneuma_percent: float = current_pneuma / max_pneuma
if pneuma_percent <= 0.2 and pneuma_percent > 0.0:
    if pneuma_low_sound and not pneuma_low_sound.playing:
        pneuma_low_sound.play()
elif pneuma_low_sound and pneuma_low_sound.playing:
    pneuma_low_sound.stop()
```

**Step 6: Verify**

Run the playground. Confirm:
- Dash plays a whoosh sound
- Double jump plays an air burst sound
- Attempting an action with insufficient Pneuma plays a buzz
- Below 20% Pneuma, a subtle heartbeat loop plays
- Above 20% Pneuma, the loop stops

**Step 7: Commit**

```bash
git add scripts/player/player_controller.gd
git commit -m "feat: wire pneuma audio cues into player controller"
```

---

## Task 6: Add `drops_pneuma` Flag to Enemy Base

**Files:**
- Modify: `scripts/enemies/enemy_base.gd`

**Step 1: Add the export flag and pneuma amount**

Add after the existing exports (after line 8):

```gdscript
@export_group("Pneuma")
@export var drops_pneuma: bool = true
@export var pneuma_drop_amount: float = 15.0
```

**Step 2: Update the `enemy_died` signal to include position**

The death signal currently passes `self`, but we'll also need the position for spawning the orb. The current signal `enemy_died(enemy: Node3D)` already passes the enemy node, so the receiver can read `enemy.global_position` and `enemy.drops_pneuma`. No change needed to the signal itself.

**Step 3: Commit**

```bash
git add scripts/enemies/enemy_base.gd
git commit -m "feat: add drops_pneuma flag to enemy base"
```

---

## Task 7: Create Pneuma Pickup Orb

**Files:**
- Create: `scripts/pickups/pneuma_pickup.gd`
- Create: `scenes/pneuma_pickup.tscn`

The Pneuma pickup extends the existing Area3D pickup pattern but adds magnetism behavior: orbs sit on the ground until the player enters a speed-scaled radius, then lerp toward the player.

**Step 1: Create `pneuma_pickup.gd`**

```gdscript
extends Area3D

@export var pneuma_amount: float = 15.0
@export var pickup_base_radius: float = 2.0
@export var pickup_speed_bonus_radius: float = 3.0
@export var magnetize_speed: float = 10.0
@export var bob_speed: float = 3.0
@export var bob_height: float = 0.15
@export var rotate_speed: float = 3.0

var is_magnetized: bool = false
var player: Node3D = null
var time: float = 0.0
var base_y: float = 0.0

var pickup_sound: AudioStreamPlayer3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	base_y = global_position.y
	time = randf() * TAU
	body_entered.connect(_on_body_entered)

	pickup_sound = AudioStreamPlayer3D.new()
	pickup_sound.stream = SfxGenerator.pneuma_pickup()
	pickup_sound.max_db = 8.0
	add_child(pickup_sound)

	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _process(delta: float) -> void:
	if is_magnetized and player:
		var dir: Vector3 = (player.global_position + Vector3.UP * 0.9 - global_position).normalized()
		global_position += dir * magnetize_speed * delta
		# Accelerate as it gets close for snappy feel
		magnetize_speed += delta * 40.0
		return

	if not player:
		return

	# Check magnetism radius based on player speed
	var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var max_speed: float = player.ground_speed
	var effective_radius: float = pickup_base_radius + (player_speed / max_speed) * pickup_speed_bonus_radius
	var dist: float = global_position.distance_to(player.global_position)

	if dist < effective_radius:
		is_magnetized = true
		return

	# Idle animation: bob and rotate
	time += delta
	if mesh:
		mesh.position.y = sin(time * bob_speed) * bob_height
		mesh.rotate_y(rotate_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("gain_pneuma"):
		body.gain_pneuma(pneuma_amount)
	if pickup_sound:
		# Reparent sound so it plays after orb is freed
		pickup_sound.reparent(get_tree().current_scene)
		pickup_sound.play()
		pickup_sound.finished.connect(pickup_sound.queue_free)
	queue_free()
```

**Step 2: Create `scenes/pneuma_pickup.tscn`**

This will need to be created in the Godot editor or via a .tscn text file. The scene structure:

```
PneumaPickup (Area3D)
  ├── MeshInstance3D (SphereMesh, light blue emissive material)
  └── CollisionShape3D (SphereShape3D, radius 0.3)
```

Write the .tscn file:

```tscn
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/pickups/pneuma_pickup.gd" id="1_pneuma"]

[sub_resource type="SphereMesh" id="SphereMesh_pneuma"]
radius = 0.2
height = 0.4

[sub_resource type="StandardMaterial3D" id="Mat_pneuma"]
albedo_color = Color(0.5, 0.85, 1.0, 1)
emission_enabled = true
emission = Color(0.3, 0.6, 1.0, 1)
emission_energy_multiplier = 2.0

[sub_resource type="SphereShape3D" id="SphereShape3D_pneuma"]
radius = 0.4

[node name="PneumaPickup" type="Area3D"]
collision_layer = 16
collision_mask = 2
script = ExtResource("1_pneuma")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("SphereMesh_pneuma")
surface_material_override/0 = SubResource("Mat_pneuma")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("SphereShape3D_pneuma")
```

**Step 3: Commit**

```bash
git add scripts/pickups/pneuma_pickup.gd scenes/pneuma_pickup.tscn
git commit -m "feat: create pneuma pickup orb with magnetism"
```

---

## Task 8: Spawn Pneuma Orbs on Enemy Death

**Files:**
- Modify: `scripts/enemies/grunt_ai.gd`

The grunt already has a `_die()` override. We need to spawn a pneuma orb at the enemy's feet before the fade-out begins.

**Step 1: Add pneuma orb spawn to `_die()`**

In `grunt_ai.gd`, modify `_die()`:

```gdscript
func _die() -> void:
	if drops_pneuma:
		_spawn_pneuma_orb()
	super._die()
	state = State.DEAD
	velocity = Vector3.ZERO

	# Fade out and free (existing code unchanged)
	var tween: Tween = create_tween()
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var original_mat: Material = mesh.get_surface_override_material(0)
		if original_mat:
			var mat: StandardMaterial3D = original_mat.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, mat)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _spawn_pneuma_orb() -> void:
	var scene: PackedScene = load("res://scenes/pneuma_pickup.tscn")
	if not scene:
		return
	var orb: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector3.UP * 0.3
	orb.pneuma_amount = pneuma_drop_amount
```

**Step 2: Verify**

Run the playground with enemies. Confirm:
- Killing a grunt spawns a glowing light-blue orb at its position
- The orb bobs and rotates
- Walking close to the orb magnetizes it toward the player
- Running past at speed grabs it from further away
- Collecting the orb restores 15 Pneuma
- A chime plays on collection

**Step 3: Commit**

```bash
git add scripts/enemies/grunt_ai.gd
git commit -m "feat: spawn pneuma orbs on enemy death"
```

---

## Task 9: Rework HUD — Move Bars to Top, Add Pneuma Bar

**Files:**
- Modify: `scripts/ui/hud.gd`
- Modify: `scenes/hud.tscn`

The HUD gets a significant rework: health bar (red) and pneuma bar (light blue) move to the top of the screen, stacked vertically, wider. The pneuma bar shows color transitions (blue > orange > red) and denial flash.

**Step 1: Update `hud.tscn` — Reposition health bar to top**

Update the HealthBar node position and size:
```
offset_left = 30.0     →  460.0
offset_top = 990.0     →  20.0
offset_right = 300.0   →  1460.0
offset_bottom = 1020.0 →  44.0
```

Update HealthTitle position:
```
offset_left = 30.0     →  460.0
offset_top = 965.0     →  2.0
offset_right = 300.0   →  540.0
offset_bottom = 990.0  →  20.0
```

Change HealthTitle font_color to red:
```
theme_override_colors/font_color = Color(0.9, 0.3, 0.3, 1)
```

**Step 2: Add Pneuma bar nodes to `hud.tscn`**

Add after the HealthTitle node:

```tscn
[node name="PneumaBar" type="ProgressBar" parent="."]
offset_left = 460.0
offset_top = 50.0
offset_right = 1460.0
offset_bottom = 74.0
mouse_filter = 2
value = 100.0
show_percentage = false

[node name="PneumaLabel" type="Label" parent="PneumaBar"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_font_sizes/font_size = 18
text = "100 / 100"
horizontal_alignment = 1
vertical_alignment = 1

[node name="PneumaTitle" type="Label" parent="."]
offset_left = 460.0
offset_top = 32.0
offset_right = 540.0
offset_bottom = 50.0
mouse_filter = 2
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.4, 0.75, 1.0, 1)
text = "PNEUMA"
```

**Step 3: Add Pneuma bar references and logic to `hud.gd`**

Add `@onready` vars:

```gdscript
@onready var pneuma_bar: ProgressBar = $PneumaBar
@onready var pneuma_label: Label = $PneumaBar/PneumaLabel
```

Add state vars for visual effects:

```gdscript
var pneuma_flash_timer: float = 0.0
var pneuma_pulse_timer: float = 0.0
```

**Step 4: Connect pneuma signals in `_connect_player()`**

After connecting speed_changed:

```gdscript
player.pneuma_changed.connect(_on_pneuma_changed)
player.pneuma_denied.connect(_on_pneuma_denied)

# Initial update
_on_pneuma_changed(player.current_pneuma, player.max_pneuma)
```

**Step 5: Add pneuma callback handlers**

```gdscript
func _on_pneuma_changed(current: float, maximum: float) -> void:
	if not pneuma_bar:
		return
	pneuma_bar.max_value = maximum
	pneuma_bar.value = current
	if pneuma_label:
		pneuma_label.text = "%d / %d" % [int(current), int(maximum)]

	# Color transitions based on percentage
	var percent: float = current / maximum
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
```

**Step 6: Add visual effect updates in `_process()`**

Add to `_process()`:

```gdscript
# Pneuma denial flash
if pneuma_flash_timer > 0.0:
    pneuma_flash_timer -= delta
    if pneuma_bar:
        var style: StyleBoxFlat = pneuma_bar.get("theme_override_styles/fill") as StyleBoxFlat
        if not style:
            style = StyleBoxFlat.new()
            pneuma_bar.add_theme_stylebox_override("fill", style)
        style.bg_color = Color(0.9, 0.15, 0.15)
elif player:
    # Restore correct color after flash
    _on_pneuma_changed(player.current_pneuma, player.max_pneuma)

# Pneuma low pulse (below 20%)
if player and pneuma_bar:
    var pct: float = player.current_pneuma / player.max_pneuma
    if pct <= 0.2 and pct > 0.0:
        pneuma_pulse_timer += delta * 4.0
        pneuma_bar.modulate.a = 0.7 + sin(pneuma_pulse_timer) * 0.3
    elif pct <= 0.0:
        pneuma_bar.modulate.a = 0.4  # Desaturated "dead" look
    else:
        pneuma_bar.modulate.a = 1.0
        pneuma_pulse_timer = 0.0
```

**Step 7: Also update the health bar to use a red StyleBox**

In `_ready()` or `_connect_player()`, set up the health bar with a red fill:

```gdscript
if health_bar:
    var health_style: StyleBoxFlat = StyleBoxFlat.new()
    health_style.bg_color = Color(0.85, 0.2, 0.2)
    health_bar.add_theme_stylebox_override("fill", health_style)
```

**Step 8: Update DashBar position (move it below pneuma bar)**

Update DashBar in the tscn:
```
offset_left = 860.0  →  460.0
offset_top = 1040.0  →  80.0
offset_right = 1060.0 → 1460.0
offset_bottom = 1055.0 → 90.0
```

Update DashLabel:
```
offset_left = 860.0  →  460.0
offset_top = 1020.0  →  90.0
offset_right = 1060.0 → 540.0
offset_bottom = 1040.0 → 108.0
```

**Step 9: Verify**

Run the playground. Confirm:
- Health bar is at top of screen, red, wide (1000px)
- Pneuma bar is directly below health, light blue, same width
- Pneuma bar shows "73/100" style numeric label
- Spending pneuma smoothly depletes the bar
- Below 30% the bar turns orange, below 15% turns red
- Denied action flashes the whole bar red for 0.2s
- Below 20% the bar gently pulses
- At 0% the bar looks dim/dead

**Step 10: Commit**

```bash
git add scripts/ui/hud.gd scenes/hud.tscn
git commit -m "feat: rework HUD with top-of-screen health and pneuma bars"
```

---

## Task 10: Add Floating Pickup Text

**Files:**
- Modify: `scripts/ui/hud.gd`

**Step 1: Add floating "+15" text on pneuma pickup**

Modify `_on_pneuma_changed` to detect gains and show floating text:

Add a state var:

```gdscript
var last_pneuma: float = 100.0
```

Update `_on_pneuma_changed`:

```gdscript
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

	# Color transitions (unchanged)
	var percent: float = current / maximum
	var style: StyleBoxFlat = pneuma_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		pneuma_bar.add_theme_stylebox_override("fill", style)
	if percent <= 0.15:
		style.bg_color = Color(0.9, 0.15, 0.15)
	elif percent <= 0.30:
		style.bg_color = Color(0.9, 0.6, 0.15)
	else:
		style.bg_color = Color(0.4, 0.75, 1.0)
```

**Step 2: Implement `_spawn_floating_text`**

```gdscript
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
```

**Step 3: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: add floating pickup text for pneuma gains"
```

---

## Task 11: Final Integration & Polish Pass

**Files:**
- All modified files (review pass)

**Step 1: Verify full gameplay loop**

Run the movement playground. Walk through this sequence:
1. Start with full Pneuma (100)
2. Dash several times — Pneuma depletes, whoosh sounds play
3. Double jump — Pneuma depletes, air burst sound plays
4. Wall jump — Pneuma depletes
5. Try to dash with insufficient Pneuma — denied buzz + red bar flash
6. Kill a grunt enemy — blue orb spawns
7. Run toward orb — it magnetizes at speed-scaled radius
8. Collect orb — chime plays, "+15" floats up, bar fills
9. Sprint past an orb at full speed — grabs from further away
10. Walk slowly past an orb — must be very close
11. Get below 20% Pneuma — heartbeat loop + bar pulsing
12. Slide while running — camera lowers, speed maintains ~1s, then slows
13. Release slide key — camera returns to normal
14. Verify base movement (sprint, single jump, bhop, air strafe) all work at 0 Pneuma

**Step 2: Check all `@export` values appear in inspector**

Open the Player scene in editor. Verify the Pneuma export group shows:
- max_pneuma
- pneuma_per_dash
- pneuma_per_double_jump
- pneuma_per_wall_jump

Open the enemy_grunt scene. Verify:
- drops_pneuma (checkbox, default true)
- pneuma_drop_amount (default 15)

**Step 3: Commit final state**

```bash
git add -A
git commit -m "feat: pneuma system integration complete"
```

---

## Dependency Order

```
Task 1 (Pneuma pool) ← Task 2 (Double jump) ← Task 5 (Audio wiring)
Task 1 ← Task 3 (Slide rework) — independent
Task 4 (SfxGenerator sounds) ← Task 5 (Audio wiring)
Task 6 (Enemy flag) ← Task 8 (Spawn orbs)
Task 7 (Pickup scene) ← Task 8 (Spawn orbs)
Task 9 (HUD rework) ← Task 10 (Floating text)
Task 11 (Final) depends on all above
```

Parallelizable groups:
- **Group A:** Task 1 → Task 2 → Task 3
- **Group B:** Task 4 (independent until Task 5)
- **Group C:** Task 6, Task 7 (independent of Group A)
- **Group D:** Task 9 (can start after Task 1 for signal definitions)
- **Merge:** Task 5, Task 8, Task 10 once dependencies are met
- **Final:** Task 11

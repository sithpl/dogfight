# Saucer.gd
class_name Saucer extends Area3D

# --- Horizonal rotation ---
@export var min_speed_y     : float = 180.0 # Minimum degrees/sec for Y axis rotation
@export var max_speed_y     : float = 360.0 # Maximum degrees/sec for Y axis rotation
@export var change_interval : float = 1.0   # How often to pick a new target speed (secs)
@export var transition_time : float = 0.25  # How long to smoothly move to the new speed (secs)

# --- Vertical rotation and bobbing ---
@export var rotation_tilt_x : float = 20.0 # Maximum tilt in degrees on X axis
@export var tilt_speed      : float = 1.0  # Tilt cycles per second
@export var bob_amplitude   : float = 1.0  # Vertical bob distance (world units)
@export var bob_speed       : float = 1.0  # Bob cycles per second

# --- Rotation state variables ---
var start_y     : float       # Initialize Y axis origin for rotation
var start_rot_x : float       # Initialize X axis origin for tilt
var time        : float = 0.0 # Initialize timer for X axis tilt

# --- Rotation speed smoothing ---
var current_speed_y  : float = 60.0
var prev_speed_y     : float = 60.0
var target_speed_y   : float = 60.0
var change_timer     : float = 0.0
var transition_timer : float = 0.0
var rng              : RandomNumberGenerator = RandomNumberGenerator.new()

# --- Unit death ---
@export var death_timer : float = 3.0
@onready var death_sfx : AudioStreamPlayer = $DeathSFX
var is_dying         : bool  = false
var death_fall_speed : float = 0.0

# --- Firing settings ---
@export var enemy_laser_scene : PackedScene     # Scene for the EnemyLaser shot (so it can be externally edited)
@export var fire_range        : float = 120.0   # Distance at which Saucer will start firing (world units)
@export var volley_count      : int   = 3       # Number of lasers per volley
@export var volley_spacing    : float = 0.12    # Time between each shot in a volley (secs)
@export var volley_cooldown   : float = 3.0     # Time between volleys (secs)
@export var gun_offsets       : Array = [Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]

# --- Firing state ---
var can_fire: bool = true
var player_node: Node3D = null

signal target_destroyed # Signal emitted when the target is destroyed (hit by a laser)

# Called once when scene starts
func _ready():
	add_to_group("Enemy")
	connect("area_entered", Callable(self, "_on_area_entered"))
	if self.has_signal("target_destroyed"):
		print("Saucer.gd -> target_destroyed signal ready...")
	
	start_y = transform.origin.y
	start_rot_x = rotation_degrees.x
	rng.randomize()

	# Initialize speeds within range
	current_speed_y = rng.randf_range(min_speed_y, max_speed_y)
	prev_speed_y = current_speed_y
	target_speed_y = current_speed_y
	change_timer = 0.0
	transition_timer = transition_time

# Called every frame
func _process(delta: float):
	if is_dying:
		death_fall_speed += 300.0 * delta        # Gravity-like acceleration
		translate(Vector3(0, -death_fall_speed * delta, 0))
		return

	# Simulate erratic Y rotation speed logic
	change_timer += delta
	if change_timer >= change_interval:
		change_timer -= change_interval
		# Pick a new random target speed
		prev_speed_y = current_speed_y
		target_speed_y = rng.randf_range(min_speed_y, max_speed_y)
		transition_timer = 0.0

	# Advance transition toward target
	if transition_timer < transition_time:
		transition_timer += delta
		var t: float = clamp(transition_timer / max(0.0001, transition_time), 0.0, 1.0)
		# Smoothstep-like easing for nicer change
		t = t * t * (3.0 - 2.0 * t)
		current_speed_y = lerp(prev_speed_y, target_speed_y, t)

	# Apply rotation around Y axis
	rotation_degrees.y += current_speed_y * delta

	# Tilt on X axis
	time += delta
	rotation_degrees.x = start_rot_x + sin(time * TAU * tilt_speed) * rotation_tilt_x

	# Bob up and down
	var tform: Transform3D = transform
	tform.origin.y = start_y + sin(time * TAU * bob_speed) * bob_amplitude
	transform = tform

	# Find Player node
	if player_node == null:
		var players := get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_node = players[0] as Node3D

	# Firing logic if Player node is found
	if player_node != null and can_fire:
		var dist: float = player_node.global_transform.origin.distance_to(global_transform.origin)
		if dist <= fire_range:
			can_fire = false
			# start the volley (don't await here so _process continues)
			_fire_volley(player_node)

# Fires a volley of enemy lasers toward the Player
func _fire_volley(player: Node3D):
	# Basic safety: ensure scene resource exists
	if enemy_laser_scene == null:
		#print("enemy_laser_scene not set on Saucer")
		can_fire = true
		return

	# Capture Player node position at the start of the volley (aim at collision box / center)
	var aim_pos: Vector3 = player.global_transform.origin

	# Spawn the requested number of shots
	for i in range(volley_count):
		var laser := enemy_laser_scene.instantiate() as Node3D
		if laser == null:
			continue
		#print("Spawned shots scale: ", laser.scale)

		# Add the laser to the tree immediately so it can use global coordinates safely.
		var root := get_tree().current_scene
		if root:
			root.add_child(laser)
		else:
			get_tree().get_root().add_child(laser)

		# Choose gun offset
		var offset_local: Vector3 = Vector3.ZERO
		if gun_offsets.size() > 0:
			offset_local = gun_offsets[i % gun_offsets.size()]

		# Compute spawn position in world space
		@warning_ignore("unused_variable")
		var spawn_pos: Vector3 = global_transform.origin + global_transform.basis * offset_local

		# Save instantiated EnemyLaser's scale, then position it and reapply the saved scale
		var saved_scale: Vector3 = laser.scale

		# Place Enemylaser at spawn_pos WITHOUT stomping its current basis
		laser.global_transform = Transform3D(laser.global_transform.basis, spawn_pos)

		# Rotate to face the aim target
		laser.look_at(aim_pos, Vector3.UP)

		# Reapply the saved scale so rotation didn't change visual size
		laser.scale = saved_scale

		#print("Fired shots scale: ", laser.scale)

		# Small random spread tweak so not every shot is identical
		laser.rotate_x(deg_to_rad(rng.randf_range(-2.0, 2.0)))
		laser.rotate_y(deg_to_rad(rng.randf_range(-4.0, 4.0)))

		# Spacing between shots in the volley
		if i < volley_count - 1:
			await get_tree().create_timer(volley_spacing).timeout

	# After volley, wait cooldown before allowing next volley
	await get_tree().create_timer(volley_cooldown).timeout

	# Re-check whether Player node is still in range, only allow firing again if they are still close.
	if player_node != null:
		var _d_after: float = player_node.global_transform.origin.distance_to(global_transform.origin)
		# Allow future volleys regardless
		can_fire = true
	else:
		can_fire = true

# Called when another object enters this targets's collision area
func _on_area_entered(area):
	#print("Saucer.gd -> _on_area_entered() called!")
	# If the colliding object belongs to the "Laser" group
	if area.is_in_group("Laser") and is_dying == false:
		# Emit the target_destroyed signal to notify listeners (Main.gd for scoring)
		target_destroyed.emit()
		print("Saucer.gd -> target_destroyed emitting!")
		# Play explosion sound
		death_sfx.play()
		# Remove (despawn) this target from the scene
		dramatic_death()

# Call this when the Saucer is killed
func dramatic_death():
	print("Saucer.gd -> dramatic_death() called!")
	if is_dying:
		return
	is_dying = true  #
	can_fire = false # Stop firing

	# Quick tilt (85 degrees on X) then long spin/roll while it falls
	var tilt_time := 0.2
	var fall_spin_time := 2.0

	var tw = create_tween()
	# Tilt forward on X quickly (makes it flip toward ground)
	tw.tween_property(self, "rotation_degrees:x", rotation_degrees.x + 85.0, tilt_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Then spin on Y and roll on Z over a few seconds (visual dramatic spin)
	tw.tween_property(self, "rotation_degrees:y", rotation_degrees.y + 720.0, fall_spin_time).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "rotation_degrees:z", rotation_degrees.z + 360.0, fall_spin_time).set_trans(Tween.TRANS_LINEAR)
	# Slightly scale down as it falls (like it's tumbling away)
	tw.tween_property(self, "scale", scale * 0.95, fall_spin_time).set_trans(Tween.TRANS_SINE)

	# Wait for tumbling tween
	await get_tree().create_timer(fall_spin_time).timeout

	# Play explosion sound
	death_sfx.play()

	# Set Mesh and CollisionShape3D invisible for explosion sound to finish
	$Mesh.visible = false
	$CollisionShape3D.visible = false

	# Wait for exported death_timer duration
	await get_tree().create_timer(death_timer).timeout

	# Despawn (free) unit
	queue_free()
	print("Saucer.gd -> Saucer removed!")

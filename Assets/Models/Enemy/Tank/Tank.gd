# Tank.gd
class_name Tank extends Area3D

# --- Rotation speed smoothing ---
var rng              : RandomNumberGenerator = RandomNumberGenerator.new()

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

# --- Signals ---
signal target_destroyed # Signal emitted when the target is destroyed (hit by a laser)

# Called once when scene starts
func _ready():
	# Verify target is in "Enemy" group so Player can find it
	add_to_group("Enemy")
	# Connect area_entered signal to _on_area_entered handler
	connect("area_entered", Callable(self, "_on_area_entered"))

func _process(_delta: float):
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
	#print("Tank.gd -> _on_area_entered() called!")
	# If the colliding object belongs to the "Laser" group
	if area.is_in_group("Laser"):
		# Emit the target_destroyed signal to notify listeners (Training.gd for scoring)
		target_destroyed.emit()
		# Remove (despawn) this target from the scene
		queue_free()
		#print("Targets.gd -> Target removed!")

# Tank.gd
class_name Tank extends Area3D

# --- Signals ---
signal target_destroyed # Signal emitted when the target is destroyed (hit by a laser)

# --- Modes ---
@export var spawn_mode  : int = mode_travel
const mode_travel  := 1
const mode_parked  := 2

# --- Movement / Pivoting settings ---
@export var move_speed  : float = 1.0   ## Speed when traveling forward (units/secs)
@export var pivot_speed : float = 0.0   ## Max pivot speed toward player (degrees/secs)
@export var scan_speed  : float = 15.0  ## Max pivot speed for scanning area when no player is detected (degrees/secs)

# --- Firing settings ---
@export var enemy_laser_scene : PackedScene     ## Scene for the EnemyLaser shot (so it can be externally edited)
@export var fire_range        : float = 60.0    ## Distance at which Tank will start firing (world units)
@export var firing_cone       : float = 90.0    ## Front field-of-view (FOV) used for shooting/detection (degrees)
@export var volley_count      : int   = 1       ## Number of lasers per volley
@export var volley_spacing    : float = 0.0     ## Time between each shot in a volley (secs)
@export var volley_cooldown   : float = 3.0     ## Time between volleys (secs)
@export var gun_offsets       : Array = [       ## Offset of EnemyLaser spawn point on model
	Vector3(-1.0, 0.0, 0.0), # X
	Vector3(0.0, 0.0, 0.0),  # Y
	Vector3(1.0, 0.0, 0.0)]  # Z

# --- States ---
var can_fire    : bool = true
var player_node : Node3D = null
var rng         : RandomNumberGenerator = RandomNumberGenerator.new()

# --- Firing range/zone debug  ---
@export var debug_draw     : bool  = true                    ## True = Draws the fire_range and firing_cone around the model
@export var debug_color    : Color = Color(0.962, 0.0, 0.52, 0.902)  ## Sets the color of the debug frame
@export var debug_segments : int   = 24                      ## TODO

# --- Debug instances (ArrayMesh + MeshInstance3D) ---
var debug_root   : Node3D         = null
var debug_circle : MeshInstance3D = null
var debug_cone   : MeshInstance3D = null

# Called once when scene starts
func _ready():
	add_to_group("Enemy")
	connect("area_entered", Callable(self, "_on_area_entered"))
	rng.randomize()
	
	#if self.has_signal("target_destroyed"):
		#print("Tank.gd -> target_destroyed signal ready...")

	if debug_draw:
		_create_debug_frame()
		# Initial update deferred to ensure debug_root is in the tree
		call_deferred("_update_debug_frame")

# Called every frame
func _process(_delta: float):
	# Cache the Player node (first found in group "Player")
	if player_node == null:
		var players: Array = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_node = players[0] as Node3D

	# Firing logic: only fire if player is in FOV and within range
	if player_node != null and can_fire and self.is_visible_in_tree():
		if _is_player_in_fov(player_node):
			can_fire = false
			_fire_volley(player_node)

	# Update debug gizmo each frame (so it follows the Tank's world position)
	if debug_draw:
		_update_debug_frame()

func _physics_process(delta: float):
	if spawn_mode == mode_travel:
		# Move forward in the direction the Tank is facing (Godot forward = -Z)
		var forward: Vector3 = -global_transform.basis.z.normalized()
		# Move in global space by translating along that forward vector
		global_translate(forward * move_speed * delta)
		# Do NOT rotate toward player while traveling

	elif spawn_mode == mode_parked:
		# Stay in place and pivot (yaw) to face the player if present
		if player_node != null:
			var to_player: Vector3 = player_node.global_transform.origin - global_transform.origin
			to_player.y = 0.0
			if to_player.length() > 0.001:
				to_player = to_player.normalized()
				var current_forward: Vector3 = -global_transform.basis.z
				current_forward.y = 0.0
				current_forward = current_forward.normalized()

				var current_yaw: float = atan2(current_forward.x, current_forward.z)
				var target_yaw: float  = atan2(to_player.x, to_player.z)

				var max_delta_rad: float = deg_to_rad(pivot_speed) * delta
				var yaw_delta: float = _wrap_angle_shortest(target_yaw - current_yaw)
				var step: float = clamp(yaw_delta, -max_delta_rad, max_delta_rad)
				rotate_y(step)
		else:
			# No player found: perform slow scan
			rotate_y(deg_to_rad(scan_speed) * delta)

func _wrap_angle_shortest(angle: float):
	var a = fmod(angle + PI, TAU)
	if a < 0.0:
		a += TAU
	return a - PI

func spawn_tank(mode: int):
	# Call this when instantiating a Tank
	# Mode = 1 -> Travel forward (no pivot), fire at player when inside front FOV
	# Mode = 2 -> Remain in place and pivot toward player, fire when inside front FOV
	if mode != mode_travel and mode != mode_parked:
		push_warning("spawn_tank: invalid mode %s, defaulting to mode_travel" % str(mode))
		spawn_mode = mode_travel
	else:
		spawn_mode = mode

# Checks whether the player is inside the Tank's forward cone AND within fire_range
func _is_player_in_fov(player: Node3D):
	if player == null:
		return false
	var to_player: Vector3 = player.global_transform.origin - global_transform.origin
	var distance: float = to_player.length()
	if distance > fire_range:
		return false
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var dir: Vector3 = to_player.normalized()
	var dot_val: float = clamp(forward.dot(dir), -1.0, 1.0)
	var angle_rad: float = acos(dot_val)
	return angle_rad <= deg_to_rad(firing_cone * 0.5)

# Fires a volley of enemy lasers toward the Player (unchanged)
func _fire_volley(player: Node3D):
	if enemy_laser_scene == null:
		can_fire = true
		return

	var aim_pos: Vector3 = player.global_transform.origin

	for i in range(volley_count):
		var laser := enemy_laser_scene.instantiate() as Node3D
		if laser == null:
			continue

		var root := get_tree().current_scene
		if root:
			root.add_child(laser)
		else:
			get_tree().get_root().add_child(laser)

		var offset_local: Vector3 = Vector3.ZERO
		if gun_offsets.size() > 0:
			offset_local = gun_offsets[i % gun_offsets.size()]

		var spawn_pos: Vector3 = global_transform.origin + global_transform.basis * offset_local
		var saved_scale: Vector3 = laser.scale
		laser.global_transform = Transform3D(laser.global_transform.basis, spawn_pos)
		laser.look_at(aim_pos, Vector3.UP)
		laser.scale = saved_scale

		laser.rotate_x(deg_to_rad(rng.randf_range(-2.0, 2.0)))
		laser.rotate_y(deg_to_rad(rng.randf_range(-4.0, 4.0)))

		if i < volley_count - 1:
			await get_tree().create_timer(volley_spacing).timeout

	await get_tree().create_timer(volley_cooldown).timeout
	can_fire = true

# Called when another object enters this targets's collision area
func _on_area_entered(area):
	if area.is_in_group("Laser"):
		target_destroyed.emit()
		#print("Tank.gd -> target_destroyed emitting!")
		queue_free()

# Debug frame using ArrayMesh + MeshInstance3D (world-scale; doesn't inherit model scale)
func _create_debug_frame():
	if debug_root != null:
		return
	debug_root = Node3D.new()
	debug_root.name = "Frame_Debug"

	# Parent debug_root to the current scene so it won't inherit Tank/model scale
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().get_root()
	# Use deferred add to avoid "Parent node is busy setting up children" error
	scene_root.call_deferred("add_child", debug_root)

	debug_circle = MeshInstance3D.new()
	debug_cone = MeshInstance3D.new()

	debug_root.add_child(debug_circle)
	debug_root.add_child(debug_cone)

	# Unshaded material that uses vertex colors
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	#mat.unshaded = true
	mat.vertex_color_use_as_albedo = true
	debug_circle.material_override = mat
	debug_cone.material_override = mat

func _update_debug_frame():
	if debug_root == null:
		return

	# Update debug_root global_transform to match Tank position/orientation but with scale = 1.0
	var clean_basis: Basis = global_transform.basis.orthonormalized()
	debug_root.global_transform = Transform3D(clean_basis, global_transform.origin)

	# Build circle lines (PRIMITIVE_LINES). Each segment is a line between two points.
	var segs: int = max(8, debug_segments)
	var circle_vertices: PackedVector3Array = PackedVector3Array()
	var circle_colors: PackedColorArray = PackedColorArray()

	for s in range(segs):
		var a0: float = TAU * float(s) / float(segs)
		var a1: float = TAU * float(s + 1) / float(segs)
		var p0: Vector3 = Vector3(sin(a0) * fire_range, 0.0, cos(a0) * fire_range)
		var p1: Vector3 = Vector3(sin(a1) * fire_range, 0.0, cos(a1) * fire_range)
		circle_vertices.append(p0)
		circle_vertices.append(p1)
		circle_colors.append(debug_color)
		circle_colors.append(debug_color)

	var circle_mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = circle_vertices
	arrays[Mesh.ARRAY_COLOR] = circle_colors
	circle_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	debug_circle.mesh = circle_mesh

	# Build cone boundary lines (origin -> left, origin -> right) + a few spokes
	var cone_vertices: PackedVector3Array = PackedVector3Array()
	var cone_colors: PackedColorArray = PackedColorArray()

	var half: float = deg_to_rad(firing_cone * 0.5)
	var left_dir: Vector3 = Vector3(sin(-half), 0.0, -cos(-half)).normalized() * fire_range
	var right_dir: Vector3 = Vector3(sin(half), 0.0, -cos(half)).normalized() * fire_range

	# Boundaries
	cone_vertices.append(Vector3.ZERO)
	cone_vertices.append(left_dir)
	cone_colors.append(debug_color)
	cone_colors.append(debug_color)

	cone_vertices.append(Vector3.ZERO)
	cone_vertices.append(right_dir)
	cone_colors.append(debug_color)
	cone_colors.append(debug_color)

	# Spokes inside cone
	var spoke_count: int = clamp(int(float(segs) / 6.0), 1, 12)
	for k in range(spoke_count):
		var t: float = float(k) / float(max(1, spoke_count - 1))
		var angle: float = -half + t * (half * 2.0)
		var dir: Vector3 = Vector3(sin(angle), 0.0, -cos(angle)).normalized() * fire_range
		cone_vertices.append(Vector3.ZERO)
		cone_vertices.append(dir)
		cone_colors.append(debug_color)
		cone_colors.append(debug_color)

	var cone_mesh: ArrayMesh = ArrayMesh.new()
	var arr2: Array = []
	arr2.resize(Mesh.ARRAY_MAX)
	arr2[Mesh.ARRAY_VERTEX] = cone_vertices
	arr2[Mesh.ARRAY_COLOR] = cone_colors
	cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr2)
	debug_cone.mesh = cone_mesh

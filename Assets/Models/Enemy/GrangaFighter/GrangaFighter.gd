# GrangaFighter.gd
class_name GrangaFighter extends Area3D

# --- Signals ---
signal target_destroyed # Signal emitted when the target is destroyed (hit by a laser)

# --- Path follow settings ---
@export var path_follow_node_path : NodePath = NodePath("")  ## PathFollow3D reference
@export var parent_to_path        : bool = true  ## If true, this node will become a child of the PathFollow3D (simplest)
@export var use_unit_offset       : bool = true  ## True -> use unit_offset (0..1), false -> use offset (world units)
@export var start_offset          : float = 0.0  ## Initial offset or unit_offset
@export var follow_speed          : float = 0.2  ## Speed in unit_offset/sec if use_unit_offset, otherwise units/sec for offset

# --- Runtime references ---
@onready var _path_follow : PathFollow3D = null

# --- Firing settings ---
@export var enemy_laser_scene : PackedScene = preload("res://Scenes/EnemyLaser.tscn") ## Scene for the EnemyLaser shot (so it can be externally edited)
@export var fire_range        : float = 50.0    ## Distance at which Tank will start firing (world units)
@export var firing_cone       : float = 30.0    ## Front field-of-view (FOV) used for shooting/detection (degrees)
@export var volley_count      : int   = 2       ## Number of lasers per volley
@export var volley_spacing    : float = 0.25    ## Time between each shot in a volley (secs)
@export var volley_cooldown   : float = 1.0     ## Time between volleys (secs)
@export var gun_offsets       : Array = [       ## Offset of EnemyLaser spawn point on model (local space)
	Vector3(-1.0, 0.0, 0.0), # X
	Vector3(0.0, 0.0, 0.0),  # Y
	Vector3(1.0, 0.0, 0.0)]  # Z

# --- States ---
var can_fire    : bool   = true
var player_node : Node3D = null
var rng         : RandomNumberGenerator = RandomNumberGenerator.new()

# --- Firing range/zone debug  ---
@export var debug_draw     : bool  = true                    ## True = Draws the fire_range and firing_cone around the model
@export var debug_color    : Color = Color(0.0, 0.638, 0.865, 0.9)  ## Sets the color of the debug frame
@export var debug_segments : int   = 24                      ## TODO

# --- Debug instances (ArrayMesh + MeshInstance3D) ---
var debug_root   : Node3D         = null
var debug_circle : MeshInstance3D = null
var debug_cone   : MeshInstance3D = null

func _ready():
	#print("[GrangaFighter] ready -> Parent = ", get_parent(), "; Global = ", global_transform)
	#print("[GrangaFighter] ready -> enemy_laser_scene = ", enemy_laser_scene, "; volley_count = ", volley_count, "; fire_range = ", fire_range)

	add_to_group("Enemy")

	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))

	rng.randomize()

	#if self.has_signal("target_destroyed"):
		#print("GrangaFighter.gd -> target_destroyed signal ready...")

	if path_follow_node_path != NodePath(""):
		_path_follow = get_node_or_null(path_follow_node_path) as PathFollow3D
		if _path_follow != null:
			_path_follow.loop = true
			if use_unit_offset:
				_path_follow.unit_offset = fmod(start_offset, 1.0)
			else:
				_path_follow.offset = start_offset
			if parent_to_path and get_parent() != _path_follow:
				var old_parent = get_parent()
				old_parent.remove_child(self)
				_path_follow.add_child(self)
				transform = Transform3D()

	if debug_draw:
		_create_debug_frame()
		_update_debug_frame()

func _process(_delta: float):
	#print_verbose("[GrangaFighter] process -> Visible = ", is_visible_in_tree(), "; can_fire = ", can_fire)
	# cache player
	if player_node == null:
		var players: Array = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_node = players[0] as Node3D

	if player_node != null and can_fire and is_visible_in_tree():
		if _is_player_in_fov(player_node):
			can_fire = false
			_fire_volley(player_node)

	if debug_draw:
		_update_debug_frame()

func _physics_process(delta: float):
	if _path_follow == null:
		return
	if use_unit_offset:
		_path_follow.unit_offset = fmod(_path_follow.unit_offset + follow_speed * delta, 1.0)
	else:
		_path_follow.offset += follow_speed * delta
	if not parent_to_path:
		global_transform = _path_follow.global_transform

func _is_player_in_fov(player: Node3D):
	if player == null:
		return false
	var to_player: Vector3 = player.global_transform.origin - global_transform.origin
	var dist = to_player.length()
	#print("[GrangaFighter] to_player =", to_player, " dist =", dist)

	if dist > fire_range:
		#print("[GrangaFighter] out of range (fire_range =", fire_range, ")")
		return false

	var forward: Vector3 = -global_transform.basis.z.normalized()
	var dir: Vector3 = to_player.normalized()
	var dotp: float = clamp(forward.dot(dir), -1.0, 1.0)
	var angle_rad: float = acos(dotp)
	var _angle_deg: float = rad_to_deg(angle_rad)
	#print("[GrangaFighter] forward =", forward, " dir =", dir, " dot =", dotp, " angle_deg =", angle_deg)

	return angle_rad <= deg_to_rad(firing_cone * 0.5)

func _fire_volley(player: Node3D):
	if enemy_laser_scene == null:
		can_fire = true
		return
	var aim_pos: Vector3 = player.global_transform.origin
	for i in range(volley_count):
		var laser = enemy_laser_scene.instantiate()
		if laser == null:
			continue
		var root: Node = get_tree().current_scene
		if root:
			root.add_child(laser)
		else:
			get_tree().get_root().add_child(laser)

		var offset_local: Vector3
		if gun_offsets.size() > 0:
			offset_local = gun_offsets[i % gun_offsets.size()]
		else:
			offset_local = Vector3.ZERO

		var spawn_pos: Vector3 = global_transform.origin + global_transform.basis * offset_local
		if laser is Node3D:
			var l3: Node3D = laser as Node3D
			l3.global_transform = Transform3D(l3.global_transform.basis, spawn_pos)
			l3.look_at(aim_pos, Vector3.UP)
		if i < volley_count - 1:
			await get_tree().create_timer(volley_spacing).timeout
	await get_tree().create_timer(volley_cooldown).timeout
	can_fire = true

func _on_area_entered(area):
	if area.is_in_group("Laser"):
		target_destroyed.emit()
		#print("GrangaFighter.gd -> target_destroyed emitting!")
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

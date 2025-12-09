# Path3DController.gd
class_name Path3DController extends Path3D

@export var model_scene: PackedScene # Which model to place on each PathFollow3D (set in the inspector; can be any PackedScene)
@export var model_scale: float = 0.02 # Scale to apply to instantiated models
@export var spawn_count: int = 0 # If there are no PathFollow3D children, optionally create 'spawn_count' of them
@export var create_missing_follows: bool = true
@export var instantiate_models: bool = true # Whether to instantiate the model_scene as a child of each PathFollow3D
@export var use_unit_offset: bool = true
@export var start_offset: float = 0.0
@export var spacing: float = 0.0
@export var follow_speed: float = 0.2
@export var loop_path: bool = true # Toggle path looping for PathFollow3D children
@export var auto_spawn_on_ready: bool = true # Automatically gather/create PathFollow3D children and spawn models on ready?
@export var model_rotation_offset: Vector3 = Vector3.ZERO

var pf_nodes: Array = []
var distances: Array = []
var baked_points: Array = []
var baked_cumulative: Array = []
var path_length: float = 0.0

const FACING_DELTA: float = 0.1

func _ready():
	_gather_or_create_path_follows()
	_build_baked_cache()
	if auto_spawn_on_ready:
		spawn_models()

func _gather_or_create_path_follows():
	pf_nodes.clear()
	for child in get_children():
		if child is PathFollow3D:
			pf_nodes.append(child)

	if pf_nodes.size() == 0 and create_missing_follows and spawn_count > 0:
		for i in range(spawn_count):
			var pf: PathFollow3D = PathFollow3D.new()
			pf.name = "PathFollow_%d" % i
			add_child(pf)
			pf_nodes.append(pf)

func _build_baked_cache():
	baked_points.clear()
	baked_cumulative.clear()
	path_length = 0.0

	if curve == null:
		push_warning("Path3DController: Path3D.curve is null; cannot build baked cache.")
		return

	if curve.has_method("get_baked_points"):
		baked_points = curve.get_baked_points()
	else:
		if curve.has_method("interpolate"):
			var pts: Array = []
			var steps: int = 200
			for s in range(steps + 1):
				var t: float = float(s) / float(steps)
				pts.append(curve.interpolate(t))
			baked_points = pts
		else:
			push_warning("Path3DController: curve has no get_baked_points and no interpolate method; baked cache empty.")
			baked_points = []
			return

	if baked_points.size() == 0:
		push_warning("Path3DController: baked point cache is empty.")
		return

	baked_cumulative.resize(baked_points.size())
	var cum: float = 0.0
	baked_cumulative[0] = 0.0
	for i in range(1, baked_points.size()):
		var d: float = baked_points[i].distance_to(baked_points[i - 1])
		cum += d
		baked_cumulative[i] = cum
	path_length = baked_cumulative[baked_cumulative.size() - 1]

	if path_length <= 0.0:
		push_warning("Path3DController: baked curve length is zero.")

func spawn_models():
	distances.clear()

	if pf_nodes.size() == 0:
		push_warning("Path3DController.spawn_models: no PathFollow3D nodes found")
		return

	_build_baked_cache()
	if baked_points.size() == 0:
		push_warning("Path3DController.spawn_models: no baked points available; aborting spawn.")
		return

	for i in range(pf_nodes.size()):
		var pf: PathFollow3D = pf_nodes[i] as PathFollow3D
		if pf == null:
			distances.append(0.0)
			continue

		pf.loop = loop_path

		if use_unit_offset:
			var initial_unit: float = start_offset + float(i) * spacing
			var frac: float = initial_unit - floor(initial_unit)
			distances.append(frac * path_length)
		else:
			distances.append(start_offset + float(i) * spacing)

		if instantiate_models and model_scene != null:
			if pf.get_child_count() == 0:
				var inst: Node3D = model_scene.instantiate() as Node3D
				if inst:
					# Add instance as a child first (this will queue _enter_tree/_ready for the instance)
					pf.add_child(inst)

					# Ensure instance scale and transform are set after the instance runs its own _ready
					# Use call_deferred so that the instance's _ready/_enter_tree finish first.
					inst.call_deferred("set", "scale", Vector3.ONE * model_scale)

					# Set initial position + orientation deferred to avoid racing with instance's own _ready
					var idx := pf_nodes.find(pf)
					if idx >= 0:
						var dist_now: float = distances[idx]
						var pos: Vector3 = _sample_curve_at_distance(dist_now)
						var ahead_pos: Vector3 = _sample_curve_at_distance(dist_now + FACING_DELTA)
						var local_tr: Transform3D = _build_local_transform(pos, ahead_pos)
						# convert local (Path3D) transform to global by multiplying Path3D.global_transform
						var target_global: Transform3D = global_transform * local_tr
						# defer applying the global transform (avoids overwriting instance initialization)
						if inst.has_method("set_global_transform"):
							inst.call_deferred("set_global_transform", target_global)
						else:
							# Generic deferred property set if set_global_transform not present
							inst.call_deferred("set", "global_transform", target_global)
			else:
				if pf.get_child_count() > 0:
					var existing := pf.get_child(0)
					if existing is Node3D:
						(existing as Node3D).scale = Vector3.ONE * model_scale

func _sample_curve_at_distance(dist: float) -> Vector3:
	if baked_points.size() == 0:
		return global_transform.origin

	if loop_path and path_length > 0.0:
		dist = fmod(dist, path_length)
		if dist < 0.0:
			dist += path_length
	else:
		dist = clamp(dist, 0.0, path_length)

	var lo: int = 0
	var hi: int = baked_cumulative.size() - 1
	while lo <= hi:
		var mid: int = (lo + hi) >> 1
		if baked_cumulative[mid] <= dist:
			lo = mid + 1
		else:
			hi = mid - 1
	var idx: int = clamp(hi, 0, baked_cumulative.size() - 1)

	if idx >= baked_points.size() - 1:
		return baked_points[baked_points.size() - 1]

	var d0: float = baked_cumulative[idx]
	var d1: float = baked_cumulative[idx + 1]
	var p0: Vector3 = baked_points[idx]
	var p1: Vector3 = baked_points[idx + 1]

	if is_equal_approx(d1, d0):
		return p0

	var t: float = (dist - d0) / (d1 - d0)
	return p0.lerp(p1, t)

# helper to build a local transform (Path3D-space) that faces from pos to ahead_pos
func _build_local_transform(pos: Vector3, ahead_pos: Vector3) -> Transform3D:
	var forward: Vector3 = (ahead_pos - pos)
	if forward.length() < 0.0001:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()

	var up: Vector3 = Vector3.UP
	if abs(forward.dot(up)) > 0.999:
		up = Vector3(0, 0, 1)

	var right: Vector3 = up.cross(forward)
	if right.length() < 0.0001:
		right = Vector3(1, 0, 0)
	right = right.normalized()

	var corrected_up: Vector3 = forward.cross(right).normalized()

	var basis: Basis = Basis(right, -corrected_up, forward)

	var rot_deg: Vector3 = model_rotation_offset
	var rot_rad: Vector3 = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var rot_x: Basis = Basis(Vector3(1, 0, 0), rot_rad.x)
	var rot_y: Basis = Basis(Vector3(0, 1, 0), rot_rad.y)
	var rot_z: Basis = Basis(Vector3(0, 0, 1), rot_rad.z)
	var rot_offset_basis: Basis = rot_x * rot_y * rot_z

	var final_basis: Basis = basis * rot_offset_basis

	var tr: Transform3D = Transform3D()
	tr.basis = final_basis
	tr.origin = pos
	return tr

func _physics_process(delta: float):
	if pf_nodes.size() == 0:
		return
	if baked_points.size() == 0 or path_length <= 0.0:
		return

	for i in range(pf_nodes.size()):
		var pf: PathFollow3D = pf_nodes[i] as PathFollow3D
		if pf == null:
			continue

		var delta_distance: float
		if use_unit_offset:
			delta_distance = follow_speed * delta * path_length
		else:
			delta_distance = follow_speed * delta

		var new_dist: float = distances[i] + delta_distance

		if loop_path:
			new_dist = fmod(new_dist, path_length)
			if new_dist < 0.0:
				new_dist += path_length
		else:
			new_dist = clamp(new_dist, 0.0, path_length)

		distances[i] = new_dist

		var model_node: Node3D = null
		if pf.get_child_count() > 0:
			var c = pf.get_child(0)
			if c is Node3D:
				model_node = c as Node3D

		if model_node == null:
			continue

		var pos: Vector3 = _sample_curve_at_distance(new_dist)
		var ahead_dist: float = new_dist + FACING_DELTA
		var ahead_pos: Vector3 = _sample_curve_at_distance(ahead_dist)

		var local_tr: Transform3D = _build_local_transform(pos, ahead_pos)

		# IMPORTANT: convert Path3D-local transform to world/global transform
		model_node.global_transform = global_transform * local_tr

		# enforce scale so it's preserved regardless of transform assignment
		model_node.scale = Vector3.ONE * model_scale

func clear_instantiated_models():
	for pf in pf_nodes:
		if pf is Node:
			for child in pf.get_children():
				child.queue_free()
	distances.clear()
	baked_points.clear()
	baked_cumulative.clear()
	path_length = 0.0

# ChargedLaser.gd
class_name ChargedLaser extends Area3D

# --- Gameplay settings ---
@export var speed                 : float = 100.0
@export var turn_speed            : float = 180.0      # max turn rate in DEGREES per second (tune for feel)
@export var life_time             : float = 1.5
@export var pulse_speed           : float = 6.0
@export var base_emission_energy  : float = 2.0
@export var homing_min_distance   : float = 0.6

# --- Node settings ---
@onready var orb_mesh    : MeshInstance3D  = $Orb
@onready var glow_light  : OmniLight3D     = $GlowLight

# --- Game state variables ---
var target             : Node3D              = null
var initial_direction  : Vector3             = Vector3(0, 0, -1)
var charge_strength    : float               = 1.0
var life_timer         : float               = 0.0
var material           : StandardMaterial3D  = null

# movement bookkeeping to detect tunneling
var _prev_pos          : Vector3 = Vector3.ZERO

# Called once when scene starts
func _ready():
	# Ensure collision signals connected
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	_prev_pos = global_transform.origin

# Use physics process for movement & collision checks to avoid missed collisions
func _physics_process(delta: float) -> void:
	life_timer += delta
	if life_timer >= life_time:
		queue_free()
		return

	# Pulse emission/light
	var pulse = 0.5 + 0.5 * sin(life_timer * pulse_speed)
	if material:
		material.emission_energy = base_emission_energy * max(0.2, charge_strength) * (0.8 + 0.6 * pulse)
	if glow_light:
		glow_light.light_energy = 0.5 * charge_strength * (0.8 + 0.6 * pulse)

	# current forward direction in world space
	var forward = -global_transform.basis.z.normalized()
	var new_dir : Vector3

	if target and is_instance_valid(target):
		var to_target = target.global_transform.origin - global_transform.origin
		var dist = to_target.length()
		if dist <= homing_min_distance:
			# close enough -> impact
			_on_hit_target(target)
			return

		var desired = to_target / dist

		# compute angle between forward and desired (clamp for numerical safety)
		var dot = clamp(forward.dot(desired), -1.0, 1.0)
		var angle_between = acos(dot) # radians

		# max turn this frame (turn_speed interpreted as degrees/sec)
		var max_turn = deg_to_rad(turn_speed) * delta

		if angle_between <= 1e-5:
			new_dir = desired
		else:
			var turn_angle = angle_between
			if turn_angle > max_turn:
				turn_angle = max_turn
			# rotation axis
			var axis = forward.cross(desired)
			if axis.length() < 1e-6:
				axis = forward.cross(Vector3.UP)
				if axis.length() < 1e-6:
					axis = forward.cross(Vector3.RIGHT)
			axis = axis.normalized()
			var q = Quaternion(axis, turn_angle)
			# rotate using Basis(q)
			new_dir = (Basis(q) * forward).normalized()
	else:
		# No target: move along initial_direction treated as local-space direction
		new_dir = (global_transform.basis * initial_direction).normalized()

	# compute candidate new position
	var move_vec = new_dir * speed * charge_strength * delta
	var from_pos = _prev_pos
	var to_pos = global_transform.origin + move_vec

	# Raycast sweep to detect tunneling (detect collider between prev and new position)
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from_pos
	params.to = to_pos
	params.exclude = [self]
	# optionally set collision_mask if desired
	var hit = space.intersect_ray(params)
	if hit and hit.has("collider"):
		var col = hit["collider"]
		# ignore other lasers, handle only targetable collisions
		if not col.is_in_group("Laser"):
			_on_hit_target(col)
			return

	# apply movement (physics step)
	global_transform = Transform3D(global_transform.basis, to_pos)

	# visual orientation decoupled from physics movement
	if new_dir.length() > 0.001:
		look_at(global_transform.origin + new_dir, Vector3.UP)

	_prev_pos = global_transform.origin

func set_charge_strength(s: float):
	charge_strength = clamp(s, 0.0, 2.0)

func set_target(node: Node):
	if node and is_instance_valid(node):
		if node is Node3D:
			target = node
		else:
			var p = node.get_parent()
			if p and p is Node3D:
				target = p

func set_initial_direction(dir: Vector3):
	if dir.length() > 0.001:
		initial_direction = dir.normalized()

func _update_visuals():
	if orb_mesh:
		var s = lerp(0.7, 1.6, clamp(charge_strength, 0.0, 1.0))
		orb_mesh.scale = Vector3.ONE * s
	if glow_light:
		glow_light.light_energy = 0.5 * charge_strength * base_emission_energy
		glow_light.omni_range = 1.5 * orb_mesh.scale.x

func _on_area_entered(area):
	# On hitting anything, despawn (but ignore "Laser" group)
	if not area.is_in_group("Laser"):
		_on_hit_target(area)

func _on_body_entered(body):
	# Also handle collisions with PhysicsBody3D (StaticBody3D, RigidBody3D, etc.)
	if not body.is_in_group("Laser"):
		_on_hit_target(body)

# Centralized hit handling: accept collider or its ancestor Node3D as the logical target
func _on_hit_target(collider: Object) -> void:
	var hit_node: Node = null
	if collider is Node3D:
		hit_node = collider
	else:
		# if collider is a CollisionShape or other object, try its owner/parent
		if collider is Object:
			# try to get node (some intersections return PhysicsDirectSpaceState shapes, but intersect_ray returns 'collider' Node)
			# fallback: attempt parent chain if collider has get_parent()
			if "get_parent" in collider:
				var p = collider.get_parent()
				if p and p is Node3D:
					hit_node = p

	# If we found a node, optionally notify it (damage) before freeing
	if hit_node and is_instance_valid(hit_node):
		if hit_node.has_method("apply_damage"):
			hit_node.apply_damage(100)
	# free the laser
	queue_free()

# ChargedLaser.gd
class_name ChargedLaser extends Area3D

# --- Gameplay settings ---
@export var speed                : float = 100.0 # Default speed of charged laser projectile
@export var turn_speed           : float = 360.0 # Max turn rate in degrees per sec
@export var life_time            : float = 1.0   # How long the projectile lasts on screen
@export var pulse_speed          : float = 6.0   # Pulsing light effect on projectile (broken)
@export var base_emission_energy : float = 2.0   # Light emission effect on projectile (broken?)
@export var homing_min_distance  : float = 0.1   # Minimum distance for homing logic

# --- Node settings ---
@onready var orb_mesh    : MeshInstance3D  = $Orb
@onready var glow_light  : OmniLight3D     = $GlowLight

# --- Game state variables ---
var target             : Node3D              = null
var initial_direction  : Vector3             = Vector3(0, 0, -1)
var charge_strength    : float               = 1.0
var life_timer         : float               = 0.0
var material           : StandardMaterial3D  = null
var _prev_pos          : Vector3             = Vector3.ZERO # Movement checking to detect tunneling issue

# Called once when scene starts
func _ready():
	# Verify collision signals connected
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	_prev_pos = global_transform.origin

# Movement & collision checks to avoid missed collisions
func _physics_process(delta: float):
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

	# Current forward direction in world space
	var forward = -global_transform.basis.z.normalized()
	var new_dir : Vector3

	if target and is_instance_valid(target):
		var to_target = target.global_transform.origin - global_transform.origin
		var dist = to_target.length()
		if dist <= homing_min_distance:
			# Close enough -> impact
			_on_hit_target(target)
			return

		var desired = to_target / dist

		# Detect angle between forward and desired
		var dot = clamp(forward.dot(desired), -1.0, 1.0)
		var angle_between = acos(dot) # radians

		# Max turn this frame (turn_speed interpreted as degrees/sec)
		var max_turn = deg_to_rad(turn_speed) * delta

		if angle_between <= 1e-5:
			new_dir = desired
		else:
			var turn_angle = angle_between
			if turn_angle > max_turn:
				turn_angle = max_turn
			# Rotation axis
			var axis = forward.cross(desired)
			if axis.length() < 1e-6:
				axis = forward.cross(Vector3.UP)
				if axis.length() < 1e-6:
					axis = forward.cross(Vector3.RIGHT)
			axis = axis.normalized()
			var q = Quaternion(axis, turn_angle)
			# Rotate using Basis(q)
			new_dir = (Basis(q) * forward).normalized()
	else:
		# No target
		# Move along initial_direction treated as local-space direction
		new_dir = (global_transform.basis * initial_direction).normalized()

	# Detect candidate new position
	var move_vec = new_dir * speed * charge_strength * delta
	var from_pos = _prev_pos
	var to_pos = global_transform.origin + move_vec

	# Detect collider between previous and new position
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from_pos
	params.to = to_pos
	params.exclude = [self]
	# Set collision_mask if desired
	var hit = space.intersect_ray(params)
	if hit and hit.has("collider"):
		var col = hit["collider"]
		# ignore other lasers, handle only targetable collisions
		if not col.is_in_group("Laser"):
			_on_hit_target(col)
			return

	# Apply movement
	global_transform = Transform3D(global_transform.basis, to_pos)

	# Visual orientation detacted from physics movement
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
	# Handle collisions if collider is not in "Laser" group
	if not body.is_in_group("Laser"):
		_on_hit_target(body)

# Accept collider or its ancestor Node3D as the logical target
func _on_hit_target(collider: Object):
	var hit_node: Node = null
	if collider is Node3D:
		hit_node = collider
	else:
		# If collider is a CollisionShape or other object, try owner/parent
		if collider is Object:
			# Attempt parent chain if collider has get_parent()
			if "get_parent" in collider:
				var p = collider.get_parent()
				if p and p is Node3D:
					hit_node = p

	# If a node is found, notify damage (if available) before freeing
	if hit_node and is_instance_valid(hit_node):
		if hit_node.has_method("apply_damage"):
			hit_node.apply_damage(100)
	# free the laser
	queue_free()

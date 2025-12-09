# Laser.gd
class_name Laser extends Area3D

# --- Gameplay settings ---
@export var laser_speed: float = 500.0 ## Default speed of laser projectile (units/sec)
@export var lifetime_sec: float = 1.0  ## Fallback lifetime (seconds) if no range is used
@export var max_range: float = 2000.0  ## Max distance from spawn before despawn (world units)
@export var debug: bool = false

# Runtime state
var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
var spawn_pos: Vector3 = Vector3.ZERO

# Called once when scene starts
func _ready():
	# remember spawn position for range-based despawn
	spawn_pos = global_transform.origin

	# allow Player to set velocity either via set_velocity or via a "vel" meta on the node
	# If Player already provided velocity via property or meta, use it; otherwise compute from orientation
	if has_meta("vel"):
		var m = get_meta("vel")
		if typeof(m) == TYPE_VECTOR3:
			velocity = m
	# If a velocity property was set earlier by the instancer, it will already be present.
	# If still zero, use node's forward (-Z) and laser_speed
	if velocity == Vector3.ZERO:
		velocity = -global_transform.basis.z.normalized() * laser_speed

	# connect collision signals (handle Area and PhysicsBody collisions)
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		connect("area_entered", Callable(self, "_on_area_entered"))
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	if debug:
		print("Laser._ready: spawn=", spawn_pos, " velocity=", velocity)

# Called every physics frame (better for consistent movement)
func _physics_process(delta: float) -> void:
	age += delta

	# Move projectile by velocity (world-space)
	if velocity != Vector3.ZERO:
		global_translate(velocity * delta)
	else:
		# fallback movement using orientation and laser_speed
		global_translate(-global_transform.basis.z.normalized() * laser_speed * delta)

	# Despawn by lifetime or range (whichever triggers first)
	if lifetime_sec > 0.0 and age >= lifetime_sec:
		if debug:
			print("Laser: killed by lifetime age=", age)
		queue_free()
		return

	if max_range > 0.0 and spawn_pos.distance_to(global_transform.origin) > max_range:
		if debug:
			print("Laser: killed by range dist=", spawn_pos.distance_to(global_transform.origin))
		queue_free()
		return

# Public API so callers (Player) can set a velocity directly
func set_velocity(v: Vector3) -> void:
	velocity = v

# Collision handlers
func _on_area_entered(area: Area3D) -> void:
	# ignore collisions with other projectiles if group used
	if not is_instance_valid(area):
		return
	# Only consider enemies/targets as valid hits
	if area.is_in_group("Enemy"):
		if debug:
			print("Laser: hit area enemy=", area.get_path())
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	# If the collider is an enemy (PhysicsBody) free the laser
	if body.is_in_group("Enemy"):
		if debug:
			print("Laser: hit body enemy=", body.get_path())
		queue_free()

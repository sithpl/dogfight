# Player.gd
class_name Player extends Node3D

# --- Gameplay settings ---
@export var brake_mult           : float = 0.5                 # Speed multiplier when braking
@export var rotation_smoothness  : float = 8.0                 # How smoothly the ship rotates/tilts (higher = snappier)
@export var max_bank_angle       : float = 45.0                # Maximum tilt/roll (degrees) under normal movement
@export var max_pitch_angle      : float = 45.0                # Maximum up/down tilt (degrees)
@export var hard_bank_angle      : float = 90.0                # Angle (degrees) to roll when hard banking (Q/E or triggers)
@export var hard_bank_smoothness : float = 10.0                # How quickly the ship snaps into/out of hard bank
@export var max_yaw_angle        : float = 30.0                # Maximum left/right tilt (degrees)
@export var hard_yaw_angle       : float = 60.0                # Sharper turn angle when hard banking
@export var follow_speed         : float = 8.0                 # How snappy Player follows Center
@export var follow_offset        : Vector3 = Vector3(0, 0, 5)  # How far back PlayerMesh stays
@export var reticle_x_max        : float = 16                  # Max reticle offset X (left/right)
@export var reticle_y_max        : float = 9                   # Max reticle offset Y (up/down)
@export var reticle_sensitivity  : float = 1.0                 # How fast the reticle snaps across the screen when aiming
@export var laser_scene          : PackedScene                 # Scene for the laser shot (so it can be externally edited)

# --- Node settings ---
@onready var mesh            : Node3D              = $PlayerMesh                 # Reference to the Player's visible mesh Node3D
@onready var reticle1        : Sprite3D            = $Reticle1                   # Reticle sprite closer to the player
@onready var reticle2        : Sprite3D            = $Reticle2                   # Reticle sprite farther away (aim)
@onready var center          : Node3D              = $"../Center"                # Reference to Center node used for following
@onready var boost_sfx       : AudioStreamPlayer3D = $SFX/Boost                  # Boost sound effect player
@onready var brake_sfx       : AudioStreamPlayer3D = $SFX/Brake                  # Brake sound effect player
@onready var laser_sfx       : AudioStreamPlayer3D = $SFX/Laser                  # Laser shot sound effect player
@onready var barrelroll_sfx  : AudioStreamPlayer3D = $SFX/BarrelRoll             # Barrel roll sound effect player
@onready var charge_sfx      : AudioStreamPlayer3D = $SFX/Charge                 # Charge sound effect player
@onready var lockon_sfx      : AudioStreamPlayer3D = $SFX/LockOn                 # Lock-on sound effect player
@onready var boost_particles : CPUParticles3D      = $PlayerMesh/BoostParticles  # Boost particles node
@onready var boost_light     : OmniLight3D         = $PlayerMesh/BoostLight      # Boost light node

# --- Game state variables ---
var is_boosting       : bool   = false          # True if currently boosting
var was_boosting      : bool   = false          # True if was boosting
var is_braking        : bool   = false          # True if currently braking
var was_braking       : bool   = false          # True if was boosting
var prev_position = Vector3.ZERO                # Used for velocity if needed
var displayed_rotation: Vector3 = Vector3.ZERO  # Smooth rotation for PlayerMesh
var reticle_pos: Vector2 = Vector2.ZERO         # Used to track reticle position

# --- Barrel Roll logic ---

# Barrel roll state
@export var barrel_duration: float = 0.3        # How long barrel roll lasts (seconds)

var is_doing_barrel_roll: bool = false          # True if currently spinning (barrel roll)
var barrel_direction: int = 0                   # +1 (right) or -1 (left), or 0 if not rolling
var barrel_elapsed: float = 0.0                 # How long this roll has run so far

# Barrel roll cooldown
@export var barrel_cooldown: float = 0.7        # How long player must wait after prevous barrel roll (seconds)

var barrel_cooldown_timer: float = 0.0          # If >0, rolling is locked out

# Double-tap detection for barrel roll
var tap_time_window  : float  = 0.25            # Max seconds between taps to count as double tap
var left_tap_timer   : float  = 0.0             # Used to measure left double taps
var left_tap_count   : int    = 0               # How many left taps so far
var right_tap_timer  : float  = 0.0             # Used to measure right double taps
var right_tap_count  : int    = 0               # How many right taps so far

# --- Charged Shot logic ---
@export var charge_time_max       : float = 1.5    # Time to reach full charge (secs)
@export var charge_min_threshold  : float = 0.5    # Minimum time to trigger "charged" effect
@export var reticle_pulse_speed   : float = 10.0   # How fast $Reticle2 pulses when fully charged
@export var reticle_pulse_scale   : float = 0.95   # Max extra scale applied during "charged" effect
@export var auto_target_range     : float = 30.0   # Search radius for nearby targets
@export var charged_laser_scene   : PackedScene    # Scene for the charged laser shot (so it can be externally edited)

var is_charging                : bool    = false                 # Is the player currently holding charge?
var charge_timer               : float   = 0.0                   # Total charge time while holding
var _reticle1_default_modulate : Color   = Color("ffffffff")  # Cached default color for reticle1 to restore after charging
var _reticle2_default_modulate : Color   = Color("ffffffff")  # Cached default color for reticle2 to restore after charging
var _reticles_charged_state    : bool    = false                 # True when full charged visual state reached
var _reticle2_base_scale       : Vector3 = Vector3.ONE           # Saved base scale for reticle2
var _reticle_pulse_timer       : float   = 0.0                   # Timer used to drive reticle pulse animation

# --- Lock On logic ---
@export var lock_reticle_scale      : float = 1.0                  # Tuning for lock reticle size
@export var lock_view_distance      : float = 100.0                # How far we can "see" to lock (scope distance)
@export var lock_view_cone_deg      : float = 6.0                  # Cone half-angle in degrees (smaller = tighter scope)
@export var lock_min_distance       : float = 8.0                  # Don't lock targets closer than this to player
@export var lock_require_los        : bool  = false                # Require LOS to target
@export var hover_reticle_scale     : float = 0.9                  # Hover reticle scale for preview target
@export var hover_reticle_modulate  : Color = Color("ffffcce6")  # Hover reticle tint color

var _lock_target        : Node     = null       # Node that we locked on to (set when full-charged)
var _lock_reticle       : Sprite3D = null       # runtime-created red reticle that sits on top of the locked target
var _hover_target       : Node     = null       # Node currently hovered by reticle2 (before lock)
var _hover_reticle      : Sprite3D = null       # Hover indicator Sprite3D
var _charge_sfx_played  : bool     = false      # Has charge_sfx played?

# Called once when scene starts
func _ready():
	# Initial position for velocity
	prev_position = position

	# Save reticle default colors to restore them after "charge" effect
	if reticle2:
		_reticle2_base_scale = reticle2.scale
		_reticle2_default_modulate = reticle2.modulate
	if reticle1:
		_reticle1_default_modulate = reticle1.modulate

# Called every frame
func _process(delta):
	# delta = time since last frame (in seconds)

	# Animate particles based on boost/brake
	if is_boosting:
		boost_light.light_energy = 8.0
	elif is_braking:
		boost_light.light_energy = 2.5
	else:
		boost_particles.emitting = true
		boost_light.light_energy = 0.2

	# --- FOLLOW CENTER NODE LOGIC ---
	if center:
		var offset = center.global_transform.basis.x * follow_offset.x \
				   + center.global_transform.basis.y * follow_offset.y \
				   + center.global_transform.basis.z * follow_offset.z
		var target_pos = center.global_transform.origin + offset
		global_transform.origin = global_transform.origin.lerp(target_pos, follow_speed * delta)
		global_transform.basis = center.global_transform.basis

	# Handle keyboard/controller input (applies on top of reticle follower)
	# ONLY used for animating mesh (bank/pitch), NOT for moving Player node
	var input_vector = Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x += 1  # right
	if Input.is_action_pressed("ui_right"):
		input_vector.x -= 1  # left
	input_vector = input_vector.normalized()

	# --- 2D Flat Reticle Logic ---
	var reticle_plane_distance = 50.0  # How far in front of the ship
	var reticle_input = Vector2(
		Input.get_axis("ui_left", "ui_right") * reticle_sensitivity,
		Input.get_axis("ui_down", "ui_up") * reticle_sensitivity
	)

	# Smoothly interpolate reticle position to target each frame
	var reticle_lerp_speed = 1.0 # You can tweak this value
	var target_reticle_pos = Vector2(
		clamp(reticle_input.x * reticle_x_max, -reticle_x_max, reticle_x_max),
		clamp(reticle_input.y * reticle_y_max, -reticle_y_max, reticle_y_max)
	)
	reticle_pos = reticle_pos.lerp(target_reticle_pos, delta * reticle_lerp_speed)

	# Generate the base for the reticle plane: origin + (-basis.z)*distance is directly ahead of player
	var reticle_plane_origin = mesh.global_transform.origin + -mesh.global_transform.basis.z.normalized() * reticle_plane_distance

	# Move reticle locally in that plane (X, Y only)
	var flat_reticle_pos = reticle_plane_origin + Vector3(-reticle_pos.x, reticle_pos.y, 0)
	reticle2.global_transform.origin = flat_reticle_pos

	# Mirror Reticle2 logic for Reticle1, putting it between PlayerMesh and Reticle2
	var reticle1_lerp_factor = 0.3 # 0.5 for halfway, 0.7 is closer to Reticle2
	reticle1.global_transform.origin = reticle2.global_transform.origin.lerp(mesh.global_transform.origin, reticle1_lerp_factor)

	mesh.look_at(reticle2.global_transform.origin, Vector3.UP)

	# --- Barrel Roll logic ---

	# Barrel roll cooldown
	if barrel_cooldown_timer > 0.0:
		barrel_cooldown_timer -= delta
		if barrel_cooldown_timer < 0.0:
			barrel_cooldown_timer = 0.0

	# Barrel roll double-tap detection
	# Only allow double-tap triggers if NOT currently rolling or cooling down
	if !is_doing_barrel_roll and barrel_cooldown_timer == 0.0:
		# Detect double tap LEFT for barrel roll
		if Input.is_action_just_pressed("ui_bank_left"):
			if left_tap_timer > 0.0 and left_tap_count == 1:
				start_barrel_roll(-1)
				left_tap_timer = 0.0
				left_tap_count = 0
			else:
				left_tap_timer = tap_time_window
				left_tap_count = 1
		if left_tap_timer > 0:
			left_tap_timer -= delta
			if left_tap_timer <= 0:
				left_tap_timer = 0.0
				left_tap_count = 0

		# Detect double tap RIGHT for barrel roll
		if Input.is_action_just_pressed("ui_bank_right"):
			if right_tap_timer > 0.0 and right_tap_count == 1:
				start_barrel_roll(1)
				right_tap_timer = 0.0
				right_tap_count = 0
			else:
				right_tap_timer = tap_time_window
				right_tap_count = 1
		if right_tap_timer > 0:
			right_tap_timer -= delta
			if right_tap_timer <= 0:
				right_tap_timer = 0.0
				right_tap_count = 0

	# --- Laser/Charged Laser logic ---
	if Input.is_action_just_pressed("ui_accept"):
		is_charging = true
		charge_timer = 0.0
		_reticles_charged_state = false
		_clear_lock()
		_clear_hover()
		# reset the "played this charge" flag
		_charge_sfx_played = false
		# ensure previous sound stopped (optional)
		if charge_sfx and charge_sfx.is_playing():
			charge_sfx.stop()

	elif Input.is_action_pressed("ui_accept") and is_charging:
		# Continue charging and refresh hover target each frame
		charge_timer += delta
		_update_hover_target()
		if not _charge_sfx_played and charge_timer >= charge_min_threshold:
			if charge_sfx:
				#print("Input.is_action_pressed('ui_accept') and is_charging -> charge_sfx playing! (1)")
				charge_sfx.play()
			_charge_sfx_played = true

		# If we already have a lock, allow "pull away" to cancel it
		if _lock_target and is_instance_valid(_lock_target):
			var eye = mesh.global_transform.origin
			var view_dir = (reticle2.global_transform.origin - eye)
			if view_dir.length() >= 0.001:
				view_dir = view_dir.normalized()
				var to_lock = (_lock_target.global_transform.origin - eye)
				if to_lock.length() > 0.0001:
					var cos_angle = view_dir.dot(to_lock.normalized())
					var cos_threshold = cos(deg_to_rad(clamp(lock_view_cone_deg, 0.0, 89.0)))
					# If reticle moved outside the cone, clear existing lock to pick up a different hover
					if cos_angle < cos_threshold:
						_clear_lock()
						# Refresh hover immediately after clearing
						_update_hover_target() 

		# If currently hovering a different target and already fully charged, convert hover into the (new) lock immediately to can retarget mid-hold.
		if _hover_target and is_instance_valid(_hover_target) and _hover_target != _lock_target and charge_timer >= charge_time_max:
			_clear_lock()
			_lock_target = _hover_target
			_clear_hover()
			_create_lock_reticle()
			# revert on-screen reticle to defaults immediately when lock is acquired
			_reset_reticles()
			# play lock sound only if we're actually in charged state
			if _reticles_charged_state:
				_play_lockon_sfx()

		# Start sustain tone only after threshold
		if charge_sfx and not _charge_sfx_played and charge_timer >= charge_min_threshold:
			#print("Input.is_action_pressed('ui_accept') and is_charging -> charge_sfx playing! (2)")
			charge_sfx.play()
			_charge_sfx_played = true

		# Full-charge reached -> visuals + lock conversion (original behavior)
		if not _reticles_charged_state and charge_timer >= charge_time_max:
			_set_reticles_charging()
			_reticles_charged_state = true
			if charge_sfx and charge_sfx.is_playing():
				charge_sfx.stop()
			# convert current hover to lock if present
			if _hover_target and is_instance_valid(_hover_target):
				_lock_target = _hover_target
				_clear_hover()
				_create_lock_reticle()
				# revert on-screen reticle to defaults immediately when lock is acquired
				_reset_reticles()
				# play lock sound only if we're actually in charged state
				if _reticles_charged_state:
					_play_lockon_sfx()

	elif Input.is_action_just_released("ui_accept") and is_charging:
		is_charging = false
		# stop any sustain tone if you were using one (optional)
		if charge_sfx and charge_sfx.is_playing():
			charge_sfx.stop()
		# reset flag
		_charge_sfx_played = false

		# decide to shoot or fire charged
		if charge_timer < charge_min_threshold:
			shoot_laser()
		else:
			fire_charged_laser()
		charge_timer = 0.0
		_reset_reticles()
		_clear_lock()
		_clear_hover()
		_reticles_charged_state = false

	# While locked, update the lock reticle position and pulse (if created)
	if _lock_target and _lock_reticle:
		if not is_instance_valid(_lock_target):
			_clear_lock()
		else:
			var target_pos = _lock_target.global_transform.origin
			_lock_reticle.global_transform.origin = target_pos

			# Force a fixed orientation (no tracking). Use local rotation so it remains (0,0,0).
			_lock_reticle.rotation_degrees = Vector3.ZERO

			# optional scale/pulse (unchanged)
			var pulse = 0.5 + 0.5 * sin(_reticle_pulse_timer * reticle_pulse_speed)
			_lock_reticle.scale = Vector3.ONE * (lock_reticle_scale * (1.0 + 0.12 * pulse))
			_reticle_pulse_timer += delta

	# Reticle2 pulsing when fully charged (visual)
	if _reticles_charged_state and reticle2 and not _lock_target:
		_reticle_pulse_timer += delta
		var pulse = 0.5 + 0.5 * sin(_reticle_pulse_timer * reticle_pulse_speed)  # 0..1
		reticle2.scale = _reticle2_base_scale * (1.0 + reticle_pulse_scale * pulse)
		var brightness = 0.85 + 0.35 * pulse   # ~0.85..1.2
		brightness = clamp(brightness, 0.0, 1.25)
		reticle2.modulate = Color(1.0 * brightness, 0.0, 0.0, 1.0)
	else:
		if reticle2:
			reticle2.scale = _reticle2_base_scale

	# Update boost/brake states
	is_boosting = Input.is_action_pressed("ui_boost")
	if is_boosting and not was_boosting:
		boost_sfx.play()
	was_boosting = is_boosting

	is_braking = Input.is_action_pressed("ui_brake")
	if is_braking and not was_braking:
		brake_sfx.play()
	was_braking = is_braking

	# Always update displayed_rotation based on input, no matter if rolling
	var is_hard_bank_left = Input.is_action_pressed("ui_bank_left")
	var is_hard_bank_right = Input.is_action_pressed("ui_bank_right")
	var bank = input_vector.x * max_bank_angle
	var pitch = -input_vector.y * max_pitch_angle

	var yaw = input_vector.x * max_yaw_angle
	# Only when bank left AND stick left
	if is_hard_bank_left and input_vector.x > 0:
		yaw = hard_yaw_angle
	# Only when bank right AND stick right
	elif is_hard_bank_right and input_vector.x < 0:
		yaw = -hard_yaw_angle

	var hard_bank_target = 0.0
	if is_hard_bank_left:
		hard_bank_target = hard_bank_angle
	elif is_hard_bank_right:
		hard_bank_target = -hard_bank_angle
	var use_hard_bank = is_hard_bank_left or is_hard_bank_right
	var target_bank = lerp(bank, hard_bank_target, float(use_hard_bank))
	var target_rotation = Vector3(-pitch, yaw, target_bank)
	var smooth_strength = hard_bank_smoothness if use_hard_bank else rotation_smoothness
	displayed_rotation = displayed_rotation.lerp(target_rotation, delta * smooth_strength)

	# Handle barrel roll overlay
	if is_doing_barrel_roll:
		barrel_elapsed += delta
		var roll_angle = 360.0 * barrel_direction * (barrel_elapsed / barrel_duration)
		mesh.rotation_degrees = Vector3(displayed_rotation.x, displayed_rotation.y, displayed_rotation.z - roll_angle)
		if barrel_elapsed >= barrel_duration:
			is_doing_barrel_roll = false
			barrel_elapsed = 0.0
			barrel_direction = 0
			barrel_cooldown_timer = barrel_cooldown
	else:
		mesh.rotation_degrees = displayed_rotation

# Returns brake multiplier depending on braking state
func get_brake_multiplier():
	#print("Player.gd -> _set_reticles_charging() called!")
	return brake_mult if is_braking else 1.0

# Set reticle visuals to the charged appearance (called at full charge)
func _set_reticles_charging():
	#print("Player.gd -> _set_reticles_charging() called!")
	# Reticle1 -> yellow, Reticle2 -> red when fully charged
	if reticle1:
		reticle1.modulate = Color(1, 1, 0, 1)   # yellow
	if reticle2:
		reticle2.modulate = Color(1, 0, 0, 1)   # red
	_reticle_pulse_timer = 0.0

# Restore reticle visuals to defaults (undo charged visuals)
func _reset_reticles():
	#print("Player.gd -> _reset_reticles() called!")
	# Restore cached default colors and scale
	if reticle1:
		reticle1.modulate = _reticle1_default_modulate
	if reticle2:
		reticle2.modulate = _reticle2_default_modulate
		reticle2.scale = _reticle2_base_scale
	_reticle_pulse_timer = 0.0

# Fire a normal instant laser toward the reticle
func shoot_laser():
	#print("Player.gd -> shoot_laser() called!")
	if laser_scene and mesh and reticle2:
		var laser = laser_scene.instantiate()
		get_parent().add_child(laser)
		laser.add_to_group("Laser")
		var laser_forward_offset = 3
		var spawn_pos = mesh.global_transform.origin + (-mesh.global_transform.basis.z.normalized() * laser_forward_offset)
		laser.global_transform.origin = spawn_pos

		# Shoot DIRECTLY toward the reticle in world space
		var direction = (reticle2.global_transform.origin - spawn_pos).normalized()
		laser.look_at(reticle2.global_transform.origin, Vector3.UP)

		# If Laser.gd provided a setter use it otherwise set velocity property if present
		if laser.has_method("set_velocity"):
			laser.set_velocity(direction * 300)
		elif "velocity" in laser:
			laser.velocity = direction * 300

		laser_sfx.play()

# Spawn and fire a charged laser; aim at locked target center when available
func fire_charged_laser():
	#print("Player.gd -> fire_charged_laser() called!")
	if not charged_laser_scene or not mesh or not reticle2:
		return

	var laser = charged_laser_scene.instantiate()
	get_parent().add_child(laser)
	laser.add_to_group("Laser")

	var laser_forward_offset = 3
	var spawn_pos = mesh.global_transform.origin + (-mesh.global_transform.basis.z.normalized() * laser_forward_offset)
	laser.global_transform.origin = spawn_pos

	var strength = clamp(charge_timer / charge_time_max, 0.0, 1.0)
	if laser.has_method("set_charge_strength"):
		laser.set_charge_strength(strength)

	# Preference to aim directly at locked target center if there is one
	var world_direction = Vector3.ZERO
	if _lock_target and is_instance_valid(_lock_target):
		# Aim at target's origin (center). Guarantees the initial trajectory points at the locked object.
		var target_pos = _lock_target.global_transform.origin
		world_direction = (target_pos - spawn_pos)
		if world_direction.length() > 0.001:
			world_direction = world_direction.normalized()
	else:
		# No lock, aim at reticle as before
		var direction = (reticle2.global_transform.origin - spawn_pos)
		if direction.length() > 0.001:
			world_direction = direction.normalized()

	# Ensure projectile is oriented toward the chosen world direction (for visuals)
	if world_direction.length() > 0.001:
		laser.look_at(spawn_pos + world_direction, Vector3.UP)

	# Provide projectile its local initial direction using existing API
	if world_direction.length() > 0.001 and laser.has_method("set_initial_direction"):
		var local_dir = laser.global_transform.basis.inverse() * world_direction
		if local_dir.length() > 0.001:
			local_dir = local_dir.normalized()
		laser.set_initial_direction(local_dir)

	# Keep any lock reference so the laser can track if it supports it
	if _lock_target and laser.has_method("set_target"):
		laser.set_target(_lock_target)

	# Keep the existing fallback raycast target-set
	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = spawn_pos
	params.to = reticle2.global_transform.origin
	params.exclude = [self, laser]
	var hit = space.intersect_ray(params)
	if hit and hit.has("collider"):
		var col = hit["collider"]
		if laser.has_method("set_target"):
			laser.set_target(col)

	laser_sfx.play()

# Clear any active lock and restore reticle visuals appropriately
func _clear_lock():
	#print("Player.gd -> _clear_lock() called!")
	_lock_target = null 
	if _lock_reticle: 
		_lock_reticle.queue_free() 
		_lock_reticle = null 
		_reticle_pulse_timer = 0.0

	# If we broke the lock while still holding a charge at full, re-show charged visuals.
	if is_charging and _reticles_charged_state:
		_set_reticles_charging()
	else:
		_reset_reticles()

# Create and attach a visible lock reticle to the current _lock_target
func _create_lock_reticle():
	#print("Player.gd -> _create_lock_reticle() called!")
	# Create a visible lock reticle for the current _lock_target
	if not reticle2 or not _lock_target:
		return
	if _lock_reticle:
		return

	_lock_reticle = Sprite3D.new()
	_lock_reticle.name = "LockReticle"

	# Reuse the reticle2 texture where possible
	if reticle2.texture:
		_lock_reticle.texture = reticle2.texture

	_lock_reticle.modulate = Color(1, 0, 0, 1)
	_lock_reticle.scale = Vector3.ONE * lock_reticle_scale

	# Make sure the reticle is visible and unshaded enough to be seen
	_lock_reticle.visible = true

	# Parent to the lock target so it follows, but set its local transform to identity
	_lock_target.add_child(_lock_reticle)
	#_lock_reticle.transform = Transform3D(Basis(), Vector3.ZERO)

	# Also force its world position immediately (in case parent origin is offset)
	_lock_reticle.global_transform.origin = _lock_target.global_transform.origin

	# Play lock-on sound once
	if lockon_sfx:
		if lockon_sfx.is_playing():
			lockon_sfx.stop()
		lockon_sfx.play()

# Find the best hover candidate under the reticle and create hover indicator
func _update_hover_target():
	#print("Player.gd -> _update_hover_target() called!")
	_clear_hover()
	if not reticle2 or not mesh:
		return

	var enemies = get_tree().get_nodes_in_group("Enemy")
	#print("DEBUG: Enemy group count =", enemies.size())

	if enemies.size() == 0:
		# no enemies in group
		return

	var eye = mesh.global_transform.origin
	var view_dir = (reticle2.global_transform.origin - eye)
	if view_dir.length() < 0.001:
		return
	view_dir = view_dir.normalized()

	var best: Node3D = null
	var best_score: float = -INF
	for e_raw in enemies:
		# guard: nodes coming from group may not be Node3D or may be invalid
		if not is_instance_valid(e_raw):
			continue
		if not (e_raw is Node3D):
			continue
		var e : Node3D = e_raw

		# skip very-close enemies (we don't want to hover over them)
		var dist_to_eye = e.global_transform.origin.distance_to(eye)
		if dist_to_eye < lock_min_distance:
			continue

		# angular cone + distance along view ray
		var to_e = e.global_transform.origin - eye
		var dist_along = to_e.dot(view_dir)
		if dist_along <= 0.0 or dist_along > lock_view_distance:
			continue
		var to_e_norm = to_e.normalized()
		var cos_angle = view_dir.dot(to_e_norm)
		var cos_threshold = cos(deg_to_rad(clamp(lock_view_cone_deg, 0.0, 89.0)))
		if cos_angle < cos_threshold:
			continue

		# optional LOS check to the candidate (allow if the ray hit is the candidate or its descendant)
		if lock_require_los:
			var space = get_world_3d().direct_space_state
			var params = PhysicsRayQueryParameters3D.new()
			params.from = eye
			params.to = e.global_transform.origin
			params.exclude = [self]
			var hit = space.intersect_ray(params)
			if hit and hit.has("collider"):
				var collider = hit["collider"]
				# if collider is not e and not a child of e, then occluded
				if not _is_node_or_ancestor(collider, e):
					continue

		# scoring: prefer higher cos_angle (closer to center) and slightly prefer nearer ones
		var score = cos_angle - (dist_along * 0.0005)
		if score > best_score:
			best_score = score
			best = e

	# if we found a best candidate, create the hover indicator
	if best:
		# debug print to verify selection during testing (comment out later)
		#print("DEBUG: hover candidate:", best, "score=", best_score)
		_hover_target = best
		_create_hover_reticle()
		# parent hover reticle to hover target and put at origin (only if not already parented)
		if _hover_reticle and is_instance_valid(_hover_target):
			if _hover_reticle.get_parent() != _hover_target:
				_hover_target.add_child(_hover_reticle)
			#_hover_reticle.transform = Transform3D(Basis(), Vector3.ZERO)

# Create the hover indicator Sprite3D or fallback mesh
func _create_hover_reticle():
	#print("Player.gd -> _create_hover_reticle() called!")
	if not reticle2 or not _hover_target:
		return
	if _hover_reticle:
		return

	if reticle2.texture:
		var s = Sprite3D.new()
		s.name = "HoverReticle"
		s.texture = reticle2.texture
		s.modulate = hover_reticle_modulate
		s.scale = Vector3.ONE * hover_reticle_scale
		_hover_reticle = s
	else:
		var m = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(0.35 * hover_reticle_scale, 0.35 * hover_reticle_scale)
		m.mesh = q
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		#mat.albedo_color = hover_reticle_modulate.rgb
		mat.emission_enabled = true
		#mat.emission = hover_reticle_modulate.rgb
		m.set_surface_override_material(0, mat)
		_hover_reticle = m

# Remove hover indicator and clear hover target
func _clear_hover():
	#print("Player.gd -> _clear_hover() called!")
	_hover_target = null
	if _hover_reticle:
		_hover_reticle.queue_free()
		_hover_reticle = null

# Check whether 'possible' is the same node or an ancestor of 'target_node'
func _is_node_or_ancestor(possible, target_node):
	#print("Player.gd -> _is_node_or_ancestor() called!")
	if not possible or not target_node:
		return false
	if possible == target_node:
		return true
	var n = possible
	while n:
		if n == target_node:
			return true
		n = n.get_parent()
	return false

# Begin a barrel roll in the given direction (+1 right, -1 left)
func start_barrel_roll(direction: int):
	#print("Player.gd -> start_barrel_roll() called!")
	if !is_doing_barrel_roll and barrel_cooldown_timer == 0.0:
		is_doing_barrel_roll = true
		barrel_direction = direction
		barrel_elapsed = 0.0

	# Play the BarrelRoll sfx
	barrelroll_sfx.play()

# Play the lock-on sound, restarting it if already playing
func _play_lockon_sfx(): 
	#print("Player.gd -> _play_lockon_sfx() called!")
	if not lockon_sfx: 
		return # restart the one-shot so we always hear it when a new lock is acquired 
	if lockon_sfx.is_playing(): 
		lockon_sfx.stop() 
		lockon_sfx.play()

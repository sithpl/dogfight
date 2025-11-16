# Player.gd
class_name Player extends Node3D

# -- Movement and bounds settings --
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

@onready var mesh           : Node3D              = $PlayerMesh
@onready var reticle1       : Sprite3D            = $Reticle1
@onready var reticle2       : Sprite3D            = $Reticle2
@onready var center         : Node3D              = $"../Center"
@onready var boost_sfx      : AudioStreamPlayer3D = $SFX/Boost
@onready var brake_sfx      : AudioStreamPlayer3D = $SFX/Brake
@onready var laser_sfx      : AudioStreamPlayer3D = $SFX/Laser
@onready var barrelroll_sfx : AudioStreamPlayer3D = $SFX/BarrelRoll

# -- Player state variables --
var is_boosting       : bool   = false         # True if currently boosting
var was_boosting      : bool   = false
var is_braking        : bool   = false         # True if braking
var was_braking       : bool   = false
var prev_position = Vector3.ZERO               # Used for velocity if you want it
var displayed_rotation: Vector3 = Vector3.ZERO # Smooth rotation for mesh
var reticle_pos: Vector2 = Vector2.ZERO

# -- Barrel roll state --
var is_doing_barrel_roll: bool = false         # Are we currently spinning?
var barrel_direction: int = 0                  # +1 (right) or -1 (left), or 0 if not rolling
var barrel_elapsed: float = 0.0                # How long this roll has run so far
@export var barrel_duration: float = 0.3       # How long barrel roll lasts (in seconds)

# -- Barrel roll cooldown --
@export var barrel_cooldown: float = 0.7       # How long you must wait after roll (seconds)
var barrel_cooldown_timer: float = 0.0         # If >0, rolling is locked out

# -- Double-tap detection for barrel roll --
var tap_time_window: float = 0.25              # Max seconds between taps to count as double tap
var left_tap_timer: float = 0.0                # Used to measure left double taps
var left_tap_count: int = 0                    # How many left taps so far
var right_tap_timer: float = 0.0               # For right double taps
var right_tap_count: int = 0                   # How many right taps so far

func _ready():
	# Called once when scene starts
	prev_position = position                   # Init position for velocity use
	#print("Player global pos:", global_transform.origin)
	#reticle.scale = Vector3(0.25, 0.25, 0.25)
	#reticle.pixel_size = 0.0010
	#print("Player scale:", scale)
	#print("Reticle scale:", reticle.scale)
	

func _process(delta):
	# delta = time since last frame (in seconds)
	
	# --- FOLLOW THE CENTER NODE ---
	if center:
		var offset = center.global_transform.basis.x * follow_offset.x \
				   + center.global_transform.basis.y * follow_offset.y \
				   + center.global_transform.basis.z * follow_offset.z
		var target_pos = center.global_transform.origin + offset
		global_transform.origin = global_transform.origin.lerp(target_pos, follow_speed * delta)
		global_transform.basis = center.global_transform.basis

	# --- Keyboard stick movement (applies on top of reticle follower) ---
	# ONLY used for animating mesh (bank/pitch), not for moving Player node!
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

	# --- Barrel roll cooldown ---
	if barrel_cooldown_timer > 0.0:
		barrel_cooldown_timer -= delta
		if barrel_cooldown_timer < 0.0:
			barrel_cooldown_timer = 0.0

	# --- Barrel roll double-tap detection ---
	# Only allow double-tap triggers if NOT currently rolling or cooling down
	if !is_doing_barrel_roll and barrel_cooldown_timer == 0.0:
		# Detect double tap LEFT for barrel roll (ui_bank_left)
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

		# Detect double tap RIGHT for barrel roll (ui_bank_right)
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

	# --- Shooting logic ---
	if Input.is_action_just_pressed("ui_accept"):
		shoot_laser()

	# Update boost/brake states
	is_boosting = Input.is_action_pressed("ui_boost")
	if is_boosting and not was_boosting:
		# Only play sound when boost begins
		boost_sfx.play()
	#elif not is_boosting and was_boosting:
		#boost_sfx.stop()
	was_boosting = is_boosting
	
	is_braking = Input.is_action_pressed("ui_brake")
	if is_braking and not was_braking:
		brake_sfx.play()
	#elif not is_braking and was_braking:
		#brake_sfx.stop()
	was_braking = is_braking

	# Always update displayed_rotation based on input, no matter if rolling
	var is_hard_bank_left = Input.is_action_pressed("ui_bank_left")
	var is_hard_bank_right = Input.is_action_pressed("ui_bank_right")
	var bank = input_vector.x * max_bank_angle
	var pitch = -input_vector.y * max_pitch_angle

	var yaw = input_vector.x * max_yaw_angle
	if is_hard_bank_left and input_vector.x > 0:      # Only when bank left AND stick left
		yaw = hard_yaw_angle
	elif is_hard_bank_right and input_vector.x < 0:   # Only when bank right AND stick right
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

	# Now handle barrel roll overlay
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

func get_brake_multiplier() -> float:
	return brake_mult if is_braking else 1.0

func shoot_laser():
	#print("Player.gd -> shoot_laser() called!")
	if laser_scene and mesh and reticle2:
		var laser = laser_scene.instantiate()
		get_parent().add_child(laser)
		laser.add_to_group("Laser")
		var laser_forward_offset = 3
		var spawn_pos = mesh.global_transform.origin + (-mesh.global_transform.basis.z.normalized() * laser_forward_offset)
		laser.global_transform.origin = spawn_pos

		# **Key fix: Shoot DIRECTLY toward the reticle in world space**
		var direction = (reticle2.global_transform.origin - spawn_pos).normalized()
		# Set its velocity (if it has one), or use look_at if it's using rotation
		laser.look_at(reticle2.global_transform.origin, Vector3.UP)
		# If you have a velocity field in Laser.gd, set it:
		if laser.has_method("laser_speed"):
			laser.set_velocity(direction)
		elif "velocity" in laser:
			laser.velocity = direction * 300  # Set your speed

		# Play the Laser sfx
		laser_sfx.play()

func start_barrel_roll(direction: int):
	print("Player.gd -> start_barrel_roll() called!")
	if !is_doing_barrel_roll and barrel_cooldown_timer == 0.0:
		is_doing_barrel_roll = true
		barrel_direction = direction
		barrel_elapsed = 0.0
	
	# Play the BarrelRoll sfx
	barrelroll_sfx.play()

# Player.gd
class_name Player extends Node3D

# -- Movement and bounds settings --
@export var move_speed      : float = 15.0      # How fast the player moves left/right/up/down (units/sec)
@export var bounds_x        : float = 8.0       # Max left/right X position in the game world
@export var bounds_y        : float = 4.5       # Max up/down Y position in the game world
@export var brake_mult      : float = 0.5       # Speed multiplier when braking
@export var lerp_speed      : float = 5.0       # How quickly the ship moves to match reticle position
@export var plane_z         : float = 0.0       # Z position to keep the player "on-rails"
@export var rotation_smoothness: float = 8.0    # How smoothly the ship rotates/tilts (higher=snapper)
@export var max_bank_angle  : float = 45.0      # Maximum tilt/roll (degrees) under normal movement
@export var max_pitch_angle : float = 45.0      # Maximum up/down tilt (degrees)
@export var hard_bank_angle : float = 90.0      # Angle (degrees) to roll when hard banking (Q/E or triggers)
@export var hard_bank_smoothness : float = 10.0 # How quickly the ship snaps into/out of hard bank

@export var laser_scene     : PackedScene       # Scene for the laser shot (assign in inspector)

@onready var mesh = $PlayerMesh                # The visible ship model that tilts and banks

# -- Player state variables --
var last_speed_mult   : float  = 1.0           # Used if you want to check last speed for effects (not used yet)
var is_boosting       : bool   = false         # True if currently boosting
var is_braking        : bool   = false         # True if braking
var reticle_ui: CanvasLayer                    # Should be set from outside to point at ReticleControl
var prev_position = Vector3.ZERO               # Used for velocity if you want it
var displayed_rotation: Vector3 = Vector3.ZERO # Smooth rotation for mesh

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
	prev_position = position                   # Init position for any velocity use

func _process(delta):
	# Called every frame

	# --- Barrel roll cooldown ---
	if barrel_cooldown_timer > 0.0:
		barrel_cooldown_timer -= delta
		if barrel_cooldown_timer < 0.0:
			barrel_cooldown_timer = 0.0

	# --- Barrel roll double-tap detection (now uses ui_bank_left/ui_bank_right for both bank and roll) ---
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

	# --- Reticle following (moves player to match reticle offset) ---
	if reticle_ui:
		var offset = reticle_ui.get_normalized_offset()
		var target_x = clamp(offset.x, -1.0, 1.0) * bounds_x
		var target_y = clamp(offset.y, -1.0, 1.0) * bounds_y
		var target_pos = Vector3(target_x, target_y, plane_z)
		position = position.lerp(target_pos, delta * lerp_speed)

	# --- Keyboard stick movement (applies on top of reticle follower) ---
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

	# Update boost/brake states
	is_boosting = Input.is_action_pressed("ui_boost")
	is_braking = Input.is_action_pressed("ui_brake")

	# Player position is updated based on input. Clamp to box:
	var effective_speed = move_speed * get_brake_multiplier()
	var new_pos = position
	new_pos.x += input_vector.x * effective_speed * delta
	new_pos.y += input_vector.y * effective_speed * delta
	new_pos.x = clamp(new_pos.x, -bounds_x, bounds_x)
	new_pos.y = clamp(new_pos.y, -bounds_y, bounds_y)
	position = new_pos

	# --- MODEL ROTATION (bank/pitch/roll) ---
	if is_doing_barrel_roll:
		# Barrel roll is active - set rotation to spinning around Z
		barrel_elapsed += delta
		var t = clamp(barrel_elapsed / barrel_duration, 0.0, 1.0)    # Progress from 0 to 1
		var roll_angle = lerp(0.0, 360.0 * barrel_direction, t)
		var pitch = -input_vector.y * max_pitch_angle                # Optional: add pitch while roll
		mesh.rotation_degrees = Vector3(pitch, 0, -roll_angle)
		if barrel_elapsed >= barrel_duration:
			is_doing_barrel_roll = false
			barrel_elapsed = 0.0
			barrel_direction = 0
			barrel_cooldown_timer = barrel_cooldown  # Must cool down before next roll

	else:
		# Normal flight & hard bank logic.
		# Hard bank: hold ui_bank_left or ui_bank_right to bank a full 90° while still moving.
		var is_hard_bank_left = Input.is_action_pressed("ui_bank_left")
		var is_hard_bank_right = Input.is_action_pressed("ui_bank_right")

		var bank = input_vector.x * max_bank_angle
		var pitch = -input_vector.y * max_pitch_angle

		# If holding hard bank, force extreme roll regardless of input_vector.x
		var hard_bank_target = 0.0
		if is_hard_bank_left:
			hard_bank_target = hard_bank_angle      # Full left (usually +90° roll)
		elif is_hard_bank_right:
			hard_bank_target = -hard_bank_angle     # Full right (usually -90° roll)

		# Blend normal bank with the hard bank if pressed
		var use_hard_bank = is_hard_bank_left or is_hard_bank_right
		var target_bank = lerp(bank, hard_bank_target, float(use_hard_bank))

		# Rotation target and smoothing
		var target_rotation = Vector3(-pitch, 0, target_bank)
		var smooth_strength = hard_bank_smoothness if use_hard_bank else rotation_smoothness
		displayed_rotation = displayed_rotation.lerp(target_rotation, delta * smooth_strength)
		mesh.rotation_degrees = displayed_rotation

func get_brake_multiplier() -> float:
	# Returns brake_mult if braking, otherwise normal speed
	return brake_mult if is_braking else 1.0

func shoot_laser():
	# Fires a laser out of player's model
	if laser_scene:
		var laser = laser_scene.instantiate()
		get_parent().add_child(laser)
		laser.global_transform = global_transform

func start_barrel_roll(direction: int):
	# Kicks off a barrel roll in the direction given (+1 right, -1 left)
	if !is_doing_barrel_roll and barrel_cooldown_timer == 0.0:
		is_doing_barrel_roll = true
		barrel_direction = direction
		barrel_elapsed = 0.0

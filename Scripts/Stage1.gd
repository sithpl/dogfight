# Stage1.gd
class_name Stage1 extends Node3D

# NEW CONCEPT FOR LEVEL USING PATH3D
# Mostly copied from Main.gd with lots of tweaks

# --- Gameplay settings ---
@export var base_scroll_speed : float = 15.0  # How fast the world scrolls by default (units/sec)
@export var boost_mult        : float = 1.5   # Multiplies base_scroll_speed when boosting
@export var brake_mult        : float = 0.5   # Multiplies base_scroll_speed when braking
@export var spawn_interval    : float = 2.0   # Seconds between spawns of targets
@export var default_fov       : float = 90.0  # Camera FOV by default
@export var boost_fov         : float = 115.0 # Camera FOV when boosting (speed effect)
@export var brake_fov         : float = 75.0  # Camera FOV when braking (tunnel vision effect)
@export var fov_lerp_speed    : float = 3.0   # How quickly the camera FOV transitions


# --- Node settings ---
@onready var fade_effect : ColorRect         = $FadeEffect                # ColorRect used for fade effect (set at Z Index 1)
@onready var player      : CharacterBody3D   = $Gameplay/Player           # Player node
@onready var camera      : Camera3D          = $Gameplay/Bounds/PlayerCam # Main camera (controls view & FOV)
@onready var targets     : Node3D            = $Level/Targets             # Targets node
@onready var ground      : MeshInstance3D    = $Level/Ground              # Floor mesh
#@onready var horizon     : MeshInstance3D    = $Level/Horizon             # Distant horizon mesh
@onready var theme       : AudioStreamPlayer = $Level/Theme               # Level background music
@onready var voice_sfx   : AudioStreamPlayer = $Level/VoiceSFX            # Voice sound effect player

# --- Path nodes (new) ---
@onready var path_node   : Path3D            = $Level/Path3D
@onready var path_follow : PathFollow3D      = $Level/Path3D/PathFollow3D

# --- Preload Nodes ---
@onready var hud_scene = preload("res://Scenes/HUD.tscn")
@onready var start_menu_scene = preload("res://Scenes/StartMenu.tscn")

# --- Constants ---
const spawn_z_distance : float = 100.0    # Distance in world units ahead of player to spawn
const LOOK_AHEAD_DISTANCE : float = 2.0   # Distance for forward direction when orienting targets

# --- Game state variables ---
var scroll_speed        : float = 20.0 # Current scroll speed (can be boosted/braked)
var spawn_timer         : float = 0.0  # Time left until next target spawn
var hud                                # Used to instantiate preloaded $HUD scene (hud_scene)
var score               : int = 0      # Score total
var start_menu                         # Used to instantiate preloaded $StartMenu scene (start_menu_scene)
var menu_is_open        : bool = false # Tracks StartMenu status (open = true/close = false)
var is_mission_finished : bool = false # Tracks current game status (completed = true, playing = false)
var score_goal_1        : bool = false

# --- BoostMeter tuning ---
@export var max_meter: float = 100.0
@export var recharge_rate: float = 20.0
@export var cooldown_after_use: float = 0.8
@export var boost_drain_rate: float = 40.0
@export var brake_drain_rate: float = 12.0

# --- BoostMeter state ---
var meter: float = 0.0
var cooldown_remaining: float = 0.0

# Cached path data (in world units)
var _path_length: float = 0.0
var _baked_points : PackedVector3Array = PackedVector3Array()

# Current distance along the path (in world units)
var _current_distance: float = 0.0

func _ready():
	$StartMenu.visible = false

	# Fade in
	fade_effect.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 0.0, 1.0)

	# HUD
	hud = hud_scene.instantiate()
	add_child(hud)
	if hud:
		hud.set_score(score)
	if hud and hud.has_node("BoostMeter"):
		hud.boost_meter.min_value = 0.0
		hud.boost_meter.max_value = max_meter

	meter = max_meter
	cooldown_remaining = 0.0
	_update_hud_meter()

	hud.show_mission_start()
	await get_tree().create_timer(2.0).timeout
	hud.hide_mission_start()
	hud.set_score(0)

	# Prepare baked path data
	if path_node and path_node.curve:
		_path_length = path_node.curve.get_baked_length()
		# get_baked_points() returns a PackedVector3Array of points along the curve
		_baked_points = path_node.curve.get_baked_points()
	else:
		_path_length = 0.0
		_baked_points = PackedVector3Array()

	# initialise PathFollow3D global position from _current_distance (keeps basis)
	_current_distance = 0.0
	_apply_current_distance_position()

	# spawn timer
	spawn_timer = spawn_interval

	var gameplay_scene = preload("res://Scenes/Gameplay.tscn")
	var gameplay_inst = gameplay_scene.instantiate()
	# parent to PathFollow3D so Gameplay inherits the path transform
	path_follow.add_child(gameplay_inst)
	# reset local transform so it sits at the PathFollow origin
	gameplay_inst.transform = Transform3D.IDENTITY

	# optionally disable the Gameplay camera (see section 3)
	var internal_cam = gameplay_inst.get_node_or_null("Bounds/PlayerCam")
	if internal_cam:
		internal_cam.current = false

	# make sure your Stage1 camera (or whichever camera you want) is current
	# 'camera' must reference the camera you want to use (e.g., Level/Path3D/PathFollow3D/Gameplay/Bounds/PlayerCam)
	camera.make_current()

func _input(event):
	if menu_is_open:
		return
	if event.is_action_pressed("ui_start"):
		show_start_menu()

func _process(delta):
	# mission end
	if score >= 10 and not is_mission_finished:
		is_mission_finished = true
		game_finished()

	# Boost meter handling (unchanged)
	var prev_meter = meter
	var prev_cooldown = cooldown_remaining

	if player and player.is_boosting and meter > 0.0:
		meter = clamp(meter - boost_drain_rate * delta, 0.0, max_meter)
		cooldown_remaining = cooldown_after_use
		if meter <= 0.0:
			meter = 0.0
			player.is_boosting = false
			if player.boost_sfx and player.boost_sfx.is_playing():
				player.boost_sfx.stop()
	if player and player.is_braking and meter > 0.0:
		meter = clamp(meter - brake_drain_rate * delta, 0.0, max_meter)
		cooldown_remaining = cooldown_after_use
		if meter <= 0.0:
			meter = 0.0
			player.is_braking = false
			if player.brake_sfx and player.brake_sfx.is_playing():
				player.brake_sfx.stop()

	if cooldown_remaining > 0.0:
		cooldown_remaining = max(cooldown_remaining - delta, 0.0)
	else:
		if meter < max_meter:
			meter = clamp(meter + recharge_rate * delta, 0.0, max_meter)

	if meter != prev_meter or cooldown_remaining != prev_cooldown:
		_update_hud_meter()

	# movement multipliers
	var speed_mult := 1.0
	if player.is_boosting:
		speed_mult = boost_mult
	elif player.is_braking:
		speed_mult = brake_mult

	var input_left = Input.is_action_pressed("ui_left")
	var input_right = Input.is_action_pressed("ui_right")
	var bank_left = Input.is_action_pressed("ui_bank_left")
	var bank_right = Input.is_action_pressed("ui_bank_right")
	var bank_speed_mult = 1.0
	if (bank_left and input_left) or (bank_right and input_right):
		bank_speed_mult = 0.8

	scroll_speed = base_scroll_speed * speed_mult * bank_speed_mult

	# Camera FOV smoothing
	var target_fov = default_fov
	if player.is_boosting:
		target_fov = boost_fov
	if player.is_braking:
		target_fov = brake_fov
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)

	# --- Path advancement: increment current distance and apply position ---
	if _path_length > 0.0 and path_follow:
		_current_distance += scroll_speed * delta
		# wrap
		if _current_distance >= _path_length:
			_current_distance = fmod(_current_distance, _path_length)
		_apply_current_distance_position()

	# --- Spawning targets ahead along the path ---
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_target()
		spawn_timer = spawn_interval

# --- Helper: set path_follow global position from _current_distance (keeps basis unchanged) ---
func _apply_current_distance_position():
	if not path_follow or _path_length <= 0.0 or _baked_points.size() == 0:
		return
	var pos := _position_at_distance(_current_distance)
	# preserve current basis (rotation) of the PathFollow3D, just set its origin/position
	var current_basis = path_follow.global_transform.basis
	path_follow.global_transform = Transform3D(current_basis, pos)

# Compute a position along the baked points at a given distance (world units).
# Linear-interpolates between baked points to get smooth positioning.
func _position_at_distance(distance: float) -> Vector3:
	if _baked_points.size() == 0:
		return Vector3.ZERO

	# clamp/wrap distance into [0, _path_length)
	if _path_length > 0.0:
		if distance < 0.0:
			distance = fmod(distance, _path_length) + _path_length
		elif distance >= _path_length:
			distance = fmod(distance, _path_length)

	# walk baked segments
	var acc := 0.0
	for i in range(_baked_points.size() - 1):
		var a = _baked_points[i]
		var b = _baked_points[i + 1]
		var seg_len = a.distance_to(b)
		if distance <= acc + seg_len or i == _baked_points.size() - 2:
			var local_d = distance - acc
			var t = 0.0
			if seg_len > 0.0:
				t = clamp(local_d / seg_len, 0.0, 1.0)
			return a.lerp(b, t)
		acc += seg_len

	# fallback: last baked point
	return _baked_points[_baked_points.size() - 1]

# Spawn target ahead along the path using _position_at_distance to place & orient it
func spawn_target():
	var scene = preload("res://Scenes/Targets.tscn")
	var inst = scene.instantiate()
	if _path_length <= 0.0 or _baked_points.size() == 0 or path_follow == null:
		push_error("spawn_target: No valid baked path data; cannot spawn target.")
		return

	var spawn_distance = _current_distance + spawn_z_distance
	# wrap
	if spawn_distance >= _path_length:
		spawn_distance = fmod(spawn_distance, _path_length)

	var pos = _position_at_distance(spawn_distance)
	inst.global_transform = Transform3D(inst.global_transform.basis, pos)

	# look-ahead for orientation
	var ahead_distance = spawn_distance + LOOK_AHEAD_DISTANCE
	if ahead_distance >= _path_length:
		ahead_distance = fmod(ahead_distance, _path_length)
	var ahead_pos = _position_at_distance(ahead_distance)
	inst.look_at(ahead_pos, Vector3.UP)

	#targets.add_child(inst)
	#targets.add_to_group("Enemy")
	#if inst.has_signal("target_destroyed"):
		#inst.target_destroyed.connect(_on_target_destroyed)

func _on_target_destroyed():
	score += 1
	hud.set_score(score)

func show_start_menu():
	if menu_is_open:
		return
	get_tree().paused = true
	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	start_menu.show()
	menu_is_open = true

func on_start_menu_closed():
	menu_is_open = false

func game_finished():
	voice_sfx.play()
	await voice_sfx.finished

	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5)
	await tween.finished

	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	start_menu.show()
	start_menu.pause_label.text = "MISSION COMPLETE"
	get_tree().paused = true

func _update_hud_meter():
	if not hud:
		return
	if hud.has_method("_on_meter_changed"):
		hud._on_meter_changed(meter, max_meter, cooldown_remaining)
	else:
		if hud.has_node("BoostMeterPanel/BoostMeter"):
			var pb = hud.get_node("BoostMeterPanel/BoostMeter") as ProgressBar
			if pb:
				pb.min_value = 0.0
				pb.max_value = max_meter
				pb.value = meter
				pb.modulate.a = 0.7 if cooldown_remaining > 0.0 else 1.0

# Stage_TEST.gd
class_name Stage_TEST extends Node3D

# NEW CONCEPT FOR LEVEL USING PATH3D
# Mostly copied from Main.gd with lots of tweaks

# 12/02/25
# OKAY FUCK PATH3D BUT I'M KEEPING THE LEVEL FOR TESTING

# 12/07/25
# Stage_TEST base_scroll_speed = 15 units/sec
# Corneria from MISSION START to stage boss dead: 00:03:08 (188 secs)
	# Water to Land      -> 00:00:33 (495 world units)
	# Land to City       -> 00:00:09 (135 world units)
	# City to Checkpoint -> 00:00:40 (600 world units)
	# Checkpoint to Boss -> 00:01:43
	# Boss Death         -> 00:00:03
# 188 * 15 = 2835 -> Round up to 2900
# $Level/Base PlaneMesh size Y = 2900

# --- Gameplay settings ---
@export var base_scroll_speed : float = 15.0  ## How fast the world scrolls by default (units/sec)
@export var boost_mult        : float = 1.5   ## Multiplies base_scroll_speed when boosting
@export var brake_mult        : float = 0.5   ## Multiplies base_scroll_speed when braking
@export var spawn_interval    : float = 2.0   ## Seconds between spawns of targets
@export var default_fov       : float = 75.0  ## Camera FOV by default
@export var boost_fov         : float = 90.0  ## Camera FOV when boosting (speed effect)
@export var brake_fov         : float = 50.0  ## Camera FOV when braking (tunnel vision effect)
@export var fov_lerp_speed    : float = 3.0   ## How quickly the camera FOV transitions


# --- Node settings ---
@onready var fade_effect : ColorRect         = $FadeEffect                # ColorRect used for fade effect (set at Z Index 1)
@onready var camera      : Camera3D          = $Gameplay/Bounds/PlayerCam # Main camera (controls view & FOV)
@onready var player      : CharacterBody3D   = $Gameplay/Player           # Player node
@onready var center      : Node3D            = $Gameplay/Center           # Center node
@onready var fogwall     : MeshInstance3D    = $Level/FogWall             # FogWall node
@onready var ground      : MeshInstance3D    = $Level/Base                # Base mesh
@onready var enemy       : Node3D            = $Level/Enemy               # Enemy container
@onready var theme       : AudioStreamPlayer = $Level/Theme               # Level background music
#@onready var voice_sfx   : AudioStreamPlayer = $Level/VoiceSFX            # Voice sound effect player

# --- Preload Nodes ---
@onready var hud_scene = preload("res://Scenes/HUD.tscn")
@onready var start_menu_scene = preload("res://Scenes/StartMenu.tscn")

# --- Constants ---
const spawn_z_distance : float = 100.0    # Distance in world units ahead of player to spawn
const look_ahead_distance : float = 2.0   # Distance for forward direction when orienting targets

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
@export var max_meter          : float = 100.0
@export var recharge_rate      : float = 20.0
@export var cooldown_after_use : float = 0.8
@export var boost_drain_rate   : float = 40.0
@export var brake_drain_rate   : float = 12.0

# --- BoostMeter state ---
var meter              : float = 0.0
var cooldown_remaining : float = 0.0

# Cached path data (in world units)
var path_length  : float = 0.0
var baked_points : PackedVector3Array = PackedVector3Array()

# Current distance along the path (in world units)
var current_distance : float = 0.0

# Called once when scene starts
func _ready():
	$StartMenu.visible = false

	# Connect existing enemies that are under $Level (including deep descendants)
	_connect_existing_level_enemies()

	# Listen for future nodes being added so we can hook up enemies created at runtime
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

	# Fade in
	fade_effect.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 0.0, 1.0)

	# HUD
	hud = hud_scene.instantiate()
	add_child(hud)
	if hud:
		hud._set_score(score)
	if hud and hud.has_node("BoostMeter"):
		hud.boost_meter.min_value = 0.0
		hud.boost_meter.max_value = max_meter

	meter = max_meter
	cooldown_remaining = 0.0
	_update_hud_meter()

	# Call HUD.gd/show_mission_start(header, start_text)
	hud._show_mission_start("Stage_TEST", "-Mission Description-")
	# Hide MissionStart Panel after a 2 seconds
	await get_tree().create_timer(2.0).timeout
	# Call HUD.gd/hide_mission_start()
	hud._hide_mission_start()
	# Call HUD.gd/set_score(), set initial score #
	hud._set_score(0)

	# Play starfox64-corneria-remix.wav
	theme.play()
	# "Corneria" by NoteBlock
	# Barrel Roll: An Electronic Tribute to Star Fox 64
	# https://www.youtube.com/watch?v=zZF0_xJ3bPA

	var gameplay_scene = preload("res://Scenes/Gameplay.tscn")
	var gameplay_inst = gameplay_scene.instantiate()

	# reset local transform so it sits at the PathFollow origin
	gameplay_inst.transform = Transform3D.IDENTITY

	# optionally disable the Gameplay camera (see section 3)
	var internal_cam = gameplay_inst.get_node_or_null("Bounds/PlayerCam")
	if internal_cam:
		internal_cam.current = false

	camera.make_current()
	center.set("lock_z_to_plane", true)

# Checks for specific inputs
func _input(event):
	if menu_is_open:
		return
	if event.is_action_pressed("ui_start"):
		_show_start_menu()

# Called every frame
func _process(delta):
	# Mission end
	#if score == 7:
		#is_mission_finished = true
		#_mission_completed()
	#if $Gameplay/Player.current_vehicle_hp == 0:
		#is_mission_finished = false
		#_mission_completed()

	# Boost meter handling
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

	# Movement multipliers
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

	# Change camera FOV depending on speed for effect
	var target_fov = default_fov
	# If player presses ui_boost
	if player.is_boosting:
		# Set FOV to 115
		target_fov = boost_fov
	# If player presses ui_brake
	if player.is_braking:
		# Set FOV to 75
		target_fov = brake_fov

	# Smoothly interpolate camera fov for polish effect
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)

func _physics_process(delta: float):
	if is_instance_valid(center):
		var forward = -center.global_transform.basis.z.normalized()
		center.global_translate(forward * scroll_speed * delta)

	# if Engine.get_physics_frames() % 60 == 0:
	#     print("DEBUG Stage_TEST phys: center = ", center.global_transform.origin)

func _position_at_distance(distance: float) -> Vector3:
	if baked_points.size() == 0:
		return Vector3.ZERO

	# Clamp/wrap distance into [0, _path_length)
	if path_length > 0.0:
		if distance < 0.0:
			distance = fmod(distance, path_length) + path_length
		elif distance >= path_length:
			distance = fmod(distance, path_length)

	# Walk baked segments
	var acc := 0.0
	for i in range(baked_points.size() - 1):
		var a = baked_points[i]
		var b = baked_points[i + 1]
		var seg_len = a.distance_to(b)
		if distance <= acc + seg_len or i == baked_points.size() - 2:
			var local_d = distance - acc
			var t = 0.0
			if seg_len > 0.0:
				t = clamp(local_d / seg_len, 0.0, 1.0)
			return a.lerp(b, t)
		acc += seg_len

	# Last baked point
	return baked_points[baked_points.size() - 1]

# Updates HUD/ScoreCounter on target destroyed
func _on_target_destroyed():
	#print("Stage_TEST.gd -> on_target_destroyed() called!")
	# Add 1 hit to total score
	score += 1
	# Call set_score in HUD.gd
	hud._set_score(score)

# Called in _input when ui_start is pressed
func _show_start_menu():
	if menu_is_open:
		return
	get_tree().paused = true
	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	start_menu.show()
	menu_is_open = true

# Updates menu_is_closed when StartMenu is closed
func _on_start_menu_closed():
	menu_is_open = false

# Called when score = X
func _mission_completed():
	if is_mission_finished == true:
		#voice_sfx.play()
		#await voice_sfx.finished

		var tween = get_tree().create_tween()
		tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5)
		await tween.finished

		start_menu = start_menu_scene.instantiate()
		add_child(start_menu)
		start_menu.show()
		start_menu.pause_label.text = "MISSION COMPLETE"
		get_tree().paused = true

	if is_mission_finished == false:
		#voice_sfx.play()
		#await voice_sfx.finished

		var tween = get_tree().create_tween()
		tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5)
		await tween.finished

		start_menu = start_menu_scene.instantiate()
		add_child(start_menu)
		start_menu.show()
		start_menu.pause_label.text = "MISSION FAILED"
		get_tree().paused = true

# Update HUD boost meter display
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
		if hud.has_node("DamMeterPanel/DamMeter"):
			var pb = hud.get_node("DamMeterPanel/DamMeter") as ProgressBar
			if pb:
				pb.min_value = 0.0
				pb.max_value = $Gameplay/Player.max_vehicle_hp
				pb.value = $Gameplay/Player.current_vehicle_hp
				#pb.modulate.a = 0.7 if cooldown_remaining > 0.0 else 1.0

# Connect already-present Enemy-group nodes that are descendants of $Level
func _connect_existing_level_enemies():
	var cb := Callable(self, "_on_target_destroyed")
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(enemy) and _is_descendant_of_level(enemy):
			if enemy.has_signal("target_destroyed") and not enemy.is_connected("target_destroyed", cb):
				enemy.connect("target_destroyed", cb)

# If the added node is an enemy and it sits under $Level, connect its signal.
func _on_node_added(node: Node):
	if not is_instance_valid(node):
		return
	# If the node itself is an enemy and lives under $Level, connect it
	if node.is_in_group("Enemy") and _is_descendant_of_level(node):
		var cb := Callable(self, "_on_target_destroyed")
		if node.has_signal("target_destroyed") and not node.is_connected("target_destroyed", cb):
			node.connect("target_destroyed", cb)

# Rreturns true if the given node is a descendant (any depth) of $Level
func _is_descendant_of_level(node: Node):
	if not is_instance_valid(node):
		return false
	var root := $Level
	var n := node
	while n != null:
		if n == root:
			return true
		n = n.get_parent()
	return false

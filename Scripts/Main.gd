# Main.gd
class_name Main extends Node3D

# --- Gameplay settings ---
@export var base_scroll_speed   : float = 20.0    # How fast the world scrolls by default (units/sec)
@export var boost_mult          : float = 2.0     # Multiplies base_scroll_speed when boosting
@export var brake_mult          : float = 0.5     # Multiplies base_scroll_speed when braking
@export var spawn_interval      : float = 1.5     # Seconds between spawns of obstacles
@export var default_fov         : float = 90.0    # Camera FOV by default
@export var boost_fov           : float = 115.0   # Camera FOV when boosting (speed effect)
@export var brake_fov           : float = 75.0    # Camera FOV when braking (tunnel vision effect)
@export var fov_lerp_speed      : float = 6.0     # How quickly the camera FOV transitions

# --- Node settings ---
@onready var fade_effect : ColorRect         = $ColorRect                    # ColorRect used for fade effect (set at Z Index 1)
@onready var player      : CharacterBody3D   = $Gameplay/Player              # Player node
@onready var camera      : Camera3D          = $Gameplay/Bounds/PlayerCam    # Main camera (controls view & FOV)
@onready var obstacles   : Node3D            = $Obstacles                    # Obstacles node
@onready var ground      : MeshInstance3D    = $Ground                       # Floor mesh
@onready var horizon     : MeshInstance3D    = $Horizon                      # Distant horizon mesh
@onready var theme       : AudioStreamPlayer = $Theme                        # Level background music
@onready var voice_sfx   : AudioStreamPlayer = $VoiceSFX                     # Voice sound effects

# --- Preload Nodes ---
@onready var hud_scene = preload("res://Scenes/HUD.tscn")
@onready var start_menu_scene = preload("res://Scenes/StartMenu.tscn")

# --- Constants ---
const spawn_z_distance : float = 100.0    # How far ahead to spawn obstacles (Z+)

# --- Game state variables ---
var scroll_speed     : float = 20.0       # Current scroll speed (can be boosted/braked)
var spawn_timer      : float = 0.0        # Time left until next obstacle spawn
var hud                                   # Used to instantiate preloaded $HUD scene (hud_scene)
var score : int = 0                       # Score total
var start_menu                            # Used to instantiate preloaded $StartMenu scene (start_menu_scene)
var menu_is_open: bool = false            # Tracks StartMenu status (open = true/close = false)
var is_mission_finished: bool = false     # Tracks current game status (completed = true, playing = false)

# Called once when scene starts
func _ready():
	# Ensures StartMenu is hidden
	$StartMenu.visible = false

	# Set fade_effect (ColorRect) to fully visible and solid black
	fade_effect.modulate.a = 1.0
	# Create tween in current node
	var tween = get_tree().create_tween()
	# Fade alpha from 1 to 0 over 1.0s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 0.0, 1.0)
	
	# Instantiate HUD.tscn on existing hud var
	hud = hud_scene.instantiate()
	# Add HUD window
	add_child(hud)
	# Call HUD.gd/show_mission_start()
	hud.show_mission_start()
	# Hide MissionStart Panel after a 2 seconds
	await get_tree().create_timer(2.0).timeout
	# Call HUD.gd/hide_mission_start()
	hud.hide_mission_start()
	# Call HUD.gd/set_score(), set initial score #
	hud.set_score(+1) 

	# Play starfox64-corneria-remix.wav
	theme.play()
	# "Corneria" by NoteBlock
	# Barrel Roll: An Electronic Tribute to Star Fox 64
	# https://www.youtube.com/watch?v=zZF0_xJ3bPA

# Checks for specific inputs
func _input(event):
	# Checks if StartMenu is already open
	if menu_is_open: 
		# Ignore input while menu is open
		return
	# If player presses ui_start
	if event.is_action_pressed("ui_start"):
		print("Main.gd -> ui_start pressed!")
		# Call show_start_menu()
		show_start_menu()

# Called every frame
func _process(delta):
	# delta = time since last frame (in seconds)
	#print("menu_is_open: ",menu_is_open)

	# When score = X, end the game
	if score >= 10 and not is_mission_finished:
		is_mission_finished = true
		game_finished()

	# Calculate speed modifier based on player actions
	var speed_mult := 1.0
	# If player presses ui_boost
	if player.is_boosting: 
		# Multiply speed by boost_mult, go faster
		speed_mult = boost_mult 
	# If player presses ui_brake
	elif player.is_braking: 
		# Multiply speed by brake_mult, go slower
		speed_mult = brake_mult 

	# Detect if player is hard banking in movement direction
	var input_left = Input.is_action_pressed("ui_left")
	var input_right = Input.is_action_pressed("ui_right")
	var bank_left = Input.is_action_pressed("ui_bank_left")
	var bank_right = Input.is_action_pressed("ui_bank_right")
	var bank_speed_mult = 1.0
	if (bank_left and input_left) or (bank_right and input_right):
		# Reduce speed by 20% when sharp banking
		bank_speed_mult = 0.8

	scroll_speed = base_scroll_speed * speed_mult * bank_speed_mult

	# Change camera FOV depending on speed for effect
	var target_fov = default_fov
	# If player presses ui_boost
	if player.is_boosting:
		# Set FOV to 115
		target_fov = boost_fov
	# If player presses ui_brake
	elif player.is_braking:
		# Set FOV to 75
		target_fov = brake_fov

	# Smoothly interpolate camera fov for polish effect
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)

	# Scroll the ground towards the camera so it looks like flying
	ground.position.z -= scroll_speed * delta

	# Snap the ground forward to "loop" it if it goes too far back
	if ground.position.z < player.position.z - 25:
		ground.position.z += 50
		#print("Main.gd -> ground reset")

	# Move all obstacles backwards (towards camera/player)
	for obstacle in obstacles.get_children():
		obstacle.translate(Vector3(0, 0, -scroll_speed * delta))
		# Remove (free) the obstacle if it passes behind the camera/player X units
		if obstacle.position.z < -10:
			obstacle.queue_free()
			#print("Main.gd -> obstacle.queue_free() called")
			# Subtract 1 hit from total score
			score -= 1
			#print("Hits: -1")
			# Call set_score in HUD.gd
			hud.set_score(score)

	# --- Spawn obstacles at intervals ---
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_obstacle()
		spawn_timer = spawn_interval    # Reset timer

# Creates a new obstacle ahead of the player
func spawn_obstacle():
	#print("Main.gd -> spawn_obstacle() called")
	var scene = preload("res://Scenes/Obstacles.tscn")
	var inst = scene.instantiate()
	
	# Randomly set obstacle X/Y, always ahead of player in +Z
	var player_pos = player.position
	inst.position = Vector3(
		randf_range(-30, 30),           # X (left/right)
		randf_range(-3, 6),             # Y (up/down)
		player_pos.z + spawn_z_distance # Z (ahead)
	)
	
	# Add obstacle to scene
	obstacles.add_child(inst)
	#print("Obstacle spawned at: ", inst.position)
	
	# Connect obstacle_destroyed signal to a handler in Main.gd
	inst.obstacle_destroyed.connect(_on_obstacle_destroyed)

# Updates HUD/ScoreCounter on obstacle destroyed
func _on_obstacle_destroyed():
	print("Main.gd -> on_obstacle_destroyed() called!")
	# Add 1 hit to total score
	score += 1
	#print("Hits: +1")
	# Call set_score in HUD.gd
	hud.set_score(score)

# Called in _input when ui_accept is pressed
func show_start_menu():
	print("Main.gd -> show_start_menu called!")
	# Prevent StarMenu opening if already open
	if menu_is_open: 
		return 
	# Pause Main node
	get_tree().paused = true
	# Instantiate StartMenu.tscn on existing start_menu var
	start_menu = start_menu_scene.instantiate()
	# Create new StartMenu window
	add_child(start_menu)
	# Show the new StartMenu
	start_menu.show()
	# Update menu_is_open to true to prevent another StartMenu from spawning
	menu_is_open = true

# Updates menu_is_closed when StartMenu is closed
func on_start_menu_closed():
	print("Main.gd -> on_start_menu_closed() called!")
	# Update menu_is_open to false to allow another pause
	menu_is_open = false

# Called when score = X
func game_finished():
	print("Main.gd -> game_finished() called!")
	
	# Play pep-goodgoing.wav
	voice_sfx.play() 
	# Wait until audio ends
	await voice_sfx.finished 

	# Create tween in current node
	var tween = get_tree().create_tween() 
	# Fade alpha from 0 to 1 over 0.5s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5) 
	# Wait until fade out is done
	await tween.finished 

	# Instantiate $StartMenu on existing start_menu var
	start_menu = start_menu_scene.instantiate()
	# Create new StartMenu window
	add_child(start_menu) 
	# Show the new StartMenu
	start_menu.show() 
	# Update Paused label with new text
	start_menu.pause_label.text = "MISSION COMPLETE" 
	# Pause Main node
	get_tree().paused = true 

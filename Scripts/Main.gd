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

@onready var fade_effect : ColorRect         = $ColorRect
@onready var player      : CharacterBody3D   = $Gameplay/Player              # Player node
@onready var camera      : Camera3D          = $Gameplay/Bounds/PlayerCam    # Main camera (controls view & FOV)
@onready var obstacles   : Node3D            = $Obstacles                    # Obsacles node
@onready var ground      : MeshInstance3D    = $Ground                       # Floor mesh
@onready var horizon     : MeshInstance3D    = $Horizon                      # Distant horizon mesh
@onready var theme       : AudioStreamPlayer = $Theme
@onready var voice_sfx   : AudioStreamPlayer = $VoiceSFX

@onready var hud_scene = preload("res://Scenes/HUD.tscn")
@onready var start_menu_scene = preload("res://Scenes/StartMenu.tscn")

const spawn_z_distance : float = 100.0    # How far ahead to spawn obstacles (Z+)

# --- Game state variables ---
var scroll_speed     : float = 20.0       # Current scroll speed (can be boosted/braked)
var spawn_timer      : float = 0.0        # Time left until next obstacle spawn
var hud
var score : int = 0
var start_menu
var menu_is_open: bool = false
var is_mission_finished: bool = false

func _ready():
	# Called once when scene starts
	$StartMenu.visible = false
	# Fade in effect
	fade_effect.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 0.0, 1.0) # Fade in to transparent
	# Show MissionStart Panel
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.show_mission_start()
	# Hide MissionStart Panel after a 2 seconds
	await get_tree().create_timer(2.0).timeout
	hud.hide_mission_start()
	hud.set_score(+1) # Sets initial score
	# Play Main theme
	theme.play()
	# "Corneria" by NoteBlock
	# Barrel Roll: An Electronic Tribute to Star Fox 64
	# https://www.youtube.com/watch?v=zZF0_xJ3bPA

func _input(event):
	if menu_is_open: 
		return # Ignore input while menu is open
	if event.is_action_pressed("ui_start"):
		print("Main.gd -> ui_start pressed!")
		show_start_menu()

func _process(delta):
	# delta = time since last frame (in seconds)
	#print("menu_is_open: ",menu_is_open)

	if score >= 10 and not is_mission_finished:
		is_mission_finished = true
		game_finished()

	# Calculate speed modifier based on player actions
	var speed_mult := 1.0
	if player.is_boosting:
		speed_mult = boost_mult           # Go faster!
	elif player.is_braking:
		speed_mult = brake_mult           # Go slower

	# Detect if player is hard banking in movement direction
	var input_left = Input.is_action_pressed("ui_left")
	var input_right = Input.is_action_pressed("ui_right")
	var bank_left = Input.is_action_pressed("ui_bank_left")
	var bank_right = Input.is_action_pressed("ui_bank_right")
	var bank_speed_mult = 1.0
	if (bank_left and input_left) or (bank_right and input_right):
		bank_speed_mult = 0.8 # Reduce speed by 20% when sharp banking

	scroll_speed = base_scroll_speed * speed_mult * bank_speed_mult

	# Change camera FOV depending on speed for effect
	var target_fov = default_fov
	if player.is_boosting:
		target_fov = boost_fov
	elif player.is_braking:
		target_fov = brake_fov

	# Smoothly interpolate camera fov for polish effect
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)

	# --- Scroll the ground towards the camera so it looks like flying ---
	ground.position.z -= scroll_speed * delta

	# Snap the ground forward to "loop" it if it goes too far back
	if ground.position.z < player.position.z - 25:
		ground.position.z += 50
		#print("Main.gd -> ground reset")

	# --- Move all obstacles backwards (towards camera/player) ---
	for obstacle in obstacles.get_children():
		obstacle.translate(Vector3(0, 0, -scroll_speed * delta))
		# Remove (free) the obstacle if it passes behind the camera/player
		if obstacle.position.z < -10:
			obstacle.queue_free()
			#print("Main.gd -> obstacle.queue_free() called")
			#print("Hits: -1")
			score -= 1
			hud.set_score(score)

	# --- Spawn obstacles at intervals ---
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_obstacle()
		spawn_timer = spawn_interval    # Reset timer

func spawn_obstacle():
	# Creates a new obstacle ahead of the player
	#print("Main.gd -> spawn_obstacle() called")
	var scene = preload("res://Scenes/Obstacles.tscn")
	var inst = scene.instantiate()
	
	# Randomly set obstacle X/Y, always ahead of player in +Z
	var player_pos = player.position
	inst.position = Vector3(
		randf_range(-30, 30),          # X (left/right)
		randf_range(-3, 6),            # Y (up/down)
		player_pos.z + spawn_z_distance # Z (ahead)
	)
	obstacles.add_child(inst)
	#print("Obstacle spawned at: ", inst.position)
	# Connect obstacle_destroyed signal to a handler in Main.gd
	inst.obstacle_destroyed.connect(_on_obstacle_destroyed)
	
func _on_obstacle_destroyed():
	#print("Hits: +1")
	score += 1
	hud.set_score(score)

func show_start_menu():
	print("Main.gd -> show_start_menu called!")
	if menu_is_open: 
		return # Prevent opening if already open
	get_tree().paused = true
	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	start_menu.show()
	menu_is_open = true

func on_start_menu_closed():
	print("Main.gd -> on_start_menu_closed() called!")
	menu_is_open = false
	
func game_finished():
	voice_sfx.play()
	await voice_sfx.finished # Wait until audio ends

	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5) # Fade alpha from 0 to 1 over 0.5s
	await tween.finished

	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	start_menu.show()
	start_menu.pause_label.text = "MISSION COMPLETE"
	get_tree().paused = true

# Main.gd
class_name Main extends Node3D

# --- Gameplay settings ---
@export var base_scroll_speed   : float = 20.0    # How fast the world scrolls by default (units/sec)
@export var boost_mult          : float = 2.0     # Multiplies base_scroll_speed when boosting
@export var brake_mult          : float = 0.5     # Multiplies base_scroll_speed when braking
@export var spawn_interval      : float = 1.5     # Seconds between auto-spawns of obstacles
@export var default_fov         : float = 90.0    # Camera field of view by default
@export var boost_fov           : float = 115.0   # Camera FOV when boosting (adds speed feel)
@export var brake_fov           : float = 75.0    # Camera FOV when braking (tunnel vision feel)
@export var fov_lerp_speed      : float = 6.0     # How quickly the camera FOV transitions

@onready var player    : CharacterBody3D   = $Gameplay/Player       # The Player node (should have Player.gd)
@onready var camera    : Camera3D          = $Gameplay/Bounds/PlayerCam    # Main camera (controls view & FOV)
@onready var obstacles : Node3D            = $Obstacles    # The Node to hold all obstacles
@onready var ground    : MeshInstance3D    = $Ground       # The "floor" mesh
@onready var horizon   : MeshInstance3D    = $Horizon      # The distant sky mesh, for parallax etc

const spawn_z_distance : float = 100.0    # How far ahead to spawn obstacles (Z+)

# --- Game state variables ---
var scroll_speed     : float = 20.0       # Current scroll speed (can be boosted/braked)
var spawn_timer      : float = 0.0        # Time left until next obstacle spawn
var ground_offset    : float = 0.0        # (Not currently used, could be for tiling ground)

func _ready():
	pass

func _process(delta):
	# delta = time since last frame (in seconds)

	# Calculate speed modifier based on player actions
	var speed_mult := 1.0
	if player.is_boosting:
		speed_mult = boost_mult           # Go faster!
	elif player.is_braking:
		speed_mult = brake_mult           # Go slower
	scroll_speed = base_scroll_speed * speed_mult

	# Change camera FOV (field of view) depending on speed for cool feeling
	var target_fov = default_fov
	if player.is_boosting:
		target_fov = boost_fov
	elif player.is_braking:
		target_fov = brake_fov

	# Smoothly interpolate camera fov for polish effect
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)

	# --- Scroll ("move") the ground towards the camera so it looks like we're flying ---
	ground.position.z -= scroll_speed * delta

	# Snap the ground forward to "loop" it if it goes too far back
	if ground.position.z < player.position.z - 25:
		ground.position.z += 50    # Just a basic wrap
		#print("Main.gd -> ground reset")

	# --- Move all obstacles backwards (towards camera/player) ---
	for obstacle in obstacles.get_children():
		obstacle.translate(Vector3(0, 0, -scroll_speed * delta))
		# Remove (free) the obstacle if it passes behind the camera/player
		if obstacle.position.z < -30:
			obstacle.queue_free()
			#print("Main.gd -> obstacle.queue_free() called")

	# --- Spawn obstacles at intervals ---
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_obstacle()
		spawn_timer = spawn_interval    # Reset timer

func spawn_obstacle():
	# This function creates ("spawns") a new obstacle ahead of the player
	#print("Main.gd -> spawn_obstacle() called")
	var scene = preload("res://Scenes/Obstacles.tscn")
	var inst = scene.instantiate()
	
	# Randomly set obstacle X/Y, always ahead of player in +Z
	var player_pos = player.position
	inst.position = Vector3(
		randf_range(-8, 8),            # X (left/right)
		randf_range(-4.5, 4.5),        # Y (up/down)
		player_pos.z + spawn_z_distance # Z (ahead)
	)
	obstacles.add_child(inst)
	#print("Obstacle spawned at: ", inst.position)

# Gameplay.gd
class_name Gameplay extends Node3D

# --- Gameplay settings ---
@export var move_speed        : float = 10.0   # Movement speed through scene along Z axis
@export var area_bounds_x     : float = 12.0   # Total allowed X axis movement from 0,0,0
@export var area_bounds_y     : float = 4.5    # Total allowed Y axis movement from 0,0,0
@export var plane_z           : float = 0.0    # PlayerMesh tracking for input
@export var reticle1_offset_z : float = -5.0   # Z offset for Reticle1 relative to center
@export var reticle2_offset_z : float = -10.0  # Z offset for Reticle2 relative to center

# --- Node settings ---
@onready var center = $Center             # Central point of player input and movement
@onready var player = $Player/PlayerMesh  # Player ship mesh/model
@onready var reticle1 = $Player/Reticle1  # Reticle nearest to Player
@onready var reticle2 = $Player/Reticle2  # Reticle furthest from Player

# Called once when scene starts
func _ready():
	pass

# Called every frame
func _process(delta: float):
	# delta = time since last frame (in seconds)
	
	# Handle keyboard/controller movement input
	var input_vector = Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x += 1
	if Input.is_action_pressed("ui_right"):
		input_vector.x -= 1
	input_vector = input_vector.normalized()

	# Update center node's position based on input, clamped to area bounds
	var new_pos = center.global_transform.origin
	new_pos.x += input_vector.x * move_speed * delta # Move horizontally (X) according to input
	new_pos.y += input_vector.y * move_speed * delta # Move vertically (Y) according to input
	
	# Clamp X and Y movement so the player can't leave the allowed area_bounds
	new_pos.x = clamp(new_pos.x, -area_bounds_x, area_bounds_x)
	new_pos.y = clamp(new_pos.y, -area_bounds_y, area_bounds_y)
	
	# Lock Z position so the center node stays on the defined tracking plane
	new_pos.z = plane_z
	
	# Apply calculated position to the center node
	center.global_transform.origin = new_pos

	# Update reticle positions relative to center node
	reticle1.global_transform.origin = center.global_transform.origin + Vector3(0, 0, reticle1_offset_z)
	reticle2.global_transform.origin = center.global_transform.origin + Vector3(0, 0, reticle2_offset_z)

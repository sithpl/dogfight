# Gameplay.gd
class_name Gameplay extends Node3D

@export var move_speed        : float = 10.0   # Movement speed through scene along Z axis
@export var area_bounds_x     : float = 12.0   # Total allowed X axis movement from 0,0,0
@export var area_bounds_y     : float = 4.5    # Total allowed Y axis movement from 0,0,0
@export var plane_z           : float = 0.0    # PlayerMesh tracking for input
@export var reticle1_offset_z : float = -5.0   # Z offset for Reticle1
@export var reticle2_offset_z : float = -10.0  # Z offset for Reticle2

@onready var center = $Center
@onready var player = $Player/PlayerMesh
@onready var reticle1 = $Player/Reticle1
@onready var reticle2 = $Player/Reticle2

func _ready():
	#global_transform.origin = Vector3(0, 0, 0) # Center at world origin - OLD
	pass

func _process(delta):
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
	var new_pos = center.global_transform.origin
	new_pos.x += input_vector.x * move_speed * delta
	new_pos.y += input_vector.y * move_speed * delta
	new_pos.x = clamp(new_pos.x, -area_bounds_x, area_bounds_x)
	new_pos.y = clamp(new_pos.y, -area_bounds_y, area_bounds_y)
	new_pos.z = plane_z
	center.global_transform.origin = new_pos

	# Reticle positions
	reticle1.global_transform.origin = global_transform.origin + Vector3(0, 0, reticle1_offset_z)
	reticle2.global_transform.origin = global_transform.origin + Vector3(0, 0, reticle2_offset_z)

# Center.gd
class_name Center extends MeshInstance3D

@export var move_speed: float = 15.0
@export var area_bounds_x: float = 8.0
@export var area_bounds_y: float = 4.5
@export var plane_z: float = 0.0

@export var reticle1_offset_z: float = -10.0
@export var reticle2_offset_z: float = -15.0

@onready var reticle1 := $"../Player/Reticle1"
@onready var reticle2 := $"../Player/Reticle2"

func _ready():
	# Place Center at world origin initially
	global_transform.origin = Vector3(0, 0, 0)

func _process(delta):
	# Move Center freely based on input (X/Y only)
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

	var new_pos = global_transform.origin
	new_pos.x += input_vector.x * move_speed * delta
	new_pos.y += input_vector.y * move_speed * delta
	new_pos.x = clamp(new_pos.x, -area_bounds_x, area_bounds_x)
	new_pos.y = clamp(new_pos.y, -area_bounds_y, area_bounds_y)

	global_transform.origin = new_pos

	# Reticle positions: always aligned in front of Center
	if is_instance_valid(reticle1):
		reticle1.global_transform.origin = global_transform.origin + Vector3(0, 0, reticle1_offset_z)
	if is_instance_valid(reticle2):
		reticle2.global_transform.origin = global_transform.origin + Vector3(0, 0, reticle2_offset_z)

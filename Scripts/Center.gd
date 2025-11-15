# Center.gd
class_name Center extends MeshInstance3D

@export var move_speed: float = 15.0
@export var area_bounds_x: float = 8.0
@export var area_bounds_y: float = 4.5
@export var plane_z: float = 0.0

func _ready():
	global_transform.origin = Vector3(0, 0, -1)
	print("Center global pos:", global_transform.origin)

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
	var new_pos = global_transform.origin
	new_pos.x += input_vector.x * move_speed * delta
	new_pos.y += input_vector.y * move_speed * delta
	new_pos.x = clamp(new_pos.x, -area_bounds_x, area_bounds_x)
	new_pos.y = clamp(new_pos.y, -area_bounds_y, area_bounds_y)
	new_pos.z = plane_z
	global_transform.origin = new_pos

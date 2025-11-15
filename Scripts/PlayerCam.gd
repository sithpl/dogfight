extends Camera3D

# Size of deadzone (soft area)
var deadzone_size = Vector2(7, 3.5)

@onready var player = get_node("../../Player")

func _process(_delta):
	var player_pos = player.global_transform.origin
	var cam_pos = global_transform.origin
	
	var offset = player_pos - cam_pos
	
	# Only move camera if outside deadzone
	if abs(offset.x) > deadzone_size.x:
		cam_pos.x = lerp(cam_pos.x, player_pos.x, 0.1)
	if abs(offset.y) > deadzone_size.y:
		cam_pos.y = lerp(cam_pos.y, player_pos.y, 0.1)
	
	global_transform.origin = cam_pos

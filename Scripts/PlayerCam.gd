# PlayerCam.gd
class_name PlayerCam extends Camera3D

@export var deadzone_size: Vector2 = Vector2(7, 3.5)
@export var follow_speed: float = 6.0 # higher = faster

@onready var player = get_node("../../Player")

func _process(delta):
	# delta = time since last frame (in seconds)
	
	var player_pos = player.global_transform.origin
	var cam_pos = global_transform.origin

	# Get offset from camera to player
	var offset = player_pos - cam_pos

	# Deadzone logic: Camera only cares if the player leaves the deadzone
	var deadzone_offset = Vector3.ZERO
	if abs(offset.x) > deadzone_size.x:
		deadzone_offset.x = offset.x - sign(offset.x) * deadzone_size.x
	if abs(offset.y) > deadzone_size.y:
		deadzone_offset.y = offset.y - sign(offset.y) * deadzone_size.y

	# New desired position is camera's current position plus offset (if any)
	var target_pos = cam_pos + deadzone_offset

	# Smoothly move (delta-based lerp for frame-rate independence)
	global_transform.origin = global_transform.origin.lerp(target_pos, delta * follow_speed)

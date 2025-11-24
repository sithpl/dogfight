# PlayerCam.gd
class_name PlayerCam extends Camera3D

# --- Gameplay settings ---
@export var deadzone_size  : Vector2 = Vector2(7, 3.5)  # X/Y area around the player where the camera won't move
@export var follow_speed   : float   = 6.0              # How quickly the camera tracks the player (higher = faster)

# --- Node settings ---
@onready var player = get_node("../../Player")  # Reference to the Player node (used for tracking)

# Called every frame (to update camera position)
func _process(delta: float):
	# delta = time since last frame (in seconds)

	# Current Player position in world space
	var player_pos = player.global_transform.origin
	# Current Camera position in world space
	var cam_pos = global_transform.origin

	# Calculate the distance (offset) between camera and player
	var offset = player_pos - cam_pos

	# --- Deadzone logic ---
	# Only apply movement if player position exceeds horizontal or vertical deadzone
	# Reduces camera jitter and keeps the camera steady while player is within deadzone
	var deadzone_offset = Vector3.ZERO
	if abs(offset.x) > deadzone_size.x:
		# If player exceeds deadzone in X, apply only amount beyond deadzone
		deadzone_offset.x = offset.x - sign(offset.x) * deadzone_size.x
	if abs(offset.y) > deadzone_size.y:
		# If player exceeds deadzone in Y, apply only amount beyond deadzone
		deadzone_offset.y = offset.y - sign(offset.y) * deadzone_size.y

	# Calculate camera's target position by adding offset to current position
	var target_pos = cam_pos + deadzone_offset

	# Smoothly lerp camera towards target position using delta for framerate and follow_speed for snappiness
	global_transform.origin = global_transform.origin.lerp(target_pos, delta * follow_speed)

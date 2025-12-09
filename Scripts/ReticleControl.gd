# ReticleControl.gd
extends CanvasLayer

# --- Reticle movement settings ---
@export var box_half_width   : float = 200    ## Horizontal distance from box center (pixels)
@export var box_half_height  : float = 120    ## Vertical distance from box center (pixels)
@export var reticle_speed    : float = 600    ## How fast the reticle offsets (pixels/sec)
@export var return_speed     : float = 8.0    ## How quickly reticle recenters (higher = snappier)

@onready var reticle = $Reticle            # The reticle sprite node

var player: Node3D                         # Reference to the Player, set in Main.gd -> ready()
var camera: Camera3D                       # Reference to the Camera3D, set in Main.gd -> ready()

var box_center: Vector2                    # Where the box is on screen (always follows player pos)
var reticle_offset: Vector2 = Vector2.ZERO # Reticle's offset -relative to- box_center (the "cage")

func _ready():
	# Initialize the box center to project the player's current 3D world pos to the screen, or if that fails, just use the center of the screen.
	if camera and player:
		# Convert player 3D position into 2D screen space
		box_center = camera.unproject_position(player.global_transform.origin)
	else:
		box_center = get_viewport().get_visible_rect().size * 0.5
	reticle_offset = Vector2.ZERO                            # Start at center of box
	reticle.position = box_center - reticle.size * 0.5       # Position sprite so reticle is centered

func _process(delta):
	# 1. Update box_center to always follow player's projected position.
	if camera and player:
		box_center = camera.unproject_position(player.global_transform.origin)
	else:
		box_center = get_viewport().get_visible_rect().size * 0.5

	# 2. Read input and build a movement vector
	var input_vector = Vector2.ZERO
	# Below, up/down/left/right are interpreted as screen space, not world
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1

	input_vector = input_vector.normalized()   # Makes diagonal movement not faster

	# 3. Move reticle within box ("deadzone"/cage), or gently return to box center when released
	if input_vector != Vector2.ZERO:
		# Move reticle opposite to input for inertia effect, or just the same direction if desired
		reticle_offset += input_vector * reticle_speed * delta
	else:
		# No input? Gradually return ("lerp") the offset to the center of the box (Vector2.ZERO)
		reticle_offset = reticle_offset.lerp(Vector2.ZERO, delta * return_speed)

	# 4. Clamp so the reticle never leaves the box
	reticle_offset.x = clamp(reticle_offset.x, -box_half_width, box_half_width)
	reticle_offset.y = clamp(reticle_offset.y, -box_half_height, box_half_height)

	# 5. Actually position the reticle node in UI.
	# Always at the center of the player's box, plus the offset, minus half its size (for center anchor)
	reticle.position = (box_center + reticle_offset) - reticle.size * 0.5

func get_normalized_offset():
	# This function gives a value from -1 to +1 (X and Y) representing how far the reticle is from "player forward" inside the movement box.
	# Player.gd uses this value to move the ship/facing/aim in world space.
	return Vector2(
		reticle_offset.x / box_half_width,
		reticle_offset.y / box_half_height
	)

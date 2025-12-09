# PlayerCam.gd
class_name PlayerCam extends Camera3D

@export var deadzone_size  : Vector2 = Vector2(7, 3.5)  ## X/Y deadzone
@export var follow_speed   : float   = 6.0              ## how quickly camera tracks player (higher = snappier)

@export var follow_z_direct : bool = true               ## if true, camera target Z = player_z + initial_offset (no separate z lerp)
@export var z_move_speed    : float = 60.0              ## used only if follow_z_direct == false and you want a capped Z speed (move_toward)

@export var player_path : NodePath = NodePath("../../Player")
@onready var player : Node3D = get_node_or_null(player_path)

var _initial_z_offset : float = -8.5

# debug toggles
@export var dbg_enabled : bool = false
var _dbg_timer : float = 0.0
@export var dbg_interval : float = 1.0

func _ready():
	if not is_instance_valid(player):
		var p = get_parent().get_parent().get_node_or_null("Player")
		if p and p is Node3D:
			player = p
	if is_instance_valid(player):
		_initial_z_offset = global_transform.origin.z - player.global_transform.origin.z

func _process(delta: float):
	if not is_instance_valid(player):
		if dbg_enabled:
			_dbg_timer += delta
			if _dbg_timer >= dbg_interval:
				_dbg_timer = 0.0
				print("DBG PlayerCam: player reference INVALID. player_path=", player_path)
		return

	var player_pos : Vector3 = player.global_transform.origin
	var cam_pos : Vector3 = global_transform.origin

	# X/Y deadzone
	var offset : Vector3 = player_pos - cam_pos
	var deadzone_offset = Vector3.ZERO
	if abs(offset.x) > deadzone_size.x:
		deadzone_offset.x = offset.x - sign(offset.x) * deadzone_size.x
	if abs(offset.y) > deadzone_size.y:
		deadzone_offset.y = offset.y - sign(offset.y) * deadzone_size.y

	# Compose target; handle Z according to mode
	var target_pos = cam_pos + deadzone_offset

	if follow_z_direct:
		# direct: camera should attempt to keep the initial offset behind the player (no separate lerp)
		target_pos.z = player_pos.z + _initial_z_offset
	else:
		# capped-speed approach: move_z toward desired at fixed max speed then use follow_speed for X/Y
		var desired_z = player_pos.z + _initial_z_offset
		# float.move_toward doesn't exist in some Godot versions; use clamp on delta instead:
		var dz = desired_z - cam_pos.z
		var max_dz = z_move_speed * delta
		dz = clamp(dz, -max_dz, max_dz)
		target_pos.z = cam_pos.z + dz

	# single lerp for the whole transform (this avoids double-smoothing)
	global_transform.origin = global_transform.origin.lerp(target_pos, clamp(follow_speed * delta, 0.0, 1.0))

	if dbg_enabled:
		_dbg_timer += delta
		if _dbg_timer >= dbg_interval:
			_dbg_timer = 0.0
			print("DBG PlayerCam:",
				" player_pos=", player_pos,
				" cam_pos=", cam_pos,
				" offset=", offset,
				" deadzone_offset=", deadzone_offset,
				" target_pos=", target_pos,
				" current=", current)

# FogWall.gd
extends MeshInstance3D
class_name FogWall

@export var distance: float = 150.0        # how far in front of the camera the wall sits
@export var opacity: float = 0.6           # overall alpha
@export var noise_tex: Texture2D           # noise/alpha texture to use for the fog
@export var unshaded: bool = true
@export var double_sided: bool = true
@export var fade_edge: float = 0.2         # multiply alpha at edges (0..1) - handled by texture or shader if you need

# If you want to pin to specific camera, set this. Defaults to viewport camera.
@export var camera_path: NodePath

# Quad mesh size used as baseline; script will scale it to match frustum.
const BASE_QUAD_SIZE := Vector2(2.0, 2.0)

var _cam: Camera3D = null
var _mat: StandardMaterial3D = null

func _ready() -> void:
	# Ensure we have a mesh (quad)
	if not mesh:
		var qm := QuadMesh.new()
		qm.size = BASE_QUAD_SIZE
		mesh = qm

	# Find camera (explicit path if provided, otherwise viewport camera)
	if camera_path != NodePath(""):
		_cam = get_node_or_null(camera_path)
	else:
		_cam = get_viewport().get_camera_3d()

	# Create or configure material
	_mat = StandardMaterial3D.new()
	#_mat.unshaded = unshaded
	_mat.albedo_color = Color(1,1,1, clamp(opacity, 0.0, 1.0))
	if noise_tex:
		_mat.albedo_texture = noise_tex
	# Make sure there's some transparency enabled
	# Use alpha transparency so the noise texture's alpha controls the fog shape.
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Disable culling so both sides render if camera passes to other side
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	# Render priority: leave default but you can bump render_priority if needed
	# _mat.render_priority = 1

	material_override = _mat

	# Optional: ensure the quad initially faces camera and is sized correctly
	_update_transform_and_size()

	set_process(true)

func _process(_delta: float) -> void:
	# Keep the fog wall positioned and sized to the camera frustum every frame
	_update_transform_and_size()

func _update_transform_and_size() -> void:
	if not _cam:
		_cam = (get_node_or_null(camera_path) if camera_path != NodePath("") else get_viewport().get_camera_3d())
		if not _cam:
			return

	# Position the wall in front of the camera
	# Camera forward in Godot is -Z in camera basis, so:
	var cam_global = _cam.global_transform
	var forward = -cam_global.basis.z.normalized()
	global_transform.origin = cam_global.origin + forward * distance

	# Make the wall face the camera
	look_at(cam_global.origin, Vector3.UP)

	# Calculate world-space size so the wall covers the camera frustum at `distance`
	# height = 2 * distance * tan(fov/2)
	var aspect = 1.0
	var vp_rect = get_viewport().get_visible_rect()
	if vp_rect.size.y != 0:
		aspect = float(vp_rect.size.x) / float(vp_rect.size.y)
	var fov_rad = deg_to_rad(_cam.fov)
	var world_h = 2.0 * distance * tan(fov_rad * 0.5)
	var world_w = world_h * aspect

	# Our base quad is 2x2 (BASE_QUAD_SIZE). Scale accordingly.
	var scale_x = world_w / BASE_QUAD_SIZE.x
	var scale_y = world_h / BASE_QUAD_SIZE.y
	scale = Vector3(scale_x, scale_y, 1.0)

	# Keep Z rotation/orientation consistent (avoid flipping)
	# Make sure the normal points away from camera (if it looks inverted, rotate 180deg on Y)
	if (global_transform.basis.z.dot(forward) > 0.0):
		rotate_y(PI)

# Small helpers to tweak properties at runtime
func set_opacity(a: float) -> void:
	opacity = clamp(a, 0.0, 1.0)
	if _mat:
		_mat.albedo_color.a = opacity

func set_distance(d: float) -> void:
	distance = d
	_update_transform_and_size()

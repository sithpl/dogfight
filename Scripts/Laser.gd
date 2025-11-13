extends Area3D

@export var speed: float = 100.0

func _process(delta):
	translate(Vector3(0, 0, -speed * delta))  # -Z
	# Free when far enough
	if global_position.z < -200:
		queue_free()

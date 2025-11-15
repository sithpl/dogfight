# Laser.gd
class_name Laser extends Area3D

@export var laser_speed: float = 300.0

func _process(delta):
	translate(Vector3(0, 0, -laser_speed * delta))  # -Z
	# Free when far enough
	if global_position.z > 150:
		queue_free()
		print("Laser.gd -> laser removed!")

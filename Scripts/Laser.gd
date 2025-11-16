# Laser.gd
class_name Laser extends Area3D

@export var laser_speed: float = 300.0

func _ready():
	# Called once when scene starts
	connect("area_entered", Callable(self, "_on_area_entered"))

# Laser despawns if it hits another target with collision
func _on_area_entered(_area):
	queue_free()
	#print("Laser.gd -> laser hit target!")

func _process(delta):
	# delta = time since last frame (in seconds)
	
	translate(Vector3(0, 0, -laser_speed * delta))  # -Z
	# Free when far enough
	if global_position.z > 150:
		queue_free()
		#print("Laser.gd -> laser despawned!")

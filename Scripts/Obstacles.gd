# Obstacles.gd
class_name Obstacles extends Area3D

# --- Signals ---
signal obstacle_destroyed # Signal emitted when the obstacle is destroyed (hit by a laser)

# Called once when scene starts
func _ready():
	# Connect area_entered signal to _on_area_entered handler
	connect("area_entered", Callable(self, "_on_area_entered"))

# Called when another object enters this obstacle's collision area
func _on_area_entered(area):
	# If the colliding object belongs to the "Laser" group
	if area.is_in_group("Laser"):
		# Emit the obstacle_destroyed signal to notify listeners (Main.gd for scoring)
		obstacle_destroyed.emit()
		# Remove (despawn) this obstacle from the scene
		queue_free()
		#print("Obstacles.gd -> Obstacle removed!")

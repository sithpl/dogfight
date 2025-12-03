# Tripod.gd
class_name Tripod extends Area3D

# --- Signals ---
signal target_destroyed # Signal emitted when the target is destroyed (hit by a laser)

# Called once when scene starts
func _ready():
	# Verify target is in "Enemy" group so Player can find it
	add_to_group("Enemy")
	# Connect area_entered signal to _on_area_entered handler
	connect("area_entered", Callable(self, "_on_area_entered"))

# Called when another object enters this targets's collision area
func _on_area_entered(area):
	print("Tank.gd -> _on_area_entered() called!")
	# If the colliding object belongs to the "Laser" group
	if area.is_in_group("Laser"):
		# Emit the target_destroyed signal to notify listeners (Training.gd for scoring)
		target_destroyed.emit()
		# Remove (despawn) this target from the scene
		queue_free()
		#print("Targets.gd -> Target removed!")

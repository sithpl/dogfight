# EnemyLaser.gd
class_name EnemyLaser extends Area3D

# --- Gameplay settings ---
@export var enemy_laser_speed: float = 100.0 # Default speed of laser projectile

# Called once when scene starts
func _ready():
	add_to_group("EnemyLaser")
	# Connect area_entered signal to _on_area_entered handler
	connect("area_entered", Callable(self, "_on_area_entered"))

# Called every frame
func _process(delta: float):
	# delta = time since last frame (in seconds)
	
	# Move the laser forward along the -Z axis at laser_speed (units/sec)
	translate(Vector3(0, 0, -enemy_laser_speed * delta))
	# Despawn (free) the laser when it moves far enough along +Z axis
	if global_position.z > 175:
		queue_free()
		#print("EnemyLaser.gd -> laser despawned!")

# Despawns (free) laser when it hits another target with collision
func _on_area_entered(area):
	#print("EnemyLaser.gd -> _on_area_entered() called!")
	if area.is_in_group("Enemy"):
		return
	if not area.is_in_group("Player"):
		queue_free()
		print("EnemyLaser hit Player!")

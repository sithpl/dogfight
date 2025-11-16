# Obstacles.gd
class_name Obstacles extends Area3D

signal obstacle_destroyed

#@onready var hit_sfx : AudioStreamPlayer = $HitSFX

func _ready():
	# Called once when scene starts
	connect("area_entered", Callable(self, "_on_area_entered"))

# If a "Laser" hits the Obstacle, then Obstacle despawns
func _on_area_entered(area):
	if area.is_in_group("Laser"):
		obstacle_destroyed.emit()
		queue_free()
		#print("Obstacles.gd -> Obstacle removed!")

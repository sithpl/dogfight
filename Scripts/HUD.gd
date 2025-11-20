# HUD.gd
class_name HUD extends Control

# --- Node settings ---
@onready var mission_start       : Panel  = $MissionStart                      # Panel for MissionStart popup
@onready var mission_start_text  : Label  = $MissionStart/VBoxContainer/Label  # MissionStart (objective) label
@onready var score_counter       : Label  = $ScoreCounter                      # Score counter label

# Called once when scene starts
func _ready():
	# Ensure MissionStart panel is hidden when HUD loads
	hide_mission_start()

# Show MissionStart Panel
func show_mission_start():
	mission_start.show()

# Hide MissionStart Panel
func hide_mission_start():
	mission_start.hide()

# Update the ScoreCounter label text
func set_score(value):
	score_counter.text = "Hits: %d" % value

# HUD.gd
class_name HUD extends Control

# --- Node settings ---
@onready var mission_start       : Panel  = $MissionStart                      # Panel for MissionStart popup
@onready var mission_start_text  : Label  = $MissionStart/VBoxContainer/Label  # MissionStart (objective) label
@onready var score_counter       : Label  = $ScoreCounter                      # Score counter label
@onready var boost_meter         : ProgressBar = $BoostMeterPanel/BoostMeter
@onready var dam_meter           : ProgressBar = $DamMeterPanel/DamMeter

# Called once when scene starts
func _ready():
	score_counter.show()
	boost_meter.show()
	dam_meter.show()
	# Ensure MissionStart panel is hidden when HUD loads (Main will show it when needed)
	hide_mission_start()

# Show MissionStart Panel
func show_mission_start():
	mission_start.show()

# Hide MissionStart Panel
func hide_mission_start():
	mission_start.hide()

# Update the ScoreCounter label text
func set_score(value):
	score_counter.text = "%03d" % value

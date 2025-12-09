# HUD.gd
class_name HUD extends Control

# --- Node settings ---
@onready var mission_start       : Panel       = $MissionStart                                          # Panel for MissionStart popup
@onready var mission_header      : Label       = $MissionStart/VBoxContainer/MarginContainer1/Header    # MissionStart header label
@onready var mission_start_text  : Label       = $MissionStart/VBoxContainer/MarginContainer2/Objective # MissionStart text (objective) label
@onready var score_counter       : Label       = $ScoreCounter                                          # Score counter label
@onready var boost_meter         : ProgressBar = $BoostMeterPanel/BoostMeter                            # Player boost meter
@onready var dam_meter           : ProgressBar = $DamMeterPanel/DamMeter                                # Player damage meter
@onready var transmission_window : Control     = $TransmissionWindow                                    # Incoming transmission window (scene)

# Called once when scene starts
func _ready():
	# Verify Score, BoostMeter, and DamMeterPanel are all visible
	score_counter.show()
	boost_meter.show()
	dam_meter.show()

	# Verify MissionStart panel is hidden when HUD loads (Main will show it when needed)
	_hide_mission_start()

# Show MissionStart Panel
func _show_mission_start(header, start_text):
	# Load information passed from level script
	mission_header.text = header
	mission_start_text.text = start_text
	mission_start.show()

# Hide MissionStart Panel
func _hide_mission_start():
	mission_start.hide()

# Update the ScoreCounter label text
func _set_score(value):
	score_counter.text = "%03d" % value

# Receive transmission data from level, pass to TransmissionWindow scene
func _play_transmission(t: Transmission):
	transmission_window.call("_play_transmission", t)

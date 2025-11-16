# HUD.gd
class_name HUD extends Control

@onready var mission_start : Panel = $MissionStart
@onready var mission_start_text : Label = $MissionStart/VBoxContainer/Label
@onready var score_counter : Label = $ScoreCounter

func _ready():
	# Called once when scene starts
	hide_mission_start()

func show_mission_start():
	mission_start.show()

func hide_mission_start():
	mission_start.hide()

func set_score(value):
	score_counter.text = "Hits: %d" % value

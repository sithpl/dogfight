class_name StartMenu extends Control

@onready var pause_label    : Label   = $Panel/VBoxContainer/Paused
@onready var restart_button : Button  = $Panel/VBoxContainer/Restart
@onready var quit_button    : Button  = $Panel/VBoxContainer/Quit
@onready var main_scene = $".."

func _ready():
	pause_label.text = "MISSION PAUSED"
	restart_button.grab_focus()
	#get_tree().paused = true
	set_process_mode(PROCESS_MODE_WHEN_PAUSED)
	
func _unhandled_input(event):
	if event is InputEventAction and event.is_action_pressed("ui_start"):
		print("StartMenu.gd -> ui_start pressed!")
		if event.has_method("accept"):
			event.accept()
		get_tree().paused = false
		queue_free()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().quit()

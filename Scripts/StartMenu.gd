# StartMenu.gd
class_name StartMenu extends Control

# --- Node settings ---
@onready var pause_label    : Label   = $Panel/VBoxContainer/Paused
@onready var restart_button : Button  = $Panel/VBoxContainer/Restart
@onready var quit_button    : Button  = $Panel/VBoxContainer/Quit
@onready var main_scene = $".."

# Called once when scene starts
func _ready():
	# Update Paused text
	pause_label.text = "MISSION PAUSED"
	# Grab focus so [Restart] is highlighted first
	restart_button.grab_focus()
	#get_tree().paused = true
	# Allow StartMenu scene to function while level scene is paused
	set_process_mode(PROCESS_MODE_WHEN_PAUSED)

# Checks for specific inputs
func _unhandled_input(event):
	if event is InputEventAction and event.is_action_pressed("ui_start"):
		print("StartMenu.gd -> ui_start pressed!")
		if event.has_method("accept"):
			event.accept()
		get_tree().paused = false
		queue_free()

# Called when [Restart] is selected
func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Called when [Quit to Desktop] is selected
func _on_quit_pressed():
	get_tree().quit()

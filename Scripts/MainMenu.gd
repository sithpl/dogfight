# MainMenu.gd
class_name MainMenu extends Node

# --- Node settings ---
@onready var confirm_sfx    : AudioStreamPlayer = $Control/VBoxContainer/ConfirmSFX  # Confirm sound
@onready var select_sfx     : AudioStreamPlayer = $Control/VBoxContainer/SelectSFX   # Select sound
@onready var back_sfx       : AudioStreamPlayer = $Control/VBoxContainer/BackSFX     # Back sound
@onready var menu_music     : AudioStreamPlayer = $Control/MenuMusic                 # Main Menu theme
@onready var fade_effect    : ColorRect         = $Control/ColorRect                 # ColorRect used for fade effect (set at Z Index 1)
@onready var options_button : Button            = $Control/VBoxContainer/Options     # Options button
@onready var coming_soon    : Panel             = $Control/ComingSoon

@onready var options_menu       : Panel             = $Control/OptionsMenu               # Options window
@onready var options_back_sfx   : AudioStreamPlayer = $Control/OptionsMenu/BackSFX

# --- Preload Nodes ---
var training_scene = preload("res://Scenes/Training.tscn")
var press_start = preload("res://Scenes/PressStart.tscn")

# Called once when scene starts
func _ready():
	# Hide Coming Soon
	
	# Hide OptionsMenu
	options_menu.hide()

	# Enable just in-case
	fade_effect.show()
	# Set fade_effect (ColorRect) to fully visible and solid black
	fade_effect.modulate.a = 1.0
	# Create tween in current node
	var tween = get_tree().create_tween()
	# Fade alpha from 1 to 0 over 0.5s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 0.0, 0.5)

	# Pull focus to NewGame button for arrow key/controller navigation
	$Control/VBoxContainer/NewGame.grab_focus()

	# Play starfox64-mainmenu-remix.wav
	menu_music.play()
	# "Star Fox 64 Main Menu (Remix)" by Beat Block
	# https://www.youtube.com/watch?v=Dni0OPN-vaM

func _input(_event):
	if Input.is_action_pressed("ui_back"):
		if options_menu.visible:
			options_menu._close_options_menu()
			options_button.grab_focus()
		else:
			menu_music.stop()
			get_tree().change_scene_to_file("res://Scenes/PressStart.tscn")

# Called when [New Game] is selected
func _on_new_game_pressed():
	#print("MainMenu.gd -> New Game pressed!")
	_is_coming_soon()

# Called when [Training] is selected
func _on_training_pressed():
	#print("MainMenu.gd -> Training pressed!")
	
	# Create tween in current node
	var tween = get_tree().create_tween()
	# Fade alpha from 0 to 1 over 0.5s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5)

	# If menu_music ($MenuMusic) or select_sfx ($VBoxContainer/SelectSFX) is playing
	if select_sfx.playing or menu_music.playing or options_back_sfx.playing:
		# Stop currently playing menu_music and select_sfx
		select_sfx.stop()
		menu_music.stop()
		options_back_sfx.stop()
	# Play goodluck-sfx.wav
	confirm_sfx.play()
	# Wait for confirm_sfx to finish
	await confirm_sfx.finished
	# Switch to main_scene (Scenes/Training.tscn)
	get_tree().change_scene_to_packed(training_scene)

# Called when [VS] is selected
func _on_vs_pressed():
	#print("MainMenu.gd -> VS pressed!")
	_is_coming_soon()

# Called when [Ranking] is selected
func _on_ranking_pressed():
	#print("MainMenu.gd -> Ranking pressed!")
	_is_coming_soon()

# Called when [Options] is selected
func _on_options_pressed():
	#print("MainMenu.gd -> Options pressed!")
	select_sfx.play()
	options_menu._show_options_menu()

# Called when [Data] is selected
func _on_data_pressed():
	#print("MainMenu.gd -> Data pressed!")
	_is_coming_soon()

# Called when [Quit] is selected
func _on_quit_pressed():
	#print("MainMenu.gd -> Quit pressed!")
	fade_effect.hide()
	get_tree().quit()

# Toggle "Coming Soon" for 2 seconds
func _is_coming_soon():
	coming_soon.show()
	await get_tree().create_timer(2.0).timeout
	coming_soon.hide()

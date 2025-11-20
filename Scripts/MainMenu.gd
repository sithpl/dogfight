# MainMenu.gd
class_name MainMenu extends Node

# --- Node settings ---
@onready var confirm_sfx  : AudioStreamPlayer = $VBoxContainer/ConfirmSFX  # Confirm sound
@onready var select_sfx   : AudioStreamPlayer = $VBoxContainer/SelectSFX   # Select sound
@onready var menu_music   : AudioStreamPlayer = $MenuMusic                 # Main Menu theme
@onready var fade_effect  : ColorRect         = $ColorRect                 # ColorRect used for fade effect (set at Z Index 1)

# --- Preload Nodes ---
var main_scene = preload("res://Scenes/Main.tscn")

# Called once when scene starts
func _ready():
	# Set fade_effect (ColorRect) to fully visible and solid black
	fade_effect.modulate.a = 1.0
	# Create tween in current node
	var tween = get_tree().create_tween()
	# Fade alpha from 1 to 0 over 0.5s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 0.0, 0.5)

	# Pull focus to NewGame button for arrow key/controller navigation
	$VBoxContainer/NewGame.grab_focus()

	# Play starfox64-opentheme-remix.wav
	menu_music.play()
	# "Opening Theme" by NoteBlock
	# Barrel Roll: An Electronic Tribute to Star Fox 64
	# https://www.youtube.com/watch?v=3drqjC2JS08

# Called when [New Game] is selected
func _on_new_game_pressed():
	print("MainMenu.gd -> New Game pressed!")
	
	# Create tween in current node
	var tween = get_tree().create_tween()
	# Fade alpha from 0 to 1 over 0.5s on fade_effect (ColorRect)
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5)

	# If menu_music ($MenuMusic) or select_sfx ($VBoxContainer/SelectSFX) is playing
	if select_sfx.playing or menu_music.playing:
		# Stop currently playing menu_music and select_sfx
		select_sfx.stop()
		menu_music.stop()
	# Play goodluck-sfx.wav
	confirm_sfx.play()
	# Wait for confirm_sfx to finish
	await confirm_sfx.finished
	# Switch to main_scene (Scenes/Main.tscn)
	get_tree().change_scene_to_packed(main_scene)

# Called when [Quit] is selected
func _on_quit_pressed():
	print("MainMenu.gd -> Quit pressed!")
	get_tree().quit()

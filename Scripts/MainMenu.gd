# MainMenu.gd
class_name MainMenu extends Node

@onready var confirm_sfx  : AudioStreamPlayer = $VBoxContainer/ConfirmSFX
@onready var select_sfx   : AudioStreamPlayer = $VBoxContainer/SelectSFX
@onready var menu_music   : AudioStreamPlayer = $MenuMusic
@onready var fade_effect  : ColorRect         = $ColorRect

var main_scene = preload("res://Scenes/Main.tscn")

func _ready():
	# Called once when scene starts
	
	# Fade in effect
	fade_effect.modulate.a = 1.0
	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 0.0, 0.5) # Fade alpha from 1 to 0 over 1 second
	# Pull focus to NewGame button for arrow key/controller navigation
	$VBoxContainer/NewGame.grab_focus()
	# Play Main Menu theme
	menu_music.play()
	# "Opening Theme" by NoteBlock
	# Barrel Roll: An Electronic Tribute to Star Fox 64
	# https://www.youtube.com/watch?v=3drqjC2JS08

func _on_new_game_pressed():
	var tween = get_tree().create_tween()
	tween.tween_property(fade_effect, "modulate:a", 1.0, 0.5) # Fade alpha from 0 to 1 over 1 second
	if select_sfx.playing or menu_music.playing:
		select_sfx.stop()
		menu_music.stop()
	confirm_sfx.play()
	await confirm_sfx.finished
	get_tree().change_scene_to_packed(main_scene)
	print("MainMenu.gd -> New Game pressed!")

func _on_quit_pressed():
	get_tree().quit()
	print("MainMenu.gd -> Quit pressed!")

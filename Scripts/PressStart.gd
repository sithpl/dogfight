# PressStart.gd
class_name PressStart extends Node

@onready var fade_effect  : ColorRect          = $ColorRect                 # ColorRect used for fade effect (set at Z Index 1)
@onready var light_source : DirectionalLight3D = $Scene/DirectionalLight3D
@onready var background   : MeshInstance3D     = $Scene/Background
@onready var scene_model  : Node3D             = $Scene/Model
@onready var start_theme  : AudioStreamPlayer  = $Theme
@onready var press_start  : Label              = $PressStart

@onready var main_menu_scene : PackedScene = preload("res://Scenes/MainMenu.tscn")

# How often to toggle PressStart label (seconds)
var flash_interval: float = 1.0
var flash_timer: float = 0.0
var is_white: bool = true

# Called once when scene starts
func _ready():
	# Play sf64-startdemo1-remix.wav
	start_theme.play()
	# "Star Fox 64 Theme (Start Demo 1)" by Player2
	# https://www.youtube.com/watch?v=yEAU1L2TJTM

	# Short delay for dramatic pause
	await get_tree().create_timer(0.5).timeout
	# Spin light_source around for similar effect
	create_tween().tween_property(light_source, "rotation_degrees:y", light_source.rotation_degrees.y + 225.0, 1.0)
	# Short delay while light_source turns around
	await get_tree().create_timer(0.2).timeout
	# Disable Negative on light_source
	light_source.light_negative = false

	# Initialize PressStart label color and flash timer
	_set_label_color(Color(1, 1, 1)) # white
	flash_timer = 0.0
	is_white = true

# Checks for specific inputs
func _input(_event):
	if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_start") :
		get_tree().change_scene_to_packed(main_menu_scene)

# Called every frame
func _process(delta: float):
	# delta = time since last frame (in seconds)

	# Scroll background
	var scroll_bg = background
	scroll_bg.translate(Vector3(-3.0 * delta, 0, 0))   # move along X
	if scroll_bg.global_transform.origin.x < -25.0:
		scroll_bg.translate(Vector3(40.0, 0, 0))  # loop forward by tile length

	flash_timer += delta
	if flash_timer >= flash_interval:
		flash_timer -= flash_interval
		is_white = !is_white
		if is_white:
			_set_label_color(Color(1, 1, 1))
		else:
			_set_label_color(Color(1, 0, 0))

# Called to modulate the PressStart label
func _set_label_color(c: Color):
	# Modulate changes the drawn color
	press_start.modulate = c

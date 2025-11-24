# MM-Anmation.gd
extends Node3D

# --- Gameplay settings ---
@export var amplitude_deg : float = 30.0
@export var speed         : float = 0.3

# --- Game state variables ---
var _time          : float = 0.0
var _phase         : float = 0.0
var _initial_z_deg : float = 0.0

# Called once when scene starts
func _ready():
	randomize()
	_initial_z_deg = rotation_degrees.z
	# Random phase so multiple instances don't sync exactly
	_phase = randf() * TAU

# Called every frame
func _process(delta: float):
	_time += delta
	var angle_deg: float = sin(_time * speed + _phase) * amplitude_deg
	rotation_degrees.z = _initial_z_deg + angle_deg

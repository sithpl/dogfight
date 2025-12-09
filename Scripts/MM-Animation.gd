# MM-Anmation.gd
extends Node3D

# --- Gameplay settings ---
@export var amplitude_deg : float = 30.0 ## Maximum degrees the model tilts side-to-side
@export var speed         : float = 0.3  ## Speed at which the model tilts (secs)

# --- Game state variables ---
var time          : float = 0.0
var phase         : float = 0.0
var initial_z_deg : float = 0.0

# Called once when scene starts
func _ready():
	randomize()
	initial_z_deg = rotation_degrees.z
	# Random phase so multiple instances don't sync exactly
	phase = randf() * TAU

# Called every frame
func _process(delta: float):
	time += delta
	var angle_deg: float = sin(time * speed + phase) * amplitude_deg
	rotation_degrees.z = initial_z_deg + angle_deg

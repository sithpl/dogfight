# Transmission.gd
class_name Transmission extends Resource

# --- Gameplay settings ---
@export var char_portrait : Texture2D
@export var char_name     : String      = ""
@export var char_text     : String      = ""
@export var char_voice    : AudioStream
@export var duration      : float       = 3.0  # Fallback duration if no voice is provided

@export var char_talking  : Texture2D          # Single talking-frame texture
@export var talking_fps   : float       = 25.0  # How fast to flip between idle/talking (frames/sec)

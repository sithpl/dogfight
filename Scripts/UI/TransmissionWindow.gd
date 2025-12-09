# TransmissionWindow.gd
class_name TransmissionWindow extends Control

# --- Gameplay settings ---
@export var noise_flick_interval : float = 0.05 ## Rate at which the Noise TextureRect is flipped (H/V)
@export var noise_open_time      : float = 0.1  ## How long it takes to complete Noise animation
@export var noise_hold_time      : float = 0.25 ## How long to hold Noise before showing/hiding Portrait
@export var text_open_time       : float = 0.1  ## How long it takes to complete TextBG animation
@export var post_voice_padding   : float = 0.12 ## How long it waits after char_audio playback

@export var reveal_mode: int = 1 ## Reveal mode: 0 = horizontal (left/right), 1 = vertical (up/down), 2 = square (expand both axes), 3 = circular (radial)


# --- Node settings ---
@onready var char_dam_panel : Panel             = $DamMeterPanel
@onready var char_dam       : ProgressBar       = $DamMeterPanel/DamMeter
@onready var char_portrait  : TextureRect       = $Portrait
@onready var noise_rect     : TextureRect       = $Noise
@onready var char_name      : RichTextLabel     = $Name
@onready var char_text_bg   : ColorRect         = $TextBackground
@onready var text_container : Control           = $MarginContainer
@onready var char_text      : RichTextLabel     = $MarginContainer/Text
@onready var char_audio     : AudioStreamPlayer = $Audio
@onready var incoming_sfx   : AudioStreamPlayer = $StartSFX
@onready var end_sfx        : AudioStreamPlayer = $EndSFX

# --- Preload Nodes ---
@onready var inctrans_sfx = preload("res://Assets/SFX/sf64-inctrans-sfx.wav")
@onready var endtrans_sfx = preload("res://Assets/SFX/sf64-endtrans-sfx.wav")

# ShaderMaterials for center-out reveal
var reveal_shader : Shader         = null
var noise_mat     : ShaderMaterial = null
var text_mat      : ShaderMaterial = null

# --- Game state variables ---
var noise_flick_timer : float               = 0.0
var queue             : Array[Transmission] = []
var is_playing        : bool                = false
var is_talking        : bool                = false

# Called once when scene starts
func _ready():
	# Hide when initially calleed
	visible = false
	modulate.a = 0.0
	char_text.bbcode_enabled = false

	# Verify nodes exist
	noise_rect = get_node_or_null("Noise")
	text_container = get_node_or_null("MarginContainer") # parent of the text

	# Create reveal shader & materials
	_create_reveal_shader_and_materials()

	# Apply materials (if available)
	if noise_mat and noise_rect:
		noise_rect.material = noise_mat
		noise_mat.set_shader_parameter("reveal", 0.0)
		noise_mat.set_shader_parameter("mode", float(reveal_mode))
	if text_mat and text_container:
		char_text_bg.material = text_mat
		text_mat.set_shader_parameter("reveal", 0.0)
		text_mat.set_shader_parameter("mode", float(reveal_mode))
		text_mat.set_shader_parameter("border", 0.012)

	# Verify Portrait/Name/DamMeterPanel/TextBG/Text are hidden so Noise reveal looks correct
	if char_portrait:
		char_portrait.visible = false
	if char_name:
		char_name.visible = false
	if char_dam_panel:
		char_dam_panel.visible = false
	if char_text_bg:
		char_text_bg.visible = false
	if text_container:
		text_container.visible = false

# Called every frame
func _process(delta: float):
	# Early out if noise_rect isn't detected
	if not noise_rect:
		return

	# Run flicker logic only while noise_rect is visible
	if noise_rect.visible:
		# Count down the flicker timer each frame
		noise_flick_timer -= delta
		# When the timer reaches zero, flip the texture and reset the timer
		if noise_flick_timer <= 0.0:
			#noise_rect.flip_v = not noise_rect.flip_v
			noise_rect.flip_h = not noise_rect.flip_h
			noise_flick_timer = noise_flick_interval
	else:
		# When noise is hidden, reset flip flags to defaults
		noise_rect.flip_h = false
		noise_rect.flip_v = false

# Receive data from HUD scene and add the transmission to the play queue
func _play_transmission(t: Transmission):
	queue.append(t)
	if not is_playing:
		_process_queue()

# Tranismission queue processor
func _process_queue():
	is_playing = true
	while queue.size() > 0:
		var t: Transmission = queue.pop_front()
		await _play_one(t)
	# Finished all
	is_playing = false

# Plays a single transmission and awaits its end
func _play_one(t: Transmission):
	# Prepare UI
	char_portrait.texture = t.char_portrait
	char_name.text = t.char_name
	char_text.text = t.char_text

	# Keep DamMeterPanel hidden until portrait reveal
	if t.char_name == "ROB64": # ROB64 doesn't have a DamMeterPanel
		char_dam_panel.hide()
	else:
		# Verify hidden until reveal moment
		char_dam_panel.hide()

	# Start simple talking toggler if talking portrait provided
	if t.char_talking and t.char_talking != null:
		# start coroutine (deferred so it doesn't block; toggler runs concurrently)
		call_deferred("_start_talk", t.char_portrait, t.char_talking, t.talking_fps)

	# Setup voice audio (but don't play yet)
	if t.char_voice:
		char_audio.stream = t.char_voice
	else:
		char_audio.stream = null

	# Reset visual reveal parameters
	if noise_mat:
		noise_mat.set_shader_parameter("reveal", 0.0)
		noise_mat.set_shader_parameter("mode", float(reveal_mode))
	if text_mat:
		text_mat.set_shader_parameter("reveal", 0.0)
		text_mat.set_shader_parameter("mode", float(reveal_mode))

	# Verify Noise is visible for the incoming transmission
	# Verify Portrait/Name/DamMeterPanel/TextBG/Text are hidden
	if noise_rect:
		noise_rect.visible = true
		noise_rect.modulate.a = 1.0
	if char_portrait:
		char_portrait.visible = false
	if char_name:
		char_name.visible = false
	if char_dam_panel:
		char_dam_panel.visible = false
	if char_text_bg:
		char_text_bg.visible = false
	if text_container:
		text_container.visible = false
		text_mat.set_shader_parameter("reveal", 0.0)

	# Show UI
	visible = true
	modulate.a = 0.0
	await create_tween().tween_property(self, "modulate:a", 1.0, 0.12).finished

	# Play incoming sfx
	if inctrans_sfx and incoming_sfx:
		incoming_sfx.stream = inctrans_sfx
		incoming_sfx.play()

	# Animate noise opening (center-out): tween "reveal" from 0 -> 1
	if noise_mat:
		noise_mat.set_shader_parameter("reveal", 0.0)
		await create_tween().tween_property(noise_mat, "shader_parameter/reveal", 1.0, noise_open_time).finished

	# Hold on fully-open noise_rect for set time before revealing portrait
	await get_tree().create_timer(noise_hold_time).timeout

	# Wait for incoming_sfx only if it's still playing (for audio sync)
	if incoming_sfx and incoming_sfx.playing:
		await incoming_sfx.finished

	# Immediately show Portrait/Name/DamMeterPanel together
	if char_portrait:
		char_portrait.visible = true
	if char_name:
		char_name.visible = true
	if char_dam_panel:
		# Show DamMeterPanel everyone except ROB64
		char_dam_panel.visible = (t.char_name != "ROB64")

	# Hide Noise now that Portrait/Name/DamMeterPanel are revealed
	if noise_rect:
		noise_rect.visible = false

	# Show and animate TextBG (center-out)
	if char_portrait and char_name and char_dam_panel:
		# Verify TextBG is visible but start with reveal closed
		char_text_bg.visible = true
		text_mat.set_shader_parameter("reveal", 0.0)
		# Animate TextBG opening (center -> outward)
		await create_tween().tween_property(text_mat, "shader_parameter/reveal", 1.0, text_open_time).finished

	# Wait just a sec
	await get_tree().create_timer(0.5).timeout

	# Verify Text is visible
	text_container.visible = true

	# Play voice while TextBG/Text is visible
	if char_audio.stream:
		char_audio.play()
		await char_audio.finished
	else:
		# No voice -> use provided duration from initial transmission call
		await get_tree().create_timer(t.duration).timeout

	# Stop talking toggler and restore idle portrait
	_stop_talk()
	char_portrait.texture = t.char_portrait

	# Wait a sec, adjust with exported Post Voice Padding
	await get_tree().create_timer(post_voice_padding).timeout

	# Play end SFX
	if endtrans_sfx and end_sfx:
		end_sfx.stream = endtrans_sfx
		end_sfx.play()
	
	# Immediately hide Portrait/Name/DamMeterPanel/Text and prepare Noise for reverse animation
	if noise_rect and noise_mat:
		if char_portrait:
			char_portrait.visible = false
		if char_name:
			char_name.visible = false
		if char_dam_panel:
			char_dam_panel.visible = false
		if text_container:
			# Reset Text and hide immediately
			text_mat.set_shader_parameter("reveal", 0.0)
			text_container.visible = false

		# Show Noise fully to take over the portrait area
		noise_rect.visible = true
		noise_rect.modulate.a = 1.0
		noise_mat.set_shader_parameter("reveal", 1.0)

		text_mat.set_shader_parameter("reveal", 1.0)
		# Animate TextBG closing (outward -> center)
		@warning_ignore("standalone_expression")
		create_tween().tween_property(text_mat, "shader_parameter/reveal", 0.0, text_open_time).finished

		# Wait a sec, adjust with exported Noise Hold Time
		await get_tree().create_timer(noise_hold_time).timeout

		# Animate Noise closing (Outward -> Center)
		await create_tween().tween_property(noise_mat, "shader_parameter/reveal", 0.0, noise_open_time).finished

		# Hide Noise again, restore initial state
		noise_rect.visible = false

	# Fade out overall UI
	await create_tween().tween_property(self, "modulate:a", 0.0, 0.12).finished
	visible = false

# Flip between idle and talking textures
func _start_talk(idle_tex: Texture2D, talk_tex: Texture2D, fps: float):
	if not idle_tex or not talk_tex:
		return
	is_talking = true
	var show_talk : bool = true
	var frame_time : float = 1.0 / max(fps, 1.0)
	while is_talking:
		if char_portrait:
			char_portrait.texture = talk_tex if show_talk else idle_tex
		show_talk = not show_talk
		await get_tree().create_timer(frame_time).timeout

func _stop_talk():
	is_talking = false

# Create a simple centered reveal shader and material instances
func _create_reveal_shader_and_materials():
	# Create Shader instance
	reveal_shader = Shader.new()
	# Load code for Shader
	reveal_shader.code = """
shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float border : hint_range(0.0, 0.05) = 0.01;
uniform float mode : hint_range(0.0, 3.0) = 0.0; // 0 horiz,1 vert,2 square,3 circle

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;

	float d;
	if (mode < 0.5) {
		// horizontal reveal (left/right from center)
		d = abs(UV.x - 0.5);
	} else if (mode < 1.5) {
		// vertical reveal (up/down from center)
		d = abs(UV.y - 0.5);
	} else if (mode < 2.5) {
		// square reveal (expand in both axes: max distance)
		d = max(abs(UV.x - 0.5), abs(UV.y - 0.5));
	} else {
		// circular/radial reveal
		d = length(UV - vec2(0.5));
	}

	// Map 'reveal' so that 0 = fully closed, 1 = fully open (center -> outward)
	float thresh = reveal * 0.5;
	// Use smoothstep to soften the edge; mask = 1 when d <= thresh (visible), 0 otherwise.
	float mask = 1.0 - smoothstep(thresh - border, thresh + border, d);

	COLOR = vec4(col.rgb, col.a * mask);
}
"""

	# Create individual ShaderMaterial instances to animate them separately
	noise_mat = ShaderMaterial.new()
	noise_mat.shader = reveal_shader.duplicate() if reveal_shader else null

	text_mat = ShaderMaterial.new()
	text_mat.shader = reveal_shader.duplicate() if reveal_shader else null

	# Default parameters (override via exported Reveal Mode)
	noise_mat.set_shader_parameter("border", 0.01)
	text_mat.set_shader_parameter("border", 0.012)

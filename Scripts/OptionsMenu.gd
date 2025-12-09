# OptionsMenu.gd
class_name OptionsMenu extends Panel

# --- Node settings ---
@onready var options_button : Button            = $"../VBoxContainer/Options"
@onready var select_sfx     : AudioStreamPlayer = $SelectSFX
@onready var back_sfx       : AudioStreamPlayer = $BackSFX
@onready var effects_slider : HSlider           = $MarginContainer/VBoxContainer/Effects/EffectsSlider
@onready var voice_slider   : HSlider           = $MarginContainer/VBoxContainer/Voice/VoiceSlider
@onready var music_slider   : HSlider           = $MarginContainer/VBoxContainer/Music/MusicSlider
@onready var invert_y       : CheckBox          = $MarginContainer/VBoxContainer/InvertY/InvertBox

# --- Audio Testing --- 
@onready var effects_test : AudioStreamPlayer = $EffectsTest
@onready var voice_test   : AudioStreamPlayer = $VoiceTest

@onready var effects_bus = AudioServer.get_bus_index("Effects")
@onready var voice_bus   = AudioServer.get_bus_index("Voice")
@onready var music_bus   = AudioServer.get_bus_index("Music")

# Called once when scene starts
func _ready():
	# Verify sliders use linear range
	for s in [effects_slider, voice_slider, music_slider]:
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01

	#_print_all_audio_buses()
	_update_sliders_from_buses()

# Checks for specific inputs
func _input(_event):
	# Test Effects
	if Input.is_action_pressed("ui_bank_left"):
		if voice_test.is_playing:
			voice_test.stop()
			effects_test.play()
	# Test Voice
	if Input.is_action_pressed("ui_bank_right"):
		if effects_test.is_playing:
			effects_test.stop()
			voice_test.play()

# Called when [Options] is selected
func _show_options_menu():
	_stop_all_sound()
	# Refresh from runtime buses right before showing
	_update_sliders_from_buses()
	show()
	effects_slider.grab_focus()

# Called when [Options] is closed
func _close_options_menu():
	_stop_all_sound()
	back_sfx.play()
	hide()
	options_button.grab_focus()

func _stop_all_sound():
	select_sfx.stop()
	effects_test.stop()
	voice_test.stop()

# Convert db value to linear value
func db_to_linear(db: float):
	return pow(10.0, db / 20.0)

# Convert linear value to db value
func linear_to_db(linear: float):
	if linear <= 0.0 or linear < 0.0001:
		return -80.0
	return 20.0 * (log(linear) / log(10.0))

# Verify audio buses and db levels
func _print_all_audio_buses():
	var count = AudioServer.get_bus_count()
	print("Audio bus count: ", count)
	for i in range(count):
		print("Bus ", i, " name -> ", AudioServer.get_bus_name(i),
			  " dB: ", AudioServer.get_bus_volume_db(i))

# Connect audio sliders to audio buses and update
func _update_sliders_from_buses():
	if effects_bus == -1:
		print("Error: Effects bus not found")
		return
	effects_slider.value = clamp(db_to_linear(AudioServer.get_bus_volume_db(effects_bus)), 0.0001, 1.0)
	voice_slider.value   = clamp(db_to_linear(AudioServer.get_bus_volume_db(voice_bus)),   0.0001, 1.0)
	music_slider.value   = clamp(db_to_linear(AudioServer.get_bus_volume_db(music_bus)),   0.0001, 1.0)

# Update Effects audio bus based on slider position
func _on_effects_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(effects_bus, linear_to_db(value))
	#print("Effects: ", value)

# Update Voice audio bus based on slider position
func _on_voice_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(voice_bus, linear_to_db(value))
	#print("Voice: ", value)

# Update Music audio bus based on slider position
func _on_music_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))
	#print("Music: ", value)

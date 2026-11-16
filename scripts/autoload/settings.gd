extends Node
## User preferences persisted to user://settings.cfg.
## mature_content is a stub for a later 18+ gate. It is saved and surfaced
## in the settings panel, and nothing in Phase 1 reads it for content.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 0.0024
var gamepad_sensitivity := 2.6
var invert_y := false
var master_volume := 0.85
var sfx_volume := 0.9
var ambience_volume := 0.55
var fullscreen := false
var screen_shake := true
var mature_content := false
var cycle_seconds := 240.0


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	gamepad_sensitivity = cfg.get_value("controls", "gamepad_sensitivity", gamepad_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	master_volume = cfg.get_value("audio", "master", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	ambience_volume = cfg.get_value("audio", "ambience", ambience_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	screen_shake = cfg.get_value("video", "screen_shake", screen_shake)
	mature_content = cfg.get_value("content", "mature_content", mature_content)
	cycle_seconds = cfg.get_value("world", "cycle_seconds", cycle_seconds)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "gamepad_sensitivity", gamepad_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("content", "mature_content", mature_content)
	cfg.set_value("world", "cycle_seconds", cycle_seconds)
	cfg.save(PATH)
	apply()
	changed.emit()
	EventBus.settings_changed.emit()


func apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Music", ambience_volume)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

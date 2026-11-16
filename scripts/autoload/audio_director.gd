extends Node
## One-shot and ambient playback. Streams are keyed so combat, UI, and the
## zone never hardcode file paths. Ambience rides the Music bus.

var _streams := {}


func _ready() -> void:
	_load_group("res://assets/audio/sfx/")
	_load_group("res://assets/audio/ui/")
	_load_group("res://assets/audio/ambient/")


func _load_group(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Audio directory missing: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".ogg"):
			var stream := load(dir_path + file_name)
			if stream:
				_streams[file_name.get_basename()] = stream
		file_name = dir.get_next()


func has_stream(key: String) -> bool:
	return _streams.has(key)


func play_ui(key: String, pitch_jitter := 0.03) -> void:
	_play(key, false, Vector3.ZERO, pitch_jitter, "SFX", -2.0)


func play_sfx(key: String, pitch_jitter := 0.05) -> void:
	_play(key, false, Vector3.ZERO, pitch_jitter, "SFX", 0.0)


func play_at(key: String, world_pos: Vector3, pitch_jitter := 0.05, volume_db := 0.0) -> void:
	_play(key, true, world_pos, pitch_jitter, "SFX", volume_db)


func play_ambience(key: String, volume_db := -8.0) -> AudioStreamPlayer:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = _looped(stream)
	player.volume_db = volume_db
	player.bus = "Music"
	add_child(player)
	player.play()
	return player


func _play(key: String, positional: bool, world_pos: Vector3, pitch_jitter: float, bus: String, volume_db: float) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var player: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = 36.0
		p3.unit_size = 6.0
		player = p3
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = bus
	player.pitch_scale = clampf(1.0 + randf_range(-pitch_jitter, pitch_jitter), 0.75, 1.3)
	add_child(player)
	if positional:
		player.global_position = world_pos
	player.play()
	player.finished.connect(player.queue_free)


func looped(key: String) -> AudioStream:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return null
	return _looped(stream)


func _looped(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		copy.loop = true
	return copy

extends Node3D
## Vesper-9 drop zone. Owns the clock, the landing, and the menu flow.
## Ship hub, followers, and extra zones attach to the groups and autoloads
## already in the tree rather than to this script.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

var terrain: TerrainField
var cycle: DayNightCycle
var player: CharacterBody3D
var flyby: Camera3D
var _menu: Control
var _pause: Control
var _settings: Control
var _death: Control
var _fly_t := 0.4
var _shot := false
var _landmarks := {}


func _ready() -> void:
	var launch_now := GameState.auto_start
	GameState.auto_start = false
	GameState.phase = GameState.Phase.MENU
	GameState.kills = 0
	player = $Player
	_menu = $UI/MainMenu
	_pause = $UI/PauseMenu
	_settings = $UI/Settings
	_death = $UI/Death
	_menu.bind_settings(_settings)
	_pause.bind_settings(_settings)
	EventBus.request_launch.connect(_begin_play)
	EventBus.request_pause.connect(_pause_game)
	EventBus.request_resume.connect(_resume_game)
	EventBus.request_menu.connect(_to_menu)
	EventBus.request_retry.connect(_retry)
	terrain = TerrainField.new()
	terrain.name = "Terrain"
	add_child(terrain)
	cycle = DayNightCycle.new()
	cycle.name = "DayNight"
	add_child(cycle)
	cycle.setup($WorldEnvironment, $Sun, $Moon)
	var dresser := OutpostDresser.new()
	_landmarks = dresser.dress(self, terrain)
	_spawn_enemies()
	var spawn: Vector3 = _landmarks["spawn"]
	player.global_position = spawn + Vector3(0, 0.2, 0)
	flyby = Camera3D.new()
	flyby.name = "Flyby"
	flyby.fov = 52.0
	flyby.current = true
	add_child(flyby)
	AudioDirector.play_ambience("spaceEngineLow_000", -12.0)
	AudioDirector.play_ambience("engineCircular_001", -18.0)
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		_begin_play()
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			print("SMOKE_OK")
			get_tree().quit()
		)
	elif "--shot" in args:
		_shot = true
		_shots()
	elif launch_now:
		_begin_play()


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.MENU or flyby == null or _shot:
		return
	_fly_t += delta * 0.07
	var look: Vector3 = _landmarks.get("look", Vector3(20, 2, -6))
	flyby.global_position = Vector3(cos(_fly_t) * 24.0 + 8.0, 8.0 + sin(_fly_t * 0.6), sin(_fly_t) * 22.0)
	flyby.look_at(look, Vector3.UP)


func _begin_play() -> void:
	if GameState.phase == GameState.Phase.DEAD:
		return
	GameState.phase = GameState.Phase.PLAYING
	_menu.visible = false
	_pause.visible = false
	_settings.hide()
	_death.visible = false
	if flyby:
		flyby.current = false
	player.get_node("CameraRig/SpringArm/Camera3D").current = true
	if not _shot and "--smoke" not in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_started.emit()


func _pause_game() -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	GameState.phase = GameState.Phase.PAUSED
	get_tree().paused = true
	_pause.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.game_paused.emit(true)


func _resume_game() -> void:
	if GameState.phase != GameState.Phase.PAUSED:
		return
	_settings.hide()
	_pause.visible = false
	get_tree().paused = false
	GameState.phase = GameState.Phase.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_paused.emit(false)


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.phase = GameState.Phase.MENU
	GameState.auto_start = false
	get_tree().reload_current_scene()


func _retry() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.auto_start = true
	get_tree().reload_current_scene()


func _spawn_enemies() -> void:
	var pad: Vector3 = _landmarks.get("outpost", Vector3(42, 1, -8))
	_add_enemy("quad", pad + Vector3(-6, 0, 6), [Vector3.ZERO, Vector3(4, 0, 3), Vector3(2, 0, -4)])
	_add_enemy("quad", pad + Vector3(8, 0, -4), [Vector3.ZERO, Vector3(4, 0, 4), Vector3(-3, 0, 5)])
	_add_enemy("quad", pad + Vector3(2, 0, 11), [Vector3.ZERO, Vector3(-5, 0, 2)])
	_add_enemy("drone", pad + Vector3(0, 0, 2), [Vector3.ZERO, Vector3(6, 0, -2), Vector3(-4, 0, -1)])
	_add_enemy("drone", pad + Vector3(10, 0, 8), [Vector3.ZERO, Vector3(4, 0, -3)])
	_add_enemy("trilobite", Vector3(18, 0, 20), [Vector3.ZERO, Vector3(-8, 0, 4), Vector3(6, 0, -4)])


func _add_enemy(kind: String, pos: Vector3, offsets: Array) -> void:
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
	enemy.kind = kind
	add_child(enemy)
	var hover := 2.6 if kind == "drone" else 0.15
	var points := PackedVector3Array()
	for offset in offsets:
		var point: Vector3 = pos + (offset as Vector3)
		point.y = terrain.sample(point.x, point.z) + hover
		points.append(point)
	pos.y = terrain.sample(pos.x, pos.z) + hover
	enemy.configure(pos, points)


func _shots() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_begin_play()
	cycle.locked = true
	cycle.time = 0.40
	cycle._apply()
	if player.has_node("Health"):
		player.get_node("Health").invulnerable = true
	await get_tree().create_timer(0.8).timeout
	await _capture("01_landing", Vector3(-6, 7.5, 18), _landmarks.get("look", Vector3(20, 2, -4)))
	await _capture("02_outpost", Vector3(22, 8, 16), _landmarks.get("outpost", Vector3(42, 2, -8)))
	player.global_position = Vector3(16, terrain.sample(16, -2) + 0.3, -2)
	await get_tree().physics_frame
	await _capture_player("03_third_person")
	var weapon := player.get_node_or_null("Weapon")
	if weapon and weapon.has_method("try_fire"):
		weapon.try_fire()
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_player("04_blaster")
	print("SHOTS_DONE")
	get_tree().quit()


func _capture(shot_name: String, pos: Vector3, look: Vector3) -> void:
	flyby.current = true
	flyby.global_position = pos
	flyby.look_at(look, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_frame(shot_name)


func _capture_player(shot_name: String) -> void:
	flyby.current = false
	player.get_node("CameraRig/SpringArm/Camera3D").current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_frame(shot_name)


func _save_frame(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("No viewport image for %s" % shot_name)
		return
	var paths := [
		"/tmp/starwake-shots/%s.png" % shot_name,
		"/opt/cursor/artifacts/%s.png" % shot_name,
	]
	for path in paths:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := image.save_png(path)
		print("SHOT ", shot_name, " ", path, " ", err, " ", image.get_width(), "x", image.get_height())

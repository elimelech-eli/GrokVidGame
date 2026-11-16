extends Node

const SkillCatalog = preload("res://scripts/rpg/skill_catalog.gd")
## Hotkeyed powers. Locked until the matching skill is bought.

const ORDER := ["shield_burst", "grenade", "combat_drone", "slow_dash"]

var cooldowns := {"shield_burst": 0.0, "grenade": 0.0, "combat_drone": 0.0, "slow_dash": 0.0}
var _slow_left := 0.0
var _player: CharacterBody3D


func setup(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	var rate := 1.0
	if has_node("/root/Stats"):
		rate = maxf(Stats.get_value("cooldown_rate"), 0.25)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(float(cooldowns[id]) - delta * rate, 0.0)
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			GameState.world_time_scale = 1.0
	if GameState.phase != GameState.Phase.PLAYING or _player == null:
		return
	for i in ORDER.size():
		if Input.is_action_just_pressed("ability_%d" % (i + 1)):
			try_cast(ORDER[i])


func try_cast(id: String) -> void:
	if GameState.skill_rank(id) <= 0:
		return
	if float(cooldowns.get(id, 0.0)) > 0.0:
		return
	var ok := false
	match id:
		"shield_burst":
			ok = _shield_burst()
		"grenade":
			ok = _grenade()
		"combat_drone":
			ok = _drone()
		"slow_dash":
			ok = _slow_dash()
	if not ok:
		return
	var rank := GameState.skill_rank(id)
	cooldowns[id] = SkillCatalog.cooldown(id, rank)
	EventBus.ability_cast.emit(id)
	AudioDirector.play_sfx("forceField_000", 0.04)


func remaining(id: String) -> float:
	return float(cooldowns.get(id, 0.0))


func fraction(id: String) -> float:
	var total := SkillCatalog.cooldown(id, maxi(GameState.skill_rank(id), 1))
	if total <= 0.0:
		return 0.0
	return clampf(remaining(id) / total, 0.0, 1.0)


func _shield_burst() -> bool:
	var health := _player.get_node_or_null("Health") as HealthComponent
	if health == null:
		return false
	health.shield = health.max_shield
	health.shield_changed.emit(health.shield, health.max_shield)
	CombatVfx.impact(get_tree().current_scene, _player.global_position + Vector3.UP, Vector3.UP, Color("7ee7ff"), true)
	return true


func _grenade() -> bool:
	var origin: Vector3 = _player.global_position + Vector3.UP * 1.2
	var cam := _player.get_node("CameraRig/SpringArm/Camera3D") as Camera3D
	var dir: Vector3 = -cam.global_basis.z
	dir.y = 0.15
	var grenade := Node3D.new()
	grenade.set_script(load("res://scripts/rpg/grenade.gd"))
	get_tree().current_scene.add_child(grenade)
	grenade.setup(origin, dir.normalized(), _player)
	return true


func _drone() -> bool:
	var drone := Node3D.new()
	drone.set_script(load("res://scripts/rpg/combat_drone.gd"))
	get_tree().current_scene.add_child(drone)
	drone.setup(_player)
	return true


func _slow_dash() -> bool:
	GameState.world_time_scale = 0.35
	_slow_left = 1.25
	if _player.has_method("_begin_dodge"):
		_player._begin_dodge()
	return true

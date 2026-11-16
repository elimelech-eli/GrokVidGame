extends Node
## Player blaster. Rays from the camera so the crosshair is truthful,
## then spawns a visible bolt, muzzle flash, and recoil kick.

signal fired(recoil_pitch: float, recoil_yaw: float)

const BOLT := preload("res://scripts/combat/projectile.gd")

@export var magazine_size := 30
@export var reserve_ammo := 120
@export var damage := 16.0
@export var fire_interval := 0.15
@export var reload_time := 1.25
@export var bolt_speed := 95.0

var magazine := 30
var reserve := 120
var reloading := false
var _cooldown := 0.0
var _reload_left := 0.0
var camera: Camera3D
var muzzle: Node3D
var source: Node3D


func _ready() -> void:
	magazine = magazine_size
	reserve = reserve_ammo
	_emit_ammo()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not reloading:
		return
	_reload_left -= delta
	if _reload_left > 0.0:
		return
	var need := magazine_size - magazine
	var take := mini(need, reserve)
	magazine += take
	reserve -= take
	reloading = false
	_emit_ammo()
	AudioDirector.play_sfx("click_001", 0.02)


func try_fire() -> void:
	if reloading or _cooldown > 0.0:
		return
	if magazine <= 0:
		if reserve > 0:
			start_reload()
		else:
			AudioDirector.play_sfx("error_001", 0.0)
		return
	if camera == null:
		return
	magazine -= 1
	_cooldown = fire_interval
	_emit_ammo()
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var muzzle_pos := muzzle.global_position if muzzle else origin + direction * 0.6
	CombatVfx.muzzle(get_tree().current_scene, muzzle_pos, direction, Color(0.7, 0.95, 1.0))
	AudioDirector.play_at("laserSmall_000", muzzle_pos, 0.07, -4.0)
	var bolt := Node3D.new()
	bolt.set_script(BOLT)
	get_tree().current_scene.add_child(bolt)
	bolt.speed = bolt_speed
	bolt.damage = damage
	bolt.color = Color(0.72, 0.96, 1.0)
	bolt.mask = Layers.WORLD | Layers.ENEMY
	bolt.source = source
	bolt.life = 1.4
	bolt.setup(muzzle_pos, direction)
	fired.emit(1.15, randf_range(-0.28, 0.28))


func start_reload() -> bool:
	if reloading or magazine >= magazine_size or reserve <= 0:
		return false
	reloading = true
	_reload_left = reload_time
	_emit_ammo()
	AudioDirector.play_sfx("impactPlate_light_002", 0.04)
	return true


func cancel_reload() -> void:
	if not reloading:
		return
	reloading = false
	_emit_ammo()


func _emit_ammo() -> void:
	GameState.set_ammo(magazine, reserve, reloading)

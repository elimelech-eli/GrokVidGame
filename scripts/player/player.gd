extends CharacterBody3D
## Third-person surveyor. The body moves in camera space; the visual rig
## turns to face travel, or the camera, while aiming. Later phases can drop
## followers and interaction on the same interact ray.

const WALK_SPEED := 3.5
const SPRINT_SPEED := 6.6
const AIM_SPEED := 2.4
const DODGE_SPEED := 11.0
const JUMP_VELOCITY := 7.4
const GRAVITY := 22.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.12

@onready var camera_rig: Node3D = $CameraRig
@onready var visual: Node3D = $Visual
@onready var weapon: Node = $Weapon
@onready var muzzle: Node3D = $Weapon/Muzzle
@onready var animator: ActorAnimator = $ActorAnimator

var health: HealthComponent
var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_time := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.FORWARD
var _melee_cd := 0.0
var _foot_time := 0.0
var _aiming := false
var _model_ready := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = 100.0
	health.max_shield = 60.0
	health.shield_regen = 16.0
	health.shield_delay = 3.2
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(func(_c, _m): _sync_vitals())
	health.shield_changed.connect(func(_c, _m): _sync_vitals())
	_sync_vitals()
	camera_rig.exclude_body(self)
	weapon.camera = camera_rig.camera
	weapon.muzzle = muzzle
	weapon.source = self
	weapon.fired.connect(_on_fired)
	_attach_body()
	_attach_weapon()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.add_mouse_look(event.relative)


func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING or not health.alive:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		animator.notify_locomotion(0.0, false, is_on_floor(), velocity.y)
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	camera_rig.add_stick_look(stick, delta)
	_aiming = Input.is_action_pressed("aim")
	camera_rig.set_aiming(_aiming)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0 and is_on_floor() and _dodge_time <= 0.0:
		_begin_dodge()
	if Input.is_action_just_pressed("reload"):
		if weapon.start_reload():
			animator.trigger("reload")
	if Input.is_action_pressed("fire") and _dodge_time <= 0.0 and _melee_cd <= 0.15:
		weapon.try_fire()
	if Input.is_action_just_pressed("melee") and _dodge_time <= 0.0:
		_melee()
	_update_prompt()
	var wish := _wish_direction()
	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity.x = _dodge_dir.x * DODGE_SPEED
		velocity.z = _dodge_dir.z * DODGE_SPEED
		if _dodge_time <= 0.0:
			health.invulnerable = false
	else:
		var speed := WALK_SPEED
		if _aiming:
			speed = AIM_SPEED
		elif Input.is_action_pressed("sprint") and wish.length_squared() > 0.1:
			speed = SPRINT_SPEED
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			AudioDirector.play_sfx("impactSoft_medium_001", 0.08)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		var landed := velocity.y < -8.0
		if landed:
			AudioDirector.play_at("impactSoft_medium_001", global_position, 0.05, -6.0)
		if velocity.y < 0.0:
			velocity.y = -0.1
	var was_floor := is_on_floor()
	move_and_slide()
	if was_floor and not is_on_floor() and velocity.y > 0.0:
		pass
	_face(wish, delta)
	var planar := Vector2(velocity.x, velocity.z).length()
	camera_rig.set_bob(planar if is_on_floor() and _dodge_time <= 0.0 else 0.0)
	animator.notify_locomotion(planar, Input.is_action_pressed("sprint") and not _aiming, is_on_floor(), velocity.y)
	_footsteps(delta, planar)


func _wish_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.01:
		return Vector3.ZERO
	var forward: Vector3 = camera_rig.flat_forward()
	var right: Vector3 = camera_rig.flat_right()
	# get_vector's Y is negative when move_forward is held.
	var dir: Vector3 = right * input.x + forward * -input.y
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


func _face(wish: Vector3, delta: float) -> void:
	var face: Vector3 = camera_rig.flat_forward() if (_aiming or weapon.reloading) else wish
	if face.length_squared() < 0.001:
		return
	var target := atan2(face.x, face.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target, 1.0 - exp(-12.0 * delta))


func _begin_dodge() -> void:
	var wish := _wish_direction()
	_dodge_dir = wish if wish.length_squared() > 0.01 else camera_rig.flat_forward()
	_dodge_time = 0.42
	_dodge_cd = 0.85
	health.invulnerable = true
	weapon.cancel_reload()
	animator.trigger("roll")
	AudioDirector.play_at("forceField_000", global_position, 0.04, -8.0)


func _melee() -> void:
	if _melee_cd > 0.0:
		return
	_melee_cd = 0.7
	animator.trigger("melee")
	AudioDirector.play_at("impactPunch_medium_000", global_position, 0.06, -2.0)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = Layers.ENEMY
	query.transform = Transform3D(Basis(), global_position + camera_rig.flat_forward() * 1.05 + Vector3.UP * 1.0)
	query.exclude = [get_rid()]
	var hits := space.intersect_shape(query, 8)
	var seen := {}
	for hit in hits:
		var body := hit.collider as Node
		while body and not body.is_in_group("enemy"):
			body = body.get_parent()
		if body == null or seen.has(body):
			continue
		seen[body] = true
		var to_enemy: Vector3 = (body as Node3D).global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01 and camera_rig.flat_forward().dot(to_enemy.normalized()) < 0.15:
			continue
		if body.has_node("Health"):
			body.get_node("Health").apply_damage(36.0, body.global_position, -to_enemy.normalized(), self)
			EventBus.hit_confirm.emit()
			CombatVfx.impact(get_tree().current_scene, body.global_position + Vector3.UP, Vector3.UP, Color(1.0, 0.75, 0.45), true)


func _update_prompt() -> void:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = camera_rig.camera.global_position
	var to: Vector3 = origin + (-camera_rig.camera.global_basis.z) * 4.5
	var query := PhysicsRayQueryParameters3D.create(origin, to, Layers.WORLD)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var text := ""
	if not hit.is_empty():
		var node := hit.collider as Node
		while node:
			if node.is_in_group("ship_hub"):
				text = "E    Ship hub sealed  —  boarding opens in a later phase"
				break
			node = node.get_parent()
	EventBus.interaction_prompt.emit(text)


func _footsteps(delta: float, planar: float) -> void:
	if not is_on_floor() or planar < 1.2 or _dodge_time > 0.0:
		return
	var interval := 0.46 if planar < 5.0 else 0.32
	_foot_time -= delta
	if _foot_time > 0.0:
		return
	_foot_time = interval
	var keys := ["footstep_grass_000", "footstep_grass_001", "footstep_grass_002"]
	AudioDirector.play_at(keys[randi() % keys.size()], global_position, 0.06, -10.0)


func _on_fired(recoil_pitch: float, recoil_yaw: float) -> void:
	camera_rig.add_recoil(recoil_pitch, recoil_yaw)
	animator.trigger("shoot")


func _on_damaged(amount: float, _pos: Vector3, _normal: Vector3, _source: Node) -> void:
	EventBus.player_damaged.emit(amount)
	camera_rig.shake(0.22 if health.shield > 0.0 else 0.4)
	var key := "forceField_002" if health.shield > 0.0 else "impactPunch_medium_000"
	AudioDirector.play_sfx(key, 0.05)
	animator.trigger("hit")


func _on_died() -> void:
	health.invulnerable = true
	animator.trigger("death")
	GameState.phase = GameState.Phase.DEAD
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.player_died.emit()
	AudioDirector.play_sfx("lowFrequency_explosion_000", 0.0)


func _sync_vitals() -> void:
	GameState.set_vitals(health.health, health.max_health, health.shield, health.max_shield)


func _attach_body() -> void:
	var packed := load("res://assets/models/character/UAL1_Standard.glb")
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	visual.add_child(model)
	PropUtils.fit_height(model, 1.78)
	PropUtils.align_feet(model)
	PropUtils.tint(model, Color("6d7c8a"), 0.0)
	# Quaternius' Godot/Unreal mannequin faces +Z. Godot forward is -Z.
	model.rotation.y = PI
	animator.setup(model, "human")
	_model_ready = true


func _attach_weapon() -> void:
	var packed := load("res://assets/models/essentials/Gun_Rifle.gltf")
	if packed == null:
		return
	var gun := packed.instantiate() as Node3D
	var hand := _find_hand(visual)
	var host: Node3D = hand if hand else visual
	host.add_child(gun)
	PropUtils.fit_longest(gun, 0.62)
	if hand:
		gun.position = Vector3(0.02, 0.08, 0.02)
		gun.rotation_degrees = Vector3(80, 0, 90)
	else:
		gun.position = Vector3(0.28, 1.15, -0.35)
		gun.rotation_degrees = Vector3(0, 0, 0)
	muzzle.top_level = false


func _find_hand(root: Node) -> BoneAttachment3D:
	var skeleton: Skeleton3D = null
	for node in root.find_children("*", "Skeleton3D", true, false):
		skeleton = node
		break
	if skeleton == null:
		return null
	var bone := -1
	for i in skeleton.get_bone_count():
		var n := String(skeleton.get_bone_name(i)).to_lower()
		if ("hand" in n or "wrist" in n) and (n.ends_with("_r") or n.ends_with(".r") or "right" in n):
			bone = i
			break
	if bone < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "GunHand"
	attachment.bone_idx = bone
	skeleton.add_child(attachment)
	return attachment

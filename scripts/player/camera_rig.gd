extends Node3D
## Over-the-shoulder spring arm. Yaw lives on this pivot, pitch on the arm,
## so the character body can face movement without dragging the camera.

@export var shoulder := 0.62
@export var aim_shoulder := 0.32
@export var rest_length := 3.45
@export var aim_length := 1.72
@export var rest_fov := 68.0
@export var aim_fov := 46.0
@export var pitch_min := -60.0
@export var pitch_max := 48.0

var aiming := false
var _yaw := 0.0
var _pitch := -8.0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _shake := 0.0
var _bob := 0.0

@onready var spring: SpringArm3D = $SpringArm
@onready var camera: Camera3D = $SpringArm/Camera3D


func _ready() -> void:
	spring.spring_length = rest_length
	spring.margin = 0.18
	spring.collision_mask = Layers.WORLD
	spring.position = Vector3(shoulder, 0.0, 0.0)
	camera.fov = rest_fov
	camera.current = false
	camera.near = 0.08
	camera.far = 800.0


func exclude_body(body: CollisionObject3D) -> void:
	spring.add_excluded_object(body.get_rid())


func add_mouse_look(relative: Vector2) -> void:
	var sens := Settings.mouse_sensitivity * (0.55 if aiming else 1.0)
	var invert := -1.0 if Settings.invert_y else 1.0
	_yaw -= rad_to_deg(relative.x * sens)
	_pitch = clampf(_pitch - rad_to_deg(relative.y * sens) * invert, pitch_min, pitch_max)


func add_stick_look(stick: Vector2, delta: float) -> void:
	if stick.length() < 0.08:
		return
	var sens := rad_to_deg(Settings.gamepad_sensitivity) * (0.62 if aiming else 1.0)
	var invert := -1.0 if Settings.invert_y else 1.0
	_yaw -= stick.x * sens * delta
	_pitch = clampf(_pitch - stick.y * sens * delta * invert, pitch_min, pitch_max)


func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_pitch += pitch_deg * (0.45 if aiming else 1.0)
	_recoil_yaw += yaw_deg * (0.45 if aiming else 1.0)
	_shake = maxf(_shake, 0.08)


func shake(amount: float) -> void:
	if Settings.screen_shake:
		_shake = maxf(_shake, amount)


func set_aiming(active: bool) -> void:
	aiming = active


func set_bob(speed: float) -> void:
	_bob = speed


func _process(delta: float) -> void:
	var damp := 1.0 - exp(-12.0 * delta)
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, damp)
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, damp)
	_shake = lerpf(_shake, 0.0, 1.0 - exp(-8.0 * delta))
	rotation_degrees.y = _yaw + _recoil_yaw
	spring.rotation_degrees.x = -_pitch + _recoil_pitch
	var target_len := aim_length if aiming else rest_length
	var target_fov := aim_fov if aiming else rest_fov
	var target_shoulder := aim_shoulder if aiming else shoulder
	spring.spring_length = lerpf(spring.spring_length, target_len, damp)
	camera.fov = lerpf(camera.fov, target_fov, damp)
	spring.position.x = lerpf(spring.position.x, target_shoulder, damp)
	var bob_y := sin(Time.get_ticks_msec() * 0.012) * clampf(_bob / 6.0, 0.0, 1.0) * 0.035
	spring.position.y = bob_y
	if _shake > 0.001 and Settings.screen_shake:
		camera.h_offset = randf_range(-_shake, _shake) * 0.15
		camera.v_offset = randf_range(-_shake, _shake) * 0.1
	else:
		camera.h_offset = lerpf(camera.h_offset, 0.0, damp)
		camera.v_offset = lerpf(camera.v_offset, 0.0, damp)


func flat_forward() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3(0, 0, -1)
	return forward.normalized()


func flat_right() -> Vector3:
	var right := global_basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		return Vector3(1, 0, 0)
	return right.normalized()

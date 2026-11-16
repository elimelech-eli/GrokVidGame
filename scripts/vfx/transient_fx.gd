extends Node3D
## Short-lived muzzle flash or impact burst.

var life := 0.08
var _start := 0.08
var light: OmniLight3D
var particles: CPUParticles3D


func _ready() -> void:
	_start = life


func _process(delta: float) -> void:
	life -= delta
	var t := clampf(life / maxf(_start, 0.001), 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.35, 1.0, t)
	if light:
		light.light_energy = light.light_energy * (0.92 if t > 0.0 else 0.0)
		light.light_energy = lerpf(0.0, light.get_meta("base_energy", 6.0), t)
	if particles and life < _start - particles.lifetime and not particles.emitting:
		pass
	if life <= 0.0:
		queue_free()

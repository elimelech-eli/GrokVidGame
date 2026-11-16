class_name CombatVfx
extends RefCounted


static func muzzle(parent: Node, origin: Vector3, direction: Vector3, color: Color) -> void:
	var flash := Node3D.new()
	flash.set_script(load("res://scripts/vfx/transient_fx.gd"))
	flash.life = 0.055
	parent.add_child(flash)
	flash.global_position = origin
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	var mat := _unshaded(color, 6.0)
	sphere.material = mat
	mesh.mesh = sphere
	flash.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 7.0
	light.omni_range = 3.4
	light.set_meta("base_energy", 7.0)
	light.shadow_enabled = false
	flash.add_child(light)
	flash.light = light
	var kick := direction.normalized() * 0.12
	flash.global_position += kick


static func impact(parent: Node, position: Vector3, normal: Vector3, color: Color, heavy := false) -> void:
	var burst := Node3D.new()
	burst.set_script(load("res://scripts/vfx/transient_fx.gd"))
	burst.life = 0.45 if heavy else 0.32
	parent.add_child(burst)
	burst.global_position = position + normal * 0.04
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 22 if heavy else 14
	particles.lifetime = 0.32
	particles.direction = normal
	particles.spread = 38.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 5.5
	particles.gravity = Vector3(0, -6.0, 0)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	var spark := SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	spark.material = _unshaded(color, 5.0)
	particles.mesh = spark
	particles.emitting = true
	burst.add_child(particles)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.5 if heavy else 2.4
	light.omni_range = 2.8
	light.set_meta("base_energy", light.light_energy)
	burst.add_child(light)
	burst.light = light


static func _unshaded(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat

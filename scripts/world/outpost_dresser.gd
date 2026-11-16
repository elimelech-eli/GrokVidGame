class_name OutpostDresser
extends RefCounted
## Places the landing ship, a modular survey outpost, and alien ground cover.
## Module scale is normalized from the imported wall so the free glTF set
## tiles even if the authoring units are not meters.

const OUT := "res://assets/models/outpost/"
const NAT := "res://assets/models/nature/"
const ESS := "res://assets/models/essentials/"
const SHIP := "res://assets/models/ship/"

var _root: Node3D
var _terrain: TerrainField
var _module_scale := 1.0
var _rng := RandomNumberGenerator.new()


func dress(root: Node3D, terrain: TerrainField) -> Dictionary:
	_root = root
	_terrain = terrain
	_rng.seed = 1407
	_calibrate()
	var ship_pos := _place_ship()
	var deck := _place_outpost()
	_scatter_nature()
	_place_fauna()
	_place_pool()
	return {
		"spawn": Vector3(-1.5, _terrain.sample(-1.5, 6.5), 6.5),
		"ship": ship_pos,
		"outpost": deck,
		"look": deck + Vector3(0, 1.6, 0),
	}


func _calibrate() -> void:
	var probe := _instance(OUT + "WallAstra_Straight.gltf")
	probe.visible = false
	var box := PropUtils.merged_local_aabb(probe)
	var height := maxf(box.size.y, 0.001)
	if height < 1.4 or height > 6.0:
		_module_scale = 3.3 / height
	probe.queue_free()
	print("OUTPOST_WALL_H ", height, " scale ", _module_scale)


func _place_ship() -> Vector3:
	var ship := _instance(SHIP + "Spaceship.fbx")
	PropUtils.fit_longest(ship, 16.0)
	PropUtils.tint(ship, Color("b7c0c8"), 0.05)
	var x := -11.0
	var z := 1.5
	ship.position = Vector3(x, 0.0, z)
	ship.rotation.y = deg_to_rad(28.0)
	PropUtils.plant(ship, _terrain.sample(x, z))
	PropUtils.add_static_collision(ship)
	ship.add_to_group("ship_hub")
	var socket := Marker3D.new()
	socket.name = "ShipHubSocket"
	ship.add_child(socket)
	socket.position = Vector3(2.2, 1.4, 0.4)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff9a45")
	glow.light_energy = 3.2
	glow.omni_range = 7.0
	glow.shadow_enabled = false
	ship.add_child(glow)
	glow.position = Vector3(-3.5, 0.8, 0.0)
	var thruster := AudioStreamPlayer3D.new()
	var looped := AudioDirector.looped("thrusterFire_000")
	if looped:
		thruster.stream = looped
		thruster.volume_db = -16.0
		thruster.bus = "Music"
		thruster.max_distance = 28.0
		ship.add_child(thruster)
		thruster.play()
	# A second hull parked by the pad, so the outpost reads as a landing field.
	var miner := _instance(SHIP + "craft_miner.glb")
	PropUtils.fit_longest(miner, 7.5)
	miner.position = Vector3(28.0, 0.0, 6.0)
	miner.rotation.y = deg_to_rad(-40.0)
	PropUtils.plant(miner, _terrain.sample(28.0, 6.0))
	PropUtils.add_static_collision(miner)
	return ship.global_position


func _place_outpost() -> Vector3:
	var origin := Vector3(36.0, 0.0, -10.0)
	var ground := _terrain.sample(origin.x, origin.z)
	var platform := _measured(OUT + "Platform_DarkPlates.gltf")
	var tile: Vector3 = platform["size"]
	var cols := 3
	var rows := 2
	for row in rows:
		for col in cols:
			var inst := _instance(OUT + "Platform_DarkPlates.gltf")
			_apply_module_scale(inst)
			var box := PropUtils.merged_local_aabb(inst)
			var min_x := origin.x + (float(col) - 1.0) * box.size.x
			var min_z := origin.z + (float(row) - 0.5) * box.size.z
			inst.position = Vector3(min_x, ground, min_z) - box.position
			PropUtils.add_static_collision(inst)
	var deck_top := ground + tile.y
	# Walls from the free modular set do not share one pivot, so a generated
	# ring floats. The camp is the deck, crates, lights, and the dish instead.
	_props(origin, deck_top)
	return Vector3(origin.x + tile.x, deck_top, origin.z + tile.z * 0.5)


func _wall_run(origin: Vector3, deck_top: float, tile: Vector3) -> void:
	var wall_w := tile.x
	var specs := [
		[OUT + "WallAstra_Straight_Window.gltf", 0],
		[OUT + "WallAstra_Straight.gltf", 1],
		[OUT + "WallAstra_Straight_Flat.gltf", 2],
	]
	for spec in specs:
		var inst := _instance(spec[0])
		_apply_module_scale(inst)
		var box := PropUtils.merged_local_aabb(inst)
		var min_x := origin.x + float(spec[1]) * wall_w
		inst.position = Vector3(min_x, deck_top, origin.z + tile.z * 1.55) - Vector3(box.position.x, box.position.y, box.position.z)
		PropUtils.add_static_collision(inst)
		var cap := _instance(OUT + "TopCables_Straight.gltf")
		_apply_module_scale(cap)
		var cap_box := PropUtils.merged_local_aabb(cap)
		cap.position = inst.position + Vector3(0, box.size.y * 0.92, 0) - Vector3(0, cap_box.position.y, 0)
	var column := _instance(OUT + "Column_Astra.gltf")
	_apply_module_scale(column)
	var col_box := PropUtils.merged_local_aabb(column)
	column.position = Vector3(origin.x - 0.4, deck_top, origin.z - 0.2) - col_box.position
	PropUtils.add_static_collision(column)
	var column_b := _instance(OUT + "Column_Pipes.gltf")
	_apply_module_scale(column_b)
	var col_b := PropUtils.merged_local_aabb(column_b)
	column_b.position = Vector3(origin.x + tile.x * 2.7, deck_top, origin.z - 0.2) - col_b.position
	PropUtils.add_static_collision(column_b)


func _props(origin: Vector3, deck_top: float) -> void:
	var placements := [
		[ESS + "Prop_Crate_Large.gltf", Vector3(1.2, 0, 0.8), 20.0],
		[ESS + "Prop_Crate.gltf", Vector3(2.4, 0, 1.1), -15.0],
		[ESS + "Prop_Barrel1.gltf", Vector3(3.4, 0, 0.6), 40.0],
		[ESS + "Prop_Chest.gltf", Vector3(5.2, 0, 2.4), 8.0],
		[ESS + "Prop_Locker.gltf", Vector3(0.8, 0, 3.6), 90.0],
		[ESS + "Prop_Desk_Medium.gltf", Vector3(4.6, 0, 3.8), 180.0],
		[ESS + "Prop_Shelves_WideTall.gltf", Vector3(7.2, 0, 3.2), 180.0],
		[OUT + "Prop_Computer.gltf", Vector3(4.8, 0.9, 3.5), 180.0],
		[OUT + "Prop_Light_Wide.gltf", Vector3(2.2, 2.6, 4.4), 0.0],
		[OUT + "Prop_Light_Floor.gltf", Vector3(7.6, 0, 0.4), 30.0],
		[ESS + "Prop_SatelliteDish.gltf", Vector3(9.4, 0, 5.5), -30.0],
		[ESS + "Prop_Ammo.gltf", Vector3(2.8, 0, 2.2), 10.0],
		[ESS + "Prop_HealthPack.gltf", Vector3(3.1, 0.4, 2.0), 0.0],
	]
	for item in placements:
		var inst := _instance(item[0])
		if String(item[0]).begins_with(OUT):
			_apply_module_scale(inst)
		else:
			PropUtils.fit_longest(inst, 1.4 if "Satellite" in String(item[0]) else (1.1 if "Shelves" in String(item[0]) or "Locker" in String(item[0]) else 0.85))
		var offset: Vector3 = item[1]
		inst.position = origin + Vector3(offset.x, deck_top - _terrain.sample(origin.x, origin.z) + offset.y, offset.z)
		inst.rotation.y = deg_to_rad(item[2])
		PropUtils.plant(inst, deck_top + offset.y)
		if "Light" in String(item[0]):
			PropUtils.boost_emission(inst, Color("7dfff2"), 4.0)
			var light := OmniLight3D.new()
			light.light_color = Color("8af7ff") if "Wide" in String(item[0]) else Color("ffb15a")
			light.light_energy = 2.8
			light.omni_range = 8.0
			light.shadow_enabled = "Wide" in String(item[0])
			inst.add_child(light)
			light.position.y = 0.4
		elif "Crate" in String(item[0]) or "Locker" in String(item[0]) or "Desk" in String(item[0]) or "Satellite" in String(item[0]):
			PropUtils.add_static_collision(inst)


func _stairs(origin: Vector3, ground: float, deck_top: float) -> void:
	var stairs := _instance(OUT + "Platform_Stairs_4.gltf")
	_apply_module_scale(stairs)
	stairs.rotation.y = PI
	var box := PropUtils.merged_local_aabb(stairs)
	stairs.position = Vector3(origin.x + 2.0, ground, origin.z - 1.2)
	PropUtils.plant(stairs, ground)
	PropUtils.add_static_collision(stairs)
	var rail := _instance(OUT + "Prop_Rail_4.gltf")
	_apply_module_scale(rail)
	rail.position = stairs.position + Vector3(0.2, 0.2, -0.4)
	PropUtils.plant(rail, ground + 0.15)
	if deck_top < ground:
		pass


func _scatter_nature() -> void:
	var specs := [
		[NAT + "TwistedTree_1.gltf", 6.5, Color("6d4a86"), 0.25],
		[NAT + "TwistedTree_3.gltf", 7.4, Color("245e58"), 0.35],
		[NAT + "TwistedTree_5.gltf", 5.8, Color("7a3568"), 0.22],
		[NAT + "DeadTree_2.gltf", 5.2, Color("6a5348"), 0.0],
		[NAT + "Fern_1.gltf", 1.15, Color("3ee0c0"), 0.85],
		[NAT + "Plant_1.gltf", 0.9, Color("ff5ad0"), 0.7],
		[NAT + "Plant_1_Big.gltf", 1.6, Color("7dffe8"), 0.9],
		[NAT + "Plant_7.gltf", 1.05, Color("ffb15a"), 0.55],
		[NAT + "Plant_7_Big.gltf", 1.8, Color("c8ff6a"), 0.45],
		[NAT + "Mushroom_Common.gltf", 0.7, Color("ff6ad5"), 1.1],
		[NAT + "Mushroom_Laetiporus.gltf", 0.85, Color("ff8a3a"), 0.8],
		[NAT + "Bush_Common.gltf", 1.3, Color("2f8f78"), 0.35],
		[NAT + "Grass_Common_Tall.gltf", 0.7, Color("d7e38a"), 0.15],
		[NAT + "Grass_Wispy_Tall.gltf", 0.85, Color("9be7c8"), 0.2],
		[NAT + "Rock_Medium_1.gltf", 1.8, Color("8a7568"), 0.0],
		[NAT + "Rock_Medium_2.gltf", 2.4, Color("6e625c"), 0.0],
		[NAT + "Rock_Medium_3.gltf", 1.5, Color("a08a78"), 0.0],
		[NAT + "Pebble_Round_1.gltf", 0.45, Color("9a887c"), 0.0],
		[NAT + "RockPath_Round_Wide.gltf", 2.2, Color("b08968"), 0.0],
	]
	var clusters := [
		Vector2(-24, 14), Vector2(-18, -16), Vector2(8, 22), Vector2(14, -24),
		Vector2(58, -6), Vector2(62, 12), Vector2(-40, -8), Vector2(22, 18),
		Vector2(-8, -28), Vector2(48, 20), Vector2(-30, 32), Vector2(70, -20),
	]
	for cluster_value in clusters:
		var cluster: Vector2 = cluster_value
		var spec: Array = specs[_rng.randi() % specs.size()]
		var count := 1 if float(spec[1]) > 3.0 else _rng.randi_range(2, 4)
		for i in count:
			var x: float = cluster.x + _rng.randf_range(-4.5, 4.5)
			var z: float = cluster.y + _rng.randf_range(-4.5, 4.5)
			if _blocked(x, z):
				continue
			var inst := _instance(spec[0])
			PropUtils.fit_height(inst, spec[1] * _rng.randf_range(0.85, 1.15))
			inst.rotation.y = _rng.randf() * TAU
			inst.position = Vector3(x, 0, z)
			PropUtils.plant(inst, _terrain.sample(x, z))
			var glow: float = spec[3]
			if glow > 0.0:
				PropUtils.tint(inst, spec[2], glow)
			if spec[1] > 1.2 and "Grass" not in String(spec[0]) and "Fern" not in String(spec[0]) and "Plant" not in String(spec[0]) and "Mushroom" not in String(spec[0]):
				PropUtils.add_static_collision(inst)


func _place_fauna() -> void:
	var fauna := [
		[OUT + "Alien_Scolitex.gltf", Vector3(-16, 0, -6), 2.2, Color("7dffe0")],
		[OUT + "Alien_Cyclop.gltf", Vector3(18, 0, 16), 1.6, Color("ff7ad4")],
		[OUT + "Alien_Oculichrysalis.gltf", Vector3(54, 0, -22), 1.8, Color("ffe08a")],
	]
	for item in fauna:
		var inst := _instance(item[0])
		PropUtils.fit_height(inst, item[2])
		var pos: Vector3 = item[1]
		inst.position = Vector3(pos.x, 0, pos.z)
		inst.rotation.y = _rng.randf() * TAU
		PropUtils.plant(inst, _terrain.sample(pos.x, pos.z))
		PropUtils.tint(inst, item[3], 0.45)
		PropUtils.play_first_animation(inst)
		PropUtils.add_static_collision(inst)


func _place_pool() -> void:
	var x := -34.0
	var z := 26.0
	var y := _terrain.sample(x, z) + 0.15
	var mesh_instance := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.2
	disc.bottom_radius = 6.2
	disc.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.75, 0.82, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("1ad6c8")
	mat.emission_energy_multiplier = 0.7
	mat.roughness = 0.08
	mat.metallic = 0.15
	disc.material = mat
	mesh_instance.mesh = disc
	mesh_instance.position = Vector3(x, y, z)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mesh_instance)
	var light := OmniLight3D.new()
	light.light_color = Color("3ef0e0")
	light.light_energy = 2.2
	light.omni_range = 10.0
	mesh_instance.add_child(light)


func _blocked(x: float, z: float) -> bool:
	if Vector2(x, z).length() < 12.0:
		return true
	if Vector2(x - 42.0, z + 8.0).length() < 16.0:
		return true
	if Vector2(x + 11.0, z - 1.5).length() < 8.0:
		return true
	return false


func _measured(path: String) -> Dictionary:
	var inst := _instance(path)
	inst.visible = false
	_apply_module_scale(inst)
	var box := PropUtils.merged_local_aabb(inst)
	inst.queue_free()
	return {"size": box.size}


func _apply_module_scale(inst: Node3D) -> void:
	inst.scale = Vector3.ONE * _module_scale


func _instance(path: String) -> Node3D:
	var packed := load(path)
	if packed == null:
		push_error("Missing model %s" % path)
		var empty := Node3D.new()
		_root.add_child(empty)
		return empty
	var inst := packed.instantiate() as Node3D
	_root.add_child(inst)
	return inst

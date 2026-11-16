class_name TerrainField
extends StaticBody3D
## Alien basin: rust flats, a flattened landing, an outpost pad, and a
## mineral pool. Heights are queried by the dresser and the spawner.

const SIZE := 190.0
const RES := 150

var _heights := PackedFloat32Array()
var _step := 1.0


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_build()


func sample(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var half := SIZE * 0.5
	var fx := clampf((x + half) / _step, 0.0, float(RES))
	var fz := clampf((z + half) / _step, 0.0, float(RES))
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, RES)
	var z1 := mini(z0 + 1, RES)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var h00 := _heights[z0 * (RES + 1) + x0]
	var h10 := _heights[z0 * (RES + 1) + x1]
	var h01 := _heights[z1 * (RES + 1) + x0]
	var h11 := _heights[z1 * (RES + 1) + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build() -> void:
	_step = SIZE / float(RES)
	var count := (RES + 1) * (RES + 1)
	_heights.resize(count)
	var broad := FastNoiseLite.new()
	broad.seed = 1407
	broad.frequency = 0.011
	broad.fractal_octaves = 4
	broad.fractal_type = FastNoiseLite.FRACTAL_FBM
	var detail := FastNoiseLite.new()
	detail.seed = 99
	detail.frequency = 0.042
	var half := SIZE * 0.5
	for z in RES + 1:
		for x in RES + 1:
			var wx := -half + x * _step
			var wz := -half + z * _step
			var h := broad.get_noise_2d(wx, wz) * 8.2
			h += detail.get_noise_2d(wx, wz) * 1.15
			h = _shape(wx, wz, h)
			_heights[z * (RES + 1) + x] = h
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in RES + 1:
		for x in RES + 1:
			var wx := -half + x * _step
			var wz := -half + z * _step
			var h := _heights[z * (RES + 1) + x]
			st.set_color(_color(wx, wz, h, detail))
			st.add_vertex(Vector3(wx, h, wz))
	for z in RES:
		for x in RES:
			var i := z * (RES + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + RES + 1)
			st.add_index(i + 1)
			st.add_index(i + RES + 2)
			st.add_index(i + RES + 1)
	st.generate_normals()
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail", _noise_texture(detail))
	visual.material_override = mat
	add_child(visual)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	add_child(col)


func _shape(x: float, z: float, h: float) -> float:
	var landing := 1.0 - smoothstep(14.0, 26.0, Vector2(x, z).length())
	var outpost := 1.0 - smoothstep(16.0, 30.0, Vector2(x - 42.0, z + 8.0).length())
	var pool := 1.0 - smoothstep(7.0, 14.0, Vector2(x + 34.0, z - 26.0).length())
	var flat := maxf(landing, outpost)
	h = lerpf(h, 0.35, flat)
	h = lerpf(h, -1.35, pool)
	var half := SIZE * 0.5
	var edge := minf(minf(x + half, half - x), minf(z + half, half - z))
	if edge < 16.0:
		h += (1.0 - edge / 16.0) * 14.0
	return h


func _color(x: float, z: float, h: float, detail: FastNoiseLite) -> Color:
	var low := Color("6b3328")
	var mid := Color("c4743c")
	var high := Color("e0b56a")
	var rock := Color("4e4946")
	var vein := Color("1c8f86")
	var pool := Color("0d3c42")
	var t := clampf((h + 1.0) / 8.0, 0.0, 1.0)
	var c := low.lerp(mid, smoothstep(0.0, 0.45, t)).lerp(high, smoothstep(0.45, 1.0, t))
	if h > 5.0:
		c = c.lerp(rock, 0.65)
	if h < -0.4:
		c = c.lerp(pool, clampf((-h) / 1.2, 0.0, 1.0))
	var mineral := detail.get_noise_2d(x * 1.7 + 40.0, z * 1.7)
	if mineral > 0.38 and h > -0.2:
		c = c.lerp(vein, (mineral - 0.38) * 1.8)
	return c


func _noise_texture(noise: FastNoiseLite) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := noise.get_noise_2d(x * 3.0, y * 3.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)


func smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

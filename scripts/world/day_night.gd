class_name DayNightCycle
extends Node
## Late-afternoon start, then a full cycle. Sky, sun, fog, and stars track
## one clock so a later phase can pause it inside the ship.

var time := 0.40
var locked := false
var environment: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var stars_mat: ShaderMaterial
var _software := false


func setup(world_env: WorldEnvironment, sun_light: DirectionalLight3D, moon_light: DirectionalLight3D) -> void:
	sun = sun_light
	moon = moon_light
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	_software = "llvmpipe" in adapter or "lavapipe" in adapter or "swiftshader" in adapter or adapter == ""
	print("RENDER_ADAPTER ", RenderingServer.get_video_adapter_name(), " software=", _software)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.05
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.02
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.95
	environment.glow_bloom = 0.14
	environment.glow_hdr_threshold = 0.82
	environment.glow_hdr_scale = 1.15
	environment.ssao_enabled = not _software
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.5
	environment.ssil_enabled = not _software
	environment.sdfgi_enabled = not _software
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.55
	environment.sdfgi_bounce_feedback = 0.45
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.volumetric_fog_enabled = not _software
	environment.volumetric_fog_density = 0.010
	environment.volumetric_fog_albedo = Color(0.72, 0.55, 0.42)
	environment.volumetric_fog_length = 96.0
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0035
	environment.fog_aerial_perspective = 0.55
	environment.fog_sky_affect = 0.45
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.03
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.16
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grade.colors = PackedColorArray([Color(0.78, 0.86, 1.0), Color(1, 1, 1), Color(1.0, 0.94, 0.84)])
	var grade_tex := GradientTexture1D.new()
	grade_tex.gradient = grade
	grade_tex.width = 256
	environment.adjustment_color_correction = grade_tex
	world_env.environment = environment
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.18
	moon.shadow_enabled = false
	moon.light_angular_distance = 0.12
	_build_stars()
	_apply()


func _process(delta: float) -> void:
	if environment == null:
		return
	if not locked:
		var seconds := maxf(Settings.cycle_seconds, 20.0)
		time = fposmod(time + delta / seconds, 1.0)
	_apply()


func _build_stars() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 420.0
	sphere.height = 840.0
	sphere.radial_segments = 24
	sphere.rings = 12
	mesh_instance.mesh = sphere
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stars_mat = ShaderMaterial.new()
	stars_mat.shader = load("res://shaders/stars.gdshader")
	mesh_instance.material_override = stars_mat
	add_child(mesh_instance)


func _apply() -> void:
	# 0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight.
	var elev := sin(time * TAU) * 68.0
	var dayness := smoothstep(-6.0, 16.0, elev)
	var golden := smoothstep(-2.0, 18.0, elev) * (1.0 - smoothstep(22.0, 48.0, elev))
	var azimuth := time * 360.0 + 28.0
	sun.rotation_degrees = Vector3(-elev, azimuth, 0.0)
	moon.rotation_degrees = Vector3(elev - 180.0, azimuth + 180.0, 0.0)
	var day_top := Color("1d4c66")
	var day_horizon := Color("f0b27a")
	var golden_horizon := Color("ff8a45")
	var night_top := Color("070814")
	var night_horizon := Color("1a2744")
	var horizon := day_horizon.lerp(golden_horizon, golden)
	sky_mat.sky_top_color = night_top.lerp(day_top, dayness)
	sky_mat.sky_horizon_color = night_horizon.lerp(horizon, dayness)
	sky_mat.ground_horizon_color = Color("2a1a16").lerp(Color("c47a48"), dayness)
	sky_mat.ground_bottom_color = Color("07080c").lerp(Color("3a2418"), dayness)
	sky_mat.sky_energy_multiplier = lerpf(0.35, 1.15, dayness)
	sky_mat.sun_curve = lerpf(0.05, 0.12, dayness)
	sun.light_color = Color("fff2dd").lerp(Color("ffb068"), golden)
	sun.light_energy = lerpf(0.0, 1.45, dayness) * lerpf(1.0, 1.15, golden)
	moon.light_color = Color("9eb6ff")
	moon.light_energy = lerpf(0.42, 0.0, dayness)
	environment.ambient_light_energy = lerpf(0.35, 1.05, dayness)
	environment.fog_light_color = night_horizon.lerp(horizon, dayness)
	environment.fog_density = lerpf(0.0065, 0.0032, dayness)
	environment.volumetric_fog_density = lerpf(0.02, 0.009, dayness) if not _software else 0.0
	environment.volumetric_fog_albedo = Color(0.45, 0.55, 0.7).lerp(Color(0.85, 0.62, 0.42), dayness)
	environment.volumetric_fog_emission = Color(0.15, 0.2, 0.35) * (1.0 - dayness) * 0.15
	environment.adjustment_saturation = lerpf(0.9, 1.18, dayness)
	if stars_mat:
		stars_mat.set_shader_parameter("visibility", clampf(1.0 - dayness, 0.0, 1.0))


func smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

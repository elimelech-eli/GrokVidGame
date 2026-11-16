extends Control
## Shield, health, ammo, crosshair, damage wash, and the interact line.

var _shield := 1.0
var _health := 1.0
var _ammo := "30"
var _reserve := "120"
var _reloading := false
var _prompt := ""
var _hurt := 0.0
var _hit := 0.0
var _spread := 8.0
var _banner := 0.0
var _aiming := false
var _shield_fill: ColorRect
var _health_fill: ColorRect
var _ammo_label: Label
var _reserve_label: Label
var _prompt_label: Label
var _zone_label: Label
var _level_label: Label
var _toast_label: Label
var _ability_label: Label
var _hurt_rect: ColorRect
var _crosshair: Control
var _toast_time := 0.0
var _toast_text := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	_hurt_rect.material = mat
	EventBus.player_vitals_changed.connect(_on_vitals)
	EventBus.player_ammo_changed.connect(_on_ammo)
	EventBus.player_damaged.connect(_on_hurt)
	EventBus.hit_confirm.connect(func(): _hit = 1.0)
	EventBus.interaction_prompt.connect(func(text): _prompt = text)
	EventBus.game_started.connect(func(): _banner = 7.0)
	EventBus.toast.connect(_on_toast)
	EventBus.xp_changed.connect(func(_l, _x, _n): _refresh_meta())
	EventBus.inventory_changed.connect(func(): _refresh_meta())
	_on_vitals(GameState.health, GameState.max_health, GameState.shield, GameState.max_shield)
	visible = false


func _process(delta: float) -> void:
	visible = GameState.phase == GameState.Phase.PLAYING or GameState.phase == GameState.Phase.PAUSED or GameState.phase == GameState.Phase.DEAD
	_hurt = maxf(_hurt - delta * 1.4, 0.0)
	_hit = maxf(_hit - delta * 3.0, 0.0)
	_banner = maxf(_banner - delta, 0.0)
	_zone_label.modulate.a = clampf(_banner / 1.5, 0.0, 1.0)
	if _hurt_rect.material is ShaderMaterial:
		_hurt_rect.material.set_shader_parameter("intensity", _hurt)
	_shield_fill.anchor_right = 0.02 + 0.98 * clampf(_shield, 0.0, 1.0)
	_health_fill.anchor_right = 0.02 + 0.98 * clampf(_health, 0.0, 1.0)
	_ammo_label.text = "RELOADING" if _reloading else _ammo
	_reserve_label.text = _reserve
	_prompt_label.text = _prompt
	_aiming = Input.is_action_pressed("aim") and GameState.phase == GameState.Phase.PLAYING
	var speed := 0.0
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	var target := 18.0 if speed > 5.0 else (14.0 if speed > 0.5 else 8.0)
	if _aiming:
		target = 3.0
	if _hit > 0.2:
		target += 4.0
	_spread = lerpf(_spread, target, 1.0 - exp(-10.0 * delta))
	_crosshair.queue_redraw()
	_toast_time = maxf(_toast_time - delta, 0.0)
	_toast_label.modulate.a = clampf(_toast_time, 0.0, 1.0)
	_refresh_abilities()


func _on_vitals(health: float, max_health: float, shield: float, max_shield: float) -> void:
	_health = health / maxf(max_health, 1.0)
	_shield = shield / maxf(max_shield, 1.0)


func _on_ammo(magazine: int, reserve: int, reloading: bool) -> void:
	_ammo = str(magazine)
	_reserve = str(reserve)
	_reloading = reloading


func _on_hurt(_amount: float) -> void:
	_hurt = 0.85


func _build() -> void:
	_hurt_rect = ColorRect.new()
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.color = Color(1, 1, 1, 1)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt_rect)
	var stack := VBoxContainer.new()
	stack.position = Vector2(36, 28)
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	stack.add_child(UiStyle.label("SHIELD", 12, UiStyle.SHIELD))
	_shield_fill = _bar(stack, UiStyle.SHIELD)
	stack.add_child(UiStyle.label("HEALTH", 12, UiStyle.HEALTH))
	_health_fill = _bar(stack, UiStyle.HEALTH)
	_level_label = UiStyle.label("LV 1", 14, UiStyle.INK)
	stack.add_child(_level_label)
	_zone_label = UiStyle.label("VESPER-9   ·   AETHER REACH", 14, UiStyle.AMBER)
	_zone_label.position = Vector2(36, 150)
	add_child(_zone_label)
	var ammo_box := VBoxContainer.new()
	ammo_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_box.offset_left = -220
	ammo_box.offset_top = -140
	ammo_box.offset_right = -36
	ammo_box.offset_bottom = -36
	ammo_box.alignment = BoxContainer.ALIGNMENT_END
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_box)
	ammo_box.add_child(UiStyle.label("RIFLE", 12, UiStyle.MUTED))
	_ammo_label = UiStyle.label("30", 42, UiStyle.INK)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_ammo_label)
	_reserve_label = UiStyle.label("120", 16, UiStyle.ACCENT)
	_reserve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(_reserve_label)
	_prompt_label = UiStyle.label("", 16, UiStyle.ACCENT)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_top = -90
	_prompt_label.offset_bottom = -50
	_prompt_label.offset_left = -360
	_prompt_label.offset_right = 360
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt_label)
	_ability_label = UiStyle.label("", 14, UiStyle.ACCENT)
	_ability_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_label.offset_top = -150
	_ability_label.offset_bottom = -110
	_ability_label.offset_left = -420
	_ability_label.offset_right = 420
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_ability_label)
	_toast_label = UiStyle.label("", 18, UiStyle.AMBER)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 36
	_toast_label.offset_bottom = 80
	_toast_label.offset_left = -400
	_toast_label.offset_right = 400
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast_label)
	_crosshair = Control.new()
	_crosshair.set_script(load("res://scripts/ui/crosshair.gd"))
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)


func _on_toast(text: String) -> void:
	_toast_text = text
	_toast_time = 2.4
	_toast_label.text = text


func _refresh_meta() -> void:
	if _level_label == null:
		return
	var level := int(GameState.progression.get("level", 1))
	var xp := int(GameState.progression.get("xp", 0))
	var need := GameState.xp_for_level(level)
	_level_label.text = "LV %d    %d/%d XP    %d cr" % [level, xp, need, Inventory.credits]


func _refresh_abilities() -> void:
	if _ability_label == null:
		return
	var names := ["BURST", "NADE", "DRONE", "SLIDE"]
	var ids := ["shield_burst", "grenade", "combat_drone", "slow_dash"]
	var parts: PackedStringArray = []
	var powers := get_tree().get_first_node_in_group("player")
	var node: Node = null
	if powers:
		node = powers.get_node_or_null("Abilities")
	for i in ids.size():
		var rank := GameState.skill_rank(ids[i])
		if rank <= 0:
			parts.append("%d %s" % [i + 1, "locked"])
			continue
		var left := 0.0
		if node and node.has_method("remaining"):
			left = node.remaining(ids[i])
		if left > 0.1:
			parts.append("%d %s %0.0f" % [i + 1, names[i], left])
		else:
			parts.append("%d %s" % [i + 1, names[i]])
	_ability_label.text = "   ".join(parts)


func _bar(parent: Node, color: Color) -> ColorRect:
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(280, 12)
	track.color = Color(1, 1, 1, 0.08)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 1.0
	fill.offset_right = 0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return fill


func draw_crosshair() -> void:
	var center := _crosshair.size * 0.5
	var color := Color(1, 1, 1, 0.9) if _hit < 0.2 else Color("ffd2a4")
	var arm := 11.0 if not _aiming else 7.0
	var gap := _spread
	var width := 1.5
	_crosshair.draw_line(center + Vector2(gap, 0), center + Vector2(gap + arm, 0), color, width)
	_crosshair.draw_line(center + Vector2(-gap, 0), center + Vector2(-gap - arm, 0), color, width)
	_crosshair.draw_line(center + Vector2(0, gap), center + Vector2(0, gap + arm), color, width)
	_crosshair.draw_line(center + Vector2(0, -gap), center + Vector2(0, -gap - arm), color, width)
	_crosshair.draw_circle(center, 1.4, color)
	if _hit > 0.0:
		var s := 10.0 + (1.0 - _hit) * 8.0
		var mark := Color(1, 0.85, 0.45, _hit)
		_crosshair.draw_line(center + Vector2(-s, -s), center + Vector2(-s + 5, -s), mark, 2.0)
		_crosshair.draw_line(center + Vector2(-s, -s), center + Vector2(-s, -s + 5), mark, 2.0)
		_crosshair.draw_line(center + Vector2(s, -s), center + Vector2(s - 5, -s), mark, 2.0)
		_crosshair.draw_line(center + Vector2(s, -s), center + Vector2(s, -s + 5), mark, 2.0)
		_crosshair.draw_line(center + Vector2(-s, s), center + Vector2(-s + 5, s), mark, 2.0)
		_crosshair.draw_line(center + Vector2(-s, s), center + Vector2(-s, s - 5), mark, 2.0)
		_crosshair.draw_line(center + Vector2(s, s), center + Vector2(s - 5, s), mark, 2.0)
		_crosshair.draw_line(center + Vector2(s, s), center + Vector2(s, s - 5), mark, 2.0)

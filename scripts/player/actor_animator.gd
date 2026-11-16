class_name ActorAnimator
extends Node
## Builds an AnimationTree over whatever clips the imported rig actually has.
## Humanoids get locomotion, jump, roll, pistol, melee. Creatures get a
## smaller graph. Missing clips are skipped instead of failing the scene.

var profile := "human"
var anim_player: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var _clips := {}
var _states := {}
var _locked := ""
var _lock_time := 0.0
var _was_grounded := true
var _grounded := true
var _vertical := 0.0
var _speed := 0.0
var _sprinting := false


func setup(model_root: Node, anim_profile: String) -> void:
	profile = anim_profile
	anim_player = _find_player(model_root)
	if anim_player == null:
		push_warning("ActorAnimator: no AnimationPlayer on %s" % model_root)
		return
	_clips = _resolve(anim_player.get_animation_list())
	_force_loops()
	_build_tree(model_root)


func notify_locomotion(horizontal_speed: float, sprinting: bool, grounded: bool, vertical_velocity: float) -> void:
	_speed = horizontal_speed
	_sprinting = sprinting
	_grounded = grounded
	_vertical = vertical_velocity
	if playback == null and anim_player:
		_fallback_locomotion(grounded)


func trigger(action: String) -> void:
	if _locked == "death":
		return
	if action != "death" and _locked in ["roll", "melee", "reload"]:
		return
	if playback == null:
		if anim_player and _clips.has(action):
			anim_player.play(_clips[action])
		return
	_play_lock(action, 0.0 if action != "death" else 10.0)


func _process(delta: float) -> void:
	if tree != null and playback == null:
		playback = tree.get("parameters/playback")
		if playback:
			playback.start("locomotion")
		return
	if playback == null or _locked == "death":
		return
	if _locked != "":
		_lock_time -= delta
		var finished := _lock_time <= 0.0
		if _current() == _locked and playback.get_current_play_position() >= _clip_length(_locked) - 0.05:
			finished = true
		if not finished:
			return
		var done := _locked
		_locked = ""
		if done == "jump_start" and not _grounded and _states.has("jump_loop"):
			playback.start("jump_loop")
		elif done != "death" and _states.has("locomotion"):
			playback.start("locomotion")
		_was_grounded = _grounded
		return
	if not _grounded:
		if _was_grounded and _states.has("jump_start"):
			_play_lock("jump_start", 0.0)
		elif _current() not in ["jump_loop", "jump_start"] and _states.has("jump_loop"):
			playback.start("jump_loop")
	else:
		if not _was_grounded and _states.has("jump_land"):
			_play_lock("jump_land", 0.02)
		else:
			if _current() != "locomotion":
				playback.start("locomotion")
			_apply_blend()
	_was_grounded = _grounded


func _apply_blend() -> void:
	var ratio := clampf(_speed / 6.6, 0.0, 1.0)
	if _sprinting and _speed > 4.0:
		ratio = 1.0
	elif _speed > 3.5:
		ratio = maxf(ratio, 0.7)
	tree.set("parameters/locomotion/blend_position", ratio)


func _play_lock(action: String, min_hold: float) -> void:
	if not _clips.has(action):
		return
	playback.start(action)
	_locked = action
	_lock_time = maxf(min_hold, _clip_length(action) * 0.92)


func _clip_length(action: String) -> float:
	var clip_name: String = _clips.get(action, "")
	if clip_name == "" or anim_player == null or not anim_player.has_animation(clip_name):
		return 0.4
	return anim_player.get_animation(clip_name).length


func _current() -> String:
	if playback == null:
		return ""
	return String(playback.get_current_node())


func _fallback_locomotion(grounded: bool) -> void:
	if anim_player == null:
		return
	var clip: String = _clips.get("idle", "")
	if grounded and _speed > 4.5 and _clips.has("sprint"):
		clip = _clips["sprint"]
	elif grounded and _speed > 0.4 and _clips.has("walk"):
		clip = _clips["walk"]
	elif _clips.has("idle"):
		clip = _clips["idle"]
	if clip != "" and anim_player.current_animation != clip:
		anim_player.play(clip)


func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.find_children("*", "AnimationPlayer", true, false):
		return child
	return null


func _resolve(list: PackedStringArray) -> Dictionary:
	var keys := {}
	if profile == "human":
		keys = {
			"idle": ["idle_loop", "idle"],
			"walk": ["walk_loop", "walk"],
			"jog": ["jog_fwd_loop", "jog"],
			"sprint": ["sprint_loop", "sprint"],
			"jump_start": ["jump_start"],
			"jump_loop": ["jump_loop"],
			"jump_land": ["jump_land"],
			"roll": ["roll"],
			"shoot": ["pistol_shoot"],
			"reload": ["pistol_reload"],
			"melee": ["punch_cross", "punch_jab"],
			"hit": ["hit_chest", "hit"],
			"death": ["death01", "death"],
			"aim": ["pistol_idle_loop", "pistol_idle"],
		}
	else:
		keys = {
			"idle": ["idle"],
			"walk": ["walk"],
			"jog": ["run", "walk"],
			"sprint": ["run"],
			"attack": ["attack"],
			"hit": ["hit"],
			"death": ["turnoff", "death"],
		}
	var resolved := {}
	for action in keys.keys():
		var clip := _pick(list, keys[action])
		if clip != "":
			resolved[action] = clip
	return resolved


func _pick(list: PackedStringArray, hints: Array) -> String:
	var best := ""
	var best_score := -100000
	for anim_name in list:
		var leaf := anim_name.to_lower().split("/")[-1]
		for i in hints.size():
			var hint: String = hints[i]
			var score := 0
			if leaf == hint:
				score = 4000
			elif leaf.begins_with(hint + "_") or leaf.ends_with("_" + hint):
				score = 1800
			elif hint in leaf and not leaf.begins_with("pistol_") and not leaf.begins_with("crouch"):
				score = 400
			else:
				continue
			score += (hints.size() - i) * 30
			score -= leaf.length()
			if score > best_score:
				best_score = score
				best = anim_name
	return best


func _force_loops() -> void:
	var looping := ["idle", "walk", "jog", "sprint", "jump_loop", "aim"]
	for key in looping:
		if not _clips.has(key):
			continue
		var anim := anim_player.get_animation(_clips[key])
		anim.loop_mode = Animation.LOOP_LINEAR
	for key in ["shoot", "reload", "melee", "hit", "death", "jump_start", "jump_land", "roll", "attack"]:
		if not _clips.has(key):
			continue
		var anim := anim_player.get_animation(_clips[key])
		anim.loop_mode = Animation.LOOP_NONE


func _build_tree(model_root: Node) -> void:
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model_root.add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	var machine := AnimationNodeStateMachine.new()
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 1.0
	_add_blend(blend, "idle", 0.0)
	_add_blend(blend, "walk", 0.32)
	_add_blend(blend, "jog", 0.68)
	_add_blend(blend, "sprint", 1.0)
	if blend.get_blend_point_count() == 0:
		tree.queue_free()
		tree = null
		return
	machine.add_node("locomotion", blend, Vector2(0, 0))
	_states["locomotion"] = true
	for action in _clips.keys():
		if action in ["idle", "walk", "jog", "sprint", "aim"]:
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = _clips[action]
		machine.add_node(action, node, Vector2(240, 60))
		_states[action] = true
	var end := AnimationNodeStateMachineTransition.new()
	end.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	end.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	end.xfade_time = 0.12
	for action in ["jump_land", "roll", "shoot", "reload", "melee", "hit", "attack"]:
		if _states.has(action):
			machine.add_transition(action, "locomotion", end.duplicate())
	tree.tree_root = machine
	tree.active = true
	playback = tree.get("parameters/playback")
	if playback:
		playback.start("locomotion")


func _add_blend(blend: AnimationNodeBlendSpace1D, key: String, position: float) -> void:
	if not _clips.has(key):
		return
	var node := AnimationNodeAnimation.new()
	node.animation = _clips[key]
	blend.add_blend_point(node, position, -1, key)

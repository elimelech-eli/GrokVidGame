extends Node
## Canonical input map. Keyboard plus an Xbox-style gamepad layout
## (Godot's standard joypad mapping). Rebuilt on boot so the map cannot
## drift from the README.

func _ready() -> void:
	_action("move_forward", [key(KEY_W), key(KEY_UP), joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_back", [key(KEY_S), key(KEY_DOWN), joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("move_left", [key(KEY_A), key(KEY_LEFT), joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [key(KEY_D), key(KEY_RIGHT), joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("look_left", [joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("look_right", [joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("look_up", [joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("look_down", [joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("jump", [key(KEY_SPACE), joy_button(JOY_BUTTON_A)])
	_action("sprint", [key(KEY_SHIFT), joy_button(JOY_BUTTON_LEFT_SHOULDER), joy_button(JOY_BUTTON_LEFT_STICK)])
	_action("dodge", [key(KEY_CTRL), key(KEY_Q), joy_button(JOY_BUTTON_B), joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("fire", [mouse(MOUSE_BUTTON_LEFT), joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("aim", [mouse(MOUSE_BUTTON_RIGHT), joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("reload", [key(KEY_R), joy_button(JOY_BUTTON_X)])
	_action("melee", [key(KEY_F), key(KEY_V), joy_button(JOY_BUTTON_Y)])
	_action("interact", [key(KEY_E), joy_button(JOY_BUTTON_DPAD_UP)])
	_action("pause", [key(KEY_ESCAPE), joy_button(JOY_BUTTON_START)])
	_action("ability_1", [key(KEY_1), joy_button(JOY_BUTTON_DPAD_LEFT)])
	_action("ability_2", [key(KEY_2), joy_button(JOY_BUTTON_DPAD_DOWN)])
	_action("ability_3", [key(KEY_3), joy_button(JOY_BUTTON_DPAD_RIGHT)])
	_action("ability_4", [key(KEY_4), joy_button(JOY_BUTTON_BACK)])
	_action("inventory", [key(KEY_I), key(KEY_TAB)])
	_action("skills", [key(KEY_K)])
	_action("quests", [key(KEY_J)])


func _action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.25)
	for event in events:
		InputMap.action_add_event(action, event)


func key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	return e


func mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

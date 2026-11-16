extends Control

func _draw() -> void:
	var hud := get_parent()
	if hud and hud.has_method("draw_crosshair"):
		hud.draw_crosshair()

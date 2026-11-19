extends Node
## Example mod: the weather stays clear; F9 sets the clock to noon.
var main

func mod_ready(m) -> void:
	main = m; main.weather.auto = false; main.weather.set_kind("clear")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F9:
		main.day_t = (12.0 - 6.0) / 24.0; main.toast("Մոդ՝ կեսօր")

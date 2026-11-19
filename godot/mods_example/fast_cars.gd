extends Node
## Example mod: more power for whatever you drive; F8 adds 10 000 ֏.
var main

func mod_ready(m) -> void:
	main = m

func _process(_dt: float) -> void:
	if main and main.pcar and main.pcar.max_speed < 600: main.pcar.max_speed = 600; main.pcar.acc = 2.4; main.pcar.grip = 1.5

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F8:
		main.missions.cash += 10000; main.missions.save(); main.toast("Մոդ՝ +10 000 ֏")

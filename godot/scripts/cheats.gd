extends Node
## Secret codes (letters that never clash with the game keys E, F, M, P, R): type the word anywhere in the city (no box to type in) and it works at once.
##   VOSKI    — 250 000 ֏ and your car mended like new
##   DILIJAN   — the police never come for you (type again to turn it off)
##   KAYTSAK    — two more stars
##   HANGIST  — the stars are gone
##   GAGAT    — all five stars at once
##   ZINANOTS — every gun with ammunition
##   HAVITYAN — guns never run out or reload (type again to turn it off)
##   ANVTANG  — full health and a full vest

const CODES := { "VOSKI": "_rich", "DILIJAN": "_sevan", "KAYTSAK": "_krak", "HANGIST": "_calm", "GAGAT": "_all_stars", "ZINANOTS": "_guns", "HAVITYAN": "_endless", "ANVTANG": "_health" }   # no E, M, P, R or F: those keys do other things
var m
var typed := ""
var no_wanted := false

func setup(main) -> void:
	m = main

## Each letter key; true when it finished a code.
func key(e: InputEventKey) -> bool:
	var ch := OS.get_keycode_string(e.keycode)
	if ch.length() != 1 or ch < "A" or ch > "Z": return false
	typed = (typed + ch).right(16)
	for code in CODES:
		if typed.ends_with(code):
			typed = ""; call(CODES[code]); return true
	return false

func _rich() -> void:
	m.missions.cash += 250000; m.missions.save()
	if m.pcar:   # a new body: no dents, whole glass, no smoke
		m.pcar.dmg = 0; m._rebuild_node(m.pcar)
	m.toast("Կոդ՝ +250 000 ֏ ու մեքենան նորոգված")

func _sevan() -> void:
	no_wanted = not no_wanted
	if no_wanted: m.heat = 0
	m.toast("Կոդ՝ ոստիկանները քեզ չեն տեսնում" if no_wanted else "Կոդ՝ ոստիկանները նորից աշխատում են")

func _krak() -> void:
	no_wanted = false; m.add_heat(2); m.toast("Կոդ՝ +2 աստղ")

func _calm() -> void:
	m.heat = 0; m.evade_t = 0; m.toast("Կոդ՝ աստղերը մարեցին")

func _all_stars() -> void:
	no_wanted = false; m.heat = 5; m.evade_t = 0; m.toast("Կոդ՝ 5 աստղ")

func tick() -> void:
	if no_wanted and m.heat > 0: m.heat = 0

func _guns() -> void:
	for id in m.weapons.ORDER: m.weapons.give(id, false)
	m.missions.save(); m.toast("Կոդ՝ բոլոր զենքերը")

func _endless() -> void:
	m.weapons.endless = not m.weapons.endless
	m.toast("Կոդ՝ անվերջ փամփուշտ" if m.weapons.endless else "Կոդ՝ փամփուշտը նորից հաշվվում է")

func _health() -> void:
	m.weapons.hp = 100.0; m.weapons.armor = 100.0; m.toast("Կոդ՝ առողջություն ու զրահ")

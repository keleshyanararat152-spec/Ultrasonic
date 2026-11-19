# Mods for Pink City

Put a `.gd` file in a folder called `mods` next to `PinkCity.exe` (or in the game's user folder,
`%APPDATA%\Godot\app_userdata\Վարդագույն քաղաք\mods` on Windows) and start the game. The mod's name shows at the top
of the screen when it loads, and it is listed in the settings menu (Esc).

A mod is a script that `extends Node` and has `func mod_ready(main)`; `main` is the game (`scripts/main.gd`):
`main.missions.cash` money, `main.cars` the cars, `main.pcar` your car, `main.me` you on foot, `main.weather`,
`main.weapons`, `main.city`, `main.toast(text)` for a message. It may use `_process`, `_unhandled_input` and so on.

- `fast_cars.gd` — every car of yours gets more power; F8 adds 10 000 ֏.
- `sunny.gd` — the weather stays clear, and F9 jumps the clock to noon.

extends Node
## Mods: GDScript files the player drops in a "mods" folder — next to the game's .exe, or in the game's user
## folder (user://mods) — are loaded at start. Each one is a script that extends Node; the game adds it to the
## scene and calls its mod_ready(main) with the main game script, so it can change anything: money, cars,
## weather, add buildings, keys, codes. See mods_example/ in the source for two small ones.

var m
var loaded: Array = []       # names of the mods that came in
var failed: Array = []

func setup(main) -> void:
	m = main
	var dirs := ["user://mods"]
	if not OS.has_feature("editor"): dirs.append(OS.get_executable_path().get_base_dir().path_join("mods"))
	DirAccess.make_dir_recursive_absolute("user://mods")
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			if f.get_extension() != "gd": continue
			var path: String = d.path_join(f)
			var sc := GDScript.new(); sc.source_code = FileAccess.get_file_as_string(path)
			if sc.reload() != OK: failed.append(f); continue
			var n = sc.new()
			if not (n is Node): failed.append(f); continue
			n.name = f.get_basename(); add_child(n)
			if n.has_method("mod_ready"): n.mod_ready(m)
			loaded.append(f.get_basename())
	if loaded.size(): m.toast("Մոդեր՝ " + ", ".join(loaded), 3)
	if failed.size(): push_warning("mods that did not load: " + ", ".join(failed))

extends SceneTree
## Dumps each level's route grid (8 px cells) for find_secret_spots.py.
## Run from EcoRescuer/:
##   <Godot> --headless --path . -s Tools/dev/dump_grid.gd -- <out dir> res://Resources/Levels/Forest.tres ...
## Writes <out>/dump_<name>.txt: first line "ox oy w h" (origin in px, size in
## cells), then one line of w*h characters: '#' solid, '.' open, 'B' trash bag,
## 'E' enemy, 'T' teleport, 'c' other item, 'P' start.
const CH := {"#": 35, ".": 46, "B": 66, "E": 69, "T": 84, "c": 99, "P": 80}

func _initialize():
	var args := OS.get_cmdline_user_args()
	create_timer(60.0).timeout.connect(func(): print("watchdog quit"); quit(1))
	await process_frame
	root.get_node("SilentWolf").free()  # nothing is posted online
	var G = root.get_node("Global")
	var LM = root.get_node("LevelManager")
	var pg = load("res://Resources/Characters/Labra.tres")
	G.selected_character = pg
	G.character_scene = pg.scene
	for path in args.slice(1):
		G.selected_level_data = load(path)
		G.selected_level = G.selected_level_data.level_scene
		G.load_game()
		for i in 20:
			await process_frame
		var rg = LM.route_guide
		var grid: AStarGrid2D = rg._grid
		var reg: Rect2i = grid.region
		var w := reg.size.x
		var data := PackedByteArray()
		data.resize(w * reg.size.y)
		data.fill(CH["."])
		for y in reg.size.y:
			for x in w:
				if grid.is_point_solid(Vector2i(reg.position.x + x, reg.position.y + y)):
					data[y * w + x] = CH["#"]
		var mark := func(p: Vector2, ch: String):
			var c: Vector2i = Vector2i((p / 8.0).floor()) - reg.position
			if Rect2i(Vector2i.ZERO, reg.size).has_point(c):
				data[c.y * w + c.x] = CH[ch]
		for node in current_scene.find_children("*", "", true, false):
			if node is TrashBag:
				mark.call(node.global_position, "B")
			elif node is Enemy:
				mark.call(node.global_position, "E")
			elif node is Collectible or node is LevelExit or node is Dossier:
				mark.call(node.global_position, "c")
		for t in rg.teleports():
			mark.call(t.entry, "T")
			mark.call(t.dest, "T")
		mark.call(current_scene.find_child("PlayerSpawn", true, false).global_position, "P")
		var f := FileAccess.open(args[0] + "/dump_" + path.get_file().get_basename() + ".txt", FileAccess.WRITE)
		f.store_line("%d %d %d %d" % [reg.position.x * 8, reg.position.y * 8, w, reg.size.y])
		f.store_buffer(data)
		f.close()
		print("DUMP ", path.get_file().get_basename(), " ", reg.size)
	quit()

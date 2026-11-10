extends SceneTree
## Loads each level given and lists the items and enemies the player can't
## walk to from the start. Run from EcoRescuer/:
##   <Godot> --headless --path . -s Tools/dev/check_reachable.gd -- res://Resources/Levels/Escape.tres
## (it removes SilentWolf first, so nothing is posted online)
func _initialize():
	await process_frame
	root.get_node("SilentWolf").free()
	var G = root.get_node("Global")
	var LM = root.get_node("LevelManager")
	var pg = load("res://Resources/Characters/Labra.tres")
	G.selected_character = pg
	G.character_scene = pg.scene
	for path in OS.get_cmdline_user_args():
		G.selected_level_data = load(path)
		G.selected_level = G.selected_level_data.level_scene
		G.load_game()
		for i in 30:
			await process_frame
		var rg = LM.route_guide
		var start: Vector2 = current_scene.find_child("PlayerSpawn", true, false).global_position
		var bad := []
		var n := 0
		for node in current_scene.find_children("*", "", true, false):
			if node is Collectible or node is Dossier or node is Enemy:
				n += 1
				if rg.route_cost(start, node.global_position) == INF:  # teleports count
					bad.append("%s %s" % [node.get_class() if node.get_script() == null else node.get_script().resource_path.get_file(), Vector2i(node.global_position / 16)])
		print("R ", G.selected_level_data.level_name, ": ", n, " checked, unreachable: ", bad)
	quit()

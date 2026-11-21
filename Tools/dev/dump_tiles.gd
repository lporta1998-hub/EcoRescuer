extends SceneTree
## Dumps the tiles and the gameplay nodes of hand-made level scenes, for
## Tools/dev/scene_to_map.py (which turns them into BuiltLevel text maps).
## Run from EcoRescuer/:
##   <Godot> --headless --path . -s Tools/dev/dump_tiles.gd -- <out dir> res://path/level.tscn ...
## (one-off, like scene_to_map.py: the hand-made scenes it read are gone)
## Writes <out>/tiles_<scene name>.json:
##   tiles: [x, y, w, h, texture, rx, ry, rw, rh, solid, z, layer]  (global rect of the tile, atlas region)
##   nodes: {kind, scene, name, x, y, ...}

func _initialize():
	var args := OS.get_cmdline_user_args()
	create_timer(120.0).timeout.connect(func(): print("watchdog quit"); quit(1))
	await process_frame
	root.get_node("SilentWolf").free()
	for path in args.slice(1):
		var scene: Node2D = load(path).instantiate()
		scene.set_script(null)  # no LevelManager setup, just the map as drawn
		root.add_child(scene)
		await process_frame
		var tiles := []
		var layers := []
		for layer: TileMapLayer in scene.find_children("*", "TileMapLayer", true, false):
			if layer.tile_set == null:
				continue
			var li := layers.size()
			layers.append({"name": str(scene.get_path_to(layer)), "visible": layer.is_visible_in_tree(),
					"collide": layer.collision_enabled, "z": layer.z_index, "alpha": layer.modulate.a * layer.self_modulate.a})
			var xf := layer.get_global_transform()
			var ts := layer.tile_set
			for cell in layer.get_used_cells():
				var sid := layer.get_cell_source_id(cell)
				var src := ts.get_source(sid) as TileSetAtlasSource
				if src == null or src.texture == null:
					continue
				var ac := layer.get_cell_atlas_coords(cell)
				var alt := layer.get_cell_alternative_tile(cell)
				var region := src.get_tile_texture_region(ac)
				var td := layer.get_cell_tile_data(cell)
				var solid := false
				if td and layer.collision_enabled:
					for p in ts.get_physics_layers_count():
						if td.get_collision_polygons_count(p) > 0:
							solid = true
				var c := xf * layer.map_to_local(cell)
				var size := Vector2(region.size) * xf.get_scale()
				var off := Vector2(td.texture_origin) * xf.get_scale() if td else Vector2.ZERO
				tiles.append([c.x - size.x / 2 - off.x, c.y - size.y / 2 - off.y, size.x, size.y,
						src.texture.resource_path, region.position.x, region.position.y, region.size.x, region.size.y,
						solid, td.z_index if td else 0, li, alt])
		var nodes := []
		for n in scene.find_children("*", "", true, false):
			if not n is Node2D:
				continue
			var d := {"name": str(n.name), "scene": n.scene_file_path, "x": n.global_position.x, "y": n.global_position.y,
					"cls": n.get_class(), "script": n.get_script().resource_path if n.get_script() else ""}
			if n.is_in_group("teleport") and n.get("destination_marker"):
				d["dest"] = [n.destination_marker.global_position.x, n.destination_marker.global_position.y]
			if n is StaticBody2D or n is Area2D:
				var shapes := []
				for s in n.get_children():
					if s is CollisionShape2D and s.shape is RectangleShape2D:
						var r: Vector2 = s.shape.size * s.global_transform.get_scale()
						shapes.append([s.global_position.x - r.x / 2, s.global_position.y - r.y / 2, r.x, r.y])
					elif s is CollisionPolygon2D:
						var pts := []
						for p in s.polygon:
							var g: Vector2 = s.global_transform * p
							pts.append([g.x, g.y])
						shapes.append(pts)
				d["shapes"] = shapes
			if n is Line2D:
				var pts := []
				for p in n.points:
					var g: Vector2 = n.global_transform * p
					pts.append([g.x, g.y])
				d["points"] = pts
			nodes.append(d)
		var f := FileAccess.open(args[0] + "/tiles_" + path.get_file().get_basename() + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"layers": layers, "tiles": tiles, "nodes": nodes}))
		f.close()
		print("TILES ", path.get_file(), " ", tiles.size(), " tiles, ", nodes.size(), " nodes")
		scene.queue_free()
		await process_frame
	quit()

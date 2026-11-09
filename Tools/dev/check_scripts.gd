extends SceneTree
## Compiles every project script with the autoloads loaded and prints the
## leaderboard ids and achievement progress. Read-only. Run from EcoRescuer/:
##   <Godot> --headless --path . -s Tools/dev/check_scripts.gd
## (silent_wolf/ has a few unused example scripts that never compiled: ignore them)
func _initialize():
	await process_frame
	var bad := 0
	for path in _scripts("res://"):
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate() and not path.contains("silent_wolf")):
			print("FAILED: ", path)
			bad += 1
	print("scripts failing: ", bad)
	var Story = root.get_node("Story")
	var Progress = root.get_node("Progress")
	print("boards: ", Story.campaign_levels().map(func(l): return Story.leaderboard_id(l)))
	print("main chapters: ", Story.main_chapters().size(), " all: ", Story.chapters().size())
	var Ach = load("res://Misc/Progress/achievements.gd")
	for a in Ach.LIST:
		print("  ", a.id, " ", Ach.value_of(a), "/", Ach.target_of(a), " unlocked=", Progress.has_achievement(a.id))
	quit()

func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out += _scripts(dir.path_join(d))
	return out

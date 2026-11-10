extends SceneTree
## Plays a level's secret from start to end. Run from EcoRescuer/, one level
## per run (loading several in one process hangs):
##   <Godot> --headless --path . -s Tools/dev/check_secrets.gd -- res://Resources/Levels/Forest.tres
## Prints "S <level>: OK ..." or what's wrong. It checks that:
##  - the portal stands on open floor, every trash bag is reachable, the
##    portal is unreachable while the crates stand, and it stays closed
##    until its seals (crates or vases) break, then opens;
##  - the portal takes the player into the vault, the vault has guards and a
##    chest that stays locked until they're down, then pays the reward once;
##  - the way back puts the player next to the portal again.
## It CHANGES THE LOCAL SAVE (the reward is recorded): back it up first.
## (it removes SilentWolf first, so nothing is posted online)

func _initialize():
	var path: String = OS.get_cmdline_user_args()[0]
	create_timer(60.0).timeout.connect(func(): print("S watchdog"); quit(1))
	await process_frame
	root.get_node("SilentWolf").free()
	var G = root.get_node("Global")
	var LM = root.get_node("LevelManager")
	var P = root.get_node("Progress")
	var pg = load("res://Resources/Characters/Labra.tres")
	G.selected_character = pg
	G.character_scene = pg.scene
	G.selected_level_data = load(path)
	G.selected_level = G.selected_level_data.level_scene
	G.load_game()
	for i in 20:
		await process_frame
	paused = false
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("story_card.gd"):
			n.queue_free()
	var lvl: Node = current_scene
	var rg = LM.route_guide
	var ld: LevelData = G.selected_level_data
	var name: String = ld.level_name
	var problems := []
	var start: Vector2 = lvl.find_child("PlayerSpawn", true, false).global_position
	var portal = lvl.find_child("SecretPortal", true, false)
	var crates: Array = lvl.find_children("*", "BreakableCrate", true, false)
	var vault = lvl.find_child("SecretVault", true, false)
	if portal == null or vault == null:
		print("S %s: portal %s, vault %s" % [name, portal, vault])
		quit(1)
		return
	if not rg.is_open(portal.global_position):
		problems.append("portal not on open floor at %s" % portal.global_position)
	for bag in lvl.find_children("*", "TrashBag", true, false):
		if rg.route_cost(start, bag.global_position) == INF:
			problems.append("trash bag unreachable at %s" % bag.global_position)
	if not crates.is_empty() and rg.route_cost(start, portal.global_position) != INF:
		problems.append("portal reachable without breaking the crates")
	if portal.visible or portal.monitoring:
		problems.append("portal open before its seals are broken")
	# the seals: the crates, or the nodes named in the spot (Snow Path's vases)
	var seals: Array = crates.duplicate()
	for seal_name in load("res://Misc/Secrets/secret_spots.gd").SPOTS.get(lvl.scene_file_path, {}).get("seals", []):
		seals.append(lvl.get_node(seal_name))
	for c in seals:
		if is_instance_valid(c):
			c.take_damage(99)
	await create_timer(1.5).timeout
	if rg.route_cost(start, portal.global_position) == INF:
		problems.append("portal unreachable")
	if not portal.visible or not portal.monitoring:
		problems.append("portal still closed after breaking its seals")
	# into the vault
	var hero = lvl.find_children("*", "CharacterBody2D", true, false).filter(func(n): return n.is_in_group("player"))[0]
	hero.health = 999  # the guards may hit during the test
	hero.global_position = portal.global_position
	await create_timer(1.6).timeout
	if not vault.world_rect().has_point(hero.global_position):
		problems.append("portal didn't move the hero into the vault (%s)" % hero.global_position)
	if not rg.is_open(vault.entry_global()):
		problems.append("vault entry not on open floor")
	var guards: int = vault.guards_left()
	if guards < 2:
		problems.append("only %d guards" % guards)
	# locked chest
	var had: bool = P.quest_done(ld, "secret")
	vault.chest._on_touch(hero)
	if P.quest_done(ld, "secret") != had:
		problems.append("chest opened with guards standing")
	for e in vault.find_children("*", "Enemy", true, false):
		e.take_damage(999, hero)
	await create_timer(1.5).timeout
	if vault.guards_left() != 0:
		problems.append("%d guards still standing" % vault.guards_left())
	var coins0: int = P.coins
	var perks0: Dictionary = P.rage_perks.duplicate()
	var disc0: Dictionary = P.discounts.duplicate()
	vault.chest._on_touch(hero)
	await process_frame
	var reward: Dictionary = root.get_node("Story").chapter_of(ld).secret.reward
	if not P.quest_done(ld, "secret"):
		problems.append("secret not recorded")
	var got := ""
	if reward.type == "perk":
		got = "perk %s %d->%d" % [reward.id, perks0.get(reward.id, 0), P.rage_perks.get(reward.id, 0)]
	else:
		got = "discount %s %d%%->%d%% (price %d)" % [reward.id, disc0.get(reward.id, 0), P.discount(reward.id), P.next_price(reward.id)]
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("story_card.gd"):
			n.queue_free()
	paused = false
	# back out
	hero.global_position = vault.exit_portal.global_position
	await create_timer(1.6).timeout
	if hero.global_position.distance_to(portal.global_position) > 80.0:
		problems.append("exit didn't bring the hero back (%s)" % hero.global_position)
	print("S %s: %s  | %d crates, %d guards, %s" % [name, "OK" if problems.is_empty() else "; ".join(problems), crates.size(), guards, got])
	quit()

class_name SecretSpots
extends RefCounted
## Every campaign level hides a secret: a corner of the map closed by
## BreakableCrate across a narrow passage (Snow Path: the two vases). Breaking
## them opens a SecretPortal there, to the level's SecretVault: a room
## outside the map where guards protect a VaultChest
## with a reward (`secret.reward` in Story.CHAPTERS, paid once, see claim()):
##  - "perk": a level of a permanent Rage mode perk (Rage.PERKS);
##  - "discount": a permanent discount on a Shop buff (Progress.discount).
## Nothing the objective needs is ever behind the crates or in the vault.
##
## Built levels (text maps) carve their secret pocket in the map itself (map
## letters V crates and Y portal, Tools/dev/carve_secret_rooms.py). The
## hand-made levels are listed in SPOTS: pockets found with
## Tools/dev/find_secret_spots.py (cut off by a few crates, holding no trash
## bag, enemy or teleport). Tools/dev/check_secrets.gd checks them all.
## `crates`: centres of 16 px cells to fill. `portal`: where the portal goes.
## `seals`: other breakable nodes that keep the portal closed.

## Gap between the map's right edge and its vault.
const VAULT_GAP := 400.0

const SPOTS := {
	# the island in the lake, across the wooden bridge
	"res://Levels/Forest_level/Assets/Scenes/forest.tscn": {
		"crates": [Vector2(856, 400), Vector2(856, 416), Vector2(856, 432)],
		"portal": Vector2(580, 420)},
	# the end of the trail behind the two vases, at the mouth of the cave
	"res://Levels/SnowPathLevel/Assets/Scenes/snow_path.tscn": {
		"crates": [], "portal": Vector2(-160, 806), "seals": ["DestructibleObj", "DestructibleObj2"]},
	# inside the monument in the middle of the roundabout
	"res://Levels/City_level/Assets/Scenes/city.tscn": {
		"crates": [Vector2(2344, 3176), Vector2(2360, 3176), Vector2(2376, 3176)],
		"portal": Vector2(2332, 3252)},
	# the far end of the old wooden pier
	"res://Levels/BeachLevel/Assets/Scenes/beach_level.tscn": {
		"crates": [Vector2(1320, 40), Vector2(1320, 56)],
		"portal": Vector2(972, 52)},
	# a dead-end corridor past the server racks
	"res://Levels/Ai DataCenter_level/Assets/Scenes/Ai DataCenter.tscn": {
		"crates": [Vector2(1144, 936), Vector2(1144, 952), Vector2(1144, 968)],
		"portal": Vector2(1452, 964)},
}

## Tiles of each level's vault (BuiltLevel themes).
const VAULT_THEMES := {
	"res://Resources/Levels/Forest.tres": "ruins", "res://Resources/Levels/SnowPath.tres": "ruins",
	"res://Resources/Levels/City.tres": "factory", "res://Resources/Levels/BeachLevel.tres": "harbor",
	"res://Resources/Levels/Ruins.tres": "ruins", "res://Resources/Levels/Factory.tres": "factory",
	"res://Resources/Levels/Harbor.tres": "harbor", "res://Resources/Levels/AiDataCenter.tres": "factory",
	"res://Resources/Levels/Fortress.tres": "fortress", "res://Resources/Levels/Escape.tres": "harbor",
}


## Adds the crates and the portal of the hand-made levels, then builds the
## vault of any level that has a portal (before the route grid is built, so
## the crates count as walls and the vault's floor is part of the grid).
static func apply(level: Node2D) -> void:
	var spot: Dictionary = SPOTS.get(level.scene_file_path, {})
	if not spot.is_empty():
		for c: Vector2 in spot.get("crates", []):
			var crate := BreakableCrate.new()
			crate.position = level.to_local(c)
			level.add_child(crate)
			crate.owner = level
		var p := SecretPortal.new()
		p.name = "SecretPortal"
		p.position = level.to_local(spot.portal)
		level.add_child(p)
		p.owner = level
	_add_vault(level)
	seal_portal(level)


static func _add_vault(level: Node2D) -> void:
	var entrance := level.find_child("SecretPortal", true, false) as SecretPortal
	var ld: LevelData = Global.selected_level_data
	if entrance == null or ld == null:
		return
	var i := maxi(0, Story.chapter_index(ld))
	var vault := SecretVault.make(VAULT_THEMES.get(ld.resource_path, "ruins"), 2 + i / 2, 1 if i < 5 else 2)
	var edge := _map_rect(level)
	vault.position = level.to_local(Vector2(snappedf(edge.end.x + VAULT_GAP, 16.0), snappedf(edge.position.y + 64.0, 16.0)))
	level.add_child(vault)
	vault.owner = level
	entrance.vault = vault
	vault.exit_portal.vault = vault
	vault.exit_portal.entrance = entrance
	vault.exit_portal.back_to = entrance.global_position


## The level's map in world coordinates (all its tile layers).
static func _map_rect(level: Node2D) -> Rect2:
	if level is BuiltLevel:
		return Rect2(level.global_position + level.bounds.position, level.bounds.size)
	var out := Rect2()
	var first := true
	for layer: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO or layer.tile_set == null:
			continue
		var a := layer.to_global(layer.map_to_local(used.position))
		var b := layer.to_global(layer.map_to_local(used.end))
		var r := Rect2(a, Vector2.ZERO).expand(b)
		out = r if first else out.merge(r)
		first = false
	return out


## The vault's chest was opened: pays the level's reward the first time and
## returns the lines to show.
static func claim(level: LevelData) -> Array:
	if level == null:
		return []
	var reward: Dictionary = Story.chapter_of(level).get("secret", {}).get("reward", {})
	if not Progress.record_quest(level, "secret"):
		return ["Hai già preso il tesoro di questo caveau."]
	var lines := [reward_text(reward)]
	match reward.get("type", ""):
		"perk":
			if int(Progress.rage_perks.get(reward.id, 0)) < Rage.PERK_MAX:
				Progress.add_rage_perk(reward.id)
			else:
				Progress.add_coins(300)
				lines = ["%s è già al massimo: +300 monete." % Rage.PERKS[reward.id].title]
		"discount":
			Progress.add_discount(reward.id, int(reward.pct))
	Progress.save_progress()
	lines.append("Segreti trovati: %d/%d (Codex, scheda Segreti)." % [Progress.secrets_found(), Story.chapters().size()])
	return lines


## "Rage mode: Fortuna +1 livello, per sempre." / "Negozio: -30% su Scudo, per sempre."
static func reward_text(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"perk":
			return "Rage mode: %s +1 livello, per sempre." % Rage.PERKS[reward.id].title
		"discount":
			return "Negozio: -%d%% su %s, per sempre." % [int(reward.pct), Progress.BUFFS[reward.id].title]
	return ""


## The portal stays closed (hidden, inert) until every seal of the secret is
## broken: the BreakableCrate of the level (not the vault's), or the nodes
## named in the spot's `seals` (Snow Path's two vases). Then it opens.
static func seal_portal(level: Node2D) -> void:
	var portal := level.find_child("SecretPortal", true, false) as SecretPortal
	if portal == null:
		return
	var seals: Array = []
	for name: String in SPOTS.get(level.scene_file_path, {}).get("seals", []):
		var n := level.get_node_or_null(name)
		if n and n.has_signal("broken"):
			seals.append(n)
	for c in level.find_children("*", "BreakableCrate", true, false):
		if not c.get_parent() is SecretVault:
			seals.append(c)
	if seals.is_empty():
		return
	portal.close()
	var left := {"n": seals.size()}
	for seal: Node in seals:
		seal.broken.connect(func(_who = null):
			left.n -= 1
			if left.n == 0 and is_instance_valid(portal):
				portal.open_up())

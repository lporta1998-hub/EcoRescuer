class_name SecretVault
extends BuiltLevel
## The hidden vault of a level: a closed room built next to the map (outside
## its edges), reached only through the SecretPortal hidden in the level's
## secret area. Guards wait inside; the VaultChest opens when they're all
## down and holds the level's reward (see SecretSpots.claim).
##
## Map letters on top of BuiltLevel's: 1-8 guard slots (filled with E or L
## by guard count), I where you arrive, Q the portal back, J the chest.

const ROOM := [
	"######################",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,x,,,,,,,,,,,,,,,,x,#",
	"#,,,,,,,,,J,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,1,,,,,7,,,8,,,,2,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,3,,,,,,4,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,5,,,,,,,,,,,,,,6,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,T,,,,,,,,,,,,,,,,T,#",
	"#,,,,,,,,,IQ,,,,,,,,,#",
	"######################",
]

## Where the player arrives (global), filled by build().
var entry := Vector2.ZERO
var chest: VaultChest
var exit_portal: SecretPortal


## A vault with the tiles of `theme_name`, `basics` Inquinatori and `elites`
## Elite guards (at most 8 in all).
static func make(theme_name: String, basics: int, elites: int) -> SecretVault:
	var v := SecretVault.new()
	v.name = "SecretVault"
	v.sub_area = true
	v.theme = theme_name
	var slots := []
	for i in 8:
		slots.append("L" if i < elites else ("E" if i < elites + basics else ","))
	var rows := []
	for row: String in ROOM:
		for i in 8:
			row = row.replace(str(i + 1), slots[i])
		rows.append(row)
	v.map_text = "\n".join(rows)
	return v


func build() -> void:
	super()
	for y in map.size():
		for x in map[y].length():
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match map[y][x]:
				"I":
					entry = pos  # local for now, see entry_global()
				"Q":
					exit_portal = SecretPortal.new()
					exit_portal.name = "VaultExit"
					exit_portal.position = pos
					add_child(exit_portal)
					exit_portal.owner = self
				"J":
					chest = VaultChest.new()
					chest.vault = self
					chest.position = pos
					add_child(chest)
					chest.owner = self


func entry_global() -> Vector2:
	return to_global(entry)


## The room in world coordinates (for the camera limits).
func world_rect() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)


## Guards still standing.
func guards_left() -> int:
	var n := 0
	for e in find_children("*", "Enemy", true, false):
		if not e.is_dead:
			n += 1
	return n

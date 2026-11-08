class_name HeroShot
## Helpers shared by the melee heroes' ranged moves (can, zap, shockwave,
## laser): which nodes they can hurt and how close a hit has to be.

## Projectiles fly at the hero's chest; enemies have their origin a bit lower.
const HIT_OFFSET := Vector2(0, 8)


## Enemies (ground and flying) and bosses that a hero's move can hurt.
## With `include_flying` false, nodes in group "flying" are left out.
static func targets(tree: SceneTree, include_flying := true) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var seen := {}
	var scene := tree.current_scene
	if scene:
		for n in scene.find_children("*", "CharacterBody2D", true, false):
			_consider(n, out, seen, include_flying)
	for group in ["enemies", "flying", "boss"]:
		for n in tree.get_nodes_in_group(group):
			_consider(n, out, seen, include_flying)
	return out


static func _consider(n: Node, out: Array[Node2D], seen: Dictionary, include_flying: bool) -> void:
	if seen.has(n) or not n is Node2D or not n.has_method("take_damage"):
		return
	seen[n] = true
	if n.is_in_group("player") or n.get("is_dead") == true:
		return
	if not include_flying and n.is_in_group("flying"):
		return
	if n is Enemy or n is Boss or n.is_in_group("enemies") or n.is_in_group("flying"):
		out.append(n)


## How close (in pixels) a projectile has to get to `n` to hit it.
static func reach(n: Node) -> float:
	if n is Boss:
		return 30.0
	if n.is_in_group("flying"):
		return 16.0
	return 12.0


static func is_touching(n: Node2D, point: Vector2, extra := 0.0) -> bool:
	return n.global_position.distance_to(point + HIT_OFFSET) <= reach(n) + extra


## Damage goes through take_damage with the hero as attacker, so the shop's
## "Colpo potente" and the Eco Rush apply like on a melee hit.
static func hit(n: Node, dmg: int, by: Node) -> void:
	if is_instance_valid(n) and n.get("is_dead") != true:
		n.take_damage(dmg, by if is_instance_valid(by) else null)

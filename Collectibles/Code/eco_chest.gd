## eco_chest.gd
## Eco chest: walk into it with at least `cost` green coins (picked up in this
## level) to open it. The coins are spent and the chest gives one reward:
##   Cura        +1 max heart and full health
##   Eco Rush    LevelManager.ECO_RUSH_SECONDS of extra speed and +1 damage
##   Tesoro      TREASURE_COINS Shop coins, paid at the end of the level
##   Scudo extra blocks the next hit
## Place eco_chest.tscn in a level and set `cost` in the Inspector.
extends Area2D
class_name EcoChest

const CLOSED := preload("res://Collectibles/Assets/Sprites/eco_chest.png")
const OPEN := preload("res://Collectibles/Assets/Sprites/eco_chest_open.png")
const COIN := preload("res://Collectibles/Assets/Sprites/coin.png")
const TREASURE_COINS := 100
const REWARDS := [
	{"id": "heal", "weight": 30},
	{"id": "rush", "weight": 30},
	{"id": "treasure", "weight": 25},
	{"id": "shield", "weight": 15},
]

## Green coins needed to open it.
@export var cost := 5

var opened := false
var _t := 0.0
var _hint_cooldown := 0.0
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("eco_chest")
	collision_layer = 0
	collision_mask = 1  # the player's physics layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_hint_cooldown -= delta
	if not opened:
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if opened or not body.is_in_group("player"):
		return
	if not LevelManager.spend_run_coins(cost):
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 1.5
			var missing := cost - LevelManager.run_coins
			_toast("Ti servono ancora %d %s per aprire il forziere" % [missing, "moneta" if missing == 1 else "monete"],
					Color(1.0, 0.6, 0.45))
			var tw := create_tween()
			for r in [0.12, -0.12, 0.06, 0.0]:
				tw.tween_property(_sprite, "rotation", r, 0.05)
		return
	_open(body)


func _open(player: Node2D) -> void:
	opened = true
	LevelManager.on_chest_opened()
	queue_redraw()
	SFXManager.play_sfx(preload("res://Audio/SFX/Objects/Collection.wav"), -6)
	_sprite.texture = OPEN
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.1)
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.18)
	FloatText.spawn(self, "-%d" % cost, Color(1.0, 0.83, 0.3), Vector2(0, -24))
	var reward := _pick_reward()
	var text := ""
	match reward:
		"heal":
			if "max_health" in player:
				player.max_health += 1
				var hearts = player.get("heartsContainer")
				if hearts:
					hearts.setMaxHP(1)
				if player.has_method("heal"):
					player.heal(int(player.max_health))
			text = "Cura: +1 cuore e salute piena!"
		"rush":
			LevelManager.start_eco_rush(player)
			text = "Eco Rush: più veloce e più forte per %d secondi!" % int(LevelManager.ECO_RUSH_SECONDS)
		"treasure":
			LevelManager.chest_bonus_coins += TREASURE_COINS
			text = "Tesoro: +%d monete per il negozio!" % TREASURE_COINS
		"shield":
			LevelManager.shield_charges += 1
			text = "Scudo extra: il prossimo colpo è bloccato!"
	FloatText.spawn(self, text.get_slice(":", 0) + "!", Color(0.65, 0.95, 0.3), Vector2(0, -40))
	_toast(text, Color(0.65, 0.95, 0.3))


func _pick_reward() -> String:
	var total := 0
	for r in REWARDS:
		total += r.weight
	var roll := randi() % total
	for r in REWARDS:
		roll -= r.weight
		if roll < 0:
			return r.id
	return REWARDS[0].id


func _toast(text: String, color: Color) -> void:
	if LevelManager.objective_hud and is_instance_valid(LevelManager.objective_hud):
		LevelManager.objective_hud.toast(text, color)


## Price tag above the closed chest: coin + cost (gold when affordable).
func _draw() -> void:
	if opened:
		return
	var font := ThemeDB.fallback_font
	var fs := 11
	var text := str(cost)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bob := sin(_t * 3.0) * 1.5
	var total := 10.0 + 3.0 + w
	var x := -total / 2.0
	var y := -26.0 + bob
	draw_rect(Rect2(x - 3, y - 9, total + 6, 13), Color(0, 0, 0, 0.55))
	draw_texture_rect(COIN, Rect2(x, y - 8, 9, 11), false)
	var can := LevelManager.run_coins >= cost
	var col := Color(1.0, 0.83, 0.3) if can else Color(1, 1, 1, 0.9)
	draw_string(font, Vector2(x + 13, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

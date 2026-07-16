class_name AttackData extends Resource

var attacker
@export var damage := 10.0
@export var knockback := 50.0
@export var optional_flags = {}

func _to_string() -> String:
  return "Attacker: %s | Damage : %s | Knockback: %s | Flags: %s" % [attacker, damage, knockback, optional_flags]

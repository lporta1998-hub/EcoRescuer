class_name Weapon extends Node2D

@export var attack_zone : Area2D
@export var duration := .1
@export var cooldown := 1.0
@export var attack_data : AttackData

var can_attack := true

func _ready() -> void:
  attack_zone.body_entered.connect(on_hit)
  attack_data.attacker = self

func _process(delta: float) -> void:
  modulate = Color.WHITE if attack_zone.monitoring else Color.DARK_GRAY
  # Mouse cursor on desktop, auto-aim on touch screens.
  look_at(TouchControls.get_aim_position(self))

func start_attack():
  if can_attack:
      create_attack()
      can_attack = false
      get_tree().create_timer(cooldown).timeout.connect(on_cooldown_end)

func create_attack():
  attack_zone.monitorable = true
  attack_zone.monitoring = true
  await get_tree().create_timer(duration).timeout
  attack_zone.monitorable = false
  attack_zone.monitoring = false

func on_cooldown_end():
  can_attack = true

func on_hit(body: CharacterBody2D):
  if body is Character:
    body.on_hurt(attack_data)

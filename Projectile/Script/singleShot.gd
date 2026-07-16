extends Armi

class_name SingleShot
 
# Mantieni il vecchio activate per compatibilità
func activate(source, target, scene_tree):
    if target and is_instance_valid(target):
        var direction = (target.position - source.position).normalized()
        shoot(source, direction, scene_tree)

# Nuovo metodo che accetta direttamente la direzione
func activate_with_direction(source, direction: Vector2, scene_tree):
    shoot(source, direction, scene_tree)

func shoot(source, direction, scene_tree):
    var projectile = projectile_node.instantiate()
    projectile.position = source.position
    projectile.damage = damage
    projectile.speed = speed
    projectile.direction = direction
    projectile.shooter = source
    scene_tree.current_scene.add_child(projectile)
    # Opzionale: offset per evitare collisioni immediate
    projectile.position += direction * 10
    projectile.lifetime = range

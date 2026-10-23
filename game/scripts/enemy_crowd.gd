class_name EnemyCrowd
extends RefCounted
## Gerenciamento de multidão e espaçamento tático entre inimigos.
## Evita sobreposição física (clipping), dispersa inimigos em combate e evita que ocupem o mesmo espaço.

const DEFAULT_RADIUS := 0.55
const SEPARATION_SPEED := 3.5

## Retorna o raio de espaço pessoal de cada tipo de inimigo para evitar sobreposição
static func get_radius(e: Node3D) -> float:
	if not is_instance_valid(e):
		return DEFAULT_RADIUS
	if e is Soldier or e is Sniper:
		return 0.55
	elif e is Raptor:
		return 0.95
	elif e is Allosaurus:
		return 2.4
	elif e.has_method("get_separation_radius"):
		return float(e.get_separation_radius())
	return DEFAULT_RADIUS


## Força de repulsão suave contra outros inimigos próximos (camada horizontal)
static func compute_separation(enemy: Enemy) -> Vector3:
	if not is_instance_valid(enemy) or enemy.dead or enemy.get("_stealth_locked"):
		return Vector3.ZERO
	var tree := enemy.get_tree()
	if tree == null:
		return Vector3.ZERO
	var sep := Vector3.ZERO
	var my_pos := enemy.global_position
	var my_r := get_radius(enemy)
	for n in tree.get_nodes_in_group("enemies"):
		var other := n as Enemy
		if other == null or other == enemy or not is_instance_valid(other) or other.dead:
			continue
		var other_pos := other.global_position
		# Ignora inimigos em andares/alturas muito diferentes (ex: sniper na passarela vs soldado no chão)
		if absf(other_pos.y - my_pos.y) > 1.2:
			continue
		var to_self := Vector3(my_pos.x - other_pos.x, 0.0, my_pos.z - other_pos.z)
		var d := to_self.length()
		var min_d := my_r + get_radius(other)
		if d < min_d:
			if d < 0.001:
				var hash_code := (enemy.get_instance_id() ^ other.get_instance_id()) & 7
				var angle := float(hash_code) * (TAU / 8.0)
				to_self = Vector3(cos(angle), 0.0, sin(angle)) * 0.01
				d = 0.01
			var overlap := min_d - d
			var factor := overlap / min_d
			sep += (to_self / d) * factor
	return sep


## Aplica empurrão suave de separação à velocidade antes de move_and_slide
static func apply_separation(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.dead or enemy.get("_stealth_locked") or enemy.state == "down":
		return
	var push := compute_separation(enemy)
	if push.length_squared() > 0.0001:
		enemy.velocity.x += push.x * SEPARATION_SPEED
		enemy.velocity.z += push.z * SEPARATION_SPEED


## Verifica se há outro companheiro vivo na direção de deslocamento pretendida
static func is_enemy_in_path(enemy: Enemy, dir: Vector3, dist := 1.4) -> bool:
	if not is_instance_valid(enemy) or dir.length_squared() < 0.001:
		return false
	var tree := enemy.get_tree()
	if tree == null:
		return false
	var my_pos := enemy.global_position
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	for n in tree.get_nodes_in_group("enemies"):
		var other := n as Enemy
		if other == null or other == enemy or not is_instance_valid(other) or other.dead:
			continue
		var other_pos := other.global_position
		if absf(other_pos.y - my_pos.y) > 1.2:
			continue
		var to_other := Vector3(other_pos.x - my_pos.x, 0.0, other_pos.z - my_pos.z)
		var d := to_other.length()
		var min_d := get_radius(enemy) + get_radius(other)
		if d < maxf(dist, min_d):
			# Se o outro está quase na mesma posição ou à frente no cone do movimento
			if d < min_d * 0.8 or flat_dir.dot(to_other / maxf(d, 0.001)) > 0.45:
				return true
	return false


## Calcula direção de strafe para abrir formação (flanqueamento) e não se aglomerar com outros soldados
static func get_flank_strafe(soldier: Soldier, target_pos: Vector3, default_strafe: float) -> float:
	var tree := soldier.get_tree()
	if tree == null:
		return default_strafe
	var my_pos := soldier.global_position
	var to_target := Vector3(target_pos.x - my_pos.x, 0.0, target_pos.z - my_pos.z)
	if to_target.length_squared() < 0.01:
		return default_strafe
	var my_angle := atan2(to_target.x, to_target.z)
	
	# Procura o soldado parceiro mais próximo que também mira no mesmo alvo
	var closest_partner: Soldier = null
	var min_partner_dist := 999.0
	for n in tree.get_nodes_in_group("enemies"):
		var s := n as Soldier
		if s == null or s == soldier or not is_instance_valid(s) or s.dead or not s.in_combat():
			continue
		var p_pos := s.global_position
		if absf(p_pos.y - my_pos.y) > 1.2:
			continue
		var d := (p_pos - my_pos).length()
		if d < min_partner_dist:
			min_partner_dist = d
			closest_partner = s
	
	if closest_partner != null and min_partner_dist < 4.5:
		var p_pos := closest_partner.global_position
		var p_to_target := Vector3(target_pos.x - p_pos.x, 0.0, target_pos.z - p_pos.z)
		var p_angle := atan2(p_to_target.x, p_to_target.z)
		var diff := angle_difference(my_angle, p_angle)
		# Se estão no mesmo arco angular (menos de 35 graus de diferença)
		if absf(diff) < deg_to_rad(35.0):
			# Se estou à esquerda do parceiro relativo ao alvo, strafo para a esquerda; senão para a direita
			return 1.0 if diff > 0.0 else -1.0
	return default_strafe


## Distribui pontos de destino para múltiplos inimigos investigando ou caçando no mesmo local
static func disperse_goal(enemy: Enemy, at: Vector3) -> Vector3:
	var tree := enemy.get_tree()
	if tree == null:
		return at
	var crowd := 0
	for n in tree.get_nodes_in_group("enemies"):
		var other := n as Enemy
		if other != null and other != enemy and not other.dead and is_instance_valid(other):
			if other.get("_goal").distance_to(at) < 2.0:
				crowd += 1
	if crowd == 0:
		return at
	# Há outros companheiros indo para o mesmo ponto: distribui posições em volta
	var angle := float(enemy.get_instance_id() % 6) * (TAU / 6.0)
	var offset := Vector3(cos(angle), 0, sin(angle)) * 1.4
	var candidate := at + offset
	if enemy.global_position.y < 1.2 and at.y > 1.8 and candidate.z >= Catwalk.FRONT_Z - 1.0:
		candidate.z = minf(candidate.z, Catwalk.FRONT_Z - 5.0)
	return candidate

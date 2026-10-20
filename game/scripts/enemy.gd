class_name Enemy
extends CharacterBody3D
## Base dos inimigos (raptor, soldado): patrulha uma rota (`route`) e percebe a presa pela visão (cone à frente,
## alcance e linha de visão; quem se agacha, anda devagar ou fica no capim é visto de menos longe) e pelo barulho
## (`hear_noise`). Primeiro desconfia (para e olha, "?"), depois investiga o ponto do barulho; ao ver a presa dá o
## alarme (`spot` -> `on_alarm` em todo o grupo "enemies": os outros vêm caçar o lugar, "!") e reage à sua maneira
## (`_on_spotted`). Perdida de vista, caça o último lugar onde ela estava e depois procura por perto antes de voltar à
## patrulha. Quem herda: `in_combat()` (estados de luta), `_play()` (animações), `_anim_speed()`, `_on_spotted()`,
## `take_hit()` e `wound()` (ferido, deixa rastro de sangue: Blood.Trail), e chama `_enemy_ready()`, `_tick()` e
## `_calm_state()` no seu `_physics_process`. Tiro na cabeça: `take_headshot` (o dano já vem vezes `head_mult`).

const GRAVITY := 18.0
# percepção e patrulha
const SIGHT_RANGE := 14.0
const CLOSE_SIGHT := 2.5  # até aqui vê em volta toda, não só o cone
const ALERT_SIGHT := 22.0  # alcance de quem já foi alertado (vezes a visibilidade dela: agachada ou no capim ainda se esconde)
const ALERT_FOV_BONUS := deg_to_rad(35.0)  # alertado olha mais para os lados, mas não vê nas costas (dá para escapar por trás)
const COMBAT_SENSE := 5.0  # em combate, até aqui sabe onde ela está mesmo agachada (com nada no meio)
const SUSPECT_AT := 0.3  # atenção a partir da qual para e olha
const AWARE_DECAY := 0.3  # por segundo, sem nada de novo
const ALERT_TIME := 15.0  # depois de alertado, fica caçando por este tempo
const LOSE_TIME := 3.0  # em combate, sem ver a presa por este tempo = foi atrás do último lugar onde a viu
const SEARCH_TIME := 6.0
const ASSASSINATE_RANGE := 2.2  # alcance do abate furtivo pelas costas
const CRIT_RANGE := 2.5  # alcance do golpe crítico no inimigo caído

@export var target: Player
## Pontos (no mundo) da patrulha, percorridos em ciclo. Vazio = fica parado de guarda.
@export var route: Array[Vector3] = []

var state := "idle"
var dead := false
var rng := RandomNumberGenerator.new()
# ajustes de cada tipo de inimigo
var sight_range := SIGHT_RANGE
var fov_half := deg_to_rad(75.0)  # meio cone de visão (raptor: olhos nas laterais da cabeça)
var eye_height := 1.3
var marker_height := 2.4
var turn_rate := 6.0
var patrol_speed := 1.4
var investigate_speed := 2.4
var hunt_speed := 4.2
var head_mult := 2.0  # o tiro na cabeça tira esta vez o dano normal (quem atira multiplica); 1 = sem headshot
var can_stealth := false  # aceita abate furtivo pelas costas (soldado e velociraptor; alossauro nunca)
var _stealth_locked := false  # travado no lugar enquanto recebe o golpe furtivo ou crítico
@export var drop_kind := ""
@export var drop_is_weapon := false
@export var drop_amount := 0
@export var drop_chance := 1.0
var _dropped := false
var aware := 0.0  # 0 = não notou nada, 1 = notou (viu ou ouviu)
var alert_t := 0.0  # > 0: foi alertado (viu a presa ou ouviu o alarme de outro) e caça com cone mais aberto e alcance maior
var _t := 0.0
var _dur := 0.0
var _spawn: Transform3D
var _route_i := 0
var _goal := Vector3.ZERO  # destino de patrulha, investigação ou caça
var _stimulus := Vector3.ZERO  # de onde veio o último barulho ou vulto
var _last_known := Vector3.ZERO  # último lugar onde viu a presa
var _lost_t := 0.0
var _heard := false  # o último barulho já bastou para chamar a atenção toda (aware chegou a 1)
var _alarm_delay := -1.0
var _look_to := 0.0  # direção (yaw) para onde olha enquanto procura
var _look_t := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _repath_t := 0.0
var _stuck_t := 0.0
var _stuck_n := 0
var _marker: Label3D
var _trail := Blood.Trail.new()


## Chamar no `_ready` de quem herda (depois de montar o corpo): indicador "?"/"!", grupo e ponto de partida.
func _enemy_ready() -> void:
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.pixel_size = 0.012
	_marker.font_size = 64
	_marker.outline_size = 16
	_marker.position = Vector3(0, marker_height, 0)
	_marker.shaded = false
	add_child(_marker)
	add_to_group("enemies")
	_spawn = global_transform
	rng.randomize()


## Em luta (ataques, mira): a percepção calma não roda; quem herda diz quais estados são.
func in_combat() -> bool:
	return false


## Toca a animação `anim` (nomes do raptor: "Idle", "Walk", "Run", "Study"); `speed` = velocidade dela.
func _play(_anim: String, _blend := 0.15, _speed := 1.0, _restart := false) -> void:
	pass


## m/s que a animação de andar (ou correr) representa em velocidade 1 (o pé não patina).
func _anim_speed(_run: bool) -> float:
	return 1.0


## Viu a presa agora (já alertou os outros): grita, ergue a arma...
func _on_spotted() -> void:
	pass


## Zera o que quem herda guarda de cada estado (ao entrar nele).
func _on_enter() -> void:
	pass


func _enter(s: String, anim: String, blend := 0.15) -> void:
	state = s
	_t = 0.0
	_stuck_t = 0.0
	_stuck_n = 0
	_on_enter()
	_play(anim, blend, 1.0, true)
	_update_marker()


## Começo de cada passo de física: relógio do alerta, percepção (calmo) ou rastreio da presa (em luta).
func _tick(delta: float) -> void:
	if _stealth_locked:
		velocity = Vector3.ZERO
		return
	_t += delta
	alert_t = maxf(alert_t - delta, 0.0)
	if dead:
		# morto não cai: o soldado sem colisor atravessaria o chão levando o ragdoll (filho do esqueleto dele) junto
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_trail.update(self, delta, wound())
	if state == "down":
		return
	if not in_combat():
		_wake_on_alarm(delta)
		_perceive(delta)
	elif state != "hold":
		_track_target(delta)


## Estados calmos e de busca (iguais para todo inimigo). Devolve true se `state` era um deles.
func _calm_state(delta: float) -> bool:
	if _stealth_locked:
		_stop(delta)
		return true
	match state:
		"idle":
			_stop(delta)
			_play("Idle")
			if not route.is_empty():
				start_patrol()
		"patrol":
			_patrol(delta)
		"look":
			_look(delta, "Idle")
			if _t >= _dur:
				start_patrol()
		"suspicious":
			_suspicious(delta)
		"investigate":
			if _go(_goal, investigate_speed, delta):
				start_search()
		"hunt":
			if _go(_goal, hunt_speed, delta):
				start_search()
		"search":
			_look(delta, "Study")
			if _t >= _dur:
				alert_t = 0.0
				aware = 0.0
				_resume()
		_:
			return false
	return true


## Levou `amount` de dano vindo de `dir`, acertando em `at` (`head` = na cabeça). Quem herda implementa.
func take_hit(_amount: int, _dir: Vector3, _at: Vector3, _head := false) -> void:
	pass


## Tiro na cabeça (o dano já vem multiplicado por `head_mult`).
func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(amount, dir, at, true)


## Quanto da vida já perdeu (0..1): ferido, sangra pelo caminho.
func wound() -> float:
	return 0.0


## Trava o inimigo no lugar durante a execução do abate furtivo ou golpe crítico.
func stealth_lock(on: bool) -> void:
	_stealth_locked = on
	if on:
		velocity = Vector3.ZERO


## Abate furtivo disponível: vivo, fora de combate/alerta, aceita furtivo (soldado ou raptor) e ela está atrás/fora do cone a até ASSASSINATE_RANGE.
func can_assassinate(p: Player) -> bool:
	if not can_stealth or dead or in_combat() or state in ["down", "hunt"] or alert_t > 0.0:
		return false
	if not is_instance_valid(p) or p.dead:
		return false
	var to := _flat(p.global_position - global_position)
	var d := to.length()
	if d > ASSASSINATE_RANGE or d < 0.05:
		return false
	var local := global_basis.inverse() * to
	var outside_cone := absf(angle_difference(rotation.y, atan2(-to.x, -to.z))) > fov_half
	return not _sees_target() and local.z > -0.25 and outside_cone and _line_clear(p)


## Golpe crítico disponível no inimigo caído no chão (implementado pelo velociraptor em estado "down").
func can_crit_strike(_p: Player) -> bool:
	return false


## Recebe o abate furtivo silencioso pelas costas. Quem herda implementa.
func assassinate(_dir: Vector3, _at: Variant = null) -> void:
	pass


## Recebe o golpe crítico enquanto está caído no chão. Quem herda implementa.
func crit_strike(_dir: Vector3, _at: Variant = null) -> void:
	pass


## De volta ao ponto de partida, calmo (ao reiniciar).
func _reset_enemy() -> void:
	global_transform = _spawn
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	dead = false
	_stealth_locked = false
	aware = 0.0
	alert_t = 0.0
	_route_i = 0
	_alarm_delay = -1.0
	_lost_t = 0.0
	_path = PackedVector3Array()
	_dropped = false


## Solta item ao morrer (arma ou munição). Devolve o Pickup instanciado ou null.
func drop_loot() -> Pickup:
	if _dropped or drop_kind == "" or randf() > drop_chance:
		return null
	_dropped = true
	var p := get_parent()
	return Pickup.spawn_drop(p, global_position + Vector3.UP * 0.8, drop_kind, drop_amount, drop_is_weapon) if p else null


# ------------------------------------------------------------------ IA: percepção, patrulha e alarme
func start_patrol() -> void:
	if route.is_empty():
		_enter("idle", "Idle", 0.25)
		return
	_goal = route[_route_i % route.size()]
	_path = PackedVector3Array()
	_repath_t = 0.0
	_enter("patrol", "Walk", 0.3)


## Volta à rotina (patrulha pelo ponto mais próximo, ou guarda parada).
func _resume() -> void:
	if route.is_empty():
		_enter("idle", "Idle", 0.25)
		return
	var best := 0
	for i in route.size():
		if _flat(route[i] - global_position).length() < _flat(route[best] - global_position).length():
			best = i
	_route_i = best
	start_patrol()


## Pausa num ponto da patrulha olhando em volta.
func start_look() -> void:
	_enter("look", "Idle", 0.3)
	_dur = rng.randf_range(2.0, 4.0)
	_look_t = 0.0


## Notou algo (vulto na beira da vista ou barulho): para e olha para lá, sem ainda saber o que é.
func start_suspicious() -> void:
	_enter("suspicious", "Study", 0.25)


## Foi ver de onde veio o barulho.
func start_investigate(at: Vector3) -> void:
	_goal = at
	_path = PackedVector3Array()
	_repath_t = 0.0
	_enter("investigate", "Walk", 0.3)


## Corre até o último lugar onde a presa foi vista (ou de onde veio o grito de outro).
func start_hunt(at: Vector3) -> void:
	_goal = at
	_path = PackedVector3Array()
	_repath_t = 0.0
	_enter("hunt", "Run", 0.2)


## Chegou e não achou ninguém: olha em volta por um tempo antes de desistir.
func start_search() -> void:
	_enter("search", "Study", 0.3)
	_dur = SEARCH_TIME
	_look_t = 0.0


## 0 = calmo, 1 = desconfiado (para, investiga, procura), 2 = alertado (caça ou luta).
func alert_level() -> int:
	if dead:
		return 0
	if in_combat() or state == "hunt":
		return 2
	if state in ["suspicious", "investigate", "search"]:
		return 1
	return 0


func _update_marker() -> void:
	if _marker == null:
		return
	var lv := alert_level()
	_marker.text = "!" if lv == 2 else ("?" if lv == 1 else "")
	_marker.modulate = Color(1.0, 0.25, 0.15) if lv == 2 else Color(1.0, 0.85, 0.2)
	_marker.visible = lv > 0


## Som vindo de `pos` chega aqui: mesma sala, ou salas ligadas por portas abertas (a porta fechada segura tiro e grito).
func _reaches(pos: Vector3) -> bool:
	return Level.connected(get_tree(), Level.room_of(pos.x), Level.room_of(global_position.x))


## Barulho em `pos` que alcança `radius` metros: a atenção sobe mais quanto mais perto (`power` = o quanto, no máximo).
func hear_noise(pos: Vector3, radius: float, power: float) -> void:
	if dead or in_combat() or not _reaches(pos):
		return
	var d := _flat(pos - global_position).length()
	if d >= radius:
		return
	aware = minf(aware + power * (1.0 - d / radius), 1.0)
	_heard = _heard or aware >= 1.0
	_stimulus = pos
	if alert_t > 0.0:
		_last_known = pos


## Grito de outro raptor que viu a presa: depois de um instante (o som viaja, eles reagem) vem caçar o lugar.
func on_alarm(src: Node3D, at: Vector3) -> void:
	if dead or src == self or not _reaches(src.global_position):
		return
	_last_known = at
	alert_t = ALERT_TIME
	if in_combat():
		return
	aware = 1.0
	_alarm_delay = global_position.distance_to(src.global_position) * 0.015 + rng.randf_range(0.2, 0.7)


func _wake_on_alarm(delta: float) -> void:
	if _alarm_delay <= 0.0:
		return
	_alarm_delay -= delta
	if _alarm_delay <= 0.0:
		_alarm_delay = -1.0
		start_hunt(_last_known)


func _raise_alarm() -> void:
	alert_t = ALERT_TIME
	aware = 1.0
	_lost_t = 0.0
	_last_known = target.global_position
	get_tree().call_group("enemies", "on_alarm", self, _last_known)


## Viu a presa: dá o alarme aos outros e reage à sua maneira (`_on_spotted`).
func spot() -> void:
	_raise_alarm()
	_on_spotted()


func _perceive(delta: float) -> void:
	if not _has_target():
		aware = move_toward(aware, 0.0, AWARE_DECAY * delta)
		return
	var seen := _sees_target()
	if seen:
		_last_known = target.global_position
		_stimulus = _last_known
		var close := 1.0 - clampf(_to_target().length() / _sight_range(), 0.0, 1.0)
		# alertado: nota na hora; senão a atenção sobe devagar de longe e rápido de perto
		aware = minf(aware + (12.0 if alert_t > 0.0 else lerpf(0.5, 3.0, close)) * delta, 1.0)
	else:
		aware = move_toward(aware, 0.0, AWARE_DECAY * delta)
	var alarmed := aware >= 1.0 or _heard
	_heard = false
	if alarmed:
		if seen:
			spot()
		elif state == "search" or state == "investigate":
			# barulho novo longe do que estava vendo: vai lá
			if _stimulus.distance_to(_goal) > 3.0:
				start_investigate(_stimulus)
		elif state != "hunt":
			start_investigate(_stimulus)
	elif aware >= SUSPECT_AT and state in ["idle", "patrol", "look"]:
		start_suspicious()


func _suspicious(delta: float) -> void:
	_stop(delta)
	_play("Study", 0.25)
	_face(_stimulus - global_position, delta, 3.0)
	if aware < 0.12 and _t > 1.5:
		_resume()


## Parado olhando em volta (pausa da patrulha ou procura), virando o corpo para pontos sorteados.
func _look(delta: float, anim: String) -> void:
	_stop(delta)
	_play(anim, 0.3)
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = rng.randf_range(1.0, 1.8)
		_look_to = rotation.y + rng.randf_range(-1.6, 1.6)
	rotation.y = lerp_angle(rotation.y, _look_to, 1.0 - exp(-2.0 * delta))


func _patrol(delta: float) -> void:
	if route.is_empty():
		start_patrol()
		return
	if _go(_goal, patrol_speed, delta):
		_route_i = (_route_i + 1) % route.size()
		start_look()


func _sight_range() -> float:
	var vis := target.visibility()
	if alert_t > 0.0:
		return ALERT_SIGHT * vis
	return sight_range * vis


## Vê a presa: dentro do alcance (menor se ela anda devagar, agachada ou no capim), no cone à frente
## (alertado, cone mais aberto; muito perto, em volta toda) e sem nada no meio.
func _sees_target() -> bool:
	if not _has_target():
		return false
	var to := _to_target()
	var d := to.length()
	if d > _sight_range():
		return false
	var behind := (global_basis.inverse() * to).z > -0.25
	var half := fov_half + (ALERT_FOV_BONUS if alert_t > 0.0 else 0.0)
	if (d > CLOSE_SIGHT or (behind and alert_t <= 0.0)) and absf(angle_difference(rotation.y, atan2(-to.x, -to.z))) > half:
		return false
	return _line_clear()


## Em combate ele sabe onde ela está se a vê: perto (COMBAT_SENSE) ou dentro do alcance de alertado, sempre com nada no
## meio. Atrás de parede/caixa ou agachada no capim, longe, ele perde o rastro.
func _combat_sees() -> bool:
	if not _has_target():
		return false
	var d := _to_target().length()
	return (d < COMBAT_SENSE or d < ALERT_SIGHT * target.visibility()) and _line_clear()


## Em combate: ela à vista zera o tempo sem vê-la e guarda o lugar onde está.
func _track_target(delta: float) -> void:
	if not _has_target():
		return
	if _combat_sees():
		_lost_t = 0.0
		_last_known = target.global_position
	else:
		_lost_t += delta


func _line_clear(who: Player = target) -> bool:
	if not is_instance_valid(who):
		return false
	var eye := global_position + Vector3.UP * eye_height
	var goal := who.global_position + Vector3.UP * (0.8 if who.crouching else 1.2)
	var q := PhysicsRayQueryParameters3D.create(eye, goal, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Anda até `goal` (caminho da malha de navegação; sem malha, em linha reta desviando de paredes).
## Devolve true ao chegar ou ao desistir (preso).
func _go(goal: Vector3, speed: float, delta: float) -> bool:
	var to := _flat(goal - global_position)
	if to.length() < 1.0:
		_stop(delta)
		return true
	var dir := _steer(goal, to, delta)
	_face(dir, delta, 5.0)
	var fwd := -global_basis.z
	var v := speed * maxf(fwd.dot(dir), 0.0)
	velocity.x = fwd.x * v
	velocity.z = fwd.z * v
	var run := speed > 3.0
	_play("Run" if run else "Walk", 0.25, maxf(v, 0.3) / _anim_speed(run))
	# mandou andar e não sai do lugar (árvore, quina): refaz o caminho; preso de novo, desiste
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if v > 0.5 and real < v * 0.25:
		_stuck_t += delta
		if _stuck_t > 1.2:
			_stuck_t = 0.0
			_stuck_n += 1
			_repath_t = 0.0
			rotation.y += 1.0 if _stuck_n % 2 == 1 else -1.0
			if _stuck_n > 2:
				_stuck_n = 0
				return true
	else:
		_stuck_t = maxf(_stuck_t - delta, 0.0)
	return false


func _steer(goal: Vector3, to: Vector3, delta: float) -> Vector3:
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = 0.4
		_path = PackedVector3Array()
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
		_path_i = 0
	if _path.is_empty():
		return _avoid(to.normalized())
	while _path_i < _path.size() - 1 and _flat(_path[_path_i] - global_position).length() < 0.8:
		_path_i += 1
	var aim := _flat(_path[_path_i] - global_position)
	return aim.normalized() if aim.length() > 0.05 else to.normalized()


## Sem malha de navegação: se há parede à frente, vira para o lado que está livre.
func _avoid(dir: Vector3) -> Vector3:
	var from := global_position + Vector3.UP * 0.6
	if _free(from, dir):
		return dir
	if _free(from, dir.rotated(Vector3.UP, 0.7)):
		return dir.rotated(Vector3.UP, 0.9)
	if _free(from, dir.rotated(Vector3.UP, -0.7)):
		return dir.rotated(Vector3.UP, -0.9)
	return dir.rotated(Vector3.UP, 1.6)


func _free(from: Vector3, dir: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _has_target() -> bool:
	return is_instance_valid(target) and not target.dead


func _to_target() -> Vector3:
	if not is_instance_valid(target):
		return -global_basis.z
	var to := target.global_position - global_position
	to.y = 0.0
	return to


func _stop(delta: float) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	velocity.x = lerpf(velocity.x, 0.0, k)
	velocity.z = lerpf(velocity.z, 0.0, k)


func _face(dir: Vector3, delta: float, rate := turn_rate) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))

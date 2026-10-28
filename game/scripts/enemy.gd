class_name Enemy
extends CharacterBody3D
## Base dos inimigos (raptor, soldado): patrulha uma rota (`route`) e percebe a presa pela visão e pelo barulho.
## Níveis de alerta: 0 calmo, 1 amarelo (atenção chamada), 2 laranja (busca ativa/perseguindo), 3 vermelho (encontrou/combate).

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
const SEARCH_TIME := 3.0  # olhando em volta em cada lugar da busca (de SEARCH_TIME a SEARCH_TIME + 2 s)
const SEARCH_SWEEPS := 2  # depois do lugar onde a viu, vasculha mais estes pontos em volta antes de desistir
const SWEEP_RINGS := [3.0, 5.0, 7.0]  # distâncias (do lugar onde a viu) dos pontos vasculhados
const CLAIM_DIST := 3.0  # destino a menos disto do de um colega = já tem gente indo lá
const NO_PROGRESS_TIME := 3.0  # andando sem encurtar o caminho por este tempo (porta fechada, quina, colega no meio) = chegou o mais perto que dá
const ASSASSINATE_RANGE := 2.2  # alcance do abate furtivo pelas costas
const STEER_RADIUS := 0.3  # raio do corpo (cápsula de gente) ao conferir se dá para ir reto ao próximo ponto do caminho
const CRIT_RANGE := 2.5  # alcance do golpe crítico no inimigo caído

@export var target: Player
## Pontos (no mundo) da patrulha, percorridos em ciclo. Vazio = fica parado de guarda.
@export var route: Array[Vector3] = []

var state := "idle"
var dead := false
## escondido fora de cena (emboscada, ver Raptor.lurk): sem corpo, sem IA, não ouve nem recebe alarme
var lurking := false
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
var head_yaw := 0.0
var head_pitch := 0.0
var arrival_dist := 1.0
var _vigil_t := 0.0
var _vigil_target_yaw := 0.0
var _vigil_target_pitch := 0.0
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
## Malha de navegação própria (soldados: a de gente, Yard.bake_people_nav); vazio = a do mundo (raptors).
var nav_map := RID()
var search_sweeps := SEARCH_SWEEPS  # 0 = só olha em volta onde chegou (sniper preso à passarela)
var alarm_responders := 99  # quantos do mesmo tipo (os mais perto) saem do posto quando um dá o alarme (raptors: a matilha toda)
var alarm_walks := false  # vai ao alarme andando, com calma (gente), em vez de correr
## Guarda de posto (guardas da porta do pátio): barulho e vulto só o fazem parar e olhar para lá, sem sair do lugar,
## até alguém vê-la (alerta: `alert_t` > 0); aí caça e procura como os outros e, quando desiste, volta ao posto.
var hold_post := false
var _heeding := false  # "look" por causa do alarme de outro: olha para o lugar dele
var _sweeps_left := 0
var _search_center := Vector3.ZERO  # o lugar que está procurando (onde a viu ou ouviu)
var _visited: Array[Vector3] = []
var _best_left := INF  # menor resto de caminho até o destino desde que entrou no estado
var _progress_t := 0.0
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
	_marker.visible = false
	add_child(_marker)
	add_to_group("enemies")
	_spawn = global_transform
	rng.randomize()
	_vigil_t = rng.randf_range(2.0, 3.5)
	_vigil_target_yaw = 0.0

## Em luta (ataques, mira): a percepção calma não roda; quem herda diz quais estados são.
func in_combat() -> bool: return false
func _play(_anim: String, _blend := 0.15, _speed := 1.0, _restart := false) -> void: pass
func _anim_speed(_run: bool) -> float: return 1.0
func _on_spotted() -> void: pass
func _on_enter() -> void: pass

func _enter(s: String, anim: String, blend := 0.15) -> void:
	state = s
	_t = 0.0
	_stuck_t = 0.0
	_stuck_n = 0
	_best_left = INF
	_progress_t = 0.0
	_on_enter()
	_play(anim, blend, 1.0, true)
	_update_marker()

## Começo de cada passo de física: relógio do alerta, percepção (calmo) ou rastreio da presa (em luta).
func _tick(delta: float) -> void:
	if lurking:
		velocity = Vector3.ZERO
		return
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
		_check_corpses()
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
			elif _t > 2.0 and _flat(_spawn.origin - global_position).length() > arrival_dist + 0.3:
				_resume()  # a volta ao posto empacou (colega no caminho): tenta de novo
			else:
				# guarda de volta ao posto: vira para onde vigiava
				var post_yaw := _spawn.basis.get_euler().y
				if absf(angle_difference(rotation.y, post_yaw)) > 0.02:
					rotation.y = lerp_angle(rotation.y, post_yaw, 1.0 - exp(-4.0 * delta))
				_idle_vigil(delta)
		"patrol":
			_patrol(delta)
		"look":
			if _heeding:
				_search_look(delta)
			else:
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
			_search_look(delta)
			if _t >= _dur and not _start_sweep():
				alert_t = 0.0
				aware = 0.0
				_resume()
		"sweep":
			if _go(_goal, patrol_speed, delta):  # vasculhando: passo de ronda, com calma
				start_search()
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

## Abate furtivo disponível: vivo, fora de combate/alerta, aceita furtivo (soldado, raptor ou sniper) e ela está atrás/fora do cone a até ASSASSINATE_RANGE.
func can_assassinate(p: Player) -> bool:
	if not can_stealth or dead or lurking or in_combat() or state in ["down", "hunt"] or alert_t > 0.0:
		return false
	if not is_instance_valid(p) or p.dead or absf(p.global_position.y - global_position.y) > 1.2:
		return false
	var to := _flat(p.global_position - global_position)
	var d := to.length()
	if d > ASSASSINATE_RANGE or d < 0.05:
		return false
	var local := global_basis.inverse() * to
	var outside_cone := absf(angle_difference(rotation.y + head_yaw, atan2(-to.x, -to.z))) > fov_half
	return not _sees_target() and local.z > -0.25 and outside_cone and _line_clear(p)

func can_crit_strike(_p: Player) -> bool: return false
func assassinate(_dir: Vector3, _at: Variant = null) -> void: pass
func crit_strike(_dir: Vector3, _at: Variant = null) -> void: pass

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
	head_yaw = 0.0
	head_pitch = 0.0
	_vigil_t = rng.randf_range(2.0, 3.5)
	_vigil_target_yaw = 0.0

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

## Volta à rotina (patrulha pelo ponto mais próximo, ou guarda parada, que antes anda de volta ao posto).
func _resume() -> void:
	if route.is_empty():
		if _flat(_spawn.origin - global_position).length() > arrival_dist + 0.3:
			_goal = _spawn.origin
			_path = PackedVector3Array()
			_repath_t = 0.0
			_enter("patrol", "Walk", 0.3)
		else:
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
	_heeding = false
	_dur = rng.randf_range(2.0, 4.0)
	_look_t = 0.0

## Notou algo (vulto na beira da vista ou barulho): para e olha para lá, sem ainda saber o que é.
func start_suspicious() -> void:
	_enter("suspicious", "Study", 0.25)

## Foi ver de onde veio o barulho.
func start_investigate(at: Vector3) -> void:
	_begin_search(at)
	_enter("investigate", "Walk", 0.3)

## Corre até o último lugar onde a presa foi vista (ou de onde veio o grito de outro).
func start_hunt(at: Vector3) -> void:
	_begin_search(at)
	_enter("hunt", "Run", 0.2)

func _begin_search(at: Vector3) -> void:
	_search_center = at
	_sweeps_left = search_sweeps
	_visited.clear()
	_goal = _search_goal(at)
	_path = PackedVector3Array()
	_repath_t = 0.0

## Chegou e não achou ninguém: olha em volta por um tempo; depois vasculha outro ponto (`_start_sweep`) ou desiste.
func start_search() -> void:
	_visited.append(global_position)
	_enter("search", "Study", 0.3)
	_dur = rng.randf_range(SEARCH_TIME, SEARCH_TIME + 2.0)
	_look_t = 0.0

## Olhando em volta: primeiro vira para o lugar procurado (e ergue a cabeça se é alto, como a passarela), depois varre.
func _search_look(delta: float) -> void:
	var to := _flat(_search_center - global_position)
	if _t < 0.8 and to.length() > 1.5:
		_stop(delta)
		_play("Study", 0.3)
		_face(to, delta, 4.0)
	else:
		_look(delta, "Study")
	if has_head_look():
		var rise := _search_center.y + 1.0 - (global_position.y + eye_height)
		head_pitch = lerpf(head_pitch, clampf(atan2(rise, maxf(to.length(), 0.5)), -0.3, 0.6), 1.0 - exp(-3.0 * delta))

## Vai vasculhar mais um ponto em volta do lugar procurado. Devolve false se acabaram os pontos (ou não há malha).
func _start_sweep() -> bool:
	if _sweeps_left <= 0:
		return false
	_sweeps_left -= 1
	var p: Variant = _sweep_goal()
	if p == null:
		return false
	_goal = p
	_path = PackedVector3Array()
	_repath_t = 0.0
	_enter("sweep", "Walk", 0.3)
	return true

# ------------------------------------------------------------------ IA: onde procurar (lê a malha de navegação)
func _nav() -> RID:
	return nav_map if nav_map.is_valid() else get_world_3d().navigation_map

func _has_nav() -> bool:
	var map := _nav()
	return not NavigationServer3D.map_get_regions(map).is_empty() and NavigationServer3D.map_get_iteration_id(map) > 0

## Ponto do chão (mesmo andar que ele) perto de `p`, na malha; null se ali não é chão livre.
func _floor_at(p: Vector3) -> Variant:
	var c := Vector3(p.x, global_position.y, p.z)
	var q := NavigationServer3D.map_get_closest_point(_nav(), c)
	if _flat(q - c).length() > 0.6 or absf(q.y - global_position.y) > 0.6:
		return null
	return q

## Chega a pé em `p`: o caminho termina nele (não numa ilha da malha, como o topo das caixas).
func _reachable(p: Vector3, max_len := 40.0) -> bool:
	var path := NavigationServer3D.map_get_path(_nav(), global_position, p, true)
	if path.is_empty() or _flat(path[path.size() - 1] - p).length() > 0.5:
		return false
	var length := 0.0
	for k in path.size() - 1:
		length += path[k].distance_to(path[k + 1])
	return length <= max_len

## Um colega (vivo, procurando) já vai para perto de `p`.
func _claimed(p: Vector3) -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e == self or e.dead or not e.state in ["hunt", "investigate", "sweep", "search"]:
			continue
		var g: Vector3 = e.global_position if e.state == "search" else e._goal
		if _flat(g - p).length() < CLAIM_DIST and absf(g.y - p.y) < 1.5:
			return true
	return false

## Vê `at` (à altura do peito dela) parado em `p`.
func _sees_from(p: Vector3, at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * eye_height, at + Vector3.UP * 0.9, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Para onde ir procurar `at`. Sem malha: o próprio lugar (afastado dos colegas). Com malha: o ponto alcançável mais
## perto dele (entra no corredor, vai ao pé da escada); se um colega já vai para lá, um ponto do chão em volta de onde
## se vê o lugar (alto, como a passarela, ou atrás das caixas). Cada um pega um lugar: não ficam amontoados.
func _search_goal(at: Vector3) -> Vector3:
	if not _has_nav():
		return EnemyCrowd.disperse_goal(self, at)
	var path := NavigationServer3D.map_get_path(_nav(), global_position, at, true)
	var near := path[path.size() - 1] if not path.is_empty() else at
	if not _claimed(near):
		return near
	var spots := []
	var blind := []  # sem vista do lugar (dentro do labirinto quase nada vê): ainda serve, desde que livre
	for r: float in [2.5, 4.0, 6.0, 8.0, 10.0]:
		for k in 12:
			var a := TAU * k / 12.0
			var q: Variant = _floor_at(at + Vector3(cos(a), 0.0, sin(a)) * r)
			if q == null or _claimed(q):
				continue
			var score := r + _flat(q - global_position).length() * 0.25
			(spots if _sees_from(q, at) else blind).append([score, q])
	for list: Array in [spots, blind]:
		list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for s: Array in list.slice(0, 8):
			if _reachable(s[1]):
				return s[1]
	return near

## Próximo ponto a vasculhar em volta do lugar procurado: chão alcançável, longe dos já olhados e do destino dos
## colegas; de preferência um que daqui não se vê (atrás de caixa, coluna, dentro do corredor), onde ela pode estar.
func _sweep_goal() -> Variant:
	if not _has_nav():
		return null
	var spots := []
	for r: float in SWEEP_RINGS:
		for k in 10:
			var a := TAU * (k + rng.randf()) / 10.0
			var q: Variant = _floor_at(_search_center + Vector3(cos(a), 0.0, sin(a)) * r)
			if q == null or _claimed(q) or _visited.any(func(v: Vector3) -> bool: return _flat(v - q).length() < 2.5):
				continue
			var score := _flat(q - global_position).length() + rng.randf_range(0.0, 2.0)
			if not _sees_from(global_position, q):
				score -= 3.0
			spots.append([score, q])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for s: Array in spots.slice(0, 8):
		if _reachable(s[1], 25.0):
			return s[1]
	return null

## 0 = calmo, 1 = amarelo (atenção chamada), 2 = laranja (busca ativa/perseguindo), 3 = vermelho (encontrou/combate)
func alert_level() -> int:
	if dead or lurking: return 0
	if in_combat(): return 3
	if state in ["hunt", "search", "sweep", "investigate"]: return 2
	return 1 if state == "suspicious" else 0

## Sensor de perigo do HUD (DangerMeter): chance (0..1) de ela levar tiro ou golpe deste inimigo nos próximos instantes.
## Só em luta, com ela viva, com controle e à mostra (no telhado ou escondida no alto da escada ninguém a acerta);
## esquivando/rolando nada a acerta (0). Quem herda diz o resto (`_threat`).
func threat() -> float:
	if dead or lurking or not in_combat() or not _has_target() or target.dead or target.cutscene or target.is_dodging():
		return 0.0
	if _target_hidden():
		return 0.0
	return clampf(_threat(), 0.0, 1.0)

func _threat() -> float: return 0.0

## Em luta e com ela à vista agora (o radar não a mostra INVISIVEL enquanto alguém a está vendo).
func has_eyes_on() -> bool:
	return not dead and not lurking and in_combat() and _has_target() and _lost_t < 0.4

## Ameaça de quem ataca de perto: dando um golpe de `strikes` ao alcance (`reach` m, com folga), certa; longe ou só
## rondando, cresce conforme chega perto (até 0,6 em cima dela). `rush` = investidas que vêm de longe.
func _melee_threat(strikes: Array, reach: float, rush: Array = []) -> float:
	var d := _to_target().length()
	if state in rush:
		return 0.9
	if state in strikes:
		return 1.0 if d < reach * 1.6 else 0.5
	return clampf(1.0 - (d - reach) / 12.0, 0.0, 1.0) * 0.6

func _update_marker() -> void:
	if _marker == null: return
	var lv := alert_level()
	_marker.visible = lv > 0
	if lv == 3: _marker.text = "!"; _marker.modulate = UiStyle.DANGER
	elif lv == 2: _marker.text = "!"; _marker.modulate = UiStyle.WARN
	elif lv == 1: _marker.text = "?"; _marker.modulate = UiStyle.ACCENT

## Som vindo de `pos` chega aqui: mesma sala, ou salas ligadas por portas abertas (a porta fechada segura tiro e grito).
## Do telhado não chega nada (a laje abafa).
func _reaches(pos: Vector3) -> bool:
	if Roof.has(pos):
		return false
	return Level.connected(get_tree(), Level.room_of(pos.x), Level.room_of(global_position.x))

func is_searching() -> bool:
	return not in_combat() and not dead and (alert_level() == 2 or state in ["hunt", "search", "sweep", "investigate"])

## Barulho em `pos` que alcança `radius` metros: se estiver vasculhando, vai direto em encontrar.
func hear_noise(pos: Vector3, radius: float, power: float) -> void:
	if dead or lurking or in_combat() or not _reaches(pos):
		return
	var d := _flat(pos - global_position).length()
	if d >= radius:
		return
	_stimulus = pos
	_last_known = pos
	if is_searching():
		aware = 1.0
		spot()
		return
	aware = minf(aware + power * (1.0 - d / radius), 1.0)
	_heard = _heard or aware >= 1.0

## Morte de companheiro próximo: se estiver vasculhando, interpreta como posição revelada e encontra.
func on_nearby_kill(at: Vector3, radius := 8.0) -> void:
	if dead or lurking or in_combat() or not _reaches(at):
		return
	if is_searching() and _flat(at - global_position).length() <= radius:
		_last_known = at
		_stimulus = at
		aware = 1.0
		spot()

## Grito de outro raptor que viu a presa: depois de um instante (o som viaja, eles reagem) vem caçar o lugar.
## `rank` = quantos do mesmo tipo estão mais perto de `at` (0 = o mais perto): só os `alarm_responders` mais perto saem
## do posto; os outros param, olham para lá e ficam alertados onde estão (`_heed`). Gente vai andando (`alarm_walks`).
func on_alarm(src: Node3D, at: Vector3, rank := 0) -> void:
	if dead or lurking or src == self or not _reaches(src.global_position):
		return
	_last_known = at
	alert_t = ALERT_TIME
	if in_combat():
		return
	if rank >= alarm_responders:
		_heed(at)
		return
	aware = 1.0
	_alarm_delay = global_position.distance_to(src.global_position) * 0.015 + rng.randf_range(0.2, 0.7)

## Ouviu o alarme mas não é dos que vão: para, olha para o lugar e segue a rotina (alertado: vê mais longe e mais aberto).
func _heed(at: Vector3) -> void:
	if not state in ["idle", "patrol", "look"]:
		return
	_search_center = at
	_enter("look", "Idle", 0.3)
	_heeding = true
	_dur = rng.randf_range(2.5, 4.0)
	_look_t = 0.0

func _wake_on_alarm(delta: float) -> void:
	if _alarm_delay <= 0.0:
		return
	_alarm_delay -= delta
	if _alarm_delay <= 0.0:
		_alarm_delay = -1.0
		if alarm_walks:
			start_investigate(_last_known)
		else:
			start_hunt(_last_known)

func _raise_alarm() -> void:
	alert_t = ALERT_TIME
	aware = 1.0
	_lost_t = 0.0
	_last_known = target.global_position
	broadcast_alarm(_last_known)

## Avisa os outros que ela está em `at`, do mais perto ao mais longe (a ordem de cada tipo é o `rank` de `on_alarm`).
func broadcast_alarm(at: Vector3) -> void:
	var others: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e is Enemy and e != self and not e.dead)
	others.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	var ranks := {}
	for e: Enemy in others:
		var kind: Script = e.get_script()
		e.on_alarm(self, at, ranks.get(kind, 0))
		ranks[kind] = ranks.get(kind, 0) + 1

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
		elif state in ["search", "sweep", "investigate"]:
			# barulho novo longe do que estava vendo: vai lá
			if _stimulus.distance_to(_goal) > 3.0:
				start_investigate(_stimulus)
		elif _holds_post():
			if state in ["idle", "patrol", "look"]:
				start_suspicious()
		elif state != "hunt":
			start_investigate(_stimulus)
	elif aware >= SUSPECT_AT and state in ["idle", "patrol", "look"]:
		start_suspicious()

## Guarda de posto que ainda não foi alertado: não sai do lugar para ver o que foi.
func _holds_post() -> bool:
	return hold_post and alert_t <= 0.0

func _suspicious(delta: float) -> void:
	_stop(delta)
	_play("Study", 0.25)
	_face(_stimulus - global_position, delta, 3.0)
	if _stimulus != Vector3.ZERO and _t > 1.2 and not _holds_post():
		start_investigate(_stimulus)
		return
	if aware < 0.12 and _t > 1.5:
		_resume()

## Parado olhando em volta (pausa da patrulha ou procura).
func _look(delta: float, anim: String) -> void:
	_stop(delta)
	_play(anim, 0.3)
	_look_t -= delta
	if has_head_look():
		if _look_t <= 0.0:
			_look_t = rng.randf_range(1.5, 2.5)
			var r := rng.randf()
			_vigil_target_yaw = 0.0 if r < 0.34 else (rng.randf_range(0.45, 0.85) if r < 0.67 else rng.randf_range(-0.85, -0.45))
		head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.5 * delta))
	else:
		if _look_t <= 0.0:
			_look_t = rng.randf_range(1.0, 1.8)
			_look_to = rotation.y + rng.randf_range(-1.6, 1.6)
		rotation.y = lerp_angle(rotation.y, _look_to, 1.0 - exp(-2.0 * delta))

func _patrol(delta: float) -> void:
	if route.is_empty():
		# guarda sem rota voltando ao posto (`_resume`)
		if _go(_goal, patrol_speed, delta):
			_enter("idle", "Idle", 0.25)
		return
	if _go(_goal, patrol_speed, delta):
		_route_i = (_route_i + 1) % route.size()
		start_look()

func _sight_range() -> float:
	var vis := target.visibility()
	if alert_t > 0.0:
		return ALERT_SIGHT * vis
	return sight_range * vis

## Fora do alcance de qualquer um: em cima do telhado ou na parte de cima da escada do alçapão.
func _target_hidden() -> bool:
	return Roof.has(target.global_position) or target.moves.hidden_on_ladder()

## Vê a presa: dentro do alcance (menor se ela anda devagar, agachada ou no capim), no cone à frente
## (alertado, cone mais aberto; muito perto, em volta toda) e sem nada no meio.
func _sees_target() -> bool:
	if not _has_target() or _target_hidden():
		return false
	var to := _to_target()
	var d := to.length()
	if d > _sight_range():
		return false
	var behind := (global_basis.inverse() * to).z > -0.25
	var half := fov_half + (ALERT_FOV_BONUS if alert_t > 0.0 else 0.0)
	var look_angle := rotation.y + head_yaw
	if (d > CLOSE_SIGHT or (behind and alert_t <= 0.0)) and absf(angle_difference(look_angle, atan2(-to.x, -to.z))) > half:
		return false
	return _line_clear()

## Em combate ele sabe onde ela está se a vê: perto (COMBAT_SENSE) ou dentro do alcance de alertado, sempre com nada no
## meio. Atrás de parede/caixa ou agachada no capim, longe, ele perde o rastro.
func _combat_sees() -> bool:
	if not _has_target() or _target_hidden():
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
## Devolve true ao chegar ou ao desistir (preso, ou sem encurtar o caminho por NO_PROGRESS_TIME).
## Destino fora da malha (em cima das caixas, dentro do labirinto, na passarela, atrás de porta fechada): o caminho
## termina no ponto alcançável mais perto dele, e chegar ali conta como chegar.
func _go(goal: Vector3, speed: float, delta: float) -> bool:
	var to := _flat(goal - global_position)
	if to.length() < arrival_dist:
		_stop(delta)
		return true
	var dir := _steer(goal, to, delta)
	var left := _path_left(goal)
	if left < arrival_dist:
		_stop(delta)
		return true
	if left < _best_left - 0.3:
		_best_left = left
		_progress_t = 0.0
	else:
		_progress_t += delta
		if _progress_t > NO_PROGRESS_TIME:
			_stop(delta)
			return true
	var sep := EnemyCrowd.compute_separation(self)
	if sep.length_squared() > 0.01:
		dir = (dir + sep * 1.2).normalized()
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
		_repath_t = 2.0  # não refaz a cada instante: com duas rotas parecidas ele trocaria de uma para a outra e ficaria indo e voltando (preso refaz na hora)
		_path = PackedVector3Array()
		var map := _nav()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
		_path_i = 0
	if _path.is_empty():
		return _avoid(to.normalized())
	while _path_i < _path.size() - 1:
		var d := _flat(_path[_path_i] - global_position).length()
		# já perto do ponto: pula para o seguinte só se o corpo passa reto até ele (senão corta a quina e prende nela)
		if d < 0.25 or (d < 0.8 and _clear_to(_path[_path_i + 1])):
			_path_i += 1
		else:
			break
	var aim := _flat(_path[_path_i] - global_position)
	return aim.normalized() if aim.length() > 0.05 else to.normalized()

## O corpo (esfera de `STEER_RADIUS` na altura do joelho) anda reto daqui até `p` sem bater no cenário?
func _clear_to(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = STEER_RADIUS
	q.shape = s
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.6)
	q.motion = _flat(p - global_position)
	return get_world_3d().direct_space_state.cast_motion(q)[0] >= 1.0

## Quanto falta andar: pelo caminho da malha até o fim dele (sem caminho, em linha reta até `goal`).
func _path_left(goal: Vector3) -> float:
	if _path.is_empty():
		return _flat(goal - global_position).length()
	var i := mini(_path_i, _path.size() - 1)
	var left := _flat(_path[i] - global_position).length()
	for k in range(i, _path.size() - 1):
		left += _flat(_path[k + 1] - _path[k]).length()
	return left

## Sem malha de navegação: se há parede à frente, vira para o lado que está livre.
func _avoid(dir: Vector3) -> Vector3:
	var from := global_position + Vector3.UP * 0.6
	if _free_dir(from, dir): return dir
	if _free_dir(from, dir.rotated(Vector3.UP, 0.7)): return dir.rotated(Vector3.UP, 0.9)
	if _free_dir(from, dir.rotated(Vector3.UP, -0.7)): return dir.rotated(Vector3.UP, -0.9)
	return dir.rotated(Vector3.UP, 1.6)

func _free_dir(from: Vector3, dir: Vector3) -> bool:
	return _free(from, dir) and not EnemyCrowd.is_enemy_in_path(self, dir, 1.5)

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

func has_head_look() -> bool: return false

func _idle_vigil(delta: float) -> void:
	_stop(delta)
	_play("Idle", 0.3)
	_vigil_t -= delta
	if _vigil_t <= 0.0:
		_vigil_t = rng.randf_range(2.0, 4.0)
		_vigil_target_yaw = rng.randf_range(-0.9, 0.9) if rng.randf() > 0.35 else 0.0
	head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.0 * delta))

func _check_corpses() -> void:
	if dead or in_combat() or state in ["dead", "down"]:
		return
	var eye := global_position + Vector3.UP * eye_height
	var look := rotation.y + head_yaw
	var half := fov_half + (ALERT_FOV_BONUS if alert_t > 0.0 else 0.0)
	var space := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e == self or not e.dead or e._t < 1.8 or not _reaches(e.global_position):
			continue
		var to := e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > sight_range or d < 0.2 or absf(angle_difference(look, atan2(-to.x, -to.z))) > half:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, e.global_position + Vector3.UP * 0.3, 1)).is_empty():
			continue
		_stimulus = e.global_position
		if d <= 2.2 and not e.has_meta("reported"):
			e.set_meta("reported", true)
			_raise_alarm()
			start_hunt(e.global_position)
			return
		elif state in ["idle", "patrol", "look"]:
			aware = maxf(aware, 0.9)
			start_suspicious()
			return

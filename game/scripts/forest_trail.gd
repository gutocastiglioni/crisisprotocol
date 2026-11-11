class_name ForestTrail
extends Node
## Trilha em S do pátio da mata (Yard), jeito Dino Crisis 2: a jogadora segue um caminho e os raptors saem da mata na
## frente dela, por trechos, em vez de um pátio aberto com ameaça de todos os lados.
##   seção 0 (S1)  os 3 da emboscada no guerrilheiro morto (a cena os solta; ver Cutscene.play_ambush);
##   seção 1 (S2)  7 raptors em trechos de 2 (Yard.WAVES "section" 1);
##   seção 2 (S3)  9 raptors em três levas de 3 (Yard.WAVES "section" 2).
## Ela passa da linha `z` de um trecho (na faixa do meio, no chão): cada raptor dele pula da moita dele (Raptor.emerge),
## um pouco depois do outro. Passou correndo: os trechos seguintes também soltam os seus e todos vão atrás dela (vão se
## juntando); o certo é encarar os que aparecem na frente.
## Cada portão de grade (Yard.GRATES, na mesma ordem das seções) fica travado (`Door.held`) até todos os raptors da seção
## de antes dele morrerem; aí destrava (estalo, lampião verde) e ela abre com E. O portão de trás fica aberto: ela pode
## voltar e eles vão atrás. O barranco do fim de S2 tem os 2 de Yard.CLIFF_RAPTORS: pulam das moitas do planalto quando
## ela chega lá em cima (fora das seções: não seguram portão nenhum).

signal cleared(section: int)

const STAGGER := 0.3  # s entre um raptor do trecho e o próximo sair da moita

var player: Player
var gates: Array[Door] = []  # na ordem de Yard.GRATES (= a seção que cada um espera)
var sections: Array = [[], [], []]  # raptors de cada seção
var waves: Array[Dictionary] = []  # {"section", "z", "raptors": Array[Raptor], "entries": Array[Vector3], "fired"}
var cliff: Array[Raptor] = []
var cliff_fired := false
var done: Array[bool] = [false, false, false]
var _pending: Array[Dictionary] = []  # {"r": Raptor, "at": Vector3, "t": s até sair}


## Cria os raptors dos trechos e do barranco (escondidos nas moitas) e liga os portões. `place` = Callable(Raptor, post)
## do main (alvo, posto, rota); `ambush` = os 3 da emboscada (seção 0). Devolve os raptors criados, na ordem.
func build(place: Callable, ambush: Array[Raptor], grates: Array[Door]) -> Array[Raptor]:
	gates = grates
	sections[0].assign(ambush)
	var out: Array[Raptor] = []
	for w: Dictionary in Yard.WAVES:
		var group: Array[Raptor] = []
		var entries: Array[Vector3] = []
		for e: Vector3 in w.entries:
			var r := _make(place, e)
			group.append(r)
			entries.append(e)
			sections[w.section].append(r)
			out.append(r)
		waves.append({"section": w.section, "z": w.z, "raptors": group, "entries": entries, "fired": false})
	for e: Vector3 in Yard.CLIFF_RAPTORS:
		var r := _make(place, e)
		cliff.append(r)
		out.append(r)
	reset()
	return out


func _make(place: Callable, at: Vector3) -> Raptor:
	var r := Raptor.new()
	# rota curta da moita para o meio da faixa (se a perder de vista depois da luta, ronda ali)
	var inward := Vector3(signf(-34.5 - at.x) * 3.0, 0, 0) if absf(at.x + 34.5) > 1.0 else Vector3(0, 0, -3.0)
	place.call(r, {"pos": at, "route": [at, at + inward]})
	return r


## R / do zero: todos de volta às moitas, trechos armados, portões travados.
func reset() -> void:
	_pending.clear()
	for w in waves:
		w.fired = false
		for i in w.raptors.size():
			w.raptors[i].lurk(w.entries[i])
	for i in cliff.size():
		cliff[i].lurk(Yard.CLIFF_RAPTORS[i])
	cliff_fired = false
	for i in done.size():
		done[i] = false
	for g in gates:
		g.set_held(true, true)


## Checkpoint: depois do `restore` dos inimigos (mortos fora do jogo, vivos de volta ao posto). Quem está vivo num trecho
## volta para a moita e o trecho arma de novo; seção sem nenhum vivo = acabou (portão destravado, sem estalo).
func restore() -> void:
	_pending.clear()
	for w in waves:
		var alive := false
		for i in w.raptors.size():
			if not w.raptors[i].dead:
				alive = true
				w.raptors[i].lurk(w.entries[i])
		w.fired = not alive
	var cliff_alive := false
	for i in cliff.size():
		if not cliff[i].dead:
			cliff_alive = true
			cliff[i].lurk(Yard.CLIFF_RAPTORS[i])
	cliff_fired = not cliff_alive
	for i in done.size():
		done[i] = _all_dead(sections[i])
		if i < gates.size():
			gates[i].set_held(not done[i], true)


func section_done(i: int) -> bool:
	return done[i]


func _all_dead(list: Array) -> bool:
	return list.all(func(r: Raptor) -> bool: return r.dead)


func _physics_process(delta: float) -> void:
	for k in range(_pending.size() - 1, -1, -1):
		var pn: Dictionary = _pending[k]
		pn.t -= delta
		if pn.t <= 0.0:
			_pending.remove_at(k)
			(pn.r as Raptor).emerge(pn.at)
	for i in done.size():
		if not done[i] and _all_dead(sections[i]) and not sections[i].is_empty():
			done[i] = true
			if i < gates.size():
				gates[i].set_held(false)
			cleared.emit(i)
	if player == null or player.dead or player.cutscene:
		return
	var at := player.global_position
	for w in waves:
		if not w.fired and Yard.in_mid(at) and at.z > w.z:
			fire(w)
	if not cliff_fired and Yard.on_plateau(at):
		cliff_fired = true
		_queue(cliff, Yard.CLIFF_RAPTORS)


## Solta o trecho `w` (os raptors dele pulam das moitas, um STAGGER depois do outro).
func fire(w: Dictionary) -> void:
	w.fired = true
	_queue(w.raptors, w.entries)


func _queue(list: Array, entries: Array) -> void:
	for i in list.size():
		var r: Raptor = list[i]
		if not r.dead and r.lurking:
			_pending.append({"r": r, "at": entries[i], "t": STAGGER * i})

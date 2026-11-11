class_name Checkpoint
extends RefCounted
## Checkpoints por área (jeito Syphon Filter): ao chegar a cada um o jogo grava a jogadora (vida, armas, munição,
## silenciador, chaves, tiros, tempo) e o mundo como está (quem morreu, portas, baús, caixa de paraquedas, alçapão, chave e
## cartões, itens do chão e os largados, caixotes de explosivos, cenas já tocadas). No Game Over, CONTINUAR volta ao último:
## o mundo como foi gravado e ela no lugar de renascer daquela área (`SPAWNS`). R / REINICIAR do menu recomeçam do zero.
##   yard        abriu o portão do galpão para o pátio dos velociraptors
##   trail       matou os 3 raptors da emboscada (S1 da trilha; o primeiro portão de grade destravou)
##   trail2      limpou S2 (os 7 dos trechos)
##   standoff    limpou S3 (os 9; daqui em diante a rendição aos snipers toca sem parar o jogo)
##   tunnel      abriu o portão do teclado, do pátio para a mina
##   allosaurus  passou pelo portão arrombado e chegou à pedreira do alossauro
## Quem morreu antes do checkpoint volta fora do jogo (`Enemy.clear_out`), sem corpo; os vivos voltam calmos ao posto.
## Fogo, fumaça, sangue e buracos de bala não voltam. Só vale na partida aberta (não vai para arquivo).

const ORDER := ["yard", "trail", "trail2", "standoff", "tunnel", "allosaurus"]
const NAMES := {"yard": "PÁTIO", "trail": "PÁTIO", "trail2": "PÁTIO", "standoff": "PÁTIO", "tunnel": "MINA", "allosaurus": "PEDREIRA"}
## onde ela renasce em cada um: [pé, giro (rotation.y; PI/2 = olhando para oeste, para dentro da fase)]
const SPAWNS := {
	"yard": [Vector3(-15.5, 0, Yard.DOOR_Z), PI * 0.5],  # do lado do pátio do portão do galpão
	"trail": [Vector3(-22.5, 0, -36.5), PI * 0.5],  # no fim de S1, de frente para o primeiro portão de grade
	"trail2": [Vector3(-36.0, 0, -4.0), PI],  # no fim de S2, de frente para o portão do meio
	"standoff": [Vector3(-38.0, 0, 36.5), PI * 0.5],  # no fim de S3, de frente para o último portão de grade
	"tunnel": [Vector3(Tunnel.X_NEAR - 2.5, 0, Tunnel.Z), PI * 0.5],  # na boca da mina
	"allosaurus": [Vector3(Tunnel.X_FAR - 0.8, 0, Tunnel.Z), PI * 0.5],  # logo depois do portão arrombado
}


static func rank(id: String) -> int:
	return ORDER.find(id)


## Tudo o que o checkpoint `id` precisa para voltar (ver o cabeçalho).
static func capture(main: Node, id: String) -> Dictionary:
	var p: Player = main.player
	var data := {
		"id": id,
		"player": {"health": p.health, "weapons": p.weapons.duplicate(), "silencer": p.silencer, "keys": p.keys.duplicate(),
			"ammo": p.ammo.duplicate(), "weapon": p.weapon(), "shots": p.shots_fired},
		"play_t": main._play_t,
		"smelled": main.smelled,
		"standoff_armed": main.standoff_armed,
		"standoff_t": main._standoff_t,
		"towers": [main.towers_armed, main.towers_up],
		"corpse_armed": main.corpse.armed,
		"lab_played": main.lab.played,
		"hatch": main.hatch.opened,
		"drop": main.drop.save_state(),
		"chests": main.chests.map(func(c: Chest) -> Dictionary: return c.save_state()),
		"doors": _doors(main).map(func(d: Door) -> Dictionary: return d.save_state()),
		"keys": _key_items(main).map(func(k: KeyItem) -> Dictionary: return k.save_state()),
		"crates": _crates(main).map(func(c: ExplosiveCrate) -> bool: return c.exploded),
		"tunnel": {"breached": main.tunnel.is_breached, "talk": main.tunnel.talk_armed, "lair": main.tunnel.lair_armed},
		"enemies": main.all_enemies().map(func(e: Enemy) -> Dictionary: return {"dead": e.dead, "lurking": e.lurking}),
		"taken": [],
		"drops": [],
	}
	for pk: Pickup in main.get_tree().get_nodes_in_group("pickups"):
		if pk.is_queued_for_deletion():
			continue
		if pk.is_drop:
			if not pk.taken:
				data.drops.append({"kind": pk.kind, "amount": pk.amount, "weapon": pk.is_weapon, "at": pk._home})
		elif pk.taken:
			data.taken.append(pk._home)
	return data


## Põe o mundo e a jogadora como estavam no checkpoint `data` (o `main` já recomeçou o mundo do zero antes).
static func restore(main: Node, data: Dictionary) -> void:
	var p: Player = main.player
	var s: Dictionary = data.player
	var spawn: Array = SPAWNS[data.id]
	p.weapons.assign(s.weapons)
	p.silencer = s.silencer
	p.keys.assign(s.keys)
	p.ammo = (s.ammo as Dictionary).duplicate()
	p.model.set_weapon(s.weapon)
	p.health = s.health
	p.health_changed.emit(p.health)
	p.shots_fired = s.shots
	p.global_position = spawn[0]
	p.rotation = Vector3(0, spawn[1], 0)
	p.reset_physics_interpolation()
	p.camera_rig.reset_view(p.rotation.y)
	main._play_t = data.play_t
	main.smelled = data.smelled
	main.standoff_armed = data.standoff_armed
	main._standoff_t = data.standoff_t
	main.towers_armed = data.towers[0]
	main.towers_up = data.towers[1]
	main.corpse.armed = data.corpse_armed
	main.lab.played = data.lab_played
	main.hatch.load_open(data.hatch)
	main.drop.load_state(data.drop)
	for i in main.chests.size():
		main.chests[i].load_state(data.chests[i])
	var doors := _doors(main)
	for i in doors.size():
		doors[i].load_state(data.doors[i])
	var keys := _key_items(main)
	for i in keys.size():
		keys[i].load_state(data.keys[i])
	var crates := _crates(main)
	for i in crates.size():
		crates[i].load_exploded(data.crates[i])
	main.tunnel.is_breached = data.tunnel.breached
	main.tunnel.talk_armed = data.tunnel.talk
	main.tunnel.lair_armed = data.tunnel.lair
	var enemies: Array = main.all_enemies()
	for i in enemies.size():
		var e: Enemy = enemies[i]
		var es: Dictionary = data.enemies[i]
		if es.dead:
			e.clear_out()
		elif e is Sniper and e in main.tower_snipers and not es.lurking:
			(e as Sniper).appear()
		elif e is Raptor and e in main.yard_raptors and not es.lurking:
			e.reset()  # a emboscada já tinha tocado: de volta à rota do pátio, fora da moita
	main.trail.restore()
	main.refresh_tower_loot()
	for pk: Pickup in main.get_tree().get_nodes_in_group("pickups"):
		if not pk.is_drop and pk._home in data.taken:
			pk.taken = true
			pk.visible = false
	for d: Dictionary in data.drops:
		Pickup.spawn_drop(main, d.at + Vector3.UP * 0.3, d.kind, d.amount, d.weapon)


## Portas na ordem do grupo (a mesma da montagem da fase).
static func _doors(main: Node) -> Array[Door]:
	var out: Array[Door] = []
	out.assign(main.get_tree().get_nodes_in_group("doors"))
	return out


static func _crates(main: Node) -> Array[ExplosiveCrate]:
	var out: Array[ExplosiveCrate] = []
	out.assign(main.get_tree().get_nodes_in_group("explosives"))
	return out


## Chave do container, cartão do painel do portão e cartão do sniper do mezanino.
static func _key_items(main: Node) -> Array[KeyItem]:
	var out: Array[KeyItem] = [main.key, main.gate_card]
	if is_instance_valid(main.keycard):
		out.append(main.keycard)
	return out

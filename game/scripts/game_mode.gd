class_name GameMode
## Perfil de jogo: "survival" (padrão) é o jogo de sobrevivência no estilo RE4 Remake + Dino Crisis 2; "arcade" é o jogo de
## ação frenética de antes (câmera livre, munição infinita, mira temporária ao atirar, dano normal), mantido inteiro e
## testado para servir de base a outro jogo. F3 alterna no jogo e `--mode=arcade|survival` escolhe ao abrir.
##
## O que muda em "survival":
##   - câmera por cima do ombro direito, sem voltar sozinha para trás dela; mirando, chega mais perto e a mira fica lenta;
##   - ela anda e corre mais devagar (`move_scale`), com uma corrida forte segurando SHIFT ou o analógico (L3), mas sem ser
##     de velocista, e a esquiva (X / espaço) é um pulinho curto para o lado ou para trás em vez da cambalhota
##     (`short_dodge`, PlayerMoves.start_dodge; clique duplo no X = cambalhota), com intervalo (`roll_cooldown`);
##   - a mira (retícula) só existe com o botão de mirar apertado, e só atira mirando (nada de tiro "do quadril");
##   - cada arma manda no movimento enquanto ela mira (`SURVIVAL_WEAPONS`), sem ela precisar parar: pistola corre e atira com
##     recuo mínimo, M16 vira andar devagar e atira com recuo médio, escopeta trava o movimento sozinha (só gira a mira);
##   - munição limitada por arma (`START_AMMO`, `WEAPON_AMMO`, caixas em `Pickup.LAYOUT`) e kits de vida;
##   - os inimigos machucam o dobro (`enemy_damage`).

const ARCADE := "arcade"
const SURVIVAL := "survival"
const MODES := [SURVIVAL, ARCADE]

const PROFILES := {
	ARCADE: {
		"shoulder_cam": false, "move_scale": 1.0, "roll_cooldown": 0.0, "short_dodge": false, "aim_to_shoot": false,
		"weapon_handling": false, "limited_ammo": false, "enemy_damage": 1.0, "pickups": false, "sprint": false,
	},
	SURVIVAL: {
		"shoulder_cam": true, "move_scale": 0.8, "roll_cooldown": 1.4, "short_dodge": true, "aim_to_shoot": true,
		"weapon_handling": true, "limited_ammo": true, "enemy_damage": 2.0, "pickups": true, "sprint": true,
	},
}

## Munição que ela tem ao começar (e ao reiniciar), a que vem junto ao pegar a arma no baú e o máximo que carrega.
const START_AMMO := {"pistol": 10, "m16": 0, "shotgun": 0, "m79": 0}
const WEAPON_AMMO := {"pistol": 0, "m16": 15, "shotgun": 5, "m79": 4}
const AMMO_CAP := {"pistol": 40, "m16": 90, "shotgun": 20, "m79": 10}

## Valores das armas que mudam em "survival" (os do "arcade" estão em Player.WEAPON_STATS). Além dos de lá: `aim_speed` =
## velocidade máxima enquanto o botão de mirar está apertado (m/s; 0 = o movimento trava sozinho, ela só gira a mira); `lock`/
## `lock_slow` = depois de cada tiro, por `lock` s a velocidade vira `lock_slow` vezes a de antes; `kick` = coice na câmera
## (radianos); `move_spread` = dispersão a mais (graus) se ela está andando.
const SURVIVAL_WEAPONS := {
	"pistol": {"cooldown": 0.42, "bloom": 0.35, "max_spread": 1.2, "shake": 0.012, "kick": 0.012, "move_spread": 0.8,
		"aim_speed": 2.8, "lock": 0.0, "lock_slow": 1.0},
	"m16": {"cooldown": 0.13, "bloom": 1.3, "max_spread": 5.0, "shake": 0.04, "kick": 0.022, "move_spread": 2.0,
		"aim_speed": 1.5, "lock": 0.25, "lock_slow": 0.55},
	"shotgun": {"cooldown": 1.1, "shake": 0.2, "kick": 0.09, "move_spread": 3.0, "aim_speed": 0.0, "lock": 0.6, "lock_slow": 0.0},
	# M79: pesada, um tiro por vez (quebra o cano para recarregar): anda devagar mirando e o coice a segura no lugar
	"m79": {"cooldown": 1.9, "shake": 0.16, "kick": 0.11, "move_spread": 0.0, "aim_speed": 1.0, "lock": 0.8, "lock_slow": 0.0},
}
## o que as armas têm no "arcade" para as chaves acima
const HANDLING_DEFAULTS := {"kick": 0.0, "move_spread": 0.0, "aim_speed": 99.0, "lock": 0.0, "lock_slow": 1.0}

static var mode := SURVIVAL


static func set_mode(m: String) -> void:
	assert(m in MODES, "modo de jogo desconhecido: " + m)
	mode = m


static func is_survival() -> bool:
	return mode == SURVIVAL


static func value(key: String) -> Variant:
	return PROFILES[mode][key]


static func shoulder_cam() -> bool:
	return value("shoulder_cam")


static func move_scale() -> float:
	return value("move_scale")


static func roll_cooldown() -> float:
	return value("roll_cooldown")


## Botão de esquiva = pulinho curto de lado/para trás (survival) em vez da cambalhota (arcade).
static func short_dodge() -> bool:
	return value("short_dodge")


static func aim_to_shoot() -> bool:
	return value("aim_to_shoot")


static func weapon_handling() -> bool:
	return value("weapon_handling")


static func limited_ammo() -> bool:
	return value("limited_ammo")


## SHIFT / apertar o analógico = corrida forte (`Player.SPRINT_SPEED`); o andar devagar do teclado passa para ALT.
static func sprint() -> bool:
	return value("sprint")


static func pickups() -> bool:
	return value("pickups")


## Dano de um golpe/tiro de inimigo já na escala do modo.
static func enemy_damage(amount: int) -> int:
	return maxi(1, roundi(amount * float(value("enemy_damage"))))


## Números da arma `kind` neste modo: os de `base` (Player.WEAPON_STATS) com os do perfil por cima.
static func weapon_stats(kind: String, base: Dictionary) -> Dictionary:
	var s := base.duplicate()
	s.merge(HANDLING_DEFAULTS)
	if weapon_handling():
		s.merge(SURVIVAL_WEAPONS[kind], true)
	return s

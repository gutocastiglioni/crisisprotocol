class_name Moves
## Medidas e caminhos da raiz dos movimentos animados (cambalhota, subir da borda, escalar obstáculo, pegar o
## fuzil), gerados pelo build da arte (art/heroine_moves.py -> heroine_moves.json). A interpolação é a mesma do
## Blender (`hermite`): a cápsula anda exatamente o que o corpo animado anda, sem escorregar.

const DATA_PATH := "res://assets/characters/heroine_moves.json"

static var _data: Dictionary


static func data() -> Dictionary:
	if _data.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		# o arquivo vem do build da arte; sem ele (build parcial) nada dos movimentos funciona: falha uma vez, alto
		assert(v is Dictionary and v.has_all(["fps", "speeds", "roll", "dodge", "hang", "climb", "mantle", "rifle", "shotgun", "assassinate", "crit_strike"]),
			DATA_PATH + " ausente ou incompleto: rode o build da arte (ver CLAUDE.md)")
		_data = v
	return _data


static func fps() -> float:
	return float(data().fps)


## Velocidade do chão em que cada ciclo de passo foi resolvido ("walk", "crouch_walk", "strafe", "crouch_strafe").
static func speed(gait: String) -> float:
	return float(data().speeds[gait])


static func _slopes(fr: Array, vals: Array) -> Array:
	var n := vals.size()
	var s := []
	s.resize(n)
	s.fill(0.0)
	for i in range(1, n - 1):
		var d0: float = (vals[i] - vals[i - 1]) / (fr[i] - fr[i - 1])
		var d1: float = (vals[i + 1] - vals[i]) / (fr[i + 1] - fr[i])
		if d0 * d1 > 0.0:
			var lim := 3.0 * minf(absf(d0), absf(d1))
			s[i] = clampf((vals[i + 1] - vals[i - 1]) / (fr[i + 1] - fr[i - 1]), -lim, lim)
	return s


static func hermite(fr: Array, vals: Array, f: float) -> float:
	if f <= fr[0]:
		return vals[0]
	if f >= fr[-1]:
		return vals[-1]
	var i := 0
	while fr[i + 1] <= f:
		i += 1
	var h: float = fr[i + 1] - fr[i]
	var t: float = (f - fr[i]) / h
	var s := _slopes(fr, vals)
	var t2 := t * t
	var t3 := t2 * t
	return ((2 * t3 - 3 * t2 + 1) * vals[i] + (t3 - 2 * t2 + t) * h * s[i]
		+ (-2 * t3 + 3 * t2) * vals[i + 1] + (t3 - t2) * h * s[i + 1])


## Caminho [[quadro, frente, cima], ...] no quadro f: Vector2(frente, cima) em metros.
static func path_at(path: Array, f: float) -> Vector2:
	var fr := []
	var a := []
	var b := []
	for k in path:
		fr.append(float(k[0]))
		a.append(float(k[1]))
		b.append(float(k[2]))
	return Vector2(hermite(fr, a, f), hermite(fr, b, f))


## Caminho do escalar obstáculo baixo: parado, salto até a raiz de contato (hop) e o resto relativo a ela.
static func mantle_path(hop_fwd: float, hop_up: float) -> Array:
	var m: Dictionary = data().mantle
	var out := [[0, 0.0, 0.0], [m.hop[0], 0.0, 0.0]]
	for k in m.rel:
		out.append([k[0], k[1] + hop_fwd, k[2] + hop_up])
	return out

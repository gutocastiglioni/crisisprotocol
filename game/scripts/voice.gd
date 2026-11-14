class_name Voice
## Falas dos guerrilheiros (WAV de tools/make_voices.py em assets/voices/<voz>_<fala>_<n>.wav). Quem tem `Enemy.voice`
## fala nos momentos do alerta (`Enemy._voice_on`): "Ahn?" ao desconfiar, "Ali!" ao vê-la, "Cadê ela?" ao perdê-la...
## Com muitos inimigos não vira falatório: uma fala por vez no jogo todo (a mais importante corta a menos importante,
## `PRIORITY`), cada tipo de fala com intervalo próprio (`GAP`), nunca a mesma frase duas vezes seguidas da mesma voz,
## e só fala quem ela ouviria (mesma sala ou portas abertas, até `MAX_DIST`).

const DIR := "res://assets/voices/"
const VOICES := ["cadu", "faber", "jeff"]
## fala -> quantas variações, normais + furiosas (tem que bater com LINES de make_voices.py; voice_tests confere os
## arquivos). O sorteio é entre todas: às vezes sai a furiosa ("Ali, desgraçada!"). "taunt" = provocação no tiroteio,
## "down" = o tiro dele a matou.
const LINES := {"huh": 4, "check": 3, "nothing": 3, "spot": 7, "lost": 5, "search": 5, "corpse": 5, "hit": 5,
	"giveup": 4, "ack": 5, "taunt": 5, "down": 4}
## mais alto corta a fala que estiver tocando; igual ou mais baixo espera a vez (e se perde)
const PRIORITY := {"down": 6, "spot": 5, "hit": 5, "corpse": 4, "lost": 3, "search": 3, "ack": 2, "giveup": 2,
	"taunt": 2, "huh": 1, "check": 1, "nothing": 1}
## segundos mínimos entre duas falas do mesmo tipo (de qualquer um)
const GAP := {"down": 2.0, "spot": 2.5, "hit": 3.0, "corpse": 3.0, "lost": 5.0, "search": 6.0, "ack": 4.0, "giveup": 8.0,
	"taunt": 7.0, "huh": 4.0, "check": 5.0, "nothing": 6.0}
const AFTER := 0.4  # silêncio depois de cada fala antes da próxima
const MAX_DIST := 35.0
const UNIT := 4.0  # distância até onde a fala toca cheia (AudioStreamPlayer3D.unit_size)
const DB := 0.0

## quantas vezes cada fala tocou (testes e conferência)
static var played := {}
static var _busy_until := -1.0
static var _busy_prio := 0
static var _speaking: WeakRef
static var _last_cat := {}  # fala -> quando tocou por último
static var _last_line := {}  # "voz_fala" -> número da última frase
static var _next := 0
static var _streams := {}


## Voz da próxima pessoa criada (gira entre as VOICES).
static func assign() -> String:
	_next += 1
	return VOICES[(_next - 1) % VOICES.size()]


## Esquece quem falou (reinício e testes).
static func reset() -> void:
	played.clear()
	_busy_until = -1.0
	_busy_prio = 0
	_speaking = null
	_last_cat.clear()
	_last_line.clear()


static func path(voice: String, cat: String, i: int) -> String:
	return DIR + "%s_%s_%d.wav" % [voice, cat, i]


## Relógio do jogo (passos de física): igual com `--fixed-fps` e com o jogo pausado.
static func now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second


## `e` diz uma fala do tipo `cat`, se der (ver o cabeçalho). Devolve se falou.
static func say(e: Enemy, cat: String) -> bool:
	if e == null or e.voice == "" or e.dead or e.lurking or not e.is_inside_tree() or not LINES.has(cat):
		return false
	var p: Player = e.target
	if p == null or not is_instance_valid(p) or p.cutscene:
		return false
	if e.global_position.distance_to(p.global_position) > MAX_DIST or not e._reaches(p.global_position):
		return false
	var t := now()
	if t - float(_last_cat.get(cat, -INF)) < float(GAP[cat]):
		return false
	var prio: int = PRIORITY[cat]
	if t < _busy_until and prio <= _busy_prio:
		return false
	if t < _busy_until and _speaking:
		var old: AudioStreamPlayer3D = _speaking.get_ref()
		if old:
			old.queue_free()  # a mais importante corta a que estava tocando
	var key: String = e.voice + "_" + cat
	var n: int = LINES[cat]
	var i := randi_range(1, n)
	if n > 1 and i == int(_last_line.get(key, 0)):
		i = i % n + 1
	_last_line[key] = i
	var file := path(e.voice, cat, i)
	var st: AudioStreamWAV = _streams.get(file)
	if st == null:
		st = load(file)
		_streams[file] = st
	var a := AudioStreamPlayer3D.new()
	a.stream = st
	a.volume_db = DB
	a.unit_size = UNIT
	a.max_distance = MAX_DIST + 10.0
	a.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
	a.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	a.position = Vector3.UP * e.eye_height
	e.add_child(a)
	a.play()
	var length := st.get_length() / a.pitch_scale
	var ref: WeakRef = weakref(a)  # o mundo pode sumir antes (reinício, teste): sem prender o tocador na lambda
	e.get_tree().create_timer(length + 0.1).timeout.connect(func() -> void:
		var node: Node = ref.get_ref()
		if node:
			node.queue_free())
	_speaking = ref
	_busy_until = t + length + AFTER
	_busy_prio = prio
	_last_cat[cat] = t
	played[cat] = int(played.get(cat, 0)) + 1
	return true

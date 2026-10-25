class_name Sfx
## Efeitos sonoros (WAV gerados por tools/make_sounds.py em assets/sounds/): toca um som no mundo, preso a um nó
## (anda junto com ele) ou num ponto, com volume, alcance e uma pequena variação de tom em cada vez. Sons com
## variações (`n` > 0: passos, impactos, cápsulas) sorteiam uma delas. Avisos de interface (`ui`) tocam sem posição.
## Muitos iguais no mesmo quadro (8 chumbos da escopeta) tocam no máximo MAX_PER_FRAME vezes.

const DIR := "res://assets/sounds/"
## nome -> variações (0 = arquivo único), volume (dB), distância até onde toca cheio (m), alcance (m) e sorteio de tom
const SOUNDS := {
	"pistol_shot": {"n": 0, "db": 0.0, "unit": 6.0, "max": 80.0, "pitch": 0.05},
	"pistol_sd_shot": {"n": 0, "db": -6.0, "unit": 2.0, "max": 18.0, "pitch": 0.06},
	"m16_shot": {"n": 0, "db": -2.0, "unit": 6.0, "max": 80.0, "pitch": 0.06},
	"shotgun_shot": {"n": 0, "db": 2.0, "unit": 7.0, "max": 90.0, "pitch": 0.04},
	"sniper_shot": {"n": 0, "db": 3.0, "unit": 8.0, "max": 110.0, "pitch": 0.04},
	"shotgun_pump_back": {"n": 0, "db": -6.0, "unit": 2.0, "max": 20.0, "pitch": 0.03},
	"shotgun_pump_fwd": {"n": 0, "db": -5.0, "unit": 2.0, "max": 20.0, "pitch": 0.03},
	"weapon_switch": {"n": 0, "db": -8.0, "unit": 1.5, "max": 12.0, "pitch": 0.05},
	"weapon_pickup": {"n": 0, "db": -6.0, "unit": 1.5, "max": 12.0, "pitch": 0.03},
	"dry_fire": {"n": 0, "db": -4.0, "unit": 1.5, "max": 15.0, "pitch": 0.04},
	"chest_open": {"n": 0, "db": -2.0, "unit": 2.0, "max": 20.0, "pitch": 0.05},
	"m79_shot": {"n": 0, "db": 1.0, "unit": 6.0, "max": 70.0, "pitch": 0.04},
	"explosion": {"n": 0, "db": 6.0, "unit": 12.0, "max": 140.0, "pitch": 0.06},
	"key_drop": {"n": 0, "db": -6.0, "unit": 1.5, "max": 15.0, "pitch": 0.06},
	"lock_rattle": {"n": 0, "db": -3.0, "ui": true},
	"unlock": {"n": 0, "db": -3.0, "ui": true},
	"item_get": {"n": 0, "db": -6.0, "ui": true},
	"keypad_beep": {"n": 0, "db": -10.0, "ui": true},
	"keypad_error": {"n": 0, "db": -8.0, "ui": true},
	"keypad_ok": {"n": 0, "db": -6.0, "ui": true},
	"casing_brass": {"n": 3, "db": -16.0, "unit": 1.0, "max": 12.0, "pitch": 0.08},
	"casing_shell": {"n": 2, "db": -12.0, "unit": 1.0, "max": 12.0, "pitch": 0.06},
	"impact_concrete": {"n": 3, "db": -8.0, "unit": 2.0, "max": 30.0, "pitch": 0.1},
	"impact_metal": {"n": 3, "db": -8.0, "unit": 2.0, "max": 30.0, "pitch": 0.08},
	"impact_wood": {"n": 2, "db": -8.0, "unit": 2.0, "max": 30.0, "pitch": 0.1},
	"impact_flesh": {"n": 3, "db": -4.0, "unit": 2.0, "max": 25.0, "pitch": 0.1},
	"step_concrete": {"n": 4, "db": -6.0, "unit": 1.5, "max": 25.0, "pitch": 0.08},
	"step_grass": {"n": 4, "db": -6.0, "unit": 1.5, "max": 25.0, "pitch": 0.08},
	"raptor_step": {"n": 3, "db": -3.0, "unit": 2.5, "max": 35.0, "pitch": 0.08},
	"roll": {"n": 0, "db": -6.0, "unit": 2.0, "max": 25.0, "pitch": 0.05},
	"jump": {"n": 0, "db": -8.0, "unit": 2.0, "max": 20.0, "pitch": 0.06},
	"land": {"n": 0, "db": -4.0, "unit": 2.0, "max": 25.0, "pitch": 0.06},
	"ledge_grab": {"n": 0, "db": -5.0, "unit": 2.0, "max": 20.0, "pitch": 0.05},
	"climb": {"n": 0, "db": -8.0, "unit": 2.0, "max": 20.0, "pitch": 0.04},
	"body_fall": {"n": 0, "db": -2.0, "unit": 2.5, "max": 30.0, "pitch": 0.06},
	"claw_hit": {"n": 0, "db": 0.0, "unit": 3.0, "max": 30.0, "pitch": 0.06},
	"raptor_roar": {"n": 0, "db": 4.0, "unit": 8.0, "max": 100.0, "pitch": 0.06},
	"raptor_screech": {"n": 0, "db": 2.0, "unit": 6.0, "max": 70.0, "pitch": 0.06},
	"raptor_snarl": {"n": 0, "db": 0.0, "unit": 4.0, "max": 50.0, "pitch": 0.06},
	"raptor_hiss": {"n": 0, "db": -6.0, "unit": 3.0, "max": 25.0, "pitch": 0.06},
	"raptor_chirp": {"n": 2, "db": -4.0, "unit": 5.0, "max": 50.0, "pitch": 0.08},
	"raptor_suspicious": {"n": 0, "db": -2.0, "unit": 5.0, "max": 50.0, "pitch": 0.06},
	"raptor_bite": {"n": 0, "db": 2.0, "unit": 3.0, "max": 40.0, "pitch": 0.05},
	"raptor_shake": {"n": 0, "db": 2.0, "unit": 3.0, "max": 40.0, "pitch": 0.04},
	"raptor_hurt": {"n": 2, "db": 2.0, "unit": 5.0, "max": 60.0, "pitch": 0.07},
	"raptor_death": {"n": 0, "db": 3.0, "unit": 6.0, "max": 80.0, "pitch": 0.04},
	"tail_whoosh": {"n": 0, "db": -2.0, "unit": 3.0, "max": 25.0, "pitch": 0.08},
	"alert": {"n": 0, "db": -4.0, "ui": true},
	"suspicious": {"n": 0, "db": -10.0, "ui": true},
	"amb_yard": {"n": 0, "db": -8.0, "ui": true, "loop": true},
	"amb_warehouse": {"n": 0, "db": -14.0, "ui": true, "loop": true},
}
const MAX_PER_FRAME := 3

## quantas vezes cada som tocou (testes e conferência)
static var played := {}
static var _streams := {}
static var _frame := -1
static var _frame_counts := {}


## Arquivo do som `name` (variação `i`, de 1 a n; 0 = sorteia). Ambiente já vem em loop.
static func stream(name: String, i := 0) -> AudioStreamWAV:
	var s: Dictionary = SOUNDS[name]
	var n := int(s.n)
	if n > 0 and i <= 0:
		i = randi_range(1, n)
	var path := DIR + name + ("_%d" % i if n > 0 else "") + ".wav"
	var st: AudioStreamWAV = _streams.get(path)
	if st == null:
		st = load(path)
		if s.get("loop", false):
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(st.get_length() * st.mix_rate)
		_streams[path] = st
	return st


## Toca `name` preso a `node` (anda junto com ele); com `at`, começa naquele ponto do mundo. `db` soma ao volume
## da tabela e `pitch` multiplica o tom; `delay` = segundos até tocar. Devolve o tocador (ou null se não tocou).
static func play(node: Node3D, name: String, at: Variant = null, db := 0.0, pitch := 1.0, delay := 0.0) -> AudioStreamPlayer3D:
	if node == null or not node.is_inside_tree():
		return null
	if delay > 0.0:
		# referência fraca: o nó pode sumir antes (reinício, cena trocada)
		var ref: WeakRef = weakref(node)
		node.get_tree().create_timer(delay).timeout.connect(func() -> void:
			var n: Node3D = ref.get_ref()
			if n:
				play(n, name, at, db, pitch))
		return null
	if not _take_slot(name):
		return null
	var s: Dictionary = SOUNDS[name]
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = float(s.db) + db
	p.unit_size = float(s.unit)
	p.max_distance = float(s.max)
	p.pitch_scale = pitch * (1.0 + randf_range(-1.0, 1.0) * float(s.pitch))
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	node.add_child(p)
	if at is Vector3:
		p.global_position = at
	p.play()
	_free_after(p, p.stream.get_length() / p.pitch_scale)
	return p


## Aviso de interface (sem posição: "!" visto, "?" desconfiado).
static func ui(node: Node, name: String, db := 0.0) -> AudioStreamPlayer:
	if node == null or not node.is_inside_tree() or not _take_slot(name):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = float(SOUNDS[name].db) + db
	node.add_child(p)
	p.play()
	_free_after(p, p.stream.get_length())
	return p


## Passo em `at`: grama se o chão embaixo tem meta "step" = "grass" (pátio da mata), senão concreto.
static func step(node: Node3D, at: Vector3, db := 0.0) -> AudioStreamPlayer3D:
	return play(node, "step_" + ground(node, at), at, db)


## Tipo de chão sob `at` ("grass" ou "concrete").
static func ground(node: Node3D, at: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.6, 1)
	var hit := node.get_world_3d().direct_space_state.intersect_ray(q)
	if hit and (hit.collider as Node).get_meta("step", "") == "grass":
		return "grass"
	return "concrete"


static func _take_slot(name: String) -> bool:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_frame_counts.clear()
	var c: int = _frame_counts.get(name, 0)
	if c >= MAX_PER_FRAME:
		return false
	_frame_counts[name] = c + 1
	played[name] = int(played.get(name, 0)) + 1
	return true


static func _free_after(p: Node, sec: float) -> void:
	p.get_tree().create_timer(sec + 0.1).timeout.connect(p.queue_free)

class_name Fire
extends Node3D
## Incêndio depois da explosão dos caixotes (`ExplosiveCrate`): línguas de fogo de frente para a câmera que tremem e sobem,
## luz laranja piscando e fumaça escura subindo, por `life` s, e depois apaga devagar (`FADE`). No chão (`burn`) machuca
## quem fica dentro dele (`radius`, `DPS` em toques de `TICK` s: jogadora, guarda ou raptor); num corpo (`attach`, presa a
## uma parte do ragdoll) segue o corpo caído e não machuca ninguém. R apaga tudo (`clear`).

const LIFE := 22.0  # s queimando no chão
const BODY_LIFE := 12.0  # s queimando num corpo
const FADE := 3.0  # s apagando no fim
const DPS := 10.0  # dano por segundo dentro do fogo do chão
const TICK := 0.5
const FLAME := Color(1.0, 0.55, 0.18, 0.9)
const CORE := Color(1.0, 0.85, 0.45, 0.95)
const MAX_FIRES := 24  # os mais antigos apagam

var radius := 0.6
var life := LIFE
var hurts := true
var follow: Node3D  # parte do corpo que ela acompanha (attach)
var _t := 0.0
var _tick := 0.0
var _smoke_t := 0.0
var _flames: Array = []  # [MeshInstance3D, fase, base (Vector3), altura]
var _light: OmniLight3D
var _energy := 2.2


## Fogo no chão em `at`, de raio `r` (m).
static func burn(parent: Node, at: Vector3, r := 0.6, duration := LIFE) -> Fire:
	var f := Fire.new()
	f.radius = r
	f.life = duration
	parent.add_child(f)
	f.global_position = at
	return f


## Fogo preso a `part` (osso do ragdoll): segue o corpo, sem machucar.
static func attach(parent: Node, part: Node3D, r := 0.25, duration := BODY_LIFE) -> Fire:
	var f := Fire.new()
	f.radius = r
	f.life = duration
	f.hurts = false
	f.follow = part
	f._energy = 0.8
	parent.add_child(f)
	f.global_position = part.global_position
	return f


static func clear(tree: SceneTree) -> void:
	for f in tree.get_nodes_in_group("fires"):
		f.queue_free()


func _ready() -> void:
	add_to_group("fires")
	top_level = true
	var all := get_tree().get_nodes_in_group("fires")
	if all.size() > MAX_FIRES:
		all[0].queue_free()
	var n := clampi(roundi(radius * 9.0), 2, 9)
	for i in n:
		var a := randf() * TAU
		var d := sqrt(randf()) * radius * 0.8
		var size := radius * randf_range(0.9, 1.4) + 0.15
		var core := i % 3 == 0
		var mi := Fx._quad(size, CORE if core else FLAME, Fx.BURST if core else Fx.PUFF, true)
		add_child(mi)
		_flames.append([mi, randf() * TAU, Vector3(cos(a) * d, size * 0.4, sin(a) * d), size])
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 2.0 + radius * 5.0
	_light.light_energy = _energy
	_light.position.y = 0.4
	add_child(_light)


func _physics_process(delta: float) -> void:
	_t += delta
	if follow != null:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position
	var k := 1.0 if _t < life else 1.0 - (_t - life) / FADE  # força do fogo (apaga no fim)
	if k <= 0.0:
		queue_free()
		return
	for f in _flames:
		var mi: MeshInstance3D = f[0]
		var ph: float = f[1]
		var h: float = f[3]
		# tremida: cada língua cresce, encolhe e sobe no seu ritmo
		var w := 0.75 + 0.25 * sin(_t * 9.0 + ph) + 0.12 * sin(_t * 23.0 + ph * 2.0)
		mi.scale = Vector3(w, w * (1.0 + 0.3 * sin(_t * 6.0 + ph)), w) * k
		mi.position = f[2] + Vector3(0, h * 0.15 * sin(_t * 5.0 + ph), 0)
	_light.light_energy = _energy * k * (0.8 + 0.2 * sin(_t * 17.0) + 0.1 * sin(_t * 41.0))
	_smoke_t -= delta
	if _smoke_t <= 0.0 and k > 0.3:
		_smoke_t = randf_range(0.25, 0.45) / maxf(radius * 2.0, 0.5)
		var v := Vector3(randf_range(-0.2, 0.2), randf_range(0.9, 1.5), randf_range(-0.2, 0.2))
		Fx._particle(get_parent(), global_position + Vector3(randf_range(-radius, radius) * 0.5, radius + 0.3, randf_range(-radius, radius) * 0.5),
			v, 0.5 + radius * 0.4, Color(0.13, 0.12, 0.11, 0.55), randf_range(1.8, 2.8), 4.0, -0.04)
	if hurts and k > 0.5:
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_scorch_people()


## Quem está dentro do fogo do chão leva um toque de dano.
func _scorch_people() -> void:
	var dmg := maxi(1, roundi(DPS * TICK))
	for who: Node in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if not (who is Node3D) or who.get("dead") or who.get("lurking") or not who.has_method("take_hit"):
			continue
		var p := (who as Node3D).global_position
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + 0.3 and absf(p.y - global_position.y) < 1.0:
			var dir := Vector3(p.x - global_position.x, 0, p.z - global_position.z).normalized()
			who.take_hit(dmg, dir if dir.length() > 0.1 else Vector3.FORWARD, p + Vector3.UP * 0.5)

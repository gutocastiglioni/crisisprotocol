class_name SubjectPlate
extends Node3D
## Plaqueta "SUBJECT XXXX" num pedestal na frente de um tubo da sala dos clones (CloneLab): número, espécie e estado.
## Ela chega perto pela frente e aperta interagir (`Player.pick_plate`): o sinal `Player.read_plate` faz o main abrir
## `Inspect.plate_zoom` (a câmera vai até a plaqueta e a ficha aparece embaixo). Frente = +Z local (o lado de quem lê).

const READ_RANGE := 1.4  # do pé do pedestal até ela, no chão
const POST_H := 1.0
const PLATE := Vector3(0.44, 0.27, 0.025)
const TILT := 50.0  # graus para trás: virada para cima e para quem lê, como um painel de leitura
const VIEW_DIST := 0.95
const INK := Color(0.95, 0.82, 0.35)

var number := "0000"
var species := ""
var status := ""
var empty := false  # o tanque dele está vazio: LED e estado em vermelho
var _face: Node3D


func _ready() -> void:
	add_to_group("plates")
	var metal := Level.material("wall", 2.0)
	var post := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.07, POST_H - 0.12, 0.07)  # acaba embaixo da plaqueta (não fura a frente)
	post.mesh = pb
	post.material_override = metal
	post.position = Vector3(0, (POST_H - 0.12) * 0.5, -0.04)
	add_child(post)
	var foot := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.3, 0.04, 0.24)
	foot.mesh = fb
	foot.material_override = metal
	foot.position.y = 0.02
	add_child(foot)
	_face = Node3D.new()
	_face.position.y = POST_H
	_face.rotation.x = -deg_to_rad(TILT)
	add_child(_face)
	var plate := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = PLATE
	plate.mesh = b
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.13, 0.14, 0.15)
	pm.metallic = 0.6
	pm.roughness = 0.4
	plate.material_override = pm
	_face.add_child(plate)
	var z := PLATE.z * 0.5 + 0.002
	_text("SUBJECT " + number, 40, Vector3(0, 0.06, z), INK)
	_text(species, 22, Vector3(0, -0.02, z), Color(0.8, 0.85, 0.85))
	_text(status, 22, Vector3(0, -0.08, z), Color(1.0, 0.3, 0.25) if empty else Color(0.4, 1.0, 0.5))
	# LED de estado no canto
	var led := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.025, 0.025, 0.01)
	led.mesh = lb
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1.0, 0.2, 0.15) if empty else Color(0.3, 1.0, 0.45)
	led.material_override = lm
	led.position = Vector3(PLATE.x * 0.5 - 0.03, PLATE.y * 0.5 - 0.03, z)
	_face.add_child(led)


func _text(s: String, size: int, at: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = s
	l.font_size = size
	l.pixel_size = 0.0016
	l.outline_size = 0
	l.modulate = color
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = at
	_face.add_child(l)


## Ela está na frente, perto o bastante para ler?
func can_read(pos: Vector3) -> bool:
	var local := to_local(pos)
	return local.z > 0.1 and Vector2(local.x, local.z).length() < READ_RANGE and absf(local.y) < 1.4


## Câmera da tela de inspeção: de frente para a plaqueta, a VIEW_DIST dela, mirando um pouco abaixo (a plaqueta fica
## acima da faixa de texto de baixo).
func view() -> Transform3D:
	var c := _face.global_position
	var eye := c + _face.global_basis.z * VIEW_DIST
	return Transform3D(Basis.looking_at(c - _face.global_basis.y * 0.12 - eye), eye)


func title() -> String:
	return "SUBJECT " + number


func body() -> String:
	return "%s\nESTADO: %s" % [species, status]

class_name GuardTower
extends Node3D
## Torre de guarda de madeira do pátio da mata, ao lado do portão do fundo (Yard.TOWERS, uma de cada lado): quatro pernas
## com X de reforço, plataforma em FLOOR_Y, parapeito de tábuas atrás e dos lados (cobre o sniper da cintura para baixo),
## guarda-corpo vazado na frente (virada para o pátio, +X local) e telhado de chapa. Sem escada: ninguém sobe. Em cima fica
## um sniper (Sniper com `perch` = `perch()`, encostado no guarda-corpo); o último a morrer se debruça na barra de cima
## (`ledge`, na altura do abdome) e cai por cima dela (Sniper.falls).

const SIZE := 2.6  # lado da plataforma
const FLOOR_Y := 4.2  # piso da plataforma
const WALL_H := 1.0  # parapeito
const RAIL_H := 1.1  # barra de cima do guarda-corpo da frente (no abdome de quem está encostado: dobra na cintura)
const POST_AHEAD := 0.6  # o sniper fica a isto do centro, para a frente (o último cambaleia daqui até a barra)
const RAIL_LAYER := 1 << 4  # camada só da barra da frente: segura o corpo mole (Sniper) sem empurrar a cápsula dele vivo
const ROOF_Y := FLOOR_Y + 2.3
const LEG := 0.22
const EDGE := 0.4  # o sniper anda até esta distância do parapeito de trás e dos lados (na frente, até encostar)


func _ready() -> void:
	var h := SIZE * 0.5
	var leg := h - LEG * 0.5
	var wood: Material = Level.material("crate", 0.5)
	# pernas inteiras do chão ao telhado e o X de reforço em cada face (só enfeite: tiro passa entre as tábuas)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Level.block(self, Vector3(LEG, ROOF_Y, LEG), Vector3(sx * leg, ROOF_Y * 0.5, sz * leg), "crate", 0.5)
	var low := 0.5
	var high := FLOOR_Y - 0.35
	for s in [-1, 1]:
		_beam(Vector3(s * leg, low, -leg), Vector3(s * leg, high, leg), wood)
		_beam(Vector3(s * leg, low, leg), Vector3(s * leg, high, -leg), wood)
		_beam(Vector3(-leg, low, s * leg), Vector3(leg, high, s * leg), wood)
		_beam(Vector3(leg, low, s * leg), Vector3(-leg, high, s * leg), wood)
	# plataforma, com uma viga embaixo de cada lado
	Level.block(self, Vector3(SIZE + 0.2, 0.2, SIZE + 0.2), Vector3(0, FLOOR_Y - 0.1, 0), "crate", 0.5)
	for s in [-1, 1]:
		_beam(Vector3(-h, FLOOR_Y - 0.3, s * leg), Vector3(h, FLOOR_Y - 0.3, s * leg), wood, Vector2(0.16, 0.2))
	# parapeito de tábuas atrás e dos lados (com colisão: o tiro de baixo para nele)
	Level.block(self, Vector3(0.08, WALL_H, SIZE), Vector3(-h + 0.04, FLOOR_Y + WALL_H * 0.5, 0), "crate", 0.5)
	for s in [-1, 1]:
		Level.block(self, Vector3(SIZE, WALL_H, 0.08), Vector3(0, FLOOR_Y + WALL_H * 0.5, s * (h - 0.04)), "crate", 0.5)
	# guarda-corpo vazado na frente: a barra de cima segura o corpo (o último sniper se debruça nela e cai por cima)
	var rail := Level.block(self, Vector3(0.08, 0.08, SIZE - LEG), Vector3(leg, FLOOR_Y + RAIL_H - 0.04, 0), "crate", 0.5)
	rail.collision_layer = RAIL_LAYER
	rail.physics_material_override = PhysicsMaterial.new()
	rail.physics_material_override.friction = 0.15  # madeira lisa: o corpo escorrega por cima dela
	_beam(Vector3(leg, FLOOR_Y + RAIL_H * 0.5, -leg), Vector3(leg, FLOOR_Y + RAIL_H * 0.5, leg), wood, Vector2(0.08, 0.08))
	# telhado de chapa e a lâmpada embaixo dele (o sniper aparece no escuro e na neblina)
	Level.block(self, Vector3(SIZE + 0.6, 0.1, SIZE + 0.6), Vector3(0, ROOF_Y + 0.05, 0), "wall", 0.5)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.2
	lamp.omni_range = 5.0
	lamp.position = Vector3(0, ROOF_Y - 0.35, 0)
	add_child(lamp)


## Onde o sniper fica (mundo): na frente da plataforma, olhando para o pátio.
func post() -> Vector3:
	return global_transform * Vector3(POST_AHEAD, FLOOR_Y, 0)


## Meio do alto da barra de cima do guarda-corpo da frente (mundo).
func ledge() -> Vector3:
	return global_transform * Vector3(SIZE * 0.5 - LEG * 0.5, FLOOR_Y + RAIL_H, 0)


## Para onde a frente da torre olha (yaw de quem fica no posto: -Z do corpo para +X local da torre).
func facing_yaw() -> float:
	return global_rotation.y - PI * 0.5


## Retângulo XZ (mundo) em que o sniper pode andar em cima da plataforma.
func perch() -> Rect2:
	var a := global_transform * Vector3(-SIZE * 0.5 + EDGE, 0, -SIZE * 0.5 + EDGE)
	var b := global_transform * Vector3(POST_AHEAD, 0, SIZE * 0.5 - EDGE)
	var r := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
	return r.expand(Vector2(b.x, b.z))


## Viga de madeira de `a` até `b` (seção `section`), só malha.
func _beam(a: Vector3, b: Vector3, mat: Material, section := Vector2(0.1, 0.1)) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(section.x, section.y, a.distance_to(b))
	mi.mesh = box
	mi.material_override = mat
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT), (a + b) * 0.5)
	add_child(mi)

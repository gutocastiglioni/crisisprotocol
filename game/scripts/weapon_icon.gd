class_name WeaponIcon
extends TextureRect
## Arma na mão no HUD (canto de baixo à direita): o modelo 3D dela de perfil, com o cano para a direita, desenhado numa
## SubViewport com mundo e luz próprios (câmera ortográfica) e mostrado em VIEW unidades do HUD de 320x240 (ampliado
## com ele; a imagem é renderizada a RES vezes isso e filtrada sem suavizar, pixelada como o resto). Armas longas e a
## pistola com silenciador vêm dos .glb soltos (já de perfil); a pistola comum é a malha "Pistol" do corpo dela.

const VIEW := Vector2(76, 30)
const RES := 2
const FIT := 0.94  # comprimento da arma em relação à largura da imagem
const ATLAS := preload("res://assets/characters/heroine_atlas.png")
const SCENES := {
	"m16": preload("res://assets/characters/m16.glb"),
	"shotgun": preload("res://assets/characters/shotgun.glb"),
	"m79": preload("res://assets/characters/m79.glb"),
	"sniper": preload("res://assets/characters/sniper.glb"),
	"pistol_sd": preload("res://assets/characters/pistol_sd.glb"),
}
## giro (graus) até ficar de perfil, cano para a direita e cabo para baixo: [em volta do Y do modelo, depois em volta do
## eixo da câmera]. Os .glb soltos já vêm assim; a pistola do corpo está no coldre, de cano para baixo.
const TURN := {"pistol": [90.0, 90.0]}

var kind := ""
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = VIEW
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.size = Vector2i(VIEW * RES)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.9
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 200, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.8, 1.0)
	_vp.add_child(fill)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = VIEW.y / VIEW.x  # altura visível: a largura fica 1 m (a arma é ajustada para FIT m)
	_cam.position = Vector3(0, 0, 2.0)
	_cam.current = true
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	texture = _vp.get_texture()
	# fundo escuro atrás da arma: a pistola cinza e o M16 escuro sumiam no chão escuro
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.4)
	back.size = VIEW
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	add_child(back)


## Mostra a arma `k` ("pistol", "pistol_sd", "m16", ...). `body` = o modelo dela, de onde sai a malha da pistola comum.
func show_weapon(k: String, body: HeroineModel) -> void:
	if k == kind:
		return
	kind = k
	for c in _pivot.get_children():
		_pivot.remove_child(c)
		c.queue_free()
	var gun: Node3D
	if SCENES.has(k):
		gun = SCENES[k].instantiate()
	else:
		var src := body.find_child("Pistol", true, false) as MeshInstance3D if body else null
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh if src else null
		gun = mi
	for mi in _meshes(gun):
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader()
		m.set_shader_parameter("albedo_tex", ATLAS)
		mi.material_override = m
	var holder := Node3D.new()
	holder.add_child(gun)
	var turn: Array = TURN.get(k, [0.0, 0.0])
	holder.basis = Basis(Vector3.BACK, deg_to_rad(turn[1])) * Basis(Vector3.UP, deg_to_rad(turn[0]))
	_pivot.add_child(holder)
	_fit(holder)


## Centraliza a arma girada na imagem e ajusta o comprimento (X da câmera) para FIT m.
func _fit(holder: Node3D) -> void:
	holder.position = Vector3.ZERO
	holder.scale = Vector3.ONE
	var box := AABB()
	var first := true
	for mi in _meshes(holder):
		if mi.mesh == null:
			continue
		var rel := Transform3D.IDENTITY
		var n: Node = mi
		while n != holder:
			rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var b := Transform3D(holder.basis, Vector3.ZERO) * rel * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var k := FIT / maxf(box.size.x, 0.01)
	k = minf(k, _cam.size * 0.9 / maxf(box.size.y, 0.01))  # arma alta (M79) não sai por cima/baixo
	holder.scale = Vector3.ONE * k
	holder.position = -box.get_center() * k


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.find_children("*", "MeshInstance3D", true, false):
		out.append(c as MeshInstance3D)
	return out

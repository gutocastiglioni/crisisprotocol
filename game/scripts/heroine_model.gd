class_name HeroineModel
extends Node3D
## Modelo da heroína: materiais PS1, árvore de animação (corpo + fuzil/mira/tiro na parte de cima), armas
## (pistola, M16, escopeta e M79 em malhas à parte: só a da mão aparece; a telha da escopeta desliza no bombeamento)
## e ragdoll. Os sons do corpo saem daqui (Sfx), para quem usa o modelo (heroína, guerrilheiro, alvo): tiro da arma da
## mão, telha, troca de arma, pancada, queda do ragdoll, cambalhota/pulo/aterrissagem/borda/subida e os passos, que
## tocam quando um pé desce até o chão (altura do osso Foot_*), no volume do jeito de andar e no tipo de chão.

## a escopeta bombeou (a telha chegou para trás): sai o cartucho em `at` com velocidade `vel`
signal shell_ejected(at: Vector3, vel: Vector3)

const SCENE := preload("res://assets/characters/heroine.glb")
# o atlas direto (não a cópia dentro do .glb): tem o alfa das pontas do cabelo e mipmaps para o visual PS2
const ATLAS := preload("res://assets/characters/heroine_atlas.png")

const LOOPS := [
	"Idle", "Walk", "Run", "AimIdle", "Crouch", "StrafeL", "StrafeR", "CrouchWalk", "CrouchStrafeL", "CrouchStrafeR",
	"Fall", "Hang", "RifleHold", "RifleAim", "Dazed", "LadderUp", "LadderDown", "LadderIdle",
]
const UPPER_BODY := [
	"Spine", "Chest", "Neck", "Head",
	"UpperArm_L", "LowerArm_L", "Hand_L", "UpperArm_R", "LowerArm_R", "Hand_R",
]
const STATES := {
	"idle": "Idle", "walk": "Walk", "run": "Run", "crouch": "Crouch", "crouch_walk": "CrouchWalk", "roll": "Roll",
	"dodge_l": "DodgeL", "dodge_r": "DodgeR", "dodge_back": "DodgeBack",
	"strafe_l": "StrafeL", "strafe_r": "StrafeR", "crouch_strafe_l": "CrouchStrafeL", "crouch_strafe_r": "CrouchStrafeR",
	"jump": "Jump", "fall": "Fall", "hang": "Hang", "climb": "ClimbUp", "mantle": "Mantle", "pickup": "Pickup",
	"assassinate": "Assassinate", "crit_strike": "CritStrike",
	"death": "Death", "dazed": "Dazed", "ladder_up": "LadderUp", "ladder_down": "LadderDown", "ladder_idle": "LadderIdle",
}
## estados de andar: a velocidade da animação acompanha a do corpo (parâmetro "<estado>_speed")
const SCALED := ["walk", "run", "crouch_walk", "strafe_l", "strafe_r", "crouch_strafe_l", "crouch_strafe_r", "ladder_up", "ladder_down"]
## com o fuzil, nestes estados os braços ficam na pose de carregar; nos outros seguem a animação
const CARRY := [
	"idle", "walk", "run", "crouch", "crouch_walk", "strafe_l", "strafe_r", "crouch_strafe_l", "crouch_strafe_r",
	"jump", "fall", "dodge_l", "dodge_r", "dodge_back",
]
## arma: [malha, marcador do cano]
const WEAPONS := {
	"pistol": ["Pistol", "Muzzle"], "m16": ["M16", "RifleMuzzle"], "shotgun": ["Shotgun", "ShotgunMuzzle"],
	"m79": ["M79", "M79Muzzle"], "sniper": ["Sniper", "SniperMuzzle"],
}
## armas longas: pose de carregar, mira e pegar do fuzil (escopeta e M79 têm o cabo e a telha nos mesmos pontos)
const LONG_GUNS := ["m16", "shotgun", "m79", "sniper"]
## janela de ejeção da escopeta em relação ao centro da telha em repouso (lado direito, atrás, em cima; m)
const SHELL_PORT := Vector3(0.02, 0.018, 0.21)
## passo: o pé (osso Foot_*, em relação aos pés do corpo) subiu STEP_UP acima da altura dele em repouso e voltou a
## menos de STEP_DOWN dela (m); apoiado ele fica nela e no ar passa de +0,045 em todos os ciclos de andar (a altura do
## tornozelo muda de um corpo para outro: heroína, guerrilheiro). Volume (dB) de cada jeito de andar.
const STEP_UP := 0.03
const STEP_DOWN := 0.01
const STEP_DB := {
	"walk": -6.0, "run": 0.0, "strafe_l": -7.0, "strafe_r": -7.0,
	"crouch_walk": -13.0, "crouch_strafe_l": -13.0, "crouch_strafe_r": -13.0,
}
const AIR := ["jump", "fall"]
const LAND_AIR_TIME := 0.25  # no ar por mais que isto: barulho de aterrissagem
## entram mais rápido (a mistura longa com a corrida cruzava as pernas no começo do pulinho)
const QUICK := ["dodge_l", "dodge_r", "dodge_back", "assassinate", "crit_strike"]
const XFADE := 0.15
const QUICK_XFADE := 0.05
## som ao entrar no estado
const STATE_SOUNDS := {"roll": "roll", "dodge_l": "jump", "dodge_r": "jump", "dodge_back": "jump", "jump": "jump", "climb": "climb", "mantle": "climb", "hang": "ledge_grab", "ladder_up": "climb", "ladder_down": "climb"}

@export var tint := Color.WHITE
@export var desaturate := 0.0
## Outro personagem com o mesmo esqueleto e animações (guerrilheiro): a cena e o atlas dele (antes de entrar na árvore).
var scene: PackedScene = SCENE
var atlas: Texture2D = ATLAS

var skeleton: Skeleton3D
var aim_pitch: AimPitch
var anim_player: AnimationPlayer
var tree: AnimationTree
var ragdoll: Ragdoll
var state := "idle"
var weapon := "pistol"
var holstered := false
var _meshes := {}
var _muzzles := {}
var _aim := 0.0
var _aim_target := 0.0
var _carry := 0.0
var _pump: Node3D
var _pump_rest: Transform3D
var _pump_t := -1.0  # segundos desde o tiro da escopeta (-1 = parada)
var _ejected := false
var _pump_sounds := 0  # 1 = já tocou a ida da telha, 2 = a volta
var _foot_bones: Array[int] = []
var _foot_up := [false, false]
var _foot_rest := 0.08  # altura do tornozelo em repouso (lida do esqueleto)
var _air_t := 0.0
var _quiet := true  # montando (_ready): a primeira arma na mão não faz barulho


func _ready() -> void:
	var inst := scene.instantiate()
	inst.rotation.y = PI  # o glTF olha para +Z; no Godot a frente é -Z
	add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	anim_player = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for w in WEAPONS:
		_meshes[w] = inst.find_child(WEAPONS[w][0], true, false)
		_muzzles[w] = inst.find_child(WEAPONS[w][1], true, false)
	_pump = inst.find_child("ShotgunPump", true, false)
	if _pump:
		_pump_rest = _pump.transform
	_apply_materials(inst)
	for a in LOOPS:
		anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_build_tree()
	# inclinação da mira antes do ragdoll (que, ligado, manda no esqueleto)
	aim_pitch = AimPitch.new()
	aim_pitch.influence = 0.0
	skeleton.add_child(aim_pitch)
	_setup_braid()
	ragdoll = Ragdoll.create(skeleton)
	ragdoll.hit_owner = get_parent()
	set_weapon(weapon)
	_foot_bones = [skeleton.find_bone("Foot_L"), skeleton.find_bone("Foot_R")]
	_foot_rest = skeleton.get_bone_global_rest(_foot_bones[0]).origin.y
	_quiet = false


## Trança (ossos Braid1..N, só a heroína): mola que balança com o movimento e não atravessa as costas (cápsulas no
## peito, na coluna e no quadril). A animação deixa esses ossos em repouso; a mola roda depois dela.
const BRAID_STIFFNESS := 1.2
const BRAID_DRAG := 0.45
const BRAID_GRAVITY := 1.0
const BRAID_RADIUS := 0.025
const BRAID_BODY := [["Chest", 0.105, 0.30], ["Spine", 0.10, 0.16], ["Hips", 0.12, 0.16]]  # osso, raio, altura
var braid: SpringBoneSimulator3D


func _setup_braid() -> void:
	if skeleton.find_bone("Braid1") < 0:
		return
	var last := 1
	while skeleton.find_bone("Braid%d" % (last + 1)) >= 0:
		last += 1
	braid = SpringBoneSimulator3D.new()
	braid.name = "BraidSpring"
	skeleton.add_child(braid)
	braid.set_setting_count(1)
	braid.set_root_bone_name(0, "Braid1")
	braid.set_end_bone_name(0, "Braid%d" % last)
	braid.set_extend_end_bone(0, true)
	braid.set_end_bone_length(0, 0.06)
	braid.set_radius(0, BRAID_RADIUS)
	braid.set_stiffness(0, BRAID_STIFFNESS)
	braid.set_drag(0, BRAID_DRAG)
	braid.set_gravity(0, BRAID_GRAVITY)
	for b in BRAID_BODY:
		var c := SpringBoneCollisionCapsule3D.new()
		c.bone_name = b[0]
		c.radius = b[1]
		c.height = b[2]
		# cápsula de pé ao longo do osso, no meio da altura dele
		c.set_position_offset(Vector3(0, b[2] * 0.5, 0))
		braid.add_child(c)
	braid.set_enable_all_child_collisions(0, true)


func _apply_materials(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var m := ShaderMaterial.new()
			var two_sided := src != null and src.cull_mode == BaseMaterial3D.CULL_DISABLED
			m.shader = Gfx.shader(two_sided)
			m.set_shader_parameter("rim", 0.35)
			# corpo da heroína (modelo base, materiais Body_*): cada parte com a textura própria; armas e guerrilheiro usam o atlas
			var tex: Texture2D = atlas
			if src != null and src.resource_name.begins_with("Body_") and src.albedo_texture != null:
				tex = src.albedo_texture
			m.set_shader_parameter("albedo_tex", tex)
			m.set_shader_parameter("tint", tint)
			m.set_shader_parameter("desaturate", desaturate)
			mi.set_surface_override_material(i, m)


func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	anim_player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	var bt := AnimationNodeBlendTree.new()

	var base := AnimationNodeTransition.new()
	base.xfade_time = XFADE
	for s in STATES:
		base.add_input(s)
		bt.add_node("a_" + s, _anim(STATES[s]))
	bt.add_node("base", base)
	for s in SCALED:
		bt.add_node(s + "_speed", AnimationNodeTimeScale.new())
		bt.connect_node(s + "_speed", 0, "a_" + s)
	# subir da borda pode começar no meio (borda baixa: o pulo já entra na subida)
	bt.add_node("climb_seek", AnimationNodeTimeSeek.new())
	bt.connect_node("climb_seek", 0, "a_climb")
	var i := 0
	for s in STATES:
		var src: String = s + "_speed" if s in SCALED else ("climb_seek" if s == "climb" else "a_" + s)
		bt.connect_node("base", i, src)
		# rolar, pular, subir, pegar e morrer sempre começam do quadro 0
		base.set_input_reset(i, true)
		i += 1

	# fuzil nas mãos (pose de carregar) por cima da locomoção
	var carry := AnimationNodeBlend2.new()
	_filter_upper_body(carry)
	bt.add_node("a_carry", _anim("RifleHold"))
	bt.add_node("carry", carry)
	bt.connect_node("carry", 0, "base")
	bt.connect_node("carry", 1, "a_carry")
	# mira e tiro: a pose de cada arma (0 = pistola, 1 = fuzil)
	var aim := AnimationNodeBlend2.new()
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.02
	shoot.fadeout_time = 0.08
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.15
	_filter_upper_body(aim)
	_filter_upper_body(shoot)
	for n in [["aim_pose", "AimIdle", "RifleAim"], ["shoot_pose", "Shoot", "RifleShoot"]]:
		bt.add_node("a_" + n[0] + "_pistol", _anim(n[1]))
		bt.add_node("a_" + n[0] + "_m16", _anim(n[2]))
		bt.add_node(n[0], AnimationNodeBlend2.new())
		bt.connect_node(n[0], 0, "a_" + n[0] + "_pistol")
	bt.connect_node("aim_pose", 1, "a_aim_pose_m16")
	# tiro das armas longas: M16 (0) ou pesada (1) = escopeta com o bombeamento (0) ou M79 com o coice forte (1)
	bt.add_node("a_shoot_pose_shotgun", _anim("ShotgunShoot"))
	bt.add_node("a_shoot_pose_m79", _anim("M79Shoot"))
	bt.add_node("heavy_shoot", AnimationNodeBlend2.new())
	bt.connect_node("heavy_shoot", 0, "a_shoot_pose_shotgun")
	bt.connect_node("heavy_shoot", 1, "a_shoot_pose_m79")
	bt.add_node("long_shoot", AnimationNodeBlend2.new())
	bt.connect_node("long_shoot", 0, "a_shoot_pose_m16")
	bt.connect_node("long_shoot", 1, "heavy_shoot")
	bt.connect_node("shoot_pose", 1, "long_shoot")
	bt.add_node("a_hit", _anim("Hit"))
	bt.add_node("aim", aim)
	bt.add_node("shoot", shoot)
	bt.add_node("hit", hit)
	bt.connect_node("aim", 0, "carry")
	bt.connect_node("aim", 1, "aim_pose")
	bt.connect_node("shoot", 0, "aim")
	bt.connect_node("shoot", 1, "shoot_pose")
	bt.connect_node("hit", 0, "shoot")
	bt.connect_node("hit", 1, "a_hit")
	bt.connect_node("output", 0, "hit")
	tree.tree_root = bt
	tree.active = true
	state = ""
	set_state("idle")


func _anim(name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = name
	return n


func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	var a := anim_player.get_animation("Idle")
	for t in a.get_track_count():
		var path := a.track_get_path(t)
		if path.get_concatenated_subnames() in UPPER_BODY:
			node.set_filter_path(path, true)


func _process(delta: float) -> void:
	if tree == null or not tree.active:
		return
	_aim = move_toward(_aim, _aim_target, delta * 8.0)
	tree.set("parameters/aim/blend_amount", _aim)
	aim_pitch.influence = _aim
	var carry := 1.0 if weapon in LONG_GUNS and not holstered and state in CARRY else 0.0
	_carry = move_toward(_carry, carry, delta * 6.0)
	tree.set("parameters/carry/blend_amount", _carry)
	_update_pump(delta)
	_air_t = _air_t + delta if state in AIR else 0.0
	_footsteps()


## Passo: um pé que estava no ar desceu até o chão (só nos estados de andar).
func _footsteps() -> void:
	if not STEP_DB.has(state):
		_foot_up = [false, false]
		return
	for i in 2:
		var foot := skeleton.global_transform * skeleton.get_bone_global_pose(_foot_bones[i]).origin
		var h := foot.y - global_position.y - _foot_rest
		if h > STEP_UP:
			_foot_up[i] = true
		elif h < STEP_DOWN and _foot_up[i]:
			_foot_up[i] = false
			Sfx.step(self, foot, STEP_DB[state])


## Bombeamento: a telha segue o mesmo caminho que a mão esquerda faz na animação ShotgunShoot
## (heroine_moves.json "shotgun": quadro -> recuo, smoothstep entre as chaves, como no Blender).
func _update_pump(delta: float) -> void:
	if _pump_t < 0.0 or _pump == null:
		return
	_pump_t += delta
	var d: Dictionary = Moves.data().shotgun
	var f := _pump_t * Moves.fps()
	var back := pump_offset(f)
	_pump.transform = _pump_rest * Transform3D(Basis(), Vector3(0, 0, back))  # -Z local = para a frente (cano)
	# a telha começou a ir para trás / começou a voltar (o som arrasta e bate no fim do curso)
	if _pump_sounds == 0 and back > float(d.stroke) * 0.05:
		_pump_sounds = 1
		Sfx.play(_pump, "shotgun_pump_back")
	elif _pump_sounds == 1 and _ejected and back < float(d.stroke) * 0.95:
		_pump_sounds = 2
		Sfx.play(_pump, "shotgun_pump_fwd")
	if not _ejected and back >= float(d.stroke) * 0.95:
		_ejected = true
		var port: Transform3D = (_pump.get_parent() as Node3D).global_transform * _pump_rest
		var b := port.basis.orthonormalized()
		shell_ejected.emit(port * SHELL_PORT, b.x * randf_range(1.6, 2.2) + b.y * randf_range(0.8, 1.3))
	if f >= float(d.frames):
		_pump_t = -1.0
		_pump.transform = _pump_rest


## Recuo da telha (m, para trás) no quadro `f` do ShotgunShoot.
static func pump_offset(f: float) -> float:
	var keys: Array = Moves.data().shotgun.pump
	for i in keys.size() - 1:
		var k0: Array = keys[i]
		var k1: Array = keys[i + 1]
		if f >= k0[0] and f <= k1[0]:
			var t: float = (f - k0[0]) / (k1[0] - k0[0])
			return lerpf(k0[1], k1[1], t * t * (3.0 - 2.0 * t))
	return float(keys[-1][1])


## Troca o estado do corpo; `speed_scale` = velocidade da animação nos estados de andar (negativa = de costas).
func set_state(s: String, speed_scale := 1.0) -> void:
	if s in SCALED:
		tree.set("parameters/%s_speed/scale" % s, speed_scale)
	if s == state:
		return
	if state in AIR and not s in AIR and not s in STATE_SOUNDS and _air_t > LAND_AIR_TIME:
		Sfx.play(self, "land")
	if STATE_SOUNDS.has(s) and not (s == "jump" and state in AIR):
		Sfx.play(self, STATE_SOUNDS[s])
	state = s
	(tree.tree_root as AnimationNodeBlendTree).get_node("base").xfade_time = QUICK_XFADE if s in QUICK else XFADE
	tree.set("parameters/base/transition_request", s)


## Começa o estado do quadro 0 mesmo se já estiver nele (outra cambalhota, outro pulo).
func play(s: String) -> void:
	state = ""
	set_state(s)


## Começa o estado em `sec` segundos da animação (só "climb").
func play_from(s: String, sec: float) -> void:
	play(s)
	if sec > 0.0:
		tree.set("parameters/climb_seek/seek_request", sec)


## Arma na mão ("pistol", "m16", "shotgun" ou "m79"): mostra a malha dela e usa as poses de mira/tiro dela.
func set_weapon(w: String) -> void:
	if w != weapon and not _quiet and not holstered:
		Sfx.play(self, "weapon_switch", global_position + Vector3.UP * 1.1)
	weapon = w
	var k := 1.0 if w in LONG_GUNS else 0.0
	tree.set("parameters/aim_pose/blend_amount", k)
	tree.set("parameters/shoot_pose/blend_amount", k)
	tree.set("parameters/long_shoot/blend_amount", 1.0 if w in ["shotgun", "m79"] else 0.0)
	tree.set("parameters/heavy_shoot/blend_amount", 1.0 if w == "m79" else 0.0)
	_stop_pump()
	_show_weapon()


func _stop_pump() -> void:
	_pump_t = -1.0
	if _pump:
		_pump.transform = _pump_rest


## Guardada (pendurada, subindo, pegando outra arma): nenhuma arma na mão.
func holster(on: bool) -> void:
	holstered = on
	_show_weapon()


func _show_weapon() -> void:
	for w in _meshes:
		if _meshes[w]:
			_meshes[w].visible = w == weapon and not holstered
	if _pump:
		_pump.visible = weapon == "shotgun" and not holstered


func set_aim(on: bool) -> void:
	_aim_target = 1.0 if on else 0.0


## Altura da mira (radianos, > 0 = para cima): o tronco inclina e a arma aponta para o ponto mirado.
func set_aim_pitch(rad: float) -> void:
	aim_pitch.pitch = rad


func is_aimed() -> bool:
	return _aim > 0.9


func shoot() -> void:
	tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Sfx.play(self, weapon + "_shot", muzzle_position())
	if weapon == "shotgun":
		_pump_t = 0.0
		_ejected = false
		_pump_sounds = 0


func hit() -> void:
	tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Sfx.play(self, "impact_flesh", global_position + Vector3.UP * 1.2)
	_stop_pump()  # o golpe tira a mão da telha (a animação do tiro é cortada)


func muzzle_position() -> Vector3:
	var m: Node3D = _muzzles.get(weapon)
	return m.global_position if m else global_position + Vector3.UP * 1.3


func is_weapon_visible(w: String) -> bool:
	return _meshes[w] != null and _meshes[w].visible


## Liga o ragdoll (golpe `impulse` em `at`): com golpe, pancada e o corpo batendo no chão logo depois; sem golpe
## (presa na boca do raptor) os sons são dele.
func start_ragdoll(impulse: Vector3, at: Variant = null) -> void:
	if impulse != Vector3.ZERO and not is_ragdoll():
		Sfx.play(self, "impact_flesh", at if at is Vector3 else global_position + Vector3.UP * 1.2)
		Sfx.play(self, "body_fall", null, 0.0, 1.0, 0.5)
	_stop_pump()
	aim_pitch.influence = 0.0
	tree.active = false
	ragdoll.start(impulse, at)


## Ragdoll com o corpo todo voando a `vel` (arremessada por um golpe).
func fling_ragdoll(vel: Vector3, at: Variant = null) -> void:
	Sfx.play(self, "body_fall", null, 0.0, 1.0, 0.7)
	_stop_pump()
	aim_pitch.influence = 0.0
	tree.active = false
	await ragdoll.fling(vel, at)


func stop_ragdoll() -> void:
	ragdoll.stop()
	tree.active = true
	state = ""
	set_state("idle")
	set_aim(false)
	holster(false)
	_aim = 0.0


func is_ragdoll() -> bool:
	return ragdoll.is_simulating_physics()

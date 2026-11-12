class_name Terminal
extends Node3D
## Computador que destrava uma grade do galpão (Shed): E na frente dele (`can_use`) = `use` → sinal `used`. Não dá para usar
## com o guarda dele mexendo nele (`guard` distraído no posto, `Enemy.is_distracted`): ela tem que matá-lo ou tirá-lo dali.
## O nó fica no lugar onde ela para para digitar, com o +Z local apontando para trás dela (ela olha para -Z local).

signal used

const REACH := 1.0  # do lugar de digitar até ela (no chão)
const REACH_DY := 0.6

var verb := "USAR COMPUTADOR"
var guard: Enemy  # quem mexe nele (null = ninguém)
var done := false


func _ready() -> void:
	add_to_group("terminals")


func can_use(p: Vector3) -> bool:
	if done or (guard != null and not guard.dead and guard.is_distracted()):
		return false
	var d := p - global_position
	if absf(d.y) > REACH_DY:
		return false
	d.y = 0.0
	return d.length() < REACH


func use() -> void:
	if done:
		return
	done = true
	if is_inside_tree():
		Sfx.ui(self, "keypad_ok")
	used.emit()


## R / checkpoint: de novo sem uso (ou já usado, sem som nem sinal).
func load_done(on: bool) -> void:
	done = on

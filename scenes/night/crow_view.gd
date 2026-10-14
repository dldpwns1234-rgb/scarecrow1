extends Node2D
## 까마귀 연출 (GDD 4절): Night.crow_pecked마다 까마귀가 밭 위로 내리꽂혀 작물을 한 번 쪼고 날아간다. 그림만이다 (피해는 Night가 이미 줬다).
## 한꺼번에 날 수 있는 까마귀 수에 상한을 둔다. 상수는 연출용이다

const TEXTURE := preload("res://assets/sprites/crow.svg")
const SCALE: float = 0.4
const DIVE: float = 0.22       # 내리꽂히는 시간
const PECK: float = 0.12       # 쪼고 머무는 시간
const LEAVE: float = 0.4       # 날아가는 시간
const START_OFFSET := Vector2(-180.0, -220.0)
const LEAVE_OFFSET := Vector2(220.0, -260.0)
const BEAK_OFFSET := Vector2(-30.0, -34.0)  # 부리 끝이 작물 머리께에 오게
const MAX_CROWS: int = 8

var field: Node2D  # field_view.gd
var _flying: int = 0


func _ready() -> void:
	Night.crow_pecked.connect(_on_pecked)


func _on_pecked(index: int) -> void:
	if _flying >= MAX_CROWS:
		return
	_flying += 1
	var crow := Sprite2D.new()
	crow.texture = TEXTURE
	crow.scale = Vector2.ONE * SCALE
	var land: Vector2 = field.cell_screen(index) + BEAK_OFFSET
	crow.position = land + START_OFFSET
	add_child(crow)
	var tween := crow.create_tween()
	tween.tween_property(crow, "position", land, DIVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(crow, "rotation", 0.35, PECK * 0.5)
	tween.tween_property(crow, "rotation", 0.0, PECK * 0.5)
	tween.tween_property(crow, "position", land + LEAVE_OFFSET, LEAVE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(crow, "modulate:a", 0.0, LEAVE)
	tween.tween_callback(func() -> void:
		crow.queue_free()
		_flying -= 1)

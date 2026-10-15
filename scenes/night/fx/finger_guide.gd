extends Control
## 폰에서 끄는 동안 손가락 자리의 작은 고리와 구름 가운데까지 이어지는 옅은 점선 (방장 #639 '손가락에 구름이 가려진다').
## 구름은 별빛의 입력이 손가락 위로 띄우고(night_screen.gd), 여기서는 어느 손가락이 어느 구름을 끄는지 이어 보여 준다.
## 터치만 본다(마우스는 커서가 곧 구름이라 필요 없다). 입력은 _input으로 보기만 하고 먹지 않는다. 손을 떼면 서서히 사라진다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const RING_RADIUS: float = 26.0
const RING_WIDTH: float = 3.0
const DASH: float = 10.0
const LINE_WIDTH: float = 3.0
const COLOR := Color(0.88, 0.8, 1.0, 0.9)    # 구름의 보랏빛을 옅게
const FADE_SECONDS: float = 0.35

var field: Node2D   # night_fx가 넘긴다 (밭 그림. 부모가 판)
var _finger := Vector2.ZERO
var _down: bool = false
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_down = event.pressed and Night.active
		_finger = event.position
	elif event is InputEventScreenDrag:
		_finger = event.position
		_down = Night.active


func _process(delta: float) -> void:
	var target := 1.0 if _down and Night.active else 0.0
	var before := _alpha
	_alpha = move_toward(_alpha, target, minf(delta, Balance.MAX_DELTA) / FADE_SECONDS)
	if _alpha > 0.0 or before > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0 or field == null:
		return
	var board := field.get_parent() as Node2D
	if board == null:
		return
	var color := Color(COLOR, COLOR.a * _alpha)
	var finger := get_global_transform().affine_inverse() * _finger
	var cloud := get_global_transform().affine_inverse() * (board.get_global_transform() * Iso.to_screen(Vector2.ZERO, Night.cloud))
	draw_arc(finger, RING_RADIUS, 0.0, TAU, 32, color, RING_WIDTH, true)
	if finger.distance_to(cloud) > RING_RADIUS * 1.5:
		draw_dashed_line(finger + finger.direction_to(cloud) * RING_RADIUS, cloud, color, LINE_WIDTH, DASH, true)

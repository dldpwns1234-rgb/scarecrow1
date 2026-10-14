extends Control
## 어둠의 나무 판의 1부: 끌어 옮기기(pan)와 줌 (방장 2026-10-15: 나무가 커져 줌 아웃이 필요하다). tree_board.gd가 상속한다.
## 마우스: 끌기·휠(커서 자리를 기준으로). 손가락: 한 손가락 끌기, 두 손가락 집기·벌리기. 짧게 누르면 _tap(자리)을 부른다 (자식이 정한다).
## 옮기거나 줌이 바뀌면 _place()를 부른다 (자식이 정한다). 판이 보이는 카드 밖으로 너무 멀리 가지 않게 _reach()(가운데에서 가장 먼 카드까지, 줌 1 기준)로 막는다. 상수는 조작감용이다

const TAP_SLOP: float = 18.0
const PAN_MARGIN: float = 160.0   # 보이는 카드 바깥으로 이만큼까지만 끌린다
const MIN_ZOOM: float = 0.2     # 나무가 64칸을 넘어도 전체 보기에 다 들어오게 (방장 #529)
const MAX_ZOOM: float = 1.25
const WHEEL_STEP: float = 1.12    # 휠 한 칸에 줌이 이만큼 곱해진다
const FIT_MARGIN: float = 40.0    # 전체 보기에서 가장자리 여백

var pan: Vector2 = Vector2.ZERO   # 가운데 노드가 판 가운데에서 얼마나 옮겨졌는지
var zoom: float = 1.0
var _press: Vector2 = Vector2.INF
var _press_pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _touches: Dictionary = {}     # 손가락 번호 → 자리 (두 손가락 집기)
var _pinch_distance: float = 0.0


## 가운데 노드의 화면 자리
func center_point() -> Vector2:
	return size * 0.5 + pan


## 줌을 바꾼다. anchor(화면 자리)가 가리키던 판의 점이 그 자리에 그대로 있게 판을 옮긴다
func set_zoom(value: float, anchor: Vector2 = Vector2.INF) -> void:
	var target := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(target, zoom):
		return
	if anchor == Vector2.INF:
		anchor = size * 0.5
	var board_point := (anchor - center_point()) / zoom
	zoom = target
	pan = _clamp_pan(anchor - size * 0.5 - board_point * zoom)
	_place()


## 보이는 카드가 모두 들어가게: 카드들을 감싼 상자에 줌을 맞추고 그 상자 가운데를 판 가운데로 (나무는 위로 더 길다)
func fit_all() -> void:
	var box := _bounds().grow(FIT_MARGIN)
	var fit := minf(size.x / maxf(box.size.x, 1.0), size.y / maxf(box.size.y, 1.0))
	zoom = clampf(fit, MIN_ZOOM, 1.0)
	pan = _clamp_pan(-box.get_center() * zoom)
	_place()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_place()


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_pinch_distance = _touch_distance()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _touches.size() >= 2:
		_touches[drag.index] = drag.position
		var distance := _touch_distance()
		if _pinch_distance > 0.0 and distance > 0.0:
			set_zoom(zoom * distance / _pinch_distance, _touch_center())
		_pinch_distance = distance
		_press = Vector2.INF  # 집는 동안은 한 손가락 끌기·누르기를 하지 않는다
		accept_event()
		return
	var gesture := event as InputEventMagnifyGesture
	if gesture != null:
		set_zoom(zoom * gesture.factor, gesture.position)
		accept_event()
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		set_zoom(zoom * (WHEEL_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_STEP), button.position)
		accept_event()
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press = button.position
			_press_pan = pan
			_dragging = false
		elif _press != Vector2.INF:
			if not _dragging and _touches.size() < 2:
				_tap(button.position)
			_press = Vector2.INF
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _press != Vector2.INF and _touches.size() < 2:
		if not _dragging and motion.position.distance_to(_press) > TAP_SLOP:
			_dragging = true
		if _dragging:
			pan = _clamp_pan(_press_pan + motion.position - _press)
			_place()
		accept_event()


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


func _touch_center() -> Vector2:
	var points: Array = _touches.values()
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


## 보이는 카드들이 화면 밖으로 다 나가지 않게: 가장 바깥 카드 너머로 PAN_MARGIN까지만
func _clamp_pan(wanted: Vector2) -> Vector2:
	var limit := (_reach() + Vector2.ONE * PAN_MARGIN) * zoom - size * 0.5
	limit = limit.max(Vector2.ZERO)
	return wanted.clamp(-limit, limit)


## 자식이 정한다: 가운데에서 가장 먼 보이는 카드의 바깥 가장자리까지 (줌 1 기준)
func _reach() -> Vector2:
	return Vector2.ZERO


## 자식이 정한다: 보이는 카드들을 감싼 상자 (가운데 노드가 원점, 줌 1 기준)
func _bounds() -> Rect2:
	return Rect2()


func _place() -> void:
	pass


func _tap(_point: Vector2) -> void:
	pass

extends Control
## 밤 화면의 알갱이 (방장 2026-10-14 "가득 차는 뽕맛"): 작물이 시들면 그 자리에서 금빛·풀빛 생기 알갱이가 튀어 오르다 떨어지며 사라진다.
## 풍작(combo_meter.gd의 burst)이면 밭 가운데에서 크게 터진다. 수박이 터지면(crop_burst) 붉은 즙이 튄다 (파동·씨앗·덩굴 번개 그림은 별빛의 scenes/night/skill_fx.gd).
## 가볍게 (2026-10-15 별빛 측정: 연쇄로 한 프레임에 수십 개 시들 때 이 층이 3.6ms): 시든 칸은 모아 두었다 한 프레임에 한 번, 새 알갱이 수에 프레임 상한,
## 알갱이는 한 배열(8칸씩)에 두고 제자리에서 당겨 지우며, 그리기는 작은 마름모를 삼각형 묶음 한 번으로 (draw_circle은 알갱이마다 꼭짓점이 많다).
## field(field_view.gd)의 cell_screen으로 자리를 얻는다. Night 시그널만 받는 연출이다. 상수는 연출용이다

const PER_WITHER: int = 6
const NEW_PER_FRAME: int = 48             # 시듦 알갱이를 한 프레임에 새로 만드는 상한 (많이 시들수록 한 칸에 적게)
const PENDING_CELLS: int = 24             # 한 프레임에 알갱이를 낼 시든 칸 상한 (넘치면 버린다)
const PER_BURST: int = 70
const PER_JUICE: int = 22
const MAX_SPARKS: int = 360
const STRIDE: int = 8                     # x, y, vx, vy, 남은 수명, 처음 수명, 반지름, 색 번호
const LIFE := Vector2(0.45, 0.9)          # 초
const SPEED := Vector2(80.0, 220.0)       # 픽셀/초
const BURST_SPEED := Vector2(220.0, 560.0)
const GRAVITY: float = 520.0
const RADIUS := Vector2(2.0, 4.5)
const COLORS: Array[Color] = [Color("f2d27a"), Color("9ad14f"), Color("fff3c4"), Color("c8f08a"), Color("e8505b"), Color("ff8a8f")]
const GOLD_COLORS: int = 4               # 앞의 넷이 생기 알갱이 색, 그다음 둘이 수박 즙
const JUICE_COLOR_FROM: int = 4

var field: Node2D                         # field_view.gd (cell_screen)
var _data := PackedFloat32Array()
var _count: int = 0
var _pending := PackedInt32Array()       # 이번 프레임에 시든 칸
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_data.resize(MAX_SPARKS * STRIDE)
	Night.crop_withered.connect(_on_withered.unbind(1))
	Night.night_started.connect(_clear)
	if Night.has_signal("crop_burst"):
		Night.connect("crop_burst", _on_burst_crop)


func _clear() -> void:
	_count = 0
	_pending.clear()
	queue_redraw()


func _on_withered(index: int) -> void:
	if _pending.size() < PENDING_CELLS:
		_pending.append(index)


## 수박이 터졌다: 붉은 즙이 사방으로 (반경이 클수록 멀리)
func _on_burst_crop(index: int, radius: float) -> void:
	if field == null:
		return
	var scale := clampf(radius, 1.0, 3.0)
	_spawn(field.call("cell_screen", index), roundi(PER_JUICE * scale), SPEED * scale, 0.0, TAU, JUICE_COLOR_FROM, 2)


## 풍작: 한 점에서 사방으로 크게. scale은 알갱이 수 배율 (그 밤의 풍작이 거듭될수록 커진다)
func burst_at(at: Vector2, scale: float = 1.0) -> void:
	_spawn(at, roundi(PER_BURST * scale), BURST_SPEED * sqrt(scale), 0.0, TAU)


func _spawn(at: Vector2, count: int, speed: Vector2, angle_from: float, angle_to: float, color_from: int = 0, color_count: int = GOLD_COLORS) -> void:
	for i in count:
		if _count >= MAX_SPARKS:
			return  # 꽉 차면 새것을 버린다 (오래된 것을 밀어내려면 배열을 당겨야 한다)
		var velocity := Vector2.from_angle(_rng.randf_range(angle_from, angle_to)) * _rng.randf_range(speed.x, speed.y)
		var life := _rng.randf_range(LIFE.x, LIFE.y)
		var at_index := _count * STRIDE
		_data[at_index] = at.x
		_data[at_index + 1] = at.y
		_data[at_index + 2] = velocity.x
		_data[at_index + 3] = velocity.y
		_data[at_index + 4] = life
		_data[at_index + 5] = life
		_data[at_index + 6] = _rng.randf_range(RADIUS.x, RADIUS.y)
		_data[at_index + 7] = float(color_from + _rng.randi() % color_count)
		_count += 1


func _process(delta: float) -> void:
	if not _pending.is_empty() and field != null:
		var each := clampi(NEW_PER_FRAME / _pending.size(), 1, PER_WITHER)
		for index in _pending:
			_spawn(field.call("cell_screen", index), each, SPEED, -PI * 0.85, -PI * 0.15)
		_pending.clear()
	if _count == 0:
		return
	delta = minf(delta, Balance.MAX_DELTA)
	var kept := 0
	for i in _count:
		var at := i * STRIDE
		var life := _data[at + 4] - delta
		if life <= 0.0:
			continue
		var to := kept * STRIDE
		var vy := _data[at + 3] + GRAVITY * delta
		_data[to] = _data[at] + _data[at + 2] * delta
		_data[to + 1] = _data[at + 1] + vy * delta
		_data[to + 2] = _data[at + 2]
		_data[to + 3] = vy
		_data[to + 4] = life
		_data[to + 5] = _data[at + 5]
		_data[to + 6] = _data[at + 6]
		_data[to + 7] = _data[at + 7]
		kept += 1
	_count = kept
	queue_redraw()


## 알갱이마다 작은 마름모 (삼각형 둘)를 한 번에 그린다
func _draw() -> void:
	if _count == 0:
		return
	_points.resize(_count * 4)
	_colors.resize(_count * 4)
	_indices.resize(_count * 6)
	for i in _count:
		var at := i * STRIDE
		var t := _data[at + 4] / _data[at + 5]
		var r := _data[at + 6] * (0.5 + 0.5 * t)
		var center := Vector2(_data[at], _data[at + 1])
		var color := Color(COLORS[int(_data[at + 7])], t)
		var p := i * 4
		_points[p] = center + Vector2(0.0, -r)
		_points[p + 1] = center + Vector2(r, 0.0)
		_points[p + 2] = center + Vector2(0.0, r)
		_points[p + 3] = center + Vector2(-r, 0.0)
		for k in 4:
			_colors[p + k] = color
		var tri := i * 6
		_indices[tri] = p
		_indices[tri + 1] = p + 1
		_indices[tri + 2] = p + 2
		_indices[tri + 3] = p
		_indices[tri + 4] = p + 2
		_indices[tri + 5] = p + 3
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)

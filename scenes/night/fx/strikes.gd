extends Control
## 밤 화면의 덩굴 번개 (방장 2026-10-14 "더 다양한 이펙트"): 포도 덩굴·연쇄 시듦이 옆 작물을 치면(Night.chain_struck) 두 칸 사이에
## 풀빛으로 꺾인 선이 번쩍였다 사라진다. 선 수에 상한을 둔다. field(field_view.gd)의 cell_screen으로 자리를 얻는다. 연출만 한다. 상수는 연출용이다

const LIFE: float = 0.28
const MAX_LINES: int = 60
const SEGMENTS: int = 5
const JITTER: float = 9.0
const CORE := Color("eaffc4")
const GLOW := Color(0.6, 0.95, 0.35, 0.55)
const CORE_WIDTH: float = 2.0
const GLOW_WIDTH: float = 7.0

var field: Node2D
var _lines: Array[Dictionary] = []  # {"points": PackedVector2Array, "life": float}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Night.has_signal("chain_struck"):
		Night.connect("chain_struck", _on_struck)
	Night.night_started.connect(func() -> void: _lines.clear())


func _on_struck(from: int, to: int) -> void:
	if field == null:
		return
	var a: Vector2 = field.call("cell_screen", from)
	var b: Vector2 = field.call("cell_screen", to)
	var points := PackedVector2Array([a])
	var normal := (b - a).orthogonal().normalized()
	for i in range(1, SEGMENTS):
		points.append(a.lerp(b, float(i) / SEGMENTS) + normal * _rng.randf_range(-JITTER, JITTER))
	points.append(b)
	if _lines.size() >= MAX_LINES:
		_lines.remove_at(0)
	_lines.append({"points": points, "life": LIFE})


func _process(delta: float) -> void:
	if _lines.is_empty():
		return
	delta = minf(delta, Balance.MAX_DELTA)
	var alive: Array[Dictionary] = []
	for line in _lines:
		line["life"] = float(line["life"]) - delta
		if float(line["life"]) > 0.0:
			alive.append(line)
	_lines = alive
	queue_redraw()


func _draw() -> void:
	for line in _lines:
		var t := float(line["life"]) / LIFE
		var points: PackedVector2Array = line["points"]
		draw_polyline(points, Color(GLOW, GLOW.a * t), GLOW_WIDTH * t)
		draw_polyline(points, Color(CORE, t), CORE_WIDTH)

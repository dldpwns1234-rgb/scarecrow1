extends Node2D
## 시든 작물에서 휴식이 튀어 오르는 연출 (GDD 4절): "+5"가 떠올라 사라지고, 금빛 알갱이가 휴식 카운터로 날아간다. Night의 시그널만 받는다.
## 한꺼번에 많이 시들면(번짐·정복) 글자와 알갱이 수를 상한에서 자른다. 상수는 연출용이다

const POP_COLOR := Color("f2d27a")
const POP_OUTLINE := Color("2b2416")
const POP_FONT_SIZE: int = 22
const POP_RISE: float = 46.0
const POP_DURATION: float = 0.8
const MAX_POPS: int = 18
const ORB_COLOR := Color("ffe08a")
const ORB_RADIUS: float = 5.0
const ORB_DURATION: float = 0.55
const MAX_ORBS: int = 24
const ARC_HEIGHT: float = 90.0   # 알갱이가 그리는 포물선의 높이

var field: Node2D                 # field_view.gd (칸의 화면 자리)
var target: Vector2 = Vector2.ZERO  # 휴식 카운터 자리
var _pops: int = 0
var _orbs: Array[Dictionary] = []  # {"from", "t"}


func _ready() -> void:
	Night.crop_withered.connect(_on_withered)


func _process(delta: float) -> void:
	if _orbs.is_empty():
		return
	for orb in _orbs:
		orb["t"] = float(orb["t"]) + delta / ORB_DURATION
	_orbs = _orbs.filter(func(orb: Dictionary) -> bool: return float(orb["t"]) < 1.0)
	queue_redraw()


func _on_withered(index: int, rest: float) -> void:
	var at: Vector2 = field.cell_screen(index)
	if _orbs.size() < MAX_ORBS:
		_orbs.append({"from": at, "t": 0.0})
	if _pops >= MAX_POPS:
		return
	_pops += 1
	var label := Label.new()
	label.text = "+" + Num.format(rest)
	label.add_theme_font_size_override("font_size", POP_FONT_SIZE)
	label.add_theme_color_override("font_color", POP_COLOR)
	label.add_theme_color_override("font_outline_color", POP_OUTLINE)
	label.add_theme_constant_override("outline_size", 6)
	label.position = at + Vector2(-20.0, -60.0)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - POP_RISE, POP_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, POP_DURATION).set_delay(POP_DURATION * 0.4)
	tween.chain().tween_callback(func() -> void:
		label.queue_free()
		_pops -= 1)


func _draw() -> void:
	for orb in _orbs:
		var t := float(orb["t"])
		var from: Vector2 = orb["from"]
		var ease := t * t * (3.0 - 2.0 * t)
		var point := from.lerp(target, ease) + Vector2(0.0, -sin(t * PI) * ARC_HEIGHT)
		draw_circle(point, ORB_RADIUS * (1.0 - 0.4 * t), ORB_COLOR)

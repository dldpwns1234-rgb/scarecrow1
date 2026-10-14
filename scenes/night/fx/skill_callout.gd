extends Control
## 밤 스킬이 저절로 터지면(Night.skill_used) 밭 위쪽에 '역병 폭풍!'처럼 이름이 커졌다 줄며 떠올라 사라진다 (방장 2026-10-15: 스킬은 누르는 게 아니라 터지는 것).
## 여럿이 잇달아 터지면 줄을 바꿔 겹치지 않게 쌓는다. Night 시그널만 받는 연출이다. 상수는 배치·연출용이다

const TOP: float = 0.24              # 화면 높이에서 첫 줄의 자리
const LINE_GAP: float = 46.0
const MAX_LINES: int = 4
const FONT_SIZE: int = 36
const RISE: float = 34.0
const POP_SECONDS: float = 0.18
const HOLD_SECONDS: float = 0.55
const FADE_SECONDS: float = 0.5
const COLOR := Color("e8d4ff")       # 어둠의 보랏빛 (풍작의 금빛과 구별)
const OUTLINE := Color(0.08, 0.03, 0.14)

var _slots: Array[float] = []        # 줄마다 비는 시각 (이 시각 전이면 그 줄은 쓰는 중)
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slots.resize(MAX_LINES)
	_slots.fill(0.0)
	Night.skill_used.connect(_on_skill_used)


func _process(delta: float) -> void:
	_clock += minf(delta, Balance.MAX_DELTA)


func _on_skill_used(skill: int) -> void:
	if skill < 0 or skill >= Balance.SKILLS.size():
		return
	var line := _free_line()
	var label := Label.new()
	label.text = "%s!" % Balance.skill_name(skill)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(size.x, FONT_SIZE * 1.6)
	label.position = Vector2(0.0, size.y * TOP + line * LINE_GAP)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.4
	add_child(label)
	var total := POP_SECONDS + HOLD_SECONDS + FADE_SECONDS
	_slots[line] = _clock + total
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - RISE, total)
	tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS).set_delay(POP_SECONDS + HOLD_SECONDS)
	tween.chain().tween_callback(label.queue_free)


## 비어 있는 가장 위 줄. 다 쓰는 중이면 가장 먼저 비는 줄
func _free_line() -> int:
	var best := 0
	for i in MAX_LINES:
		if _slots[i] <= _clock:
			return i
		if _slots[i] < _slots[best]:
			best = i
	return best

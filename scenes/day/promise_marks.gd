extends Control
## 약속된 휴식 막대 위의 눈금 (방장 #587, 장르 조사 제안 '결말까지 가는 길을 보이게', Gnorp의 압축 단계 막대).
## 바친 생기로 열리는 이야기 조각은 막대의 그 자리(그만큼 바치면 약속되는 휴식)에, 결말(백 년)은 막대 끝에 마름모로 찍는다.
## 열린 조각은 밝은 크림색(금빛 막대 위에서도 보이게 짙은 테두리), 아직이면 속이 빈 마름모, 결말은 조금 크게. 막대(부모)를 덮고 그리기만 한다. 상수는 연출용이다

const MARK_HALF: float = 6.0       # 마름모 반지름
const END_HALF: float = 8.0        # 결말 마름모
const OUTLINE_WIDTH: float = 2.0
const OPEN_FILL := Color("fff4cc")
const OPEN_OUTLINE := Color(0.18, 0.11, 0.05)
const CLOSED_FILL := Color("231c33")
const CLOSED_OUTLINE := Color(0.88, 0.83, 0.72)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	Story.story_changed.connect(queue_redraw)


func _draw() -> void:
	for i in Balance.FRAGMENTS.size():
		var at := position_of(i)
		if at < 0.0:
			continue
		var half := END_HALF if i == Balance.FRAGMENTS.size() - 1 else MARK_HALF
		var x := clampf(at * size.x, half, size.x - half)
		var open := i < Story.unlocked_count
		_diamond(Vector2(x, size.y * 0.5), half, OPEN_FILL if open else CLOSED_FILL, OPEN_OUTLINE if open else CLOSED_OUTLINE)


## 그 조각이 막대의 어디(0~1)에 서는가. 바친 생기·약속된 휴식으로 열리는 조각만 자리가 있다 (밤 수·밭 단계 조각은 -1)
static func position_of(index: int) -> float:
	var goal := Balance.fragment_goal(index)
	match Balance.fragment_stat(index):
		Balance.StoryStat.OFFERED:
			return Balance.promise_progress(Balance.promised_rest_seconds(goal))
		Balance.StoryStat.REST:
			return Balance.promise_progress(goal)
	return -1.0


func _diamond(center: Vector2, half: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)])
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, outline, OUTLINE_WIDTH, true)

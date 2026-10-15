extends VBoxContainer
## 낮 화면 오른쪽 [업적] 칸 (방장 #587, 장르 조사 제안 4·9): 첫 겨울잠 뒤에 열린다 (뒤쪽에도 새 화면이 열리는 맛. 업적과 그 생기 배율은 처음부터 쌓인다).
## 위에 연 수와 모든 생기 배율, 아래로 업적마다 이름·조건·진행 막대. 연 업적은 금빛 이름과 '열림'. 큰 목표(1만 이상)는 막대를 로그 눈금으로 채운다.
## Feats·Balance의 조회 함수만 쓰고 표시만 한다. 상수는 배치용이다

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const TapScroll := preload("res://scenes/ui/tap_scroll.gd")

const GAP: int = 10
const ROW_HEIGHT: float = 70.0
const BAR_HEIGHT: float = 8.0
const STATE_WIDTH: float = 190.0
const HEAD_COLOR := Color("f2d27a")
const DONE_COLOR := Color("f2d27a")
const NOTE_COLOR := Color("b8bcc8")
const HEAD_FONT_SIZE: int = 26
const NOTE_FONT_SIZE: int = 18
const LOG_FROM: float = 1e4   # 목표가 이만큼 크면 막대를 로그 눈금으로 (그대로 나누면 끝까지 거의 비어 있다)

var _gate: RefreshGate
var _head: Label
var _titles: Array[Label] = []
var _states: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	_head = _label(HEAD_FONT_SIZE, HEAD_COLOR)
	add_child(_head)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP / 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := TapScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.add_child(list)
	for i in Balance.ACHIEVEMENTS.size():
		list.add_child(_make_row(i))
	Feats.achievement_unlocked.connect(_gate.queue.unbind(1))
	Game.night_finished.connect(_gate.queue.unbind(1))
	Winter.slept.connect(_gate.queue.unbind(1))
	_refresh()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	if font_size > 0:  # 0이면 테마 크기
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## 업적 하나: 왼쪽에 이름과 조건, 오른쪽에 기록(또는 '열림')과 진행 막대
func _make_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, GAP)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var title := _label(0, Color.WHITE)
	title.text = Balance.ACHIEVEMENTS[index]["name"]
	text.add_child(title)
	_titles.append(title)
	var note := _label(NOTE_FONT_SIZE, NOTE_COLOR)
	note.text = Balance.ACHIEVEMENTS[index]["note"]
	text.add_child(note)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(STATE_WIDTH, 0.0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var state := _label(NOTE_FONT_SIZE, NOTE_COLOR)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(state)
	_states.append(state)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "GoalBar"
	bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	side.add_child(bar)
	_bars.append(bar)
	return panel


func _refresh() -> void:
	var count := Feats.unlocked_count()
	_head.text = "업적 %d / %d  ·  모든 생기 +%d%%" % [count, Balance.ACHIEVEMENTS.size(), roundi((Feats.vitality_multiplier() - 1.0) * 100.0)]
	for i in Balance.ACHIEVEMENTS.size():
		var done: bool = Feats.unlocked[i]
		var goal := float(Balance.ACHIEVEMENTS[i]["goal"])
		var value := Feats.stat_value(int(Balance.ACHIEVEMENTS[i]["stat"]))
		_titles[i].add_theme_color_override("font_color", DONE_COLOR if done else Color.WHITE)
		_states[i].text = "열림" if done else "%s / %s" % [Num.format(value), Num.format(goal)]
		_bars[i].value = 1.0 if done else progress(value, goal)


## 목표까지 얼마나 왔는지 (0~1). 큰 목표는 로그 눈금
static func progress(value: float, goal: float) -> float:
	if goal <= 0.0:
		return 1.0
	if goal < LOG_FROM:
		return clampf(value / goal, 0.0, 1.0)
	return clampf(log(maxf(value, 1.0)) / log(goal), 0.0, 1.0)


## 칩을 보일지: 첫 겨울잠 뒤 (방장 #587 제안 4)
static func is_open() -> bool:
	return Winter.sleeps >= 1

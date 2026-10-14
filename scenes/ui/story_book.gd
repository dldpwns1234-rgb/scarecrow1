extends Control
## 이야기 다시 읽기 (낮 화면 '이야기 N / 10' 버튼으로 연다): 화면을 덮고 조각 10개를 한 줄씩 보인다.
## 열린 조각은 눌러 카드(story_card.gd)로 다시 읽고, 다음 조각 하나만 여는 조건("??? · 밤 5번")을 보이며 나머지는 "???".
## Story를 읽기만 하고, 읽기는 read_requested 시그널로 main.gd가 카드에 넘긴다. 상수는 배치·연출용이다

signal read_requested(index: int)

const SHADE := Color(0.02, 0.02, 0.05, 0.8)
const WIDTH: float = 620.0
const PADDING: int = 20
const ROW_HEIGHT: float = 40.0
const TITLE_COLOR := Color("e9c46a")
const LOCKED_COLOR := Color("6f7486")
const TITLE_FONT_SIZE: int = 26
const CLOSE_SIZE := Vector2(200, 48)

var _count: Label
var _rows: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_count.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(_count)
	for i in Balance.FRAGMENTS.size():
		var row := Button.new()
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.pressed.connect(read_requested.emit.bind(i))
		column.add_child(row)
		_rows.append(row)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = CLOSE_SIZE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	column.add_child(close)
	Story.story_changed.connect(_refresh)
	_refresh()


func open() -> void:
	_refresh()
	visible = true


func _refresh() -> void:
	_count.text = "이야기 조각  %d / %d" % [Story.unlocked_count, Balance.FRAGMENTS.size()]
	for i in _rows.size():
		var row := _rows[i]
		var unlocked := Story.is_unlocked(i)
		row.disabled = not unlocked
		if unlocked:
			row.text = "%d.  %s" % [i + 1, Balance.FRAGMENTS[i]["title"]]
		elif i == Story.unlocked_count:
			row.text = "%d.  ???  ·  %s" % [i + 1, Balance.fragment_hint(i)]
		else:
			row.text = "%d.  ???" % (i + 1)
		row.add_theme_color_override("font_disabled_color", LOCKED_COLOR)

## 창 바깥(어두운 곳)을 누르면 닫는다 (창 안의 누름은 창이 받는다)
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		hide()
		accept_event()

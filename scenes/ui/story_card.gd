extends Control
## 이야기 조각 카드 (docs/STORY.md): 낮에 아직 안 본 조각이 있으면 화면을 어둡게 덮고 가운데에 "이야기 조각 N · 제목"과 독백을 띄운다.
## '계속'을 누르면 Story.mark_seen()으로 본 것으로 치고, 더 열린 조각이 있으면 다음 장이 이어진다.
## 다시 읽기(story_book.gd)가 show_fragment()로 이미 본 조각을 띄우기도 한다 (그때는 '닫기'). Story를 읽고 그 함수만 부른다. 상수는 배치·연출용이다

const SHADE := Color(0.02, 0.02, 0.05, 0.8)
const WIDTH: float = 900.0
const PADDING: int = 28
const TITLE_COLOR := Color("e9c46a")
const TEXT_COLOR := Color("f1eee4")
const TITLE_FONT_SIZE: int = 26
const TEXT_FONT_SIZE: int = 24
const BUTTON_SIZE := Vector2(220, 64)
const DELAY_SECONDS: float = 1.2  # 낮으로 돌아온 뒤 결과 알림을 먼저 보고 나서 뜬다
const FADE_SECONDS: float = 0.3

var _panel: PanelContainer
var _title: Label
var _text: Label
var _button: Button
var _index: int = -1      # 지금 보이는 조각
var _rereading: bool = false
var _pending: bool = false  # 띄우려고 기다리는 중


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
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PADDING / 2)
	margin.add_child(column)
	_title = _label(TITLE_FONT_SIZE, TITLE_COLOR)
	column.add_child(_title)
	_text = _label(TEXT_FONT_SIZE, TEXT_COLOR)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_text)
	_button = Button.new()
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.theme_type_variation = "AccentButton"
	_button.pressed.connect(_on_button)
	column.add_child(_button)
	Story.story_changed.connect(_queue_next)
	Game.phase_changed.connect(_queue_next.unbind(1))


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 다시 읽기: 열린 조각 하나를 띄운다 (본 수는 바꾸지 않는다)
func show_fragment(index: int) -> void:
	if not Story.is_unlocked(index):
		return
	_rereading = true
	_open(index)


## 낮이고 안 본 조각이 있으면 잠깐 뒤에 띄운다 (이미 떠 있으면 '계속'이 이어 준다)
func _queue_next() -> void:
	if visible or _pending or Game.is_night() or Story.next_unseen() < 0:
		return
	_pending = true
	await get_tree().create_timer(DELAY_SECONDS).timeout
	_pending = false
	if not visible and not Game.is_night() and Story.next_unseen() >= 0:
		_rereading = false
		_open(Story.next_unseen())


func _open(index: int) -> void:
	_index = index
	var fragment: Dictionary = Balance.FRAGMENTS[index]
	_title.text = "이야기 조각 %d  ·  %s" % [index + 1, fragment["title"]]
	_text.text = fragment["text"]
	_button.text = "닫기" if _rereading or Story.seen_count + 1 >= Story.unlocked_count else "계속"
	if not visible:
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)


func _on_button() -> void:
	if not _rereading:
		Story.mark_seen(_index)
		var next := Story.next_unseen()
		if next >= 0 and not Game.is_night():
			_open(next)
			return
	_rereading = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(hide)

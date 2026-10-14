extends Control
## 겨울잠 확인 창: 화면을 덮고 받는 것·내려놓는 것·남는 것을 적은 뒤 '겨울잠에 든다'로 Winter.perform()을 부른다. '아직'이나 바깥을 누르면 닫힌다.
## 꿈의 상점(dream_shop.gd)의 sleep_requested를 main.gd가 open()에 잇는다. 상수는 배치용이다

const SHADE := Color(0.02, 0.02, 0.05, 0.8)
const WIDTH: float = 760.0
const PADDING: int = 28
const TITLE_COLOR := Color("c9a2ff")
const TEXT_COLOR := Color("f1eee4")
const TITLE_FONT_SIZE: int = 28
const BUTTON_SIZE := Vector2(240, 64)

var _text: Label


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
	panel.theme_type_variation = "WoodPanel"
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PADDING / 2)
	margin.add_child(column)
	var title := Label.new()
	title.text = "겨울잠에 들까?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", PADDING)
	column.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "아직"
	cancel.custom_minimum_size = BUTTON_SIZE
	cancel.pressed.connect(hide)
	buttons.add_child(cancel)
	var sleep := Button.new()
	sleep.text = "겨울잠에 든다"
	sleep.custom_minimum_size = BUTTON_SIZE
	sleep.theme_type_variation = "AccentButton"
	sleep.pressed.connect(_on_sleep)
	buttons.add_child(sleep)
	gui_input.connect(_on_gui_input)


func open() -> void:
	if not Winter.can_sleep():
		return
	_text.text = "받는 것: 꿈 조각 +%s (밭 %d단계까지 열었다)\n내려놓는 것: 생기, 어둠의 나무, 밭 단계\n남는 것: 꿈 조각과 꿈의 상점, 바친 생기(약속된 휴식), 밤 기록, 이야기" \
		% [Num.format(Winter.shard_reward()), Night.best_level]
	visible = true


func _on_sleep() -> void:
	hide()
	Winter.perform()


## 창 바깥(어두운 곳)을 누르면 닫는다
func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		hide()
		accept_event()

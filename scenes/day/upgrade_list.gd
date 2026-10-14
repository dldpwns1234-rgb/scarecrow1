extends VBoxContainer
## 낮 화면 오른쪽: 업그레이드 나무 (GDD 6절). 줄마다 이름·레벨, 효과, 구매 버튼. 앞 업그레이드가 없으면 잠긴 채 무엇이 필요한지 보인다.
## 줄은 Balance.UPGRADES로 코드에서 만든다. Upgrades의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const TapScroll := preload("res://scenes/ui/tap_scroll.gd")

const GAP: int = 10
const ROW_PADDING: int = 12
const ROW_HEIGHT: float = 104.0  # 두 줄 + 버튼. 글이 바뀌어도 줄 높이와 버튼 자리가 변하지 않는다
const BUTTON_SIZE := Vector2(240, 64)
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8bcc8")
const HEADER_COLOR := Color("e9c46a")
const LOCKED_COLOR := Color("7c8396")

var _gate: RefreshGate
var _titles: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	var header := Label.new()
	header.text = "업그레이드"
	header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(header)
	var scroll := TapScroll.new()  # 버튼 위에서 시작한 드래그도 스크롤되게 (모바일)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", GAP)
	scroll.add_child(column)
	for i in Balance.UPGRADES.size():
		column.add_child(_make_row(i))
	scroll.release_buttons()
	Game.rest_changed.connect(_gate.queue)
	Upgrades.upgrade_changed.connect(_gate.queue)
	_refresh()


func _make_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, ROW_PADDING)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var title := Label.new()
	text.add_child(title)
	var note := Label.new()
	note.text = Balance.upgrade_note(index)
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Upgrades.buy.bind(index))
	row.add_child(button)
	_titles.append(title)
	_buttons.append(button)
	return panel


func _refresh() -> void:
	for i in _buttons.size():
		var cap := Balance.upgrade_max_level(i)
		var level := Upgrades.level(i)
		_titles[i].text = "%s  Lv %d / %d" % [Balance.upgrade_name(i), level, cap] if cap > 0 else "%s  Lv %d" % [Balance.upgrade_name(i), level]
		var button := _buttons[i]
		button.theme_type_variation = ""
		if not Upgrades.is_unlocked(i):
			_titles[i].add_theme_color_override("font_color", LOCKED_COLOR)
			button.text = "잠김: %s 필요" % Balance.upgrade_name(Balance.upgrade_requires(i))
			button.disabled = true
			continue
		_titles[i].remove_theme_color_override("font_color")
		if Upgrades.is_maxed(i):
			button.text = "최대"
			button.disabled = true
			continue
		button.text = "구매 (휴식 %s)" % Num.format(Upgrades.cost(i))
		button.disabled = not Upgrades.can_buy(i)
		if not button.disabled:
			button.theme_type_variation = "AccentButton"

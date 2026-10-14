extends MarginContainer
## 낮: 허수아비의 헛간 (GDD 5절). 왼쪽에 짚돌이·휴식·밤 기록·밭 단계 고르기(field_picker.gd)와 '밤으로 나가기', 오른쪽에 업그레이드 나무(upgrade_tree.gd).
## Game·Upgrades의 시그널을 받아 표시만 하고, 버튼은 Game.start_night()를 부른다. 상수는 배치용이다.

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const UpgradeTree := preload("res://scenes/day/upgrade_tree.gd")
const FieldPicker := preload("res://scenes/day/field_picker.gd")
const PORTRAIT := preload("res://icon.svg")

const MARGIN: int = 24
const GAP: int = 24
const LEFT_WIDTH: float = 420.0
const PORTRAIT_SIZE := Vector2(150, 150)
const NIGHT_BUTTON_HEIGHT: float = 88.0
const RECORD_HEIGHT: float = 80.0  # 두 줄 자리. 글이 바뀌어도 아래가 밀리지 않게
const TITLE_COLOR := Color("e9c46a")
const REST_COLOR := Color("9ad14f")
const NOTE_COLOR := Color("b8bcc8")
const REST_FONT_SIZE: int = 40
const TITLE_FONT_SIZE: int = 28

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _rest: Label
var _record: Label
var _night_button: Button


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	add_child(row)
	row.add_child(_make_left())
	var list := UpgradeTree.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list)
	Game.rest_changed.connect(_gate.queue)
	Game.night_finished.connect(_gate.queue)
	Upgrades.upgrade_changed.connect(_gate.queue)
	Night.field_level_changed.connect(_gate.queue)
	_refresh()


func _make_left() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	column.add_theme_constant_override("separation", GAP / 2)
	var title := _label("낮 · 짚돌이의 헛간", TITLE_FONT_SIZE, TITLE_COLOR)
	column.add_child(title)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)
	_rest = _label("", REST_FONT_SIZE, REST_COLOR)
	column.add_child(_rest)
	_record = _label("", 0, NOTE_COLOR)
	_record.custom_minimum_size = Vector2(0.0, RECORD_HEIGHT)
	column.add_child(_record)
	column.add_child(FieldPicker.new())  # 다음 밤의 밭 단계 (밭 정복으로 열린다)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_night_button = Button.new()
	_night_button.custom_minimum_size = Vector2(0.0, NIGHT_BUTTON_HEIGHT)
	_night_button.theme_type_variation = "AccentButton"
	_night_button.pressed.connect(Game.start_night)
	column.add_child(_night_button)
	return column


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh() -> void:
	_rest.text = "휴식 %s" % Num.format(Game.rest)
	if Game.nights == 0:
		_record.text = "아직 밤에 나가 본 적이 없다.\n밭이 망하면 나도 쉴 수 있겠지…"
	else:
		_record.text = "밤 %d번 지남\n지난 밤 +%s  ·  최고 +%s" % [Game.nights, Num.format(Game.last_haul), Num.format(Game.best_haul)]
	_night_button.text = "밤으로 나가기  ·  밭 %d단계  (%d초)" % [Night.field_level, roundi(Game.night_seconds())]

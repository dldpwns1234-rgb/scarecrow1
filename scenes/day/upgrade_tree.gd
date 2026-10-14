extends VBoxContainer
## 낮 화면 오른쪽: 어둠의 나무 (GDD 6절, 방장 2026-10-14: 사방으로 뻗고 앞 칸을 사야 다음 칸이 나타난다).
## 위에 제목과 '전체 보기'·'가운데로'(줌은 휠·두 손가락 집기도), 가운데에 끌어서 둘러보는 판(tree_board.gd), 아래에 고른 카드의 효과와 구매 버튼 (폰에서 잘못 눌러 사지 않게 구매는 여기서만).
## 카드는 Balance.UPGRADES로 만든다. Upgrades의 함수만 부르고 표시만 한다. 상수는 배치용이다

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const TreeBoard := preload("res://scenes/day/tree_board.gd")

const GAP: int = 12
const DETAIL_HEIGHT: float = 96.0
const BUY_SIZE := Vector2(240, 64)
const CENTER_BUTTON_SIZE := Vector2(130, 44)
const HEADER_COLOR := Color("e9c46a")
const NOTE_COLOR := Color("b8bcc8")
const NOTE_FONT_SIZE: int = 20
const LOCKED_TINT := Color(0.6, 0.6, 0.66)
const CONTRACT_NOTE := "까마귀 모습의 어둠: \"생기를 바쳐라. 그만큼 오래 쉬게 해 주마.\""

var _gate: RefreshGate
var _board: TreeBoard
var _detail_title: Label
var _detail_note: Label
var _buy: Button
var _selected: int = -1  # -1이면 가운데 (어둠의 계약)


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	var top := HBoxContainer.new()
	add_child(top)
	var header := Label.new()
	header.text = "어둠의 나무"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_color_override("font_color", HEADER_COLOR)
	top.add_child(header)
	var fit := Button.new()  # 나무가 커지면 한눈에 (방장 2026-10-15). 휠·두 손가락으로도 줌
	fit.text = "전체 보기"
	fit.custom_minimum_size = CENTER_BUTTON_SIZE
	fit.pressed.connect(func() -> void: _board.fit_all())
	top.add_child(fit)
	var recenter := Button.new()
	recenter.text = "가운데로"
	recenter.custom_minimum_size = CENTER_BUTTON_SIZE
	recenter.pressed.connect(_recenter)
	top.add_child(recenter)
	var frame := PanelContainer.new()  # 나무 틀 안 밤하늘: 헛간 벽과 갈라 보이게 (방장 2026-10-15)
	frame.theme_type_variation = "DarkBoard"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	_board = TreeBoard.new()
	_board.selected.connect(_select)
	frame.add_child(_board)
	_selected = _board.center_index  # 데이터에 어둠의 계약이 있으면 그 줄, 없으면 -1
	add_child(_make_detail())
	Game.vitality_changed.connect(_gate.queue)
	Upgrades.upgrade_changed.connect(_gate.queue)
	_refresh()


func _make_detail() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, DETAIL_HEIGHT)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, GAP)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	_detail_title = Label.new()
	text.add_child(_detail_title)
	_detail_note = Label.new()
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	_detail_note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(_detail_note)
	_buy = Button.new()
	_buy.custom_minimum_size = BUY_SIZE
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(func() -> void: Upgrades.buy(_selected))
	row.add_child(_buy)
	return panel


func _select(index: int) -> void:
	_selected = index
	_refresh()


func _recenter() -> void:
	_board.reset_view()
	_refresh()


func _refresh() -> void:
	_board.refresh(_texts(), _styles(), _tints())
	_buy.visible = _selected >= 0
	if _selected < 0:
		_detail_title.text = "어둠의 계약"
		_detail_note.text = CONTRACT_NOTE
		return
	_detail_title.text = "%s  ·  %s" % [Balance.upgrade_name(_selected), "최대" if Upgrades.is_maxed(_selected) else "Lv %d" % Upgrades.level(_selected)]
	_detail_note.text = Balance.upgrade_note(_selected)
	_buy.text = "최대" if Upgrades.is_maxed(_selected) else "구매 (생기 %s)" % Num.format(Upgrades.cost(_selected))
	_buy.disabled = not Upgrades.can_buy(_selected)
	_buy.theme_type_variation = "AccentButton" if not _buy.disabled else ""


func _texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for i in Balance.UPGRADES.size():
		var cap := Balance.upgrade_max_level(i)
		var level_text := "Lv %d / %d" % [Upgrades.level(i), cap] if cap > 0 else "Lv %d" % Upgrades.level(i)
		var state := "최대" if Upgrades.is_maxed(i) else "생기 %s" % Num.format(Upgrades.cost(i))
		texts.append("%s\n%s\n%s" % [Balance.upgrade_name(i), level_text, state])
	return texts


## 살 수 있으면 금색 카드, 아니면 보통
func _styles() -> PackedStringArray:
	var styles := PackedStringArray()
	for i in Balance.UPGRADES.size():
		styles.append("AccentButton" if Upgrades.can_buy(i) else "")
	return styles


## 아직 0레벨이고 살 수도 없는 카드는 조금 어둡게 (산 카드와 구분)
func _tints() -> Array[Color]:
	var tints: Array[Color] = []
	for i in Balance.UPGRADES.size():
		tints.append(Color.WHITE if Upgrades.level(i) > 0 or Upgrades.can_buy(i) else LOCKED_TINT)
	return tints

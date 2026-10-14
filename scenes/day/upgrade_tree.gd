extends VBoxContainer
## 낮 화면 오른쪽: 업그레이드 나무 (GDD 6절). 업그레이드마다 카드 하나, 앞 업그레이드(requires)에서 오른쪽으로 가지가 뻗는다.
## 깊이(앞 업그레이드를 몇 번 거치는지)가 열, 뿌리부터 그린 순서가 줄이다. 카드를 누르면 아래 설명 칸에 효과와 구매 버튼이 뜬다 (폰에서 잘못 눌러 사지 않게).
## 카드는 Balance.UPGRADES로 코드에서 만든다. Upgrades의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")

const CARD_SIZE := Vector2(160, 104)
const COLUMN_GAP: float = 32.0
const ORIGIN := Vector2(8, 8)  # 고른 카드의 테두리가 판 밖으로 잘리지 않게
const ROW_GAP: float = 24.0
const GAP: int = 12
const DETAIL_HEIGHT: float = 96.0
const BUY_SIZE := Vector2(240, 64)
const LINE_WIDTH: float = 4.0
const LINE_OPEN := Color("e9c46a")
const LINE_LOCKED := Color("3b4458")
const LOCKED_TINT := Color(0.55, 0.55, 0.6)
const SELECT_MARGIN: float = 5.0
const HEADER_COLOR := Color("e9c46a")
const NOTE_COLOR := Color("b8bcc8")
const NOTE_FONT_SIZE: int = 20

var _gate: RefreshGate
var _canvas: Control  # 가지 선을 그리고 카드를 올리는 판
var _cards: Array[Button] = []
var _detail_title: Label
var _detail_note: Label
var _buy: Button
var _selected: int = 0


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	var header := Label.new()
	header.text = "업그레이드 나무"
	header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_canvas = Control.new()
	_canvas.draw.connect(_draw_branches)
	scroll.add_child(_canvas)
	_place_cards()
	add_child(_make_detail())
	Game.rest_changed.connect(_gate.queue)
	Upgrades.upgrade_changed.connect(_gate.queue)
	_refresh()


## 깊이 = 앞 업그레이드를 거친 수. requires는 늘 앞 번호라 차례대로 잴 수 있다
func _depths() -> Array[int]:
	var depths: Array[int] = []
	for i in Balance.UPGRADES.size():
		var need := Balance.upgrade_requires(i)
		depths.append(0 if need < 0 else depths[need] + 1)
	return depths


## 뿌리부터 자식을 따라 내려가며 줄을 매긴다. 첫 자식은 부모와 같은 줄, 둘째 자식부터 새 줄
func _rows() -> Array[int]:
	var rows: Array[int] = []
	rows.resize(Balance.UPGRADES.size())
	var next_row := [0]
	for i in Balance.UPGRADES.size():
		if Balance.upgrade_requires(i) < 0:
			_assign_row(i, next_row[0], rows, next_row)
			next_row[0] += 1
	return rows


func _assign_row(index: int, row: int, rows: Array[int], next_row: Array) -> void:
	rows[index] = row
	var first := true
	for child in Balance.UPGRADES.size():
		if Balance.upgrade_requires(child) != index:
			continue
		if first:
			_assign_row(child, row, rows, next_row)
			first = false
		else:
			next_row[0] += 1
			_assign_row(child, next_row[0], rows, next_row)


func _place_cards() -> void:
	var depths := _depths()
	var rows := _rows()
	var size_needed := Vector2.ZERO
	for i in Balance.UPGRADES.size():
		var card := Button.new()
		card.size = CARD_SIZE
		card.position = ORIGIN + Vector2(depths[i] * (CARD_SIZE.x + COLUMN_GAP), rows[i] * (CARD_SIZE.y + ROW_GAP))
		card.clip_text = true
		card.pressed.connect(_select.bind(i))
		_canvas.add_child(card)
		_cards.append(card)
		size_needed = size_needed.max(card.position + CARD_SIZE)
	_canvas.custom_minimum_size = size_needed + ORIGIN


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


## 가지: 앞 업그레이드 카드의 오른쪽 가운데에서 이 카드의 왼쪽 가운데로 꺾인 선. 열렸으면 짚 색, 아니면 어둡게. 고른 카드는 짚 색 테두리
func _draw_branches() -> void:
	var selected := Rect2(_cards[_selected].position, CARD_SIZE).grow(SELECT_MARGIN)
	_canvas.draw_rect(selected, LINE_OPEN, false, LINE_WIDTH)
	for i in _cards.size():
		var need := Balance.upgrade_requires(i)
		if need < 0:
			continue
		var from := _cards[need].position + Vector2(CARD_SIZE.x, CARD_SIZE.y * 0.5)
		var to := _cards[i].position + Vector2(0.0, CARD_SIZE.y * 0.5)
		var mid_x := from.x + COLUMN_GAP * 0.5
		var color := LINE_OPEN if Upgrades.is_unlocked(i) else LINE_LOCKED
		_canvas.draw_polyline(PackedVector2Array([from, Vector2(mid_x, from.y), Vector2(mid_x, to.y), to]), color, LINE_WIDTH)


func _refresh() -> void:
	for i in _cards.size():
		var card := _cards[i]
		var cap := Balance.upgrade_max_level(i)
		var level_text := "Lv %d / %d" % [Upgrades.level(i), cap] if cap > 0 else "Lv %d" % Upgrades.level(i)
		var state := "최대" if Upgrades.is_maxed(i) else ("잠김" if not Upgrades.is_unlocked(i) else "휴식 %s" % Num.format(Upgrades.cost(i)))
		card.text = "%s\n%s\n%s" % [Balance.upgrade_name(i), level_text, state]
		card.theme_type_variation = "AccentButton" if Upgrades.can_buy(i) else ""
		card.modulate = Color.WHITE if Upgrades.is_unlocked(i) else LOCKED_TINT  # 잠긴 카드도 눌러서 무엇이 필요한지 본다
	_detail_title.text = "%s  ·  %s" % [Balance.upgrade_name(_selected), "최대" if Upgrades.is_maxed(_selected) else "Lv %d" % Upgrades.level(_selected)]
	_detail_note.text = Balance.upgrade_note(_selected)
	if not Upgrades.is_unlocked(_selected):
		_buy.text = "잠김: %s 필요" % Balance.upgrade_name(Balance.upgrade_requires(_selected))
	elif Upgrades.is_maxed(_selected):
		_buy.text = "최대"
	else:
		_buy.text = "구매 (휴식 %s)" % Num.format(Upgrades.cost(_selected))
	_buy.disabled = not Upgrades.can_buy(_selected)
	_buy.theme_type_variation = "AccentButton" if not _buy.disabled else ""
	_canvas.queue_redraw()

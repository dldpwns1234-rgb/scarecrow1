extends "res://scenes/day/tree_pan_zoom.gd"
## 스킬트리 판: 가운데 '어둠의 계약'에서 사방으로 뻗는 카드와 가지 선. 끌면 판이 움직이고, 짧게 누르면 그 카드를 고른다 (selected 시그널).
## 앞 업그레이드를 1레벨 이상 사야 카드가 나타난다(뿌리는 처음부터). 새로 나타날 때 떠오르고, 사면 톡 튄다 (card_fx.gd).
## 카드는 입력을 받지 않고(IGNORE) 판이 누름·끌기를 가른다: 버튼이 누름을 삼키면 버튼 위에서 시작한 끌기가 안 된다 (회귀 용사 tap_scroll과 같은 까닭).
## 끌기·줌·누름 판정은 1부 tree_pan_zoom.gd, 배치는 tree_layout.gd. Upgrades의 함수만 읽는다. 상수는 배치·연출용이다

signal selected(index: int)  # -1이면 가운데 (어둠의 계약)

const TreeLayout := preload("res://scenes/day/tree_layout.gd")
const CardFx := preload("res://scenes/day/card_fx.gd")
const CARD_SIZE := TreeLayout.CARD
const STEP := TreeLayout.STEP     # 격자 한 칸의 간격 (배치가 선이 카드를 지나는지 따질 때도 쓴다)
const CENTER_RADIUS: float = 58.0
const LINE_WIDTH: float = 4.0
const LINE_OPEN := Color("e9c46a")
const LINE_DIM := Color("4d5874")
const CENTER_FILL := Color("2b1f3a")
const CENTER_RING := Color("9d7bd8")
const SELECT_COLOR := Color("e9c46a")
const SELECT_MARGIN: float = 5.0
const CARD_TEXT_PADDING: float = 40.0  # 카드 안 좌우 여백 (테마 버튼 여백 포함)
const MIN_CARD_FONT: int = 13
const EDGE_MARK: float = 10.0     # 판 밖의 살 수 있는 카드를 가리키는 가장자리 세모 크기

var selected_index: int = -1
var center_index: int = -1        # 데이터에 어둠의 계약(branch "center")이 있으면 그 번호. 가운데 원이 그 카드 노릇을 한다
var _cells: Array[Vector2i] = []
var _cards: Array[Button] = []
var _shown: Array[bool] = []
var _center_label: Label
var _marks: Control  # 카드 위층: 판 밖 살 수 있는 카드를 가리키는 세모


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cells = TreeLayout.cells(Balance.UPGRADES)
	for i in Balance.UPGRADES.size():
		if Balance.UPGRADES[i].get("branch", "") == "center":
			center_index = i
			selected_index = i
	_center_label = Label.new()
	_center_label.text = "어둠의\n계약"
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.size = Vector2.ONE * CENTER_RADIUS * 2.0
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_label)
	for i in Balance.UPGRADES.size():
		var card := Button.new()
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE * 0.5
		card.clip_text = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.visible = false
		add_child(card)
		_cards.append(card)
		_shown.append(false)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_edge_marks)
	add_child(_marks)
	resized.connect(_place)


## 카드 글과 보이기를 다시 맞춘다. 새로 나타난 카드는 떠오른다
func refresh(texts: PackedStringArray, styles: PackedStringArray, tints: Array[Color]) -> void:
	for i in _cards.size():
		var card := _cards[i]
		if card.text != texts[i]:
			card.text = texts[i]
			_fit_font(card)
		card.theme_type_variation = styles[i]
		card.self_modulate = tints[i]
		var show := _is_revealed(i) and i != center_index  # 가운데 줄은 원으로 그린다
		if show and not _shown[i]:
			CardFx.reveal(card, zoom)
		card.visible = show
		_shown[i] = show
	_place()


## 가장 긴 줄(대개 이름)이 카드 폭을 넘으면 그 카드만 글을 줄인다 ("새벽 전 몰아치기"가 잘렸다)
func _fit_font(card: Button) -> void:
	card.remove_theme_font_size_override("font_size")
	var font := card.get_theme_font("font")
	var base := card.get_theme_font_size("font_size")
	var widest := 0.0
	for line in card.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x)
	var room := CARD_SIZE.x - CARD_TEXT_PADDING
	if widest > room:
		card.add_theme_font_size_override("font_size", maxi(floori(base * room / widest), MIN_CARD_FONT))


## 샀을 때 그 카드가 톡 튀며 번쩍인다 (upgrade_tree가 부른다)
func pulse(index: int) -> void:
	if index >= 0 and _cards[index].visible:
		CardFx.pulse(_cards[index], zoom)


## 뿌리는 처음부터, 나머지는 앞 업그레이드를 1레벨 이상 샀을 때 나타난다
func _is_revealed(index: int) -> bool:
	return Upgrades.is_unlocked(index)


func _place() -> void:
	var center := center_point()
	_center_label.position = center - _center_label.size * 0.5
	_center_label.pivot_offset = _center_label.size * 0.5
	_center_label.scale = Vector2.ONE * zoom
	for i in _cards.size():
		_cards[i].position = _card_center(i) - CARD_SIZE * 0.5  # 가운데(pivot)를 축으로 줄어든다
		if _cards[i].visible and not CardFx.busy(_cards[i]):
			_cards[i].scale = Vector2.ONE * zoom
	queue_redraw()
	_marks.queue_redraw()


func _card_center(index: int) -> Vector2:
	return center_point() + Vector2(_cells[index]) * STEP * zoom


func _draw() -> void:
	var center := center_point()
	for i in _cards.size():
		if not _cards[i].visible:
			continue
		var need := Balance.upgrade_requires(i)
		var from := center if need < 0 or need == center_index else _card_center(need)
		var bought := need < 0 or Upgrades.level(need) > 0
		draw_line(from, _card_center(i), LINE_OPEN if bought else LINE_DIM, LINE_WIDTH)
	var radius := CENTER_RADIUS * zoom
	draw_circle(center, radius, CENTER_FILL)
	draw_arc(center, radius, 0.0, TAU, 48, CENTER_RING, LINE_WIDTH)
	if selected_index < 0 or selected_index == center_index:
		draw_arc(center, radius + SELECT_MARGIN * 1.5, 0.0, TAU, 48, SELECT_COLOR, LINE_WIDTH)
	elif _cards[selected_index].visible:
		draw_rect(Rect2(_card_center(selected_index) - CARD_SIZE * 0.5 * zoom, CARD_SIZE * zoom).grow(SELECT_MARGIN), SELECT_COLOR, false, LINE_WIDTH)


## 판 밖에 있는 살 수 있는 카드(금칠) 쪽 가장자리에 금빛 세모: 64칸 나무를 당겨 보고 있어도 살 것을 놓치지 않게 (방장 #529)
func _draw_edge_marks() -> void:
	var view := Rect2(Vector2.ZERO, size)
	var inner := view.grow(-EDGE_MARK * 1.5)
	for i in _cards.size():
		var point := _card_center(i)
		if not _cards[i].visible or _cards[i].theme_type_variation != "AccentButton" or view.has_point(point):
			continue
		var at := point.clamp(inner.position, inner.end)
		var dir := (point - at).normalized()
		var side := dir.orthogonal() * EDGE_MARK * 0.7
		_marks.draw_colored_polygon(PackedVector2Array([at + dir * EDGE_MARK, at - dir * EDGE_MARK * 0.5 + side, at - dir * EDGE_MARK * 0.5 - side]), SELECT_COLOR)


## 짧게 누른 자리의 카드를 고른다 (끌기와 줌은 1부)
func _tap(point: Vector2) -> void:
	if point.distance_to(center_point()) <= CENTER_RADIUS * zoom:
		_choose(center_index)
		return
	for i in _cards.size():
		if _cards[i].visible and Rect2(_card_center(i) - CARD_SIZE * 0.5 * zoom, CARD_SIZE * zoom).has_point(point):
			_choose(i)
			return


func _choose(index: int) -> void:
	selected_index = index
	selected.emit(index)
	queue_redraw()


## 가운데에서 가장 먼 보이는 카드의 바깥 가장자리까지 (줌 1 기준, 1부의 끌기 한계·전체 보기가 묻는다)
func _reach() -> Vector2:
	var reach := Vector2.ONE * CENTER_RADIUS
	for i in _cards.size():
		if _cards[i].visible:
			reach = reach.max((Vector2(_cells[i]) * STEP).abs() + CARD_SIZE * 0.5)
	return reach


func _bounds() -> Rect2:
	var box := Rect2(-Vector2.ONE * CENTER_RADIUS, Vector2.ONE * CENTER_RADIUS * 2.0)
	for i in _cards.size():
		if _cards[i].visible:
			box = box.merge(Rect2(Vector2(_cells[i]) * STEP - CARD_SIZE * 0.5, CARD_SIZE))
	return box


extends Control
## 스킬트리 판: 가운데 '어둠의 계약'에서 사방으로 뻗는 카드와 가지 선. 끌면 판이 움직이고, 짧게 누르면 그 카드를 고른다 (selected 시그널).
## 앞 업그레이드를 1레벨 이상 사야 카드가 나타난다(뿌리는 처음부터). 새로 나타날 때 작게 시작해 커지며 떠오른다.
## 카드는 입력을 받지 않고(IGNORE) 판이 누름·끌기를 가른다: 버튼이 누름을 삼키면 버튼 위에서 시작한 끌기가 안 된다 (회귀 용사 tap_scroll과 같은 까닭).
## 배치는 tree_layout.gd. Upgrades의 함수만 읽는다. 상수는 배치·연출용이다

signal selected(index: int)  # -1이면 가운데 (어둠의 계약)

const TreeLayout := preload("res://scenes/day/tree_layout.gd")
const CARD_SIZE := Vector2(150, 96)
const STEP := Vector2(196, 136)   # 격자 한 칸의 간격
const CENTER_RADIUS: float = 58.0
const TAP_SLOP: float = 18.0
const PAN_MARGIN: float = 160.0   # 보이는 카드 바깥으로 이만큼까지만 끌린다
const LINE_WIDTH: float = 4.0
const LINE_OPEN := Color("e9c46a")
const LINE_DIM := Color("4d5874")
const CENTER_FILL := Color("2b1f3a")
const CENTER_RING := Color("9d7bd8")
const SELECT_COLOR := Color("e9c46a")
const SELECT_MARGIN: float = 5.0
const REVEAL_SECONDS: float = 0.35
const CARD_TEXT_PADDING: float = 40.0  # 카드 안 좌우 여백 (테마 버튼 여백 포함)
const MIN_CARD_FONT: int = 13

var pan: Vector2 = Vector2.ZERO   # 가운데 노드가 판 가운데에서 얼마나 옮겨졌는지
var selected_index: int = -1
var center_index: int = -1        # 데이터에 어둠의 계약(branch "center")이 있으면 그 번호. 가운데 원이 그 카드 노릇을 한다
var _cells: Array[Vector2i] = []
var _cards: Array[Button] = []
var _shown: Array[bool] = []
var _center_label: Label
var _press: Vector2 = Vector2.INF
var _press_pan: Vector2 = Vector2.ZERO
var _dragging: bool = false


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
	resized.connect(_place)


## 가운데 노드의 화면 자리
func center_point() -> Vector2:
	return size * 0.5 + pan


func card(index: int) -> Button:
	return _cards[index]


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
			_reveal(card)
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


## 뿌리는 처음부터, 나머지는 앞 업그레이드를 1레벨 이상 샀을 때 나타난다
func _is_revealed(index: int) -> bool:
	return Upgrades.is_unlocked(index)


func _reveal(card: Button) -> void:
	card.scale = Vector2.ONE * 0.6
	card.modulate.a = 0.0
	var tween := card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, REVEAL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, REVEAL_SECONDS)


func _place() -> void:
	var center := center_point()
	_center_label.position = center - _center_label.size * 0.5
	for i in _cards.size():
		_cards[i].position = _card_center(i) - CARD_SIZE * 0.5
	queue_redraw()


func _card_center(index: int) -> Vector2:
	return center_point() + Vector2(_cells[index]) * STEP


func _draw() -> void:
	var center := center_point()
	for i in _cards.size():
		if not _cards[i].visible:
			continue
		var need := Balance.upgrade_requires(i)
		var from := center if need < 0 or need == center_index else _card_center(need)
		var bought := need < 0 or Upgrades.level(need) > 0
		draw_line(from, _card_center(i), LINE_OPEN if bought else LINE_DIM, LINE_WIDTH)
	draw_circle(center, CENTER_RADIUS, CENTER_FILL)
	draw_arc(center, CENTER_RADIUS, 0.0, TAU, 48, CENTER_RING, LINE_WIDTH)
	if selected_index < 0 or selected_index == center_index:
		draw_arc(center, CENTER_RADIUS + SELECT_MARGIN * 1.5, 0.0, TAU, 48, SELECT_COLOR, LINE_WIDTH)
	elif _cards[selected_index].visible:
		draw_rect(Rect2(_card_center(selected_index) - CARD_SIZE * 0.5, CARD_SIZE).grow(SELECT_MARGIN), SELECT_COLOR, false, LINE_WIDTH)


## 누른 자리에서 TAP_SLOP 안에서 떼면 그 자리의 카드를 고르고, 넘으면 판을 끈다
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press = button.position
			_press_pan = pan
			_dragging = false
		elif _press != Vector2.INF:
			if not _dragging:
				_tap(button.position)
			_press = Vector2.INF
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _press != Vector2.INF:
		if not _dragging and motion.position.distance_to(_press) > TAP_SLOP:
			_dragging = true
		if _dragging:
			pan = _clamp_pan(_press_pan + motion.position - _press)
			_place()
		accept_event()


func _tap(point: Vector2) -> void:
	if point.distance_to(center_point()) <= CENTER_RADIUS:
		_choose(center_index)
		return
	for i in _cards.size():
		if _cards[i].visible and Rect2(_cards[i].position, CARD_SIZE).has_point(point):
			_choose(i)
			return


func _choose(index: int) -> void:
	selected_index = index
	selected.emit(index)
	queue_redraw()


## 보이는 카드들이 화면 밖으로 다 나가지 않게: 가장 바깥 카드 너머로 PAN_MARGIN까지만
func _clamp_pan(wanted: Vector2) -> Vector2:
	var reach := Vector2.ZERO
	for i in _cards.size():
		if _cards[i].visible:
			reach = reach.max((Vector2(_cells[i]) * STEP).abs())
	var limit := reach + Vector2.ONE * PAN_MARGIN - size * 0.5 + CARD_SIZE * 0.5
	limit = limit.max(Vector2.ZERO)
	return wanted.clamp(-limit, limit)

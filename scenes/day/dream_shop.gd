extends VBoxContainer
## 낮 화면 오른쪽 [꿈의 상점] 칸 (GDD 8절 겨울잠): 꿈 조각, 겨울잠 줄(지금 들면 받을 조각과 '겨울잠에 들기'), 꿈 6종 카드(이름·효과·레벨·구매).
## 겨울잠 버튼은 sleep_requested만 낸다 (확인 창은 main.gd의 winter_confirm.gd). Winter의 함수만 부르고 표시만 한다. 상수는 배치용이다

signal sleep_requested()

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const TapScroll := preload("res://scenes/ui/tap_scroll.gd")
const KoreanText := preload("res://scenes/ui/korean_text.gd")
const ICON_SHARD := preload("res://assets/sprites/ui/icon_shard.svg")
const SHARD_ICON := Vector2(36, 36)

const GAP: int = 12
const COLUMNS: int = 1  # 한 줄에 하나 (두 칸이면 이름·효과가 잘리고 낱말 중간에서 줄이 바뀌었다)
const CARD_HEIGHT: float = 66.0
const SLEEP_BUTTON_SIZE := Vector2(300, 64)
const BUY_SIZE := Vector2(136, 52)
const SHARD_COLOR := Color("c9a2ff")
const NOTE_COLOR := Color("b8bcc8")
const SHARD_FONT_SIZE: int = 30
const NOTE_FONT_SIZE: int = 20
const NOTE_CHARS: int = 34  # 꿈 설명 한 줄의 글자 수

var _gate: RefreshGate
var _shards: Label
var _sleep_note: Label
var _sleep: Button
var _titles: Array[Label] = []
var _buys: Array[Button] = []


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	add_child(head)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	var shard_row := HBoxContainer.new()
	text.add_child(shard_row)
	var shard := TextureRect.new()
	shard.texture = ICON_SHARD
	shard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard.custom_minimum_size = SHARD_ICON
	shard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shard_row.add_child(shard)
	_shards = _label(SHARD_FONT_SIZE, SHARD_COLOR)
	_shards.autowrap_mode = TextServer.AUTOWRAP_OFF  # 가로줄 안이라 줄바꿈을 켜면 글자마다 세로로 선다
	shard_row.add_child(_shards)
	_sleep_note = _label(NOTE_FONT_SIZE, NOTE_COLOR)
	text.add_child(_sleep_note)
	_sleep = Button.new()
	_sleep.custom_minimum_size = SLEEP_BUTTON_SIZE
	_sleep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sleep.pressed.connect(sleep_requested.emit)
	head.add_child(_sleep)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP / 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := TapScroll.new()  # 꿈이 늘어나도 끌어서 본다 (버튼 위에서 시작한 끌기도 스크롤)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.add_child(grid)
	for i in Balance.DREAMS.size():
		grid.add_child(_make_card(i))
	scroll.release_buttons()
	Winter.shards_changed.connect(_gate.queue.unbind(1))
	Winter.dream_changed.connect(_gate.queue.unbind(2))
	Winter.slept.connect(_gate.queue.unbind(1))
	Night.field_level_changed.connect(_gate.queue.unbind(2))
	_refresh()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 꿈 하나: 왼쪽에 이름·레벨과 효과, 오른쪽에 구매 버튼 (여섯 줄이 화면에 들어가게 위아래 여백 없이)
func _make_card(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, GAP)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	margin.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title := Label.new()
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # 긴 이름이 폭을 밀어내지 않게
	column.add_child(title)
	_titles.append(title)
	var note := _label(NOTE_FONT_SIZE, NOTE_COLOR)
	note.text = KoreanText.wrap(Balance.dream_note(index), NOTE_CHARS)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(note)
	var buy := Button.new()
	buy.custom_minimum_size = BUY_SIZE
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(func() -> void: Winter.buy(index))
	row.add_child(buy)
	_buys.append(buy)
	return panel


func _refresh() -> void:
	_shards.text = "꿈 조각 %s" % Num.format(Winter.shards)
	var reward := Winter.shard_reward()
	if Balance.can_winter(Night.best_level):
		_sleep_note.text = "겨울잠 %d번  ·  지금 들면 꿈 조각 +%s (밭 %d단계까지 열림)" % [Winter.sleeps, Num.format(reward), Night.best_level]
	else:
		_sleep_note.text = "겨울잠 %d번  ·  밭 %d단계를 열면 겨울잠에 들 수 있다" % [Winter.sleeps, Balance.WINTER_MIN_LEVEL]
	_sleep.text = "겨울잠에 들기  ·  +%s" % Num.format(reward) if reward > 0.0 else "겨울잠에 들기"
	_sleep.disabled = not Winter.can_sleep()
	_sleep.theme_type_variation = "AccentButton" if not _sleep.disabled else ""
	for i in _titles.size():
		var cap := Balance.dream_max_level(i)
		var level_text := "Lv %d / %d" % [Winter.level(i), cap] if cap > 0 else "Lv %d" % Winter.level(i)
		_titles[i].text = "%s  ·  %s" % [Balance.dream_name(i), level_text]
		var buy := _buys[i]
		buy.text = "최대" if Winter.is_maxed(i) else "꿈 조각 %s" % Num.format(Winter.cost(i))
		buy.disabled = not Winter.can_buy(i)
		buy.theme_type_variation = "AccentButton" if not buy.disabled else ""


## 칩을 보일지: 겨울잠을 한 번이라도 했거나 지금 들 수 있으면
static func is_open() -> bool:
	return Winter.sleeps > 0 or Balance.can_winter(Night.best_level)


## 칩에 점: 겨울잠에 들 수 있거나 살 수 있는 꿈이 있으면
static func has_dot() -> bool:
	if Winter.can_sleep():
		return true
	for i in Balance.DREAMS.size():
		if Winter.can_buy(i):
			return true
	return false

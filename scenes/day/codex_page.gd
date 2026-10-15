extends VBoxContainer
## 낮 화면 오른쪽 [도감] 칸 (방장 #587, 장르 조사 제안 4·8): 둘째 겨울잠 뒤에 열린다 (숙련과 그 생기 배율은 처음부터 쌓인다).
## 작물마다 그림·이름·숙련·그 작물 생기 배율, 다음 숙련까지 시든 수와 막대. 아직 밭에 나온 적 없는 작물은 그림자와 '???', 나오는 밭 단계(철 작물은 겨울잠 횟수).
## 작물이 늘어 그림 배열보다 많으면 밀 그림을 대신 쓴다 (그림이 올 때까지).
## Feats·Balance의 조회 함수만 쓰고 표시만 한다. 상수는 배치용이다

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const TapScroll := preload("res://scenes/ui/tap_scroll.gd")
## 작물 그림 (Balance.CROPS 순서: 밀·옥수수·호박·황금 이삭·순무·해바라기·수박·포도·얼음꽃·버섯·달맞이꽃. 밤 밭 field_view.gd와 같은 그림)
const ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/crops/wheat.svg"), preload("res://assets/sprites/crops/corn.svg"),
	preload("res://assets/sprites/crops/pumpkin.svg"), preload("res://assets/sprites/crops/golden.svg"),
	preload("res://assets/sprites/crops/turnip.svg"), preload("res://assets/sprites/crops/sunflower.svg"),
	preload("res://assets/sprites/crops/watermelon.svg"), preload("res://assets/sprites/crops/grape.svg"),
	preload("res://assets/sprites/crops/iceflower.svg"), preload("res://assets/sprites/crops/mushroom.svg"),
	preload("res://assets/sprites/crops/moonflower.svg"),
]

const GAP: int = 10
const ROW_HEIGHT: float = 74.0
const ICON_SIZE := Vector2(56, 56)
const BAR_HEIGHT: float = 8.0
const SIDE_WIDTH: float = 230.0
const HEAD_COLOR := Color("9ad14f")
const MASTER_COLOR := Color("f2d27a")
const NOTE_COLOR := Color("b8bcc8")
const HIDDEN_TINT := Color(0.05, 0.05, 0.08, 0.85)
const HEAD_FONT_SIZE: int = 26
const NOTE_FONT_SIZE: int = 18

var _gate: RefreshGate
var _head: Label
var _icons: Array[TextureRect] = []
var _titles: Array[Label] = []
var _notes: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	_head = _label(HEAD_FONT_SIZE, HEAD_COLOR)
	_head.text = "작물 도감  ·  시든 수가 쌓이면 숙련, 숙련마다 그 작물 생기 +%d%%" % roundi(Balance.MASTERY_PER_LEVEL * 100.0)
	add_child(_head)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP / 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := TapScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.add_child(list)
	for crop in Balance.CROPS.size():
		list.add_child(_make_row(crop))
	Feats.mastery_changed.connect(_gate.queue.unbind(2))
	Game.night_finished.connect(_gate.queue.unbind(1))
	Night.field_level_changed.connect(_gate.queue.unbind(2))
	_refresh()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	if font_size > 0:  # 0이면 테마 크기
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## 작물 하나: 그림, 이름·숙련, 오른쪽에 시든 수와 다음 숙련까지 막대
func _make_row(crop: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, GAP)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICONS[crop] if crop < ICONS.size() else ICONS[0]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_icons.append(icon)
	var title := _label(0, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_titles.append(title)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var note := _label(NOTE_FONT_SIZE, NOTE_COLOR)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(note)
	_notes.append(note)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "GoalBar"
	bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	side.add_child(bar)
	_bars.append(bar)
	return panel


func _refresh() -> void:
	var reached := maxi(Workers.best_ever, Night.best_level)
	for crop in Balance.CROPS.size():
		var count: float = Feats.withered[crop]
		var from := int(Balance.CROPS[crop].get("from", 1))
		var season: int = Balance.call("crop_season", crop) if Balance.has_method("crop_season") else 0  # 철 작물 (별빛: 겨울잠 횟수)
		var seen := count > 0.0 or (Winter.sleeps >= season if season > 0 else reached >= from)
		_icons[crop].modulate = Color.WHITE if seen else HIDDEN_TINT
		if not seen:
			_titles[crop].text = "???"
			_titles[crop].add_theme_color_override("font_color", NOTE_COLOR)
			_notes[crop].text = "겨울잠 %d번 뒤에 나타난다" % season if season > 0 else "밭 %d단계에서 나타난다" % from
			_bars[crop].value = 0.0
			continue
		var level := Feats.mastery(crop)
		var name: String = Balance.CROPS[crop]["name"]
		_titles[crop].text = "%s  ·  숙련 %d  ·  생기 +%d%%" % [name, level, roundi(Balance.MASTERY_PER_LEVEL * level * 100.0)] if level > 0 else name
		_titles[crop].add_theme_color_override("font_color", MASTER_COLOR if level > 0 else Color.WHITE)
		if level >= Balance.MASTERY_MAX:
			_notes[crop].text = "시든 수 %s  ·  숙련 끝" % Num.format(count)
			_bars[crop].value = 1.0
			continue
		var low := Balance.mastery_goal(level) if level > 0 else 0.0
		var high := Balance.mastery_goal(level + 1)
		_notes[crop].text = "시든 수 %s / %s" % [Num.format(count), Num.format(high)]
		_bars[crop].value = clampf((count - low) / maxf(high - low, 1.0), 0.0, 1.0)


## 칩을 보일지: 둘째 겨울잠 뒤 (방장 #587 제안 4: 업적보다 한 철 늦게)
static func is_open() -> bool:
	return Winter.sleeps >= 2

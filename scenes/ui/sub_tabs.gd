extends VBoxContainer
## 탭 안의 하위 탭 (칩 줄과 칸): 회귀 탭의 회귀·환생·초월·심연·자동, 업적 탭의 업적·도전·시련·기억 (방장 2026-10-03: 회귀 탭 스크롤이 너무 길다).
## 한 번에 한 칸만 보인다. 아직 열리지 않은 칸은 칩도 숨기고, 보이는 칩이 하나뿐이면 칩 줄을 숨겨 초반은 예전처럼 단순하다.
## 놀다가 새로 열린 칸은 칩 이름 앞에 '새 칸 ·'을 붙이고 금빛으로 숨 쉬듯 반짝이며 소리를 낸다. 한 번 눌러 보면 그친다 (방장 #626, 장르 조사 '하나씩 열리는 맛').
## 처음 만들 때 이미 열려 있던 칸(불러온 저장)은 조용하다. 살 것이 있는 칸은 칩 오른쪽 위에 점. 고른 칸은 탭을 오가도 남는다. 열림과 점은 보이는 동안 잠깐마다 다시 본다 (상태는 묻기만 한다).

const TapScroll := preload("res://scenes/ui/tap_scroll.gd")
const GAP: int = 8
const CHIP_HEIGHT: float = 52.0
const BADGE_SIZE := Vector2(10, 10)
const BADGE_COLOR := Color("ffe66d")
const BADGE_INSET := Vector2(16, 8)  # 칩 오른쪽 위 모서리에서 얼마나 안쪽에 점을 찍을지
const CHECK_INTERVAL: float = 0.5  # 초. 칩 열림과 점을 다시 보는 간격
const NEW_PREFIX := "새 칸 · "
const NEW_GLOW := Color(1.35, 1.2, 0.75)  # 새 칩이 숨 쉬듯 밝아지는 빛
const NEW_GLOW_SECONDS: float = 0.7

var _row: HBoxContainer
var _group := ButtonGroup.new()
var _chips: Array[Button] = []
var _badges: Array[Panel] = []
var _pages: Array[Control] = []
var _shown: Array[Callable] = []
var _dots: Array[Callable] = []
var _titles: PackedStringArray = []
var _known: Array[bool] = []    # 칩이 한 번이라도 보였는지
var _glows: Dictionary = {}       # 새 칩 번호 → 반짝이는 Tween
var _selected: int = 0
var _check_left: float = 0.0


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	add_child(_row)


## 칩 줄 바로 아래, 모든 칸 위에 늘 보이는 띠 하나를 둔다 (낮 화면의 마을 소문)
func add_banner(banner: Control) -> void:
	add_child(banner)
	move_child(banner, 1)


## 칸 하나를 붙인다. shown은 칸이 열렸는지(비우면 늘 열림), dot은 칩에 점을 찍을지. 먼저 이 부품을 트리에 넣고 부른다
func add_page(title: String, page: Control, shown: Callable = Callable(), dot: Callable = Callable()) -> void:
	var chip := Button.new()
	chip.text = title
	chip.toggle_mode = true
	chip.button_group = _group
	chip.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.clip_text = true
	chip.pressed.connect(select.bind(_chips.size()))
	_row.add_child(chip)
	_badges.append(_make_badge(chip))
	_chips.append(chip)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.visible = false
	add_child(page)
	_pages.append(page)
	_shown.append(shown)
	_dots.append(dot)
	_titles.append(title)
	_known.append(true)  # 만드는 동안은 알리지 않는다 (아래에서 보이는지로 다시 정한다)
	refresh()
	_known[_chips.size() - 1] = chip.visible  # 만들 때 이미 열린 칸은 새것이 아니다


## 내용을 끌어 스크롤하는 칸으로 붙인다 (버튼 위에서 시작한 드래그도 스크롤된다)
func add_scroll_page(title: String, children: Array[Control], shown: Callable = Callable(), dot: Callable = Callable()) -> void:
	var scroll := TapScroll.new()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", GAP)
	scroll.add_child(column)
	add_page(title, scroll, shown, dot)
	for child in children:
		column.add_child(child)
	scroll.release_buttons()


func select(index: int) -> void:
	_selected = index
	_calm(index)
	refresh()


func selected() -> int:
	return _selected


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0 and is_visible_in_tree():
		_check_left = CHECK_INTERVAL
		refresh()


## 칩 열림, 고른 칸(숨은 칸을 골랐으면 처음 열린 칸으로), 칸 보이기, 점을 다시 맞춘다
func refresh() -> void:
	var open_count := 0
	for i in _chips.size():
		_chips[i].visible = _shown[i].is_null() or _shown[i].call()
		if _chips[i].visible:
			open_count += 1
			if i < _known.size() and not _known[i]:
				_known[i] = true
				_announce(i)
	if _selected >= _chips.size() or not _chips[_selected].visible:
		_selected = maxi(_first_open(), 0)
	_row.visible = open_count > 1
	for i in _chips.size():
		var on := i == _selected
		_chips[i].set_pressed_no_signal(on)
		_chips[i].theme_type_variation = "AccentButton" if on else ""
		_pages[i].visible = on
		_badges[i].visible = _chips[i].visible and not on and not _dots[i].is_null() and _dots[i].call()


## 놀다가 새로 열린 칸: 이름 앞 '새 칸 ·', 숨 쉬는 금빛, 소리
func _announce(index: int) -> void:
	var chip := _chips[index]
	chip.text = NEW_PREFIX + _titles[index]
	var tween := chip.create_tween().set_loops()
	tween.tween_property(chip, "self_modulate", NEW_GLOW, NEW_GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chip, "self_modulate", Color.WHITE, NEW_GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	_glows[index] = tween
	Sfx.play("feat")


func _calm(index: int) -> void:
	if not _glows.has(index):
		return
	(_glows[index] as Tween).kill()
	_glows.erase(index)
	_chips[index].self_modulate = Color.WHITE
	_chips[index].text = _titles[index]


## 새로 열려 아직 눌러 보지 않은 칸인가 (테스트·화면 확인용)
func is_new(index: int) -> bool:
	return _glows.has(index)


func _first_open() -> int:
	for i in _chips.size():
		if _chips[i].visible:
			return i
	return -1


func _make_badge(chip: Button) -> Panel:
	var badge := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_COLOR
	style.set_corner_radius_all(roundi(BADGE_SIZE.x * 0.5))
	badge.add_theme_stylebox_override("panel", style)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-BADGE_INSET.x - BADGE_SIZE.x, BADGE_INSET.y)
	badge.size = BADGE_SIZE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	chip.add_child(badge)
	return badge

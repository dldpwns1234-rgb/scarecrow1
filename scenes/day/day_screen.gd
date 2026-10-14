extends MarginContainer
## 낮: 허수아비의 헛간 (GDD 5절). 왼쪽에 짚돌이·생기·약속된 휴식·밤 기록·밭 단계 고르기(field_picker.gd)와 '밤으로 나가기',
## 오른쪽에 칩 [어둠의 나무](upgrade_tree.gd) [꿈의 상점](dream_shop.gd, 겨울잠이 열리면) [아지트](hideout.gd, 밭 기록 10단계부터). 칩이 하나뿐이면 칩 줄은 숨는다 (sub_tabs.gd).
## Game·Upgrades의 시그널을 받아 표시만 하고, 버튼은 Game.start_night()를 부른다. 왼쪽 위 '이야기 N / 10'은 book_requested로 다시 읽기를, '설정'은 settings_requested로 설정 창을 연다(main.gd). 상수는 배치용이다.

signal book_requested()
signal settings_requested()
signal winter_requested()  # 꿈의 상점의 '겨울잠에 들기'. main.gd가 확인 창을 연다

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const UpgradeTree := preload("res://scenes/day/upgrade_tree.gd")
const DreamShop := preload("res://scenes/day/dream_shop.gd")
const Hideout := preload("res://scenes/day/hideout.gd")
const SubTabs := preload("res://scenes/ui/sub_tabs.gd")
const FieldPicker := preload("res://scenes/day/field_picker.gd")
const Portrait := preload("res://scenes/day/portrait.gd")

const MARGIN: int = 24
const GAP: int = 24
const LEFT_WIDTH: float = 420.0
const NIGHT_BUTTON_HEIGHT: float = 88.0
const PROMISE_BAR_HEIGHT: float = 10.0
const RECORD_HEIGHT: float = 64.0  # 두 줄 자리. 글이 바뀌어도 아래가 밀리지 않게
const TITLE_COLOR := Color("e9c46a")
const REST_COLOR := Color("9ad14f")
const NOTE_COLOR := Color("b8bcc8")
const REST_FONT_SIZE: int = 40
const CARRY_FONT_SIZE: int = 22
const TITLE_FONT_SIZE: int = 28
const DAY_SECONDS: float = 86400.0
const YEAR_SECONDS: float = 31536000.0
const SETTINGS_BUTTON_SIZE := Vector2(100, 48)
const STORY_BUTTON_SIZE := Vector2(126, 48)

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _rest: Label
var _carry: Label  # 아지트의 생기 나르기 '+N/초' (없으면 빈칸)
var _promise: Label  # 바친 생기로 어둠이 약속한 휴식 (Game.promised_rest_seconds)
var _promise_bar: ProgressBar  # 백 년까지 (로그 눈금, Balance.promise_progress)
var _record: Label
var _night_button: Button
var _story: Button  # 이야기 조각 다시 읽기 (Story)


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	add_child(row)
	row.add_child(_make_left())
	var tabs := SubTabs.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tabs)
	tabs.add_page("어둠의 나무", UpgradeTree.new())
	var shop := DreamShop.new()
	shop.sleep_requested.connect(winter_requested.emit)
	tabs.add_page("꿈의 상점", shop, DreamShop.is_open, DreamShop.has_dot)
	tabs.add_page("아지트", Hideout.new(), Hideout.is_open, Hideout.has_dot)
	Game.vitality_changed.connect(_gate.queue)
	Game.night_finished.connect(_gate.queue)
	Upgrades.upgrade_changed.connect(_gate.queue)
	Night.field_level_changed.connect(_gate.queue)
	Story.story_changed.connect(_gate.queue)
	_refresh()


func _make_left() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	column.add_theme_constant_override("separation", GAP / 2)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label("짚돌이의 헛간", TITLE_FONT_SIZE, TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_story = Button.new()
	_story.custom_minimum_size = STORY_BUTTON_SIZE
	_story.pressed.connect(book_requested.emit)
	top.add_child(_story)
	var settings := Button.new()  # 소리·저장 내보내기·데이터 초기화
	settings.text = "설정"
	settings.custom_minimum_size = SETTINGS_BUTTON_SIZE
	settings.pressed.connect(settings_requested.emit)
	top.add_child(settings)
	column.add_child(Portrait.new())  # 숨 쉬는 짚돌이와 어깨의 까마귀
	var vitality_row := HBoxContainer.new()
	vitality_row.add_theme_constant_override("separation", GAP / 2)
	column.add_child(vitality_row)
	_rest = _label("", REST_FONT_SIZE, REST_COLOR)
	_rest.autowrap_mode = TextServer.AUTOWRAP_OFF
	vitality_row.add_child(_rest)
	_carry = _label("", CARRY_FONT_SIZE, REST_COLOR.darkened(0.25))
	_carry.autowrap_mode = TextServer.AUTOWRAP_OFF
	_carry.size_flags_vertical = Control.SIZE_SHRINK_END
	vitality_row.add_child(_carry)
	_promise = _label("", 0, TITLE_COLOR)
	column.add_child(_promise)
	_promise_bar = ProgressBar.new()
	_promise_bar.theme_type_variation = "GoalBar"
	_promise_bar.custom_minimum_size = Vector2(0.0, PROMISE_BAR_HEIGHT)
	_promise_bar.max_value = 1.0
	_promise_bar.step = 0.0
	_promise_bar.show_percentage = false
	column.add_child(_promise_bar)
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
	var carry := Balance.carry_per_second(Game.last_haul, Workers.shares(Balance.Job.CARRY)) if Workers.is_open() else 0.0
	_rest.text = "생기 %s" % Num.format(Game.vitality)
	_carry.text = "+%s/초" % Num.format(carry) if carry > 0.0 else ""
	var promise := Game.promised_rest_seconds()
	_promise.text = "약속된 휴식  %s" % _long_duration(promise)
	_promise_bar.value = Balance.promise_progress(promise)
	_promise_bar.tooltip_text = "백 년까지 %d%%" % floori(_promise_bar.value * 100.0)
	if Game.nights == 0:
		_record.text = "까마귀가 속삭였다.\n\"생기를 모아 오면 쉬게 해 주마.\""
	else:
		_record.text = "밤 %d번 지남\n지난 밤 +%s  ·  최고 +%s" % [Game.nights, Num.format(Game.last_haul), Num.format(Game.best_haul)]
	_story.text = "이야기 %d/%d" % [Story.unlocked_count, Balance.FRAGMENTS.size()]
	_night_button.text = "밤으로 나가기  ·  밭 %d단계  (%d초)" % [Night.field_level, roundi(Game.night_seconds())]


## 약속된 휴식은 몇 분에서 백 년을 넘게까지 커진다: 1년 이상이면 "N년", 하루 이상이면 "N일 N시간", 아니면 "N시간 N분"
func _long_duration(seconds: float) -> String:
	if seconds >= YEAR_SECONDS:
		return "%s년" % Num.format(floor(seconds / YEAR_SECONDS))
	if seconds >= DAY_SECONDS:
		return "%d일 %d시간" % [floori(seconds / DAY_SECONDS), floori(fmod(seconds, DAY_SECONDS) / 3600.0)]
	return Num.format_duration(seconds)


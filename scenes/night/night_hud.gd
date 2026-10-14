extends Control
## 밤 화면 위의 글 (GDD 4절): 왼쪽 이번 밤 생기, 가운데 밭 단계와 시든 작물 막대(정복 90% 표시), 오른쪽 남은 시간, 오른쪽 아래 '새벽까지 쉬기'(밤을 일찍 끝낸다).
## Night·Game의 시그널을 받아 표시만 한다. 상수는 배치용이다

const MARGIN: int = 20
const BIG_FONT: int = 30
const SMALL_FONT: int = 20
const REST_COLOR := Color("f2d27a")
const TIME_COLOR := Color("e8eef7")
const URGENT_COLOR := Color("ff8a6a")
const URGENT_SECONDS: float = 5.0
const BAR_SIZE := Vector2(360, 18)
const CLEAR_MARK_COLOR := Color("e9c46a")
const STOP_SIZE := Vector2(220, 56)

var _rest: Label
var _time: Label
var _field: Label
var _bar: ProgressBar
var _mark: ColorRect
var _stop: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest = _label(BIG_FONT, REST_COLOR)
	_rest.position = Vector2(MARGIN, MARGIN)
	_time = _label(BIG_FONT, TIME_COLOR)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_field = _label(SMALL_FONT, TIME_COLOR)
	_field.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size = BAR_SIZE
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_mark = ColorRect.new()  # 정복 비율 자리
	_mark.color = CLEAR_MARK_COLOR
	_mark.size = Vector2(3.0, BAR_SIZE.y + 8.0)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)
	_stop = Button.new()
	_stop.text = "새벽까지 쉬기"
	_stop.custom_minimum_size = STOP_SIZE
	_stop.size = STOP_SIZE
	_stop.pressed.connect(Night.stop)
	add_child(_stop)
	Night.time_changed.connect(_on_time_changed)
	Night.night_started.connect(_refresh)
	Night.wave_started.connect(_refresh.unbind(1))
	Night.crop_withered.connect(_refresh.unbind(2))
	Game.vitality_changed.connect(_refresh.unbind(1))
	resized.connect(_layout)
	_layout()
	_refresh()


## 휴식 카운터의 화면 자리 (알갱이가 날아가는 곳)
func rest_target() -> Vector2:
	return _rest.position + Vector2(40.0, 20.0)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1b1f28"))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	_time.position = Vector2(size.x - 320.0 - MARGIN, MARGIN)
	_time.size = Vector2(320.0, 40.0)
	_field.position = Vector2((size.x - 480.0) * 0.5, MARGIN - 4.0)
	_field.size = Vector2(480.0, 28.0)
	_bar.position = Vector2((size.x - BAR_SIZE.x) * 0.5, MARGIN + 30.0)
	_mark.position = _bar.position + Vector2(BAR_SIZE.x * Balance.CLEAR_RATIO - 1.0, -4.0)
	_stop.position = size - STOP_SIZE - Vector2.ONE * MARGIN


func _on_time_changed(seconds_left: float) -> void:
	_time.text = "남은 시간 %d초" % ceili(seconds_left)
	_time.add_theme_color_override("font_color", URGENT_COLOR if seconds_left <= URGENT_SECONDS else TIME_COLOR)


func _refresh() -> void:
	_rest.text = "생기 +%s" % Num.format(Game.night_haul)
	var harvest := "  ·  수확일" if Balance.is_harvest(Night.field_level) else ""
	var wave := "  ·  물결 %d" % (Night.waves + 1) if Night.waves > 0 else ""
	_field.text = "밭 %d단계%s%s  ·  시든 작물 %d / %d" % [Night.field_level, harvest, wave, Night.wave_withered(), Night.first_planted]
	_bar.max_value = maxf(float(Night.first_planted), 1.0)  # 정복 표시(90%)는 이번 물결에 심은 수 기준
	_bar.value = Night.wave_withered()

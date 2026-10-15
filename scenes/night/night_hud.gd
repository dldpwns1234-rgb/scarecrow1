extends Control
## 밤 화면 위의 글 (GDD 4절): 왼쪽 위 이번 밤 생기, 가운데 밭 단계와 시든 작물 막대(정복 90% 표시), 오른쪽 남은 시간, 오른쪽 아래 '새벽까지 쉬기'(밤을 일찍 끝낸다),
## 막대 밑 한 줄(도깨비불이 떴다·잡은 보상·잔치 남은 초, 밤이 시작할 때 이번 철의 날씨). 밭 글 끝에 날씨(장마면 비가 오는지).
## Night·Game의 시그널을 받아 표시만 한다. 시그널은 '다시 써야 함'만 표시하고 프레임당 한 번 쓴다 (연쇄로 한 프레임에 수십 개가 시든다).
## 밤 스킬은 저절로 터지므로 칸을 두지 않는다 (방장 2026-10-15). 상수는 배치용이다

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
const BOON_COLOR := Color("bff0ff")   # 도깨비불 글 (푸른 불빛)
const BOON_SECONDS: float = 2.5
const WEATHER_SECONDS: float = 4.5  # 밤이 시작할 때 날씨 설명을 보이는 초
const BOON_WIDTH: float = 640.0
const BOON_DROP: float = 96.0  # 막대 밑, 윤슬의 밭 이름 글(fx) 아래

var _rest: Label
var _time: Label
var _field: Label
var _bar: ProgressBar
var _mark: ColorRect
var _stop: Button
var _boon: Label                      # 도깨비불: 떴다·잡았다·잔치 남은 초
var _boon_left: float = 0.0
var _dirty: bool = true


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
	_boon = _label(SMALL_FONT, BOON_COLOR)
	_boon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Night.wisp_appeared.connect(_show_boon.bind("도깨비불이 떴다! 구름으로 덮어 잡아 봐"))
	Night.wisp_faded.connect(_show_boon.bind("도깨비불이 꺼졌다"))
	Night.wisp_caught.connect(_on_wisp_caught)
	Night.night_started.connect(_on_night_started)
	Night.rain_changed.connect(_queue.unbind(1))
	Night.time_changed.connect(_on_time_changed)
	Night.night_started.connect(_queue)
	Night.wave_started.connect(_queue.unbind(1))
	Night.crop_withered.connect(_queue.unbind(2))
	Game.vitality_changed.connect(_queue.unbind(1))
	resized.connect(_layout)
	_layout()
	_refresh()


func _queue() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if _boon_left > 0.0:
		_boon_left -= minf(delta, Balance.MAX_DELTA)
		if _boon_left <= 0.0:
			_boon.text = ""
	if Night.feast_left > 0.0:
		_boon.text = "도깨비 잔치! 생기 ×%s  ·  %d초" % [Num.format(Balance.FEAST_MULTIPLIER), ceili(Night.feast_left)]
		_boon_left = 0.4  # 잔치가 끝나면 잠깐 뒤 지운다
	if _dirty and is_visible_in_tree():
		_dirty = false
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
	_boon.position = Vector2((size.x - BOON_WIDTH) * 0.5, MARGIN + BOON_DROP)
	_boon.size = Vector2(BOON_WIDTH, 28.0)


func _show_boon(text: String, seconds: float = BOON_SECONDS) -> void:
	_boon.text = text
	_boon_left = seconds if text != "" else 0.0


func _on_night_started() -> void:
	_show_boon(Balance.weathers_banner(Night.weathers), WEATHER_SECONDS)


## 잡은 도깨비불의 보상 (잔치는 _process가 남은 초와 함께 쓴다)
func _on_wisp_caught(boon: int, amount: float) -> void:
	match boon:
		Balance.Boon.PURSE:
			_show_boon("도깨비 주머니! 생기 +%s" % Num.format(amount))
		Balance.Boon.PRANK:
			_show_boon("도깨비 장난! 스킬 %d개가 한꺼번에" % int(amount) if amount > 0.0 else "도깨비 장난! 스킬이 이미 다 켜져 있다")
		Balance.Boon.DREAM:
			_show_boon("꿈 부스러기! 꿈 조각 +%s" % Num.format(amount))


func _on_time_changed(seconds_left: float) -> void:
	_time.text = "남은 시간 %d초" % ceili(seconds_left)
	_time.add_theme_color_override("font_color", URGENT_COLOR if seconds_left <= URGENT_SECONDS else TIME_COLOR)


func _refresh() -> void:
	_rest.text = "생기 +%s" % Num.format(Game.night_haul)
	var harvest := "  ·  수확일" if Balance.is_harvest(Night.field_level) else ""
	var wave := "  ·  물결 %d" % (Night.waves + 1) if Night.waves > 0 else ""
	var sky := "" if Night.weathers == 0 else "  ·  %s%s" % [Balance.weathers_name(Night.weathers), " (비)" if Night.raining else ""]
	_field.text = "밭 %d단계%s%s%s  ·  시든 작물 %d / %d" % [Night.field_level, harvest, wave, sky, Night.wave_withered(), Night.first_planted]
	_bar.max_value = maxf(float(Night.first_planted), 1.0)  # 정복 표시(90%)는 이번 물결에 심은 수 기준
	_bar.value = Night.wave_withered()

extends Label
## 새 밤의 이름 (방장 #587, 장르 조사 제안 2): 밭 단계 팔레트(night_palette.gd)가 지난 밤과 다른 밤이 시작되면 하늘에 "— 수확 달 —"을 잠깐 띄운다.
## 겉모습이 바뀐 까닭을 알려 '더 깊은 밤으로 왔다'는 느낌을 준다. Night 시그널만 받는다. 상수는 연출용이다

const NightPalette := preload("res://scenes/night/night_palette.gd")
const FONT_SIZE: int = 34
const COLOR := Color("efe3c4")
const TOP: float = 0.09         # 화면 높이의 이만큼 아래 (위 표시줄과 큰 밭 사이의 하늘 자리)
const FADE_IN: float = 0.8
const HOLD: float = 2.2
const FADE_OUT: float = 1.0

var _last: int = -1             # 마지막으로 띄운 밤 (THEMES 번호)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08))
	add_theme_constant_override("outline_size", 8)
	modulate.a = 0.0
	Night.night_started.connect(_on_night_started)
	resized.connect(_place)


func _on_night_started() -> void:
	var index := NightPalette.index_for(Night.field_level)
	if index == _last:
		return
	_last = index
	text = "— %s —" % NightPalette.THEMES[index]["name"]
	_place()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)


func _place() -> void:
	var parent_size := get_parent_area_size()
	position.y = parent_size.y * TOP

extends Label
## 첫 밤 안내: 처음 나간 밤에만 밭 아래쪽에 "손가락(마우스)으로 끌어 역병 구름을 작물 위로!"가 숨 쉬듯 떠 있다가, 작물이 몇 개 시들면 사라진다.
## 입력을 받지 않는다(밤 화면이 구름을 끈다). Game·Night의 시그널만 받는다. 상수는 배치·연출용이다

const TEXT := "손가락(마우스)으로 끌어 역병 구름을 작물 위로!"
const HIDE_AFTER_WITHERED: int = 3   # 이만큼 시들면 알아들은 것으로 친다
const BOTTOM: float = 96.0           # 화면 아래에서 이만큼 위
const FONT_SIZE: int = 28
const COLOR := Color("e9c46a")
const OUTLINE := Color("1c202a")
const OUTLINE_SIZE: int = 8
const PULSE_SECONDS: float = 0.9
const PULSE_LOW: float = 0.45

var _withered: int = 0
var _tween: Tween


func _ready() -> void:
	text = TEXT
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", OUTLINE)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -BOTTOM - FONT_SIZE * 1.5
	offset_bottom = -BOTTOM
	visible = false
	Game.phase_changed.connect(_on_phase_changed.unbind(1))
	Night.crop_withered.connect(_on_withered.unbind(2))


## 처음 나간 밤에만 (지난 밤이 0번)
func _on_phase_changed() -> void:
	_withered = 0
	_set_shown(Game.is_night() and Game.nights == 0)


func _on_withered() -> void:
	_withered += 1
	if _withered >= HIDE_AFTER_WITHERED:
		_set_shown(false)


func _set_shown(shown: bool) -> void:
	visible = shown
	if _tween != null:
		_tween.kill()
		_tween = null
	if not shown:
		return
	modulate.a = 1.0
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "modulate:a", PULSE_LOW, PULSE_SECONDS)
	_tween.tween_property(self, "modulate:a", 1.0, PULSE_SECONDS)

extends VBoxContainer
## 낮 화면: 다음 밤의 밭 단계 고르기 (GDD 4절 밭 정복). "◀  밭 3단계  ▶"와 그 단계의 작물 체력·생기 배율.
## 밭을 정복하면(90% 시듦) 다음 단계가 열린다. 낮은 단계로 돌아가 쉽게 모을 수도 있다. Night의 함수와 시그널만 쓴다. 상수는 배치용이다.
## 새 단계가 열렸는데 아래 단계에 있으면 ▶가 금색으로 숨 쉬고 아래 글이 '새 밭이 열렸다'가 된다 (방장 2026-10-14: 강해진 맛을 보고 넘어갈지는 낮에 고른다).
## 화살표를 한 번 누르거나 그 단계에 서면 알아본 것으로 친다 (저장하지 않는다).
## 아래 스위치 '정복하면 다음 밭으로'는 Night.auto_advance (켜면 예전처럼 정복한 다음 밤이 새 단계)

const ARROW_SIZE := Vector2(72, 64)
const LEVEL_FONT_SIZE: int = 28
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8bcc8")
const LEVEL_COLOR := Color("e9c46a")
const PULSE_LOW: float = 0.55
const PULSE_SECONDS: float = 0.7
const SWITCH_HEIGHT: float = 36.0
const SWITCH_FONT_SIZE: int = 18

var _down: Button
var _up: Button
var _level: Label
var _note: Label
var _known_best: int = 1  # 알아본 가장 높은 단계. 이보다 높은 단계가 열리면 ▶를 강조한다
var _pulse: Tween
var _auto: CheckButton


func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	_down = _arrow("◀", -1)
	row.add_child(_down)
	_level = Label.new()
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.add_theme_font_size_override("font_size", LEVEL_FONT_SIZE)
	_level.add_theme_color_override("font_color", LEVEL_COLOR)
	row.add_child(_level)
	_up = _arrow("▶", 1)
	row.add_child(_up)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # 큰 배율(×2308극)이 왼쪽 열을 넓히지 않게
	_note.custom_minimum_size = Vector2(1.0, 0.0)
	_note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	add_child(_note)
	_auto = CheckButton.new()  # 자동화 스위치 모양 (테마의 CheckButton)
	_auto.text = "정복하면 다음 밭으로"
	_auto.custom_minimum_size = Vector2(0.0, SWITCH_HEIGHT)
	_auto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_auto.add_theme_font_size_override("font_size", SWITCH_FONT_SIZE)
	_auto.toggled.connect(Night.set_auto_advance)
	add_child(_auto)
	_known_best = Night.best_level  # 불러온 상태는 이미 아는 것으로
	Night.field_level_changed.connect(_refresh.unbind(2))
	_refresh()


func _arrow(text: String, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ARROW_SIZE
	button.pressed.connect(func() -> void:
		_known_best = Night.best_level
		Night.choose_level(Night.field_level + step)
		_refresh())
	return button


func _refresh() -> void:
	var level := Night.field_level
	_level.text = "밭 %d단계" % level
	_down.disabled = level <= 1
	_up.disabled = level >= Night.best_level
	var hp := Balance.crop_hp(0, level) / Balance.crop_hp(0, 1)
	var vitality := Balance.crop_vitality(0, level) / Balance.crop_vitality(0, 1)
	if level >= Night.best_level:
		_known_best = Night.best_level
	var fresh := Night.best_level > _known_best  # 새 밭이 열렸는데 아직 아래에 있다
	_auto.set_pressed_no_signal(Night.auto_advance)
	_note.text = "새 밭이 열렸다  ·  ▶ %d단계까지" % Night.best_level if fresh \
		else "체력 %s  ·  생기 %s  ·  %d단계까지 열림" % [Num.multiplier(hp), Num.multiplier(vitality), Night.best_level]
	_note.add_theme_color_override("font_color", LEVEL_COLOR if fresh else NOTE_COLOR)
	_set_pulse(fresh)


func _set_pulse(on: bool) -> void:
	_up.theme_type_variation = "AccentButton" if on else ""
	if on == (_pulse != null):
		return
	if _pulse != null:
		_pulse.kill()
		_pulse = null
		_up.modulate.a = 1.0
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_up, "modulate:a", PULSE_LOW, PULSE_SECONDS)
	_pulse.tween_property(_up, "modulate:a", 1.0, PULSE_SECONDS)

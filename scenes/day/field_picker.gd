extends VBoxContainer
## 낮 화면: 다음 밤의 밭 단계 고르기 (GDD 4절 밭 정복). "◀  밭 3단계  ▶"와 그 단계의 작물 체력·생기 배율.
## 밭을 정복하면(90% 시듦) 다음 단계가 열린다. 낮은 단계로 돌아가 쉽게 모을 수도 있다. Night의 함수와 시그널만 쓴다. 상수는 배치용이다.

const ARROW_SIZE := Vector2(72, 64)
const LEVEL_FONT_SIZE: int = 28
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8bcc8")
const LEVEL_COLOR := Color("e9c46a")

var _down: Button
var _up: Button
var _level: Label
var _note: Label


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
	_note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	add_child(_note)
	Night.field_level_changed.connect(_refresh.unbind(2))
	_refresh()


func _arrow(text: String, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ARROW_SIZE
	button.pressed.connect(func() -> void: Night.choose_level(Night.field_level + step))
	return button


func _refresh() -> void:
	var level := Night.field_level
	_level.text = "밭 %d단계" % level
	_down.disabled = level <= 1
	_up.disabled = level >= Night.best_level
	var hp := Balance.crop_hp(0, level) / Balance.crop_hp(0, 1)
	var rest := Balance.crop_rest(0, level) / Balance.crop_rest(0, 1)
	_note.text = "작물 체력 %s  ·  생기 %s  ·  열린 단계 %d" % [Num.multiplier(hp), Num.multiplier(rest), Night.best_level]

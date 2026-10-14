extends Control
## 화면 전체 (가로 1280×720). 낮이면 헛간(day/day_screen.gd), 밤이면 밭(night/night_screen.gd)만 보인다. Game의 시그널을 받아 바꾸기만 한다.

const DayScreen := preload("res://scenes/day/day_screen.gd")
const NightScreen := preload("res://scenes/night/night_screen.gd")

var _day: Control
var _night: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day = DayScreen.new()
	_night = NightScreen.new()
	for screen: Control in [_day, _night]:
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
	Game.phase_changed.connect(_on_phase_changed.unbind(1))
	_on_phase_changed()


func _on_phase_changed() -> void:
	_day.visible = not Game.is_night()
	_night.visible = Game.is_night()

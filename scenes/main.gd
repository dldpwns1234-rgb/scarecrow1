extends Control
## 화면 전체 (가로 1280×720). 낮이면 헛간(day/day_screen.gd), 밤이면 밭(night/night_screen.gd)만 보인다. Game의 시그널을 받아 바꾸기만 한다.

const DayScreen := preload("res://scenes/day/day_screen.gd")
const NightScreen := preload("res://scenes/night/night_screen.gd")
const NightReport := preload("res://scenes/day/night_report.gd")
const NightHint := preload("res://scenes/ui/night_hint.gd")
const IntroCard := preload("res://scenes/ui/intro_card.gd")

var _day: Control
var _night: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day = DayScreen.new()
	_night = NightScreen.new()
	for screen: Control in [_day, _night]:
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
	add_child(NightReport.new())  # 밤이 끝나면 낮 화면 위에 잠깐 뜨는 결과
	add_child(NightHint.new())  # 첫 밤에만: 구름을 끌어 보라는 안내
	add_child(IntroCard.new())  # 처음 켤 때만: 까마귀 모습의 어둠이 계약을 건다 (맨 위)
	Game.phase_changed.connect(_on_phase_changed.unbind(1))
	_on_phase_changed()


func _on_phase_changed() -> void:
	_day.visible = not Game.is_night()
	_night.visible = Game.is_night()

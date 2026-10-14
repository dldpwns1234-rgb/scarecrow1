extends Control
## 화면 전체 (가로 1280×720). 낮이면 헛간(day/day_screen.gd), 밤이면 밭(night/night_screen.gd)만 보인다. Game의 시그널을 받아 바꾸기만 한다.

const DayScreen := preload("res://scenes/day/day_screen.gd")
const NightScreen := preload("res://scenes/night/night_screen.gd")
const NightReport := preload("res://scenes/day/night_report.gd")
const NightHint := preload("res://scenes/ui/night_hint.gd")
const IntroCard := preload("res://scenes/ui/intro_card.gd")
const StoryBook := preload("res://scenes/ui/story_book.gd")
const StoryCard := preload("res://scenes/ui/story_card.gd")
const WinterConfirm := preload("res://scenes/day/winter_confirm.gd")
const WinterScene := preload("res://scenes/ui/winter_scene.gd")
const SettingsPanel := preload("res://scenes/ui/settings_panel.gd")
const EndingScene := preload("res://scenes/ui/ending_scene.gd")

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
	var confirm := WinterConfirm.new()  # 겨울잠 확인 창 (꿈의 상점 버튼으로 연다)
	add_child(confirm)
	(_day as DayScreen).winter_requested.connect(confirm.open)
	var book := StoryBook.new()  # 이야기 다시 읽기 (낮 화면 버튼으로 연다)
	add_child(book)
	var card := StoryCard.new()  # 이야기 조각 카드: 새로 열린 조각, 다시 읽기
	add_child(card)
	(_day as DayScreen).book_requested.connect(book.open)
	book.read_requested.connect(card.show_fragment)
	add_child(WinterScene.new())  # 겨울잠에 들면 눈 내리는 전환. 카드보다 위라 '겨울잠' 이야기 카드는 눈이 걷히면 보인다
	add_child(EndingScene.new())  # 약속된 휴식 백 년: 마지막 이야기 조각 대신 엔딩 장면
	var settings := SettingsPanel.new()  # 소리·저장 문자열·데이터 초기화 (낮 화면 '설정')
	add_child(settings)
	(_day as DayScreen).settings_requested.connect(settings.open)
	add_child(IntroCard.new())  # 처음 켤 때만: 까마귀 모습의 어둠이 계약을 건다 (맨 위)
	Game.phase_changed.connect(_on_phase_changed.unbind(1))
	_on_phase_changed()


func _on_phase_changed() -> void:
	_day.visible = not Game.is_night()
	_night.visible = Game.is_night()

extends HBoxContainer
## 낮 화면 오른쪽 위의 마을 소문 한 줄 (방장 #587, 장르 조사 제안 1: Cookie Clicker 뉴스 티커). 어깨의 까마귀가 물어 온 소문이라 까마귀 그림을 앞에 둔다.
## 진행(밤 수·가장 높이 연 밭 단계·겨울잠·바친 생기)에 따라 들리는 소문이 늘고, 몇 초마다 덜 들은 소문으로 바뀐다(새로 들리게 된 것이 먼저 나온다).
## 문안과 조건은 Balance.rumors_now(balance/rumors.gd). 들은 횟수는 저장하지 않는다. 상수는 연출용이다

const CROW := preload("res://assets/sprites/crow.svg")
const ICON_SIZE := Vector2(30, 30)
const HEIGHT: float = 34.0
const INTERVAL: float = 9.0     # 초. 소문 하나가 머무는 시간
const FADE: float = 0.35
const FONT_SIZE: int = 19
const TEXT_COLOR := Color("d9cfb8")

var _label: Label
var _heard: Dictionary = {}     # 문장 → 들은 횟수
var _left: float = INTERVAL


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = CROW
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_label)
	_show_next()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_left -= minf(delta, Balance.MAX_DELTA)
	if _left > 0.0:
		return
	_left = INTERVAL
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", 0.0, FADE)
	tween.tween_callback(_show_next)
	tween.tween_property(_label, "modulate:a", 1.0, FADE)


## 지금 들리는 소문 가운데 가장 덜 들은 것 하나 (같으면 아무거나)
func _show_next() -> void:
	var lines := Balance.rumors_now(Game.nights, maxi(Workers.best_ever, Night.best_level), Winter.sleeps, Game.offered)
	if lines.is_empty():
		_label.text = ""
		return
	var least := INF
	var picks: PackedStringArray = []
	for line in lines:
		var count: float = _heard.get(line, 0)
		if count < least:
			least = count
			picks = [line]
		elif count == least and line != _label.text:
			picks.append(line)
	var line: String = picks[randi() % picks.size()]
	_heard[line] = _heard.get(line, 0) + 1
	_label.text = line


## 화면 확인·테스트용: 지금 보이는 소문
func current() -> String:
	return _label.text

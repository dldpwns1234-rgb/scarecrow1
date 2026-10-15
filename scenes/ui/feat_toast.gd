extends PanelContainer
## 업적이 열리면 화면 아래(오른쪽 열 가운데)에 잠깐 뜨는 알림 (방장 #587, 장르 조사 제안 9): "업적 · 첫 흉년" 과 "모든 생기 +2%". 여럿이면 차례로.
## 업적 칸이 열린 뒤(첫 겨울잠)부터만 띄운다 (그 전 업적은 칸이 열릴 때 한꺼번에 보인다). 누르면 바로 닫힌다. 표시만 한다. 상수는 배치용이다

const FeatsPage := preload("res://scenes/day/feats_page.gd")
const WIDTH: float = 420.0
const BOTTOM: float = 28.0      # 화면 아래에서
const LEFT_SPAN: float = 468.0  # 낮 화면 왼쪽 열 (밤으로 나가기 단추를 가리지 않게 오른쪽 열 가운데에, night_report.gd와 같다)
const SHOW_SECONDS: float = 2.6
const FADE: float = 0.3
const TITLE_COLOR := Color("f2d27a")
const NOTE_COLOR := Color("e9e1cc")

var _title: Label
var _note: Label
var _queue: Array[int] = []
var _tween: Tween


func _ready() -> void:
	theme_type_variation = "WoodPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(_title)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	column.add_child(_note)
	gui_input.connect(_on_gui_input)
	Feats.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(index: int) -> void:
	if not FeatsPage.is_open():
		return
	_queue.append(index)
	if not visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		return
	var index: int = _queue.pop_front()
	_title.text = "업적  ·  %s" % Balance.achievement_name(index)
	_note.text = "모든 생기 +%d%%  (지금 +%d%%)" % [roundi(Balance.FEAT_PER_ACHIEVEMENT * 100.0), roundi((Feats.vitality_multiplier() - 1.0) * 100.0)]
	reset_size()
	size.x = WIDTH
	var area := get_parent_area_size()
	position = Vector2(LEFT_SPAN + (area.x - LEFT_SPAN - WIDTH) * 0.5, area.y - size.y - BOTTOM)
	visible = true
	modulate.a = 0.0
	Sfx.play("feat")
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(_show_next)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if _tween != null:
			_tween.kill()
		accept_event()
		_show_next()

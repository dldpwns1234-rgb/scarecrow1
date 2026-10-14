extends PanelContainer
## 밤이 끝나 낮으로 돌아오면 오른쪽(어둠의 나무) 위쪽 가운데에 잠깐 뜨는 결과 (왼쪽 위의 이야기·소리 버튼을 가리지 않게): "지난 밤 · 생기 +120 · 작물 98 / 120 시듦", 정복했으면 둘째 줄에 "밭 3단계 정복! 4단계가 열렸다".
## 겨울잠을 한 번도 안 했는데 이번 밤에 겨울잠 단계가 열렸으면 "겨울잠이 열렸다", 일꾼이 합류했으면 "아지트가 열렸다"나 "일꾼 합류: 이름"을, 수확일 밤을 정복했으면 "풍년의 여신을 이겼다"처럼 그 밤의 가장 센 지키는 이를 덧붙인다.
## Game.night_finished·Night.field_cleared를 받아 Night의 기록을 읽기만 한다. 누르면 바로 닫힌다. 상수는 배치·연출용이다.

const KoreanText := preload("res://scenes/ui/korean_text.gd")

const TOP: float = 20.0
const LEFT_SPAN: float = 468.0  # 낮 화면 왼쪽 열(여백 24 + 폭 420 + 사이 24). 그 오른쪽에 띄운다
const RIGHT_MARGIN: float = 24.0
const WIDTH: float = 640.0
const PADDING: int = 16
const HOLD_SECONDS: float = 4.0
const FADE_SECONDS: float = 0.6
const CLEAR_COLOR := Color("e9c46a")
const HAUL_COLOR := Color("9ad14f")

var _haul: Label
var _clear: Label
var _tween: Tween
var _cleared_level: int = 0  # 이번 밤에 정복한 단계 (Night.field_cleared). 0이면 정복 못 함
var _best_before: int = 1    # 밤이 시작될 때 열린 가장 높은 단계. 낮은 단계를 다시 정복하면 새로 열리는 단계가 없다
var _workers_before: int = 0  # 밤이 시작될 때 일꾼 수 (정복으로 합류한 일꾼을 알린다)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_haul = _line(HAUL_COLOR)
	column.add_child(_haul)
	_clear = _line(CLEAR_COLOR)
	column.add_child(_clear)
	gui_input.connect(_on_gui_input)
	Night.field_cleared.connect(func(level: int) -> void: _cleared_level = level)
	Night.night_started.connect(_on_night_started)
	Game.night_finished.connect(_show_report)


func _on_night_started() -> void:
	_cleared_level = 0
	_best_before = Night.best_level
	_workers_before = Workers.worker_count()


## 수확일 밤(보스 밤)을 정복했을 때: 그 밤의 가장 센 지키는 이를 이겼다는 한 줄
func _harvest_line() -> String:
	var top := -1
	for kind in Night.farmer_kinds:
		top = maxi(top, kind)
	match top:
		Balance.Guardian.GODDESS:
			return "수확일 정복  ·  풍년의 여신을 이겼다"
		-1:
			return "수확일 정복"
	return "수확일 정복  ·  %s%s 따돌렸다" % [Balance.guardian_name(top), KoreanText.particle(Balance.guardian_name(top), "을", "를")]


func _line(color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label


func _show_report(haul: float) -> void:
	_haul.text = "지난 밤  ·  생기 +%s  ·  작물 %d / %d 시듦" % [Num.format(haul), Night.withered, Night.crops_total]
	_clear.visible = _cleared_level > 0
	_clear.text = "밭 %d단계 정복!" % _cleared_level
	if Night.best_level > _best_before:
		_clear.text += "  %d단계가 열렸다" % Night.best_level
	if _cleared_level > 0 and Balance.is_harvest(_cleared_level):
		_clear.text += "\n" + _harvest_line()
	if Winter.sleeps == 0 and _best_before < Balance.WINTER_MIN_LEVEL and Balance.can_winter(Night.best_level):
		_clear.text += "\n겨울잠이 열렸다  ·  오른쪽 위 꿈의 상점"  # 첫 겨울잠 전에 한 번
	if Workers.worker_count() > _workers_before:
		var names := PackedStringArray()
		for w in range(_workers_before, Workers.worker_count()):
			names.append(Workers.worker_name(w))
		var opened := "아지트가 열렸다  ·  " if _workers_before == 0 else ""
		_clear.text += "\n%s일꾼 합류: %s" % [opened, ", ".join(names)]
	reset_size()
	size.x = WIDTH
	position = Vector2(LEFT_SPAN + (get_parent_area_size().x - LEFT_SPAN - RIGHT_MARGIN - WIDTH) * 0.5, TOP)
	visible = true
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if _tween != null:
			_tween.kill()
		hide()
		accept_event()

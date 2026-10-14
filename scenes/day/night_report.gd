extends PanelContainer
## 밤이 끝나 낮으로 돌아오면 화면 위쪽 가운데에 잠깐 뜨는 결과: "지난 밤 · 생기 +120 · 작물 98 / 120 시듦", 정복했으면 둘째 줄에 "밭 3단계 정복! 4단계가 열렸다".
## Game.night_finished·Night.field_cleared를 받아 Night의 기록을 읽기만 한다. 누르면 바로 닫힌다. 상수는 배치·연출용이다.

const TOP: float = 20.0
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
	reset_size()
	size.x = WIDTH
	position = Vector2((get_parent_area_size().x - WIDTH) * 0.5, TOP)
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

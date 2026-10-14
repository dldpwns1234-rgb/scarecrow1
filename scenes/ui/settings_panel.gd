extends Control
## 설정 창 (낮 화면 왼쪽 위 '설정'): 화면을 덮고 가운데 창에 두 칸. 왼쪽은 소리(sound_panel.gd)·지금 저장·데이터 초기화(세 번 눌러야)·빌드 시각,
## 오른쪽은 저장 문자열 칸과 내보내기·복사·가져오기. Save·Prefs의 함수만 부르고 결과를 표시한다. 회귀 용사의 설정 탭을 가로 화면에 맞춰 옮겼다. 상수는 배치용이다

const SoundPanel := preload("res://scenes/ui/sound_panel.gd")
const BUILD_INFO_PATH: String = "res://build_info.txt"  # 배포(.github/workflows/web.yml)가 쓴다. 폰이 예전 빌드를 쥐고 있는지 볼 때

const SHADE := Color(0.02, 0.02, 0.05, 0.8)
const WIDTH: float = 1040.0
const PADDING: int = 24
const GAP: int = 12
const TITLE_COLOR := Color("e9c46a")
const STATUS_COLOR := Color("b8bcc8")
const DANGER_COLOR := Color("ff8c42")
const TITLE_FONT_SIZE: int = 28
const TEXT_HEIGHT: float = 230.0
const BUTTON_HEIGHT: float = 60.0
const STATUS_HEIGHT: float = 56.0     # 두 줄 자리. 글이 바뀌어도 아래가 밀리지 않게
const CLOSE_SIZE := Vector2(200, 56)
const RESET_ARM_SECONDS: float = 6.0  # 확인을 기다리는 시간. 지나면 처음으로 돌아간다
const RESET_STEPS: PackedStringArray = ["데이터 초기화", "정말 초기화할까?", "마지막 확인: 한 번 더"]

var _text: TextEdit
var _status: Label
var _reset_button: Button
var _reset_step: int = 0
var _reset_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	margin.add_child(column)
	var title := Label.new()
	title.text = "설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", PADDING)
	column.add_child(halves)
	halves.add_child(_make_left())
	halves.add_child(VSeparator.new())
	halves.add_child(_make_right())
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = CLOSE_SIZE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	column.add_child(close)
	Save.saved.connect(_on_saved)


## 왼쪽: 소리, 지금 저장·데이터 초기화, 빌드 시각
func _make_left() -> VBoxContainer:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", GAP)
	left.add_child(SoundPanel.new())
	left.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	left.add_child(row)
	row.add_child(_make_button("지금 저장", Save.save_game))
	_reset_button = _make_button(RESET_STEPS[0], _on_reset_pressed)
	row.add_child(_reset_button)
	var build := Label.new()
	var info := FileAccess.get_file_as_string(BUILD_INFO_PATH).strip_edges()
	build.text = "빌드 " + (info if not info.is_empty() else "개발")
	build.add_theme_color_override("font_color", STATUS_COLOR)
	left.add_child(build)
	return left


## 오른쪽: 저장 문자열 칸, 내보내기·복사·가져오기, 상태 글
func _make_right() -> VBoxContainer:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", GAP)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0.0, TEXT_HEIGHT)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = "내보내기를 누르면 저장 문자열이 여기에 나타난다. 가져오려면 여기에 붙여 넣는다"
	right.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	right.add_child(row)
	row.add_child(_make_button("내보내기", _on_export_pressed))
	row.add_child(_make_button("복사", _on_copy_pressed))
	row.add_child(_make_button("가져오기", _on_import_pressed))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0.0, STATUS_HEIGHT)
	_status.add_theme_color_override("font_color", STATUS_COLOR)
	right.add_child(_status)
	return right


func open() -> void:
	_status.text = ""
	_set_reset_step(0)
	visible = true


## 초기화 확인은 시간이 지나면 풀린다
func _process(delta: float) -> void:
	if _reset_step == 0:
		return
	_reset_left -= minf(delta, Balance.MAX_DELTA)
	if _reset_left <= 0.0:
		_set_reset_step(0)
		_status.text = "초기화를 취소했다"


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_export_pressed() -> void:
	_text.text = Save.export_string()
	_status.text = "내보냈다. 복사해서 안전한 곳에 보관하자"


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_text.text)
	_status.text = "복사했다" if not _text.text.is_empty() else "복사할 내용이 없다"


func _on_import_pressed() -> void:
	_status.text = "가져왔다" if Save.import_string(_text.text) else "잘못된 저장 문자열이다"


func _on_saved() -> void:
	if visible:
		_status.text = "저장했다  ·  %s" % Time.get_time_string_from_system()


## 세 번 눌러야 지운다: 초기화 → 정말? → 마지막 확인. 지우면 창을 닫는다 (첫 실행 장면이 다시 뜬다)
func _on_reset_pressed() -> void:
	if _reset_step < RESET_STEPS.size() - 1:
		_set_reset_step(_reset_step + 1)
		_status.text = "%d초 안에 계속 누르면 모든 데이터가 사라진다" % roundi(RESET_ARM_SECONDS)
		return
	_set_reset_step(0)
	Save.reset_data()
	_text.text = ""
	hide()


func _set_reset_step(step: int) -> void:
	_reset_step = step
	_reset_left = RESET_ARM_SECONDS
	_reset_button.text = RESET_STEPS[step]
	if step > 0:
		_reset_button.add_theme_color_override("font_color", DANGER_COLOR)
	else:
		_reset_button.remove_theme_color_override("font_color")

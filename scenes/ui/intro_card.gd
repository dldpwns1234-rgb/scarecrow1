extends Control
## 첫 실행 장면 (docs/STORY.md 조각 1·2): 화면을 덮고 짚돌이의 독백이 한 줄씩 넘어간다. 셋째 줄부터 까마귀 모습의 어둠이 어깨에 내려앉고,
## 마지막 줄의 '계약한다'를 누르면 Story.mark_intro_seen()으로 닫힌다. 데이터 초기화로 첫 장면이 지워지면 다시 처음부터 뜬다. 어디를 눌러도 다음 줄로 간다. Story를 읽고 그 함수만 부른다. 상수는 배치·연출용이다

const SCARECROW := preload("res://icon.svg")
const CROW := preload("res://assets/sprites/crow.svg")
const LINES: PackedStringArray = [
	"백 년째 같은 밭을 지켰다.\n풍년이 들면 밭은 넓어지고, 나는 그만큼 더 오래 서 있어야 한다.",
	"눕고 싶다.\n딱 하룻밤만이라도.",
	"어깨에 까마귀가 내려앉았다.\n이상하게, 날갯짓 소리가 나지 않았다.",
	"\"작물의 생기를 내게 바쳐라.\n바친 만큼 오래 쉬게 해 주마.\"",
]
const CROW_FROM_LINE: int = 2       # 이 줄부터 어둠이 보인다
const DARK_LINE: int = 3            # 이 줄은 어둠의 말 (보랏빛)
const SHADE := Color(0.03, 0.03, 0.06, 0.95)
const CROW_TINT := Color(0.35, 0.22, 0.55)   # 까마귀 그림을 어둠으로 물들인다
const TEXT_COLOR := Color("f1eee4")
const DARK_TEXT_COLOR := Color("c9a2ff")
const FIGURE_SIZE := Vector2(300, 300)
const CROW_SIZE := Vector2(120, 120)
const SHOULDER := Vector2(0.76, 0.43)  # 짚돌이 그림에서 오른 어깨 자리 (비율)
const CROW_FEET := Vector2(0.5, 0.74)  # 까마귀 그림에서 발 자리 (비율)
const TEXT_FONT_SIZE: int = 30
const FADE_SECONDS: float = 0.4
const BUTTON_SIZE := Vector2(260, 72)
const TEXT_HEIGHT: float = 130.0

var _line: int = 0
var _text: Label
var _crow: TextureRect
var _next: Button
var _scarecrow: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = not Story.intro_seen
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_scarecrow = _figure(SCARECROW, FIGURE_SIZE)
	add_child(_scarecrow)
	_crow = _figure(CROW, CROW_SIZE)
	_crow.modulate = CROW_TINT
	_crow.visible = false
	add_child(_crow)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	_next = Button.new()
	_next.custom_minimum_size = BUTTON_SIZE
	_next.size = BUTTON_SIZE
	_next.pressed.connect(_advance)
	add_child(_next)
	_show_line()
	Story.story_changed.connect(_on_story_changed)
	resized.connect(_layout)
	_layout()


## 화면 크기에 맞춰 놓는다. 웹은 켜진 뒤 캔버스 크기가 바뀌고 폰마다 비율이 달라서(aspect expand) 크기가 바뀔 때마다 다시 놓는다
func _layout() -> void:
	var area := size if size.x > 0.0 else get_viewport_rect().size
	_scarecrow.position = Vector2(0.5, 0.34) * area - FIGURE_SIZE * 0.5
	_crow.position = _scarecrow.position + SHOULDER * FIGURE_SIZE - CROW_FEET * CROW_SIZE
	_text.size = Vector2(area.x * 0.8, TEXT_HEIGHT)
	_text.position = Vector2(area.x * 0.1, area.y * 0.6)
	_next.position = Vector2((area.x - BUTTON_SIZE.x) * 0.5, area.y * 0.82)


func _on_story_changed() -> void:
	if Story.intro_seen or visible:
		return
	_line = 0
	_crow.visible = false
	modulate.a = 1.0
	_set_blocking(true)
	visible = true
	_show_line()


func _set_blocking(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_next.mouse_filter = mouse_filter


func _figure(texture: Texture2D, figure_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 크기보다 먼저 (그림 크기가 최소 크기로 잡히지 않게)
	rect.size = figure_size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		_advance()
		accept_event()


func _advance() -> void:
	if _line >= LINES.size() - 1:
		Story.mark_intro_seen()
		_set_blocking(false)  # 사라지는 동안 누른 것은 아래 화면으로 간다 (웹은 페이드가 늦을 수 있다)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
		tween.tween_callback(hide)
		return
	_line += 1
	_show_line()


func _show_line() -> void:
	_text.text = LINES[_line]
	_text.add_theme_color_override("font_color", DARK_TEXT_COLOR if _line == DARK_LINE else TEXT_COLOR)
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, "modulate:a", 1.0, FADE_SECONDS)
	if _line >= CROW_FROM_LINE and not _crow.visible:
		_crow.visible = true
		_crow.modulate.a = 0.0
		create_tween().tween_property(_crow, "modulate:a", 1.0, FADE_SECONDS * 2.0)
	var last := _line >= LINES.size() - 1
	_next.text = "계약한다" if last else "다음 ▶"
	_next.theme_type_variation = "AccentButton" if last else ""

extends Control
## 엔딩 (이야기 조각 10 '휴경지의 별', docs/STORY.md): 약속된 휴식이 백 년에 닿아 마지막 조각이 열리면, 낮에 카드 대신 이 장면이 뜬다.
## 별이 반짝이는 밤하늘과 휴경지, 처음으로 누운 짚돌이와 그 옆에 내려앉은 (그냥) 까마귀. 독백이 한 글자씩 써지고 기록과 '계속하기'가 나온다.
## '계속하기'를 누르면 Story.mark_seen()으로 본 것으로 치고 게임은 이어진다. Story·Game·Winter를 읽기만 한다. 상수는 배치·연출용이다

const SCARECROW := preload("res://icon.svg")
const CROW := preload("res://assets/sprites/crow.svg")
const SKY_TOP := Color("0b0d1f")
const SKY_LOW := Color("29244a")
const GROUND := Color("2a2318")
const GROUND_EDGE := Color("3b3122")
const STAR := Color(1.0, 0.97, 0.85)
const TEXT_COLOR := Color("f1eee4")
const STAT_COLOR := Color("e9c46a")
const STARS: int = 140
const STAR_UNDER_TEXT: float = 0.15
const GROUND_FROM: float = 0.68          # 화면 높이에서 땅이 시작하는 비율
const FIGURE_SIZE := Vector2(170, 170)
const CROW_SIZE := Vector2(80, 80)
const OUTLINE := Color(0.03, 0.03, 0.08)  # 별 위에서도 글이 읽히게
const OUTLINE_SIZE: int = 8
const TEXT_FONT_SIZE: int = 24
const TEXT_WIDTH: float = 820.0
const TEXT_TOP: float = 0.08
const CHARS_PER_SECOND: float = 22.0
const DELAY_SECONDS: float = 1.5
const FADE_SECONDS: float = 1.2
const BUTTON_SIZE := Vector2(260, 64)

var _stars: Array[Vector3] = []  # x, y 비율과 반짝임 위상
var _time: float = 0.0
var _scarecrow: TextureRect
var _crow: TextureRect
var _text: Label
var _stats: Label
var _button: Button
var _rng := RandomNumberGenerator.new()
var _pending: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_rng.seed = 100  # 별자리는 늘 같다
	for i in STARS:
		_stars.append(Vector3(_rng.randf(), _rng.randf() * GROUND_FROM * 0.95, _rng.randf() * TAU))
	_scarecrow = _figure(SCARECROW, FIGURE_SIZE)
	_scarecrow.rotation = -PI * 0.5 + 0.08  # 처음으로 눕는다 (머리가 왼쪽)
	add_child(_scarecrow)
	_crow = _figure(CROW, CROW_SIZE)
	add_child(_crow)
	_text = _label(TEXT_FONT_SIZE, TEXT_COLOR)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_text)
	_stats = _label(0, STAT_COLOR)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stats)
	_button = Button.new()
	_button.text = "계속하기"
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size = BUTTON_SIZE
	_button.theme_type_variation = "AccentButton"
	_button.pressed.connect(_close)
	add_child(_button)
	resized.connect(_layout)
	Story.story_changed.connect(_queue)
	Game.phase_changed.connect(_queue.unbind(1))


func _figure(texture: Texture2D, figure_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = figure_size
	rect.pivot_offset = figure_size * 0.5
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 마지막 조각이 아직 안 본 다음 조각이면 낮에 잠깐 뒤 띄운다 (story_card.gd는 마지막 조각을 띄우지 않는다)
func _queue() -> void:
	if visible or _pending or Game.is_night() or not is_ending_next():
		return
	_pending = true
	await get_tree().create_timer(DELAY_SECONDS).timeout
	_pending = false
	if not visible and not Game.is_night() and is_ending_next():
		play()


static func is_ending_next() -> bool:
	return Story.next_unseen() == Balance.FRAGMENTS.size() - 1


func play() -> void:
	_text.text = Balance.FRAGMENTS[Balance.FRAGMENTS.size() - 1]["text"]
	_text.visible_ratio = 0.0
	_stats.text = "밤 %d번  ·  겨울잠 %d번  ·  바친 생기 %s" % [Game.nights, Winter.sleeps, Num.format(Game.offered)]
	_stats.modulate.a = 0.0
	_button.modulate.a = 0.0
	_button.disabled = true
	_time = 0.0
	visible = true
	modulate.a = 0.0
	set_process(true)
	_layout()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / CHARS_PER_SECOND)
	tween.tween_property(_stats, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_property(_button, "modulate:a", 1.0, FADE_SECONDS * 0.5)
	tween.tween_callback(func() -> void: _button.disabled = false)


func _layout() -> void:
	var area := size if size.x > 0.0 else get_viewport_rect().size
	var ground := area.y * GROUND_FROM
	_scarecrow.position = Vector2(area.x * 0.5 - FIGURE_SIZE.x * 0.7, ground - FIGURE_SIZE.y * 0.62)  # 등이 땅에 닿게
	_crow.position = Vector2(area.x * 0.5 + FIGURE_SIZE.x * 0.35, ground - CROW_SIZE.y * 0.8)
	_text.position = Vector2((area.x - TEXT_WIDTH) * 0.5, area.y * TEXT_TOP)
	_text.size = Vector2(TEXT_WIDTH, 0.0)
	_stats.position = Vector2(0.0, area.y * 0.80)
	_stats.size = Vector2(area.x, 0.0)
	_button.position = Vector2((area.x - BUTTON_SIZE.x) * 0.5, area.y * 0.86)


func _process(delta: float) -> void:
	_time += minf(delta, Balance.MAX_DELTA)
	queue_redraw()


func _draw() -> void:
	var area := size
	var ground := area.y * GROUND_FROM
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(area.x, 0.0), Vector2(area.x, ground), Vector2(0.0, ground)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	var text_rect := Rect2(_text.position, _text.size).grow(12.0)
	for s in _stars:
		var point := Vector2(s.x * area.x, s.y * area.y)
		var twinkle := 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * 1.7 + s.z))
		if text_rect.has_point(point):
			twinkle *= STAR_UNDER_TEXT  # 글 뒤의 별은 흐리게 (글이 읽히게)
		draw_circle(point, 1.2 + (s.z / TAU) * 1.3, Color(STAR, twinkle))
	draw_rect(Rect2(0.0, ground, area.x, area.y - ground), GROUND)
	draw_line(Vector2(0.0, ground), Vector2(area.x, ground), GROUND_EDGE, 4.0)


func _close() -> void:
	Story.mark_seen(Balance.FRAGMENTS.size() - 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func() -> void:
		visible = false
		set_process(false))

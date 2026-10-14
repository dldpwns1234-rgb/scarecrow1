extends Control
## 겨울잠 전환 장면: Winter.slept를 받으면 화면이 겨울밤으로 어두워지고 눈이 내리며 "긴 겨울잠…"이 떴다가, "봄이 왔다 · 꿈 조각 +N"으로 바뀌고 걷힌다.
## 그동안 아래 화면은 새 철(밭 1단계, 생기 0)로 바뀐다. 누르면 조금 일찍 걷힌다. Winter의 시그널만 받는다. 상수는 연출용이다

const NIGHT_COLOR := Color(0.06, 0.08, 0.16, 0.97)
const SNOW_COLOR := Color(0.92, 0.95, 1.0, 0.85)
const TEXT_COLOR := Color("f1eee4")
const SPRING_COLOR := Color("9ad14f")
const FONT_SIZE: int = 34
const FLAKES: int = 110
const FLAKE_RADIUS := Vector2(1.5, 4.0)
const FLAKE_SPEED := Vector2(40.0, 110.0)   # 초당 픽셀 (아래로)
const FLAKE_SWAY: float = 18.0              # 좌우로 흔들리는 폭
const FADE_IN: float = 0.8
const SLEEP_HOLD: float = 1.6
const SPRING_HOLD: float = 1.4
const FADE_OUT: float = 0.9
const SKIP_AFTER: float = 1.0               # 이만큼 지나야 눌러서 걷을 수 있다

var _label: Label
var _flakes: Array[Vector4] = []  # x, y, 반지름, 속도
var _time: float = 0.0
var _tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	Winter.slept.connect(_play)


func _play(reward: float) -> void:
	var area := get_viewport_rect().size
	_flakes.clear()
	for i in FLAKES:
		_flakes.append(Vector4(_rng.randf() * area.x, _rng.randf() * area.y,
			_rng.randf_range(FLAKE_RADIUS.x, FLAKE_RADIUS.y), _rng.randf_range(FLAKE_SPEED.x, FLAKE_SPEED.y)))
	_time = 0.0
	_label.text = "긴 겨울잠…"
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	visible = true
	modulate.a = 0.0
	set_process(true)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(SLEEP_HOLD)
	_tween.tween_callback(_spring.bind(reward))
	_tween.tween_interval(SPRING_HOLD)
	_tween.tween_callback(_finish)


func _spring(reward: float) -> void:
	_label.text = "봄이 왔다\n꿈 조각 +%s" % Num.format(reward)
	_label.add_theme_color_override("font_color", SPRING_COLOR)


func _finish() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_close)


func _close() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	delta = minf(delta, Balance.MAX_DELTA)
	_time += delta
	var area := get_viewport_rect().size
	for i in _flakes.size():
		var f := _flakes[i]
		f.y += f.w * delta
		if f.y > area.y + f.z:
			f.y = -f.z
			f.x = _rng.randf() * area.x
		_flakes[i] = f
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT_COLOR)
	for f in _flakes:
		var sway := sin(_time * 1.3 + f.x * 0.05) * FLAKE_SWAY
		draw_circle(Vector2(f.x + sway, f.y), f.z, SNOW_COLOR)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		accept_event()
		if _time >= SKIP_AFTER:
			_finish()

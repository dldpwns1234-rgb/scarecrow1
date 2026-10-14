extends Control
## 밤 화면 오른쪽의 '풍작 콤보' (방장 2026-10-14 "가득 차는 뽕맛"): 작물이 연달아 시들면 '연쇄 ×N'이 오르고 세로 막대가 차오른다.
## 꽉 차면 burst를 내고(금빛 터짐·흔들림은 night_fx.gd) '풍작 N'이 오른다. 잠깐 쉬면 막대가 줄고 연쇄가 끊긴다.
## 시들 때마다 연쇄음이 5음 음계로 한 칸씩 올라간다. 시듦은 모아 두었다 한 프레임에 한 번 셈한다 (연쇄로 한 프레임에 수십 개 시들 때 글·소리를 한 번만). 게임 수치에는 영향이 없는 연출이다 (Night 시그널만 받는다). 상수는 배치·연출용이다

signal burst(level: int)

const BAR_SIZE := Vector2(26, 300)
const RIGHT: float = 84.0                 # 화면 오른쪽에서 막대까지 (위 글 '연쇄 ×44'가 잘리지 않게)
const COMBO_WINDOW: float = 1.0           # 이 안에 다음 작물이 시들면 연쇄가 이어진다
const FILL_PER_WITHER: float = 0.035      # 시든 작물 하나가 채우는 양 (연쇄가 길수록 조금 더)
const FILL_COMBO_BONUS: float = 0.015     # 연쇄 1마다 채우는 양 +1.5%
const DECAY_DELAY: float = 0.8            # 이만큼 쉬면 막대가 줄기 시작한다
const DECAY_PER_SECOND: float = 0.35
const BURST_COOLDOWN: float = 1.2         # 터짐 사이 최소 간격
const SHOW_COMBO_FROM: int = 3            # 연쇄가 이만큼은 돼야 '연쇄 ×N'을 보인다
const LABEL_WIDTH: float = 120.0          # 글 칸의 기본 폭 (막대 가운데에 맞춘다)
const SCREEN_EDGE: float = 8.0            # 글이 길어져도(연쇄 ×6000, 방장 #543) 화면 오른쪽에서 이만큼 띄운다
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9]
const CHAIN_STEPS: int = 12               # 연쇄음이 올라가는 칸 수 (두 옥타브 남짓), 그 뒤로는 맨 위에 머문다
const BACK := Color(0.05, 0.06, 0.1, 0.7)
const FILL_LOW := Color("9ad14f")
const FILL_HIGH := Color("f2d27a")
const RIM := Color(1.0, 1.0, 1.0, 0.25)
const COMBO_COLOR := Color("f2d27a")
const OUTLINE := Color(0.03, 0.03, 0.06)

var fill: float = 0.0
var combo: int = 0
var level: int = 0          # 이번 밤의 풍작 수
var _since_wither: float = 99.0
var _since_burst: float = 99.0
var _glow: float = 0.0      # 막 찼을 때 번쩍임
var _pending: int = 0       # 이번 프레임에 시든 수
var _combo_label: Label
var _level_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combo_label = _label(28)
	add_child(_combo_label)
	_level_label = _label(20)
	add_child(_level_label)
	Night.crop_withered.connect(_on_withered.unbind(2))
	Night.night_started.connect(_reset)
	_reset()


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COMBO_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(LABEL_WIDTH, 40)
	return label


func _reset() -> void:
	fill = 0.0
	combo = 0
	level = 0
	_pending = 0
	_since_wither = 99.0
	_glow = 0.0
	_refresh_labels()


func bar_rect() -> Rect2:
	return Rect2(Vector2(size.x - RIGHT - BAR_SIZE.x, (size.y - BAR_SIZE.y) * 0.5), BAR_SIZE)


func _on_withered() -> void:
	_pending += 1


## 이번 프레임에 시든 것을 한꺼번에: 연쇄·막대를 올리고 연쇄음은 마지막 높이로 한 번, 꽉 차면 터짐 한 번
func _apply_withers() -> void:
	if _since_wither > COMBO_WINDOW:
		combo = 0
	for i in _pending:
		combo += 1
		fill = minf(fill + FILL_PER_WITHER * (1.0 + FILL_COMBO_BONUS * combo), 1.0)
	_pending = 0
	_since_wither = 0.0
	var step := mini(combo - 1, CHAIN_STEPS - 1)
	var semitones := 12 * (step / PENTATONIC.size()) + PENTATONIC[step % PENTATONIC.size()]
	Sfx.play("chain", pow(2.0, semitones / 12.0))
	if fill >= 1.0 and _since_burst >= BURST_COOLDOWN:
		fill = 0.0
		level += 1
		_since_burst = 0.0
		_glow = 1.0
		Sfx.play("bumper")
		burst.emit(level)
	_refresh_labels()


func _process(delta: float) -> void:
	delta = minf(delta, Balance.MAX_DELTA)
	if _pending > 0:
		_apply_withers()
	_since_wither += delta
	_since_burst += delta
	_glow = maxf(_glow - delta * 2.0, 0.0)
	if _since_wither > DECAY_DELAY and fill > 0.0:
		fill = maxf(fill - DECAY_PER_SECOND * delta, 0.0)
	if _since_wither > COMBO_WINDOW and combo > 0:
		combo = 0
		_refresh_labels()
	queue_redraw()


func _refresh_labels() -> void:
	var rect := bar_rect()
	var combo_text := "연쇄 ×%s" % Num.format(combo) if combo >= SHOW_COMBO_FROM else ""
	if _combo_label.text != combo_text:
		_combo_label.text = combo_text
	_place_label(_combo_label, rect, rect.position.y - 48.0)
	var level_text := "풍작 %d" % level if level > 0 else ""
	if _level_label.text != level_text:
		_level_label.text = level_text
	_place_label(_level_label, rect, rect.end.y + 6.0)


## 막대 가운데에 맞추되, 글이 길어지면 화면 오른쪽 밖으로 나가지 않게 왼쪽으로 민다
func _place_label(label: Label, rect: Rect2, y: float) -> void:
	var width := maxf(LABEL_WIDTH, label.get_minimum_size().x)
	label.size = Vector2(width, label.size.y)
	label.position = Vector2(minf(rect.get_center().x - width * 0.5, size.x - width - SCREEN_EDGE), y)


func _draw() -> void:
	if not Night.active:
		return
	var rect := bar_rect()
	draw_rect(rect.grow(3.0), BACK)
	var height := rect.size.y * fill
	var filled := Rect2(rect.position.x, rect.end.y - height, rect.size.x, height)
	draw_rect(filled, FILL_LOW.lerp(FILL_HIGH, fill))
	if _glow > 0.0:
		draw_rect(rect.grow(6.0 * _glow), Color(FILL_HIGH, 0.6 * _glow), false, 4.0)
	draw_rect(rect, RIM, false, 2.0)

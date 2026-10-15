extends Control
## 밤 화면의 맨 아래층 (night_screen.gd): 하늘(위는 짙은 남색, 지평선은 푸르게), 반짝이는 별, 초승달과 달무리, 지평선의 먼 언덕·가까운 언덕, 그 앞의 어두운 들판.
## 밭은 들판 위에 놓인 두둑처럼 보인다 (별하늘에 떠 있으면 게임판 같았다, 방장 2026-10-15 '진짜 게임처럼'). 입력은 받지 않는다. 상수는 연출용이다
## 색·달 모양·별 수는 그 밤의 밭 단계에 맞는 팔레트(night_palette.gd)를 따른다: 밭이 깊어질수록 더 깊은 밤 (방장 #587). 밤이 시작될 때 다시 고른다.
## 모두 크기가 바뀔 때만 그린다. 별은 세 무리로 나눠 한 번 그리고, 무리마다 투명도만 바꿔 반짝인다 (별·언덕을 매 프레임 다시 그리면 1.5ms 넘게 들었다)

const NightPalette := preload("res://scenes/night/night_palette.gd")
const STAR_COLOR := Color(1.0, 0.96, 0.85)
const STAR_GROUPS: int = 3
const TWINKLE_SPEED: float = 1.8
const MOON_POSITION := Vector2(0.86, 0.18)  # 화면 비율
const MOON_RADIUS: float = 34.0
const MOON_POINTS: int = 48
const HALO_RADIUS: float = 5.0             # 달무리(가운데에서 바깥으로 사라지는 빛. 원을 겹쳐 그리면 띠가 보였다)가 달 반지름의 이만큼까지
const ECLIPSE_RING: float = 3.0           # 검은 달의 빛 테 두께
const HORIZON: float = 0.42                # 지평선 높이 (화면 비율)
const HILL_POINTS: int = 48

var _stars: Array[Vector3] = []  # (x 비율, y 비율, 박자)
var _halo: GradientTexture2D
var _groups: Array[Control] = []  # 별 무리 (투명도로 반짝인다)
var _clock: float = 0.0
var _theme: Dictionary = NightPalette.THEMES[0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in NightPalette.MAX_STARS:
		_stars.append(Vector3(rng.randf(), rng.randf() * HORIZON * 0.92, rng.randf() * TAU))
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.0)])
	_halo = GradientTexture2D.new()
	_halo.gradient = gradient
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	_halo.width = 256
	_halo.height = 256
	for g in STAR_GROUPS:
		var group := Control.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		group.draw.connect(_draw_stars.bind(g))
		add_child(group)
		_groups.append(group)
	resized.connect(_redraw_all)
	Night.night_started.connect(_apply_theme)
	_apply_theme()


## 그 밤의 밭 단계에 맞는 팔레트로 다시 그린다
func _apply_theme() -> void:
	_theme = NightPalette.theme_for(Night.field_level)
	_redraw_all()


func _redraw_all() -> void:
	queue_redraw()
	for group in _groups:
		group.queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	for g in _groups.size():
		_groups[g].modulate.a = 0.55 + 0.45 * sin(_clock * TWINKLE_SPEED + g * TAU / STAR_GROUPS)


func _draw_stars(group: int) -> void:
	for i in range(group, mini(int(_theme["stars"]), _stars.size()), STAR_GROUPS):
		var star := _stars[i]
		_groups[group].draw_circle(Vector2(star.x * size.x, star.y * size.y), 1.2 + 0.6 * sin(star.z), STAR_COLOR * Color(1, 1, 1, 0.85))


func _draw() -> void:
	var horizon := size.y * HORIZON
	var sky_top: Color = _theme["sky_top"]
	var sky_horizon: Color = _theme["sky_horizon"]
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([sky_top, sky_top, sky_horizon, sky_horizon]))
	var moon := MOON_POSITION * size
	var halo := Vector2.ONE * MOON_RADIUS * HALO_RADIUS
	draw_texture_rect(_halo, Rect2(moon - halo, halo * 2.0), false, _theme["halo"])
	var cut: Vector3 = _theme["moon_cut"]
	var disc := _circle(moon, MOON_RADIUS)
	var lit: Array[PackedVector2Array] = [disc]
	if cut.z > 0.0:  # 가리는 원만큼 잘라 낸 모양만 그린다 (하늘색 원으로 덮으면 달무리 위에 어두운 원이 보였다)
		lit = Geometry2D.clip_polygons(disc, _circle(moon + Vector2(cut.x, cut.y), MOON_RADIUS * cut.z))
	for part in lit:
		draw_colored_polygon(part, _theme["moon"])
	if _theme.get("eclipse", false):  # 검은 달: 어두운 원에 빛 테
		draw_arc(moon, MOON_RADIUS, 0.0, TAU, 48, Color(_theme["halo"], 0.9), ECLIPSE_RING, true)
	_draw_hills(horizon - 26.0, 22.0, 0.006, _theme["far_hills"])
	_draw_hills(horizon - 4.0, 14.0, 0.011, _theme["near_hills"])
	draw_polygon(PackedVector2Array([Vector2(0.0, horizon), Vector2(size.x, horizon), size, Vector2(0.0, size.y)]),
		PackedColorArray([_theme["field_top"], _theme["field_top"], _theme["field_bottom"], _theme["field_bottom"]]))


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in MOON_POINTS:
		points.append(center + Vector2.from_angle(TAU * i / MOON_POINTS) * radius)
	return points


## 지평선 위로 솟은 언덕 줄 하나 (사인 둘을 겹친 능선)
func _draw_hills(base: float, height: float, frequency: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0.0, size.y * HORIZON + 1.0)])
	for i in HILL_POINTS + 1:
		var x := size.x * i / HILL_POINTS
		var y := base - height * (0.6 + 0.4 * sin(x * frequency + 1.3)) * (0.7 + 0.3 * sin(x * frequency * 2.7))
		points.append(Vector2(x, y))
	points.append(Vector2(size.x, size.y * HORIZON + 1.0))
	draw_colored_polygon(points, color)

extends Node2D
## 밤 밭 위의 공기 (판 안 좌표, night_screen.gd): 밭 위를 천천히 흐르는 달빛 안개, 깜빡이며 떠도는 반딧불, 역병 구름이 비추는 풀빛.
## 모두 더하기 섞기(빛)로 그린다. 그리기만 한다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FOG_COLOR := Color(0.55, 0.65, 0.85, 0.11)
const FOG_COUNT: int = 7
const FOG_SIZE := Vector2(3.6, 1.6)        # 안개 덩이 크기 (칸 폭 배수, 가로·세로)
const FOG_DRIFT: float = 0.18              # 칸/초
const FLY_COLOR := Color(0.85, 1.0, 0.55)
const FLY_COUNT: int = 22
const FLY_HEIGHT: float = 40.0             # 땅 위로 떠 있는 높이 (판 픽셀)
const FLY_BLINK: float = 1.3
const CLOUD_GLOW := Color(0.45, 0.85, 0.3, 0.22)
const CLOUD_GLOW_SCALE: float = 1.7        # 구름 반경의 이만큼까지 비춘다

var _soft: GradientTexture2D               # 가운데가 밝고 가장자리로 사라지는 둥근 빛
var _fog: Array[Vector3] = []              # (격자 x, 격자 y, 크기 배율)
var _flies: Array[Vector4] = []            # (격자 x, 격자 y, 박자, 떠도는 방향)
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_soft = GradientTexture2D.new()
	_soft.gradient = gradient
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 128
	_soft.height = 128
	_rng.seed = 31
	Night.night_started.connect(_scatter)
	_scatter()


## 밤마다 밭 크기에 맞춰 안개와 반딧불을 흩는다
func _scatter() -> void:
	var n := float(Night.field_size)
	_fog.clear()
	for i in FOG_COUNT:
		_fog.append(Vector3(_rng.randf() * n, _rng.randf() * n, 0.7 + _rng.randf() * 0.6))
	_flies.clear()
	for i in FLY_COUNT:
		_flies.append(Vector4(_rng.randf() * n, _rng.randf() * n, _rng.randf() * TAU, _rng.randf() * TAU))


func _process(delta: float) -> void:
	visible = Night.active
	if not visible:
		return
	_clock += delta
	var n := float(Night.field_size)
	for i in _fog.size():
		var fog := _fog[i]
		fog.x = fposmod(fog.x + FOG_DRIFT * delta, n + 4.0)
		_fog[i] = fog
	for i in _flies.size():
		var fly := _flies[i]
		fly.w += _rng.randf_range(-1.5, 1.5) * delta
		fly.x = clampf(fly.x + cos(fly.w) * 0.35 * delta, 0.0, n)
		fly.y = clampf(fly.y + sin(fly.w) * 0.35 * delta, 0.0, n)
		_flies[i] = fly
	queue_redraw()


func _draw() -> void:
	var cell := Vector2(Iso.TILE_W, Iso.TILE_H)
	var glow := Iso.ellipse_radii(Night.cloud_radius() * CLOUD_GLOW_SCALE)
	draw_texture_rect(_soft, Rect2(Iso.to_screen(Vector2.ZERO, Night.cloud) - glow, glow * 2.0), false, CLOUD_GLOW)
	for fog in _fog:
		var at := Iso.to_screen(Vector2.ZERO, Vector2(fog.x - 2.0, fog.y))
		var extent := cell * FOG_SIZE * fog.z
		draw_texture_rect(_soft, Rect2(at - extent * 0.5, extent), false, FOG_COLOR)
	for fly in _flies:
		var blink := maxf(sin(_clock * FLY_BLINK + fly.z), 0.0)
		if blink <= 0.05:
			continue
		var at := Iso.to_screen(Vector2.ZERO, Vector2(fly.x, fly.y)) + Vector2(0.0, -FLY_HEIGHT - 6.0 * sin(_clock * 0.8 + fly.z))
		draw_texture_rect(_soft, Rect2(at - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), false, FLY_COLOR * Color(1, 1, 1, 0.5 * blink))
		draw_circle(at, 1.6, FLY_COLOR * Color(1, 1, 1, blink))

extends Node2D
## 철마다 날씨의 그림 (방장 2026-10-15 #587, 장르 조사 제안 7): 보름달은 땅 위를 떠도는 옅은 금빛 달빛 원, 장마는 밭 위로 비스듬히 긋는 빗줄기(비가 오고 그칠 때 서서히),
## 서리는 얼어붙은 작물 위에 얼음 반짝이가 깜박이고, 깨질 때 얼음 조각이 튄다 (작물의 푸른빛은 field_view.gd). Night를 읽어 그리기만 한다. 판(Node2D) 안에 있어 격자 → 화면은 Iso로 잰다.
## 작물보다 앞, 구름보다 뒤에 둔다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const MOON_LIGHT := Color(1.0, 0.92, 0.55, 0.5)
const MOON_RIM := Color(1.0, 0.95, 0.7, 0.85)
const MOON_RIM_WIDTH: float = 3.5
const MOON_PULSE_SPEED: float = 1.6
const RAIN := Color(0.7, 0.82, 1.0, 0.42)
const RAIN_DROPS: int = 70
const RAIN_SPEED: float = 620.0        # 화면 픽셀/초
const RAIN_LENGTH: float = 18.0
const RAIN_SLANT := Vector2(-0.28, 1.0)
const RAIN_HEIGHT: float = 260.0       # 밭 위로 빗줄기가 시작하는 높이
const RAIN_FADE_SECONDS: float = 0.8
const SHARD := Color("dff3ff")
const GLINT_SIZE: float = 7.0         # 얼음 반짝이 (작물 위)
const GLINT_LIFT: float = 30.0
const GLINT_SPEED: float = 3.0
const SHARD_COUNT: int = 7
const SHARD_SECONDS: float = 0.45
const SHARD_DISTANCE: float = 34.0

var _soft: GradientTexture2D
var _clock: float = 0.0
var _wet: float = 0.0                  # 빗줄기 짙기 (0 → 1)
var _drops: PackedVector2Array = PackedVector2Array()  # 빗방울마다 (밭 폭 비율, 떨어진 정도 0~1)
var _shards: Array[Vector3] = []       # 깨진 자리 (x, y, 남은 몫 1 → 0)


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0)])
	_soft = GradientTexture2D.new()
	_soft.gradient = gradient
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 128
	_soft.height = 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in RAIN_DROPS:
		_drops.append(Vector2(rng.randf(), rng.randf()))
	Night.frost_shattered.connect(_on_shattered)
	Night.night_started.connect(func() -> void:
		_shards.clear()
		_wet = 1.0 if Night.raining else 0.0)


func _on_shattered(index: int) -> void:
	var at := Iso.to_screen(Vector2.ZERO, Night.cell_position(index))
	_shards.append(Vector3(at.x, at.y, 1.0))


func _process(delta: float) -> void:
	delta = minf(delta, Balance.MAX_DELTA)
	visible = Night.active and Night.weathers != 0
	if not visible:
		return
	_clock += delta
	_wet = move_toward(_wet, 1.0 if Night.raining else 0.0, delta / RAIN_FADE_SECONDS)
	if _wet > 0.0:
		var fall := RAIN_SPEED * delta / (RAIN_HEIGHT + _field_height())
		for i in _drops.size():
			_drops[i].y = fmod(_drops[i].y + fall, 1.0)
	for i in range(_shards.size() - 1, -1, -1):
		_shards[i].z -= delta / SHARD_SECONDS
		if _shards[i].z <= 0.0:
			_shards.remove_at(i)
	queue_redraw()


func _field_height() -> float:
	return Iso.field_size(Night.field_size).y


func _draw() -> void:
	if Night.has_weather(Balance.Weather.MOON):
		var center := Iso.to_screen(Vector2.ZERO, Night.moon)
		var radii := Iso.ellipse_radii(Night.moon_radius())
		var pulse := 0.85 + 0.15 * sin(_clock * MOON_PULSE_SPEED)
		draw_texture_rect(_soft, Rect2(center - radii, radii * 2.0), false, Color(MOON_LIGHT, MOON_LIGHT.a * pulse))
		draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
		draw_arc(Vector2.ZERO, radii.x, 0.0, TAU, 48, Color(MOON_RIM, MOON_RIM.a * pulse), MOON_RIM_WIDTH)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _wet > 0.0:
		var field := Iso.field_size(Night.field_size)
		var span := field.y + RAIN_HEIGHT
		var slant := RAIN_SLANT.normalized()
		for drop in _drops:
			var top := Vector2((drop.x - 0.5) * field.x * 1.1, -RAIN_HEIGHT + drop.y * span)
			draw_line(top, top + slant * RAIN_LENGTH, Color(RAIN, RAIN.a * _wet), 2.0)
	if Night.has_weather(Balance.Weather.FROST):
		for i in Night.frost.size():
			if Night.frost[i] == 1 and Night.is_alive(i):
				var twinkle := 0.5 + 0.5 * sin(_clock * GLINT_SPEED + i * 1.7)
				_glint(Iso.to_screen(Vector2.ZERO, Night.cell_position(i)) - Vector2(0.0, GLINT_LIFT), GLINT_SIZE * (0.6 + 0.4 * twinkle), 0.45 + 0.55 * twinkle)
	for shard in _shards:
		var spread := (1.0 - shard.z) * SHARD_DISTANCE
		for k in SHARD_COUNT:
			var dir := Vector2.from_angle(TAU * k / SHARD_COUNT + 0.4)
			var at := Vector2(shard.x, shard.y - 18.0) + Vector2(dir.x, dir.y * 0.6) * spread
			draw_colored_polygon(PackedVector2Array([at + dir * 6.0, at + dir.orthogonal() * 2.5, at - dir.orthogonal() * 2.5]), Color(SHARD, shard.z))


## 네 갈래 얼음 반짝이
func _glint(at: Vector2, size: float, alpha: float) -> void:
	var color := Color(SHARD, alpha)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size * 0.22, 0.0), at + Vector2(0.0, size), at + Vector2(-size * 0.22, 0.0)]), color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 0.7, 0.0), at + Vector2(0.0, size * 0.18), at + Vector2(size * 0.7, 0.0), at + Vector2(0.0, -size * 0.18)]), color)

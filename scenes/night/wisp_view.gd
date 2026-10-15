extends Node2D
## 도깨비불의 그림 (방장 2026-10-15 #587, 장르 조사 제안 6): 밭 위에 둥실 뜬 푸른 불꽃(작물처럼 굵은 외곽선, 바깥 불·안쪽 불·심지, 작은 눈 둘)이
## 일렁이며 꼬리를 끌고, 빛무리가 숨 쉬듯 커졌다 작아지고, 땅에는 옅은 빛 웅덩이가 진다.
## 구름 안에 들면 둘레에 잡히는 몫(Night.catch_progress)이 고리로 차고, 잡히면 빛 고리가 퍼지고, 못 잡으면 작아지며 꺼진다.
## Night.wisp를 따라 그리기만 한다. 판(Node2D) 안에 있어서 격자 → 화면은 Iso로 바로 잰다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const CORE := Color("f4fdff")
const FLAME := Color("5fc4ff")        # 바깥 불
const FLAME_IN := Color("c8f4ff")     # 안쪽 불
const OUTLINE := Color("16233f")      # 작물 선처럼 짙게
const OUTLINE_WIDTH: float = 3.0
const EYE := Color("16233f")
const GLOW_COLOR := Color(0.5, 0.85, 1.0)
const GROUND := Color(0.45, 0.8, 1.0, 0.3)
const RING := Color("bff0ff")
const RING_BACK := Color(1.0, 1.0, 1.0, 0.18)
const LIFT: float = 46.0          # 땅에서 뜬 높이
const BOB: float = 6.0            # 위아래로 일렁이는 폭
const BOB_SPEED: float = 2.6
const FLICKER_SPEED: float = 11.0
const SIZE: float = 21.0          # 불꽃 반지름
const GLOW: float = 3.6           # 빛무리 = 불꽃 × 이 값
const BREATH_SPEED: float = 3.4   # 빛무리가 숨 쉬는 빠르기
const RING_RADIUS: float = 36.0
const RING_WIDTH: float = 4.0
const TRAIL: int = 8              # 꼬리 점 수
const TRAIL_STEP: float = 0.05    # 꼬리 점 사이 초
const FADE_IN: float = 0.35
const BURST_SECONDS: float = 0.45
const BURST_RADIUS: float = 90.0
const FADE_OUT_SECONDS: float = 0.5

var _soft: GradientTexture2D
var _clock: float = 0.0
var _shown: float = 0.0           # 나타난 뒤 지난 초
var _trail: Array[Vector2] = []
var _trail_left: float = 0.0
var _burst: float = 0.0           # 잡힌 순간의 빛 고리 (1에서 0으로)
var _fade: float = 0.0            # 못 잡고 꺼지는 중 (1에서 0으로)
var _last: Vector2 = Vector2.ZERO  # 마지막 자리 (잡히거나 꺼진 뒤에도 그 자리에서 연출)


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	_soft = GradientTexture2D.new()
	_soft.gradient = gradient
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 64
	_soft.height = 64
	Night.wisp_appeared.connect(_on_appeared)
	Night.wisp_caught.connect(func(_boon: int, _amount: float) -> void: _burst = 1.0)
	Night.wisp_faded.connect(func() -> void: _fade = 1.0)


func _on_appeared() -> void:
	_shown = 0.0
	_trail.clear()
	_burst = 0.0
	_fade = 0.0


func _process(delta: float) -> void:
	delta = minf(delta, Balance.MAX_DELTA)
	visible = Night.active and (Night.is_wisp_up() or _burst > 0.0 or _fade > 0.0)
	if not visible:
		return
	_clock += delta
	_shown += delta
	_burst = maxf(_burst - delta / BURST_SECONDS, 0.0)
	_fade = maxf(_fade - delta / FADE_OUT_SECONDS, 0.0)
	if Night.is_wisp_up():
		_last = Iso.to_screen(Vector2.ZERO, Night.wisp)
		_trail_left -= delta
		if _trail_left <= 0.0:
			_trail_left = TRAIL_STEP
			_trail.push_front(_last)
			if _trail.size() > TRAIL:
				_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	var lift := Vector2(0.0, -LIFT - BOB * sin(_clock * BOB_SPEED))
	if _burst > 0.0:
		var spread := 1.0 - _burst
		draw_arc(_last + lift, RING_RADIUS + BURST_RADIUS * spread, 0.0, TAU, 40, Color(RING, _burst), RING_WIDTH * (1.0 + _burst))
		draw_texture_rect(_soft, _rect(_last + lift, SIZE * GLOW * (1.0 + spread)), false, Color(FLAME, _burst))
		return
	var alpha := minf(_shown / FADE_IN, 1.0) * (_fade if _fade > 0.0 else 1.0)
	var scale_now := alpha
	var at := _last + lift
	# 땅의 빛 웅덩이 (눌린 타원)
	draw_set_transform(_last, 0.0, Vector2(1.0, 0.5))
	draw_texture_rect(_soft, _rect(Vector2.ZERO, SIZE * GLOW * 1.2), false, Color(GROUND, GROUND.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 꼬리
	for i in _trail.size():
		var share := 1.0 - float(i + 1) / float(TRAIL + 1)
		draw_circle(_trail[i] + lift, SIZE * 0.55 * share * scale_now, Color(FLAME, 0.5 * share * alpha))
	# 빛무리 · 불꽃 · 심지
	var flicker := 1.0 + 0.12 * sin(_clock * FLICKER_SPEED) + 0.06 * sin(_clock * FLICKER_SPEED * 2.3)
	var breath := 0.85 + 0.15 * sin(_clock * BREATH_SPEED)
	var radius := SIZE * flicker * scale_now
	draw_texture_rect(_soft, _rect(at, SIZE * GLOW * breath * scale_now), false, Color(GLOW_COLOR, 0.6 * alpha))
	draw_colored_polygon(_flame(at, radius + OUTLINE_WIDTH), Color(OUTLINE, alpha))
	draw_colored_polygon(_flame(at, radius), Color(FLAME, alpha))
	draw_colored_polygon(_flame(at + Vector2(0.0, radius * 0.22), radius * 0.62), Color(FLAME_IN, alpha))
	draw_circle(at + Vector2(0.0, radius * 0.38), radius * 0.3, Color(CORE, alpha))
	for side in [-1.0, 1.0]:  # 작은 눈 둘
		draw_circle(at + Vector2(side * radius * 0.26, radius * 0.12), radius * 0.1, Color(EYE, alpha))
	# 잡히는 몫
	var progress := Night.catch_progress()
	if progress > 0.0 and Night.is_wisp_up():
		draw_arc(at, RING_RADIUS, 0.0, TAU, 32, RING_BACK, RING_WIDTH)
		draw_arc(at, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, RING, RING_WIDTH)


## 위로 뾰족한 물방울 꼴 불꽃 (끝이 일렁인다)
func _flame(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var sway := sin(_clock * FLICKER_SPEED * 0.7) * radius * 0.25
	for i in 16:
		var angle := PI * 0.5 + TAU * i / 16.0  # 아래에서 돌기 시작
		var point := Vector2(cos(angle), sin(angle)) * radius
		if point.y < 0.0:  # 위쪽 반은 끝으로 모은다
			var up := -point.y / radius
			point = Vector2(point.x * (1.0 - up * 0.75) + sway * up, point.y * (1.0 + up * 0.9))
		points.append(at + point)
	return points


func _rect(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

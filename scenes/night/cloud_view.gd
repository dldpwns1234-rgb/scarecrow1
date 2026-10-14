extends Node2D
## 역병 구름의 그림 (GDD 4절): 땅 위에 눌린 타원(격자 위의 원)과 테두리를 도는 포자 덩이, 안에서 떨어지는 포자. Night.cloud를 따라 그리기만 한다.
## 구름이 칠 때마다(Night.pulsed) 잠깐 부풀고 밝아진다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FILL := Color(0.62, 0.86, 0.42, 0.22)
const RIM := Color(0.75, 0.95, 0.55, 0.75)
const PUFF := Color(0.58, 0.78, 0.4, 0.55)
const PULSE_FILL := Color(0.8, 1.0, 0.55, 0.38)
const PUFF_COUNT: int = 10
const PUFF_SIZE: float = 0.45      # 덩이 반지름 = 타원 세로 반지름 × 이 값
const SPIN_SPEED: float = 0.6      # 덩이가 테두리를 도는 빠르기 (라디안/초)
const PULSE_SCALE: float = 1.12
const PULSE_DURATION: float = 0.22
const ELLIPSE_POINTS: int = 40
const SPORE_RATE: int = 24          # 초당 떨어지는 포자

var origin: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _pulse: float = 0.0  # 1에서 0으로 줄어드는 박자 빛
var _spores: CPUParticles2D


func _ready() -> void:
	_spores = CPUParticles2D.new()
	_spores.amount = SPORE_RATE
	_spores.lifetime = 1.0
	_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_spores.direction = Vector2.DOWN
	_spores.spread = 25.0
	_spores.gravity = Vector2(0.0, 40.0)
	_spores.initial_velocity_min = 10.0
	_spores.initial_velocity_max = 30.0
	_spores.scale_amount_min = 2.0
	_spores.scale_amount_max = 4.0
	_spores.color = Color(0.78, 0.96, 0.5, 0.8)
	_spores.position = Vector2(0.0, -24.0)
	add_child(_spores)
	Night.pulsed.connect(_on_pulsed)


func _process(delta: float) -> void:
	visible = Night.active
	if not visible:
		return
	_spin += SPIN_SPEED * delta
	_pulse = maxf(_pulse - delta / PULSE_DURATION, 0.0)
	position = Iso.to_screen(origin, Night.cloud)
	var radii := Iso.ellipse_radii(Night.cloud_radius())
	_spores.emission_sphere_radius = radii.y
	queue_redraw()


func _on_pulsed() -> void:
	_pulse = 1.0


func _draw() -> void:
	var radii := Iso.ellipse_radii(Night.cloud_radius()) * lerpf(1.0, PULSE_SCALE, _pulse)
	var points := PackedVector2Array()
	for i in ELLIPSE_POINTS:
		var angle := TAU * i / ELLIPSE_POINTS
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, FILL.lerp(PULSE_FILL, _pulse))
	points.append(points[0])
	draw_polyline(points, RIM, 3.0, true)
	var puff := radii.y * PUFF_SIZE
	for i in PUFF_COUNT:
		var angle := _spin + TAU * i / PUFF_COUNT
		var wobble := 1.0 + 0.15 * sin(_spin * 3.0 + i)
		draw_circle(Vector2(cos(angle) * radii.x, sin(angle) * radii.y - puff * 0.5), puff * wobble, PUFF)

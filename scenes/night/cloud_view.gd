extends Node2D
## 역병 구름의 그림 (GDD 4절, 방장 2026-10-15 '역병 구름 정리'): 땅에는 치는 범위(격자 위의 원을 눌린 타원으로)가 옅은 풀빛 그림자와 부드러운 테두리로,
## 그 위에는 둥실 뜬 포자 구름 덩이가 천천히 뒤척인다. 작물 그림처럼 굵은 외곽선과 2단 명암(몸통, 달빛 쪽 밝은 면)으로 그린다. 구름 밑에서 포자가 떨어진다.
## 구름이 칠 때마다(Night.pulsed) 잠깐 부풀고 밝아지고, 역병 폭풍이 켜지면 보랏빛으로 크게 출렁이고, 새벽 전 몰아치기 동안은 붉게 끓는다.
## Night.cloud를 따라 그리기만 한다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const AREA := Color(0.42, 0.75, 0.3, 0.26)       # 땅 위 범위 그림자
const RIM := Color(0.78, 1.0, 0.55, 0.85)        # 범위 테두리
const OUTLINE := Color("231b2a")                # 구름 외곽선 (작물 선처럼 짙게, 보랏빛)
const OUTLINE_WIDTH: float = 3.5
const BODY := Color("94b44c")                    # 구름 몸통 (병든 노란 풀빛)
const BODY_SHADE := Color("5d4f72")              # 아래쪽 그늘 (보랏빛: 초록 덩이만이면 덤불처럼 보였다)
const BODY_LIGHT := Color("cfe684")              # 달빛 받은 면
const STORM_TINT := Color(0.62, 0.42, 0.85)
const FRENZY_TINT := Color(1.0, 0.5, 0.38)
const PULSE_GLOW := Color(0.85, 1.0, 0.6, 0.45)
const PUFFS: int = 7
const LIFT: float = 1.6           # 덩이가 뜨는 높이 = 범위 타원 세로 반지름 × 이 값
const PUFF_SIZE: float = 0.33     # 덩이 하나의 반지름 = 범위 타원 가로 반지름 × 이 값
const CHURN_SPEED: float = 0.45   # 덩이가 뒤척이는 빠르기 (라디안/초)
const PULSE_SCALE: float = 1.12
const PULSE_DURATION: float = 0.22
const STORM_DURATION: float = 0.45
const SPORE_RATE: int = 26        # 초당 떨어지는 포자

var origin: Vector2 = Vector2.ZERO
var _churn: float = 0.0
var _pulse: float = 0.0  # 1에서 0으로 줄어드는 박자 빛
var _storm: float = 0.0  # 역병 폭풍을 켠 순간의 출렁임 (1에서 0으로)
var _soft: GradientTexture2D  # 가운데가 짙고 가장자리로 사라지는 둥근 덩이
var _ring: GradientTexture2D  # 가장자리만 밝은 둥근 테
var _spores: CPUParticles2D


func _ready() -> void:
	_soft = _radial(PackedFloat32Array([0.0, 0.55, 1.0]), PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)]))
	_ring = _radial(PackedFloat32Array([0.0, 0.8, 0.93, 1.0]), PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.08), Color.WHITE, Color(1, 1, 1, 0.0)]))
	_spores = CPUParticles2D.new()
	_spores.amount = SPORE_RATE
	_spores.lifetime = 0.9
	_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_spores.direction = Vector2.DOWN
	_spores.spread = 20.0
	_spores.gravity = Vector2(0.0, 60.0)
	_spores.initial_velocity_min = 15.0
	_spores.initial_velocity_max = 35.0
	_spores.scale_amount_min = 1.5
	_spores.scale_amount_max = 3.5
	_spores.color = Color(0.8, 1.0, 0.55, 0.75)
	add_child(_spores)
	Night.pulsed.connect(_on_pulsed)
	Night.storm_pulsed.connect(func() -> void: _storm = 1.0)


func _radial(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _process(delta: float) -> void:
	visible = Night.active
	if not visible:
		return
	_churn += CHURN_SPEED * delta * (2.0 if Night.is_skill_active(Balance.Skill.STORM) else 1.0)
	_pulse = maxf(_pulse - delta / PULSE_DURATION, 0.0)
	_storm = maxf(_storm - delta / STORM_DURATION, 0.0)
	position = Iso.to_screen(origin, Night.cloud)
	var radii := Iso.ellipse_radii(Night.cloud_radius())
	_spores.position = Vector2(0.0, -radii.y * LIFT)
	_spores.emission_sphere_radius = radii.x * 0.45
	queue_redraw()


func _on_pulsed() -> void:
	_pulse = 1.0


func _draw() -> void:
	var radii := Iso.ellipse_radii(Night.cloud_radius()) * lerpf(1.0, PULSE_SCALE, _pulse) * (1.0 + 0.25 * _storm)  # 역병 폭풍을 켜면 한 번 크게 출렁인다 (반경은 Night가 키운다)
	var tint := Color.WHITE
	if Night.is_skill_active(Balance.Skill.STORM):
		tint = STORM_TINT
	if Night.in_frenzy():
		tint = FRENZY_TINT  # 새벽 전 몰아치기: 붉게 끓는다
	# 땅: 치는 범위 (그림자와 테두리)
	draw_texture_rect(_soft, Rect2(-radii, radii * 2.0), false, AREA * tint)
	draw_texture_rect(_ring, Rect2(-radii, radii * 2.0), false, RIM.lerp(PULSE_GLOW, _pulse) * tint)
	# 하늘: 뜬 구름 덩이. 외곽선(모든 덩이) → 그늘 → 몸통 → 밝은 면 순서로 겹쳐 한 덩어리로 보이게
	var puffs := _puffs(radii)
	var outline := OUTLINE.lerp(PULSE_GLOW, _pulse * 0.3)
	for puff in puffs:
		draw_circle(Vector2(puff.x, puff.y), puff.z + OUTLINE_WIDTH, outline)
	for puff in puffs:
		draw_circle(Vector2(puff.x, puff.y + puff.z * 0.18), puff.z, BODY_SHADE * tint)
	for puff in puffs:
		draw_circle(Vector2(puff.x, puff.y - puff.z * 0.06), puff.z * 0.9, BODY.lerp(PULSE_GLOW, _pulse * 0.5) * tint)
	for puff in puffs:
		draw_circle(Vector2(puff.x + puff.z * 0.22, puff.y - puff.z * 0.3), puff.z * 0.45, BODY_LIGHT.lerp(PULSE_GLOW, _pulse * 0.6) * tint)


## 구름 덩이들 (x, y, 반지름): 가운데 큰 덩이를 둘레 덩이가 둘러싸고 천천히 뒤척인다
func _puffs(radii: Vector2) -> Array[Vector3]:
	var center := Vector2(0.0, -radii.y * LIFT)
	var size := radii.x * PUFF_SIZE
	var result: Array[Vector3] = [Vector3(center.x, center.y - size * 0.2, size * 1.1)]
	for i in PUFFS:
		var angle := _churn * (1.0 if i % 2 == 0 else -0.6) + TAU * i / PUFFS
		var at := center + Vector2(cos(angle) * radii.x * 0.66, sin(angle) * radii.y * 0.3)  # 옆으로 넓고 납작하게 (구름답게)
		result.append(Vector3(at.x, at.y, size * (0.8 + 0.2 * sin(_churn * 2.0 + i * 1.7))))
	return result

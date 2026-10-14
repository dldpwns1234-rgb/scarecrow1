extends Node2D
## 농부 그림 (GDD 8절 M3): Night.farmers 자리에 농부가 걸으며 흔들리고, 발밑에 약을 친 둘레(옅은 물빛 타원)를 그린다.
## 번짐을 씻어 낼 때(Night.farmer_sprayed) 그 작물 위에 흰 김이 피어오른다. 그리기만 한다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const TEXTURE := preload("res://assets/sprites/farmer.svg")
const SCALE: float = 0.5
const BASE := Vector2(0.5, 0.96)       # 그림 안에서 발끝 자리 (크기 비율)
const AURA := Color(0.62, 0.84, 1.0, 0.16)
const AURA_RIM := Color(0.75, 0.9, 1.0, 0.45)
const BOB_HEIGHT: float = 3.0
const BOB_SPEED: float = 9.0
const PUFF_COLOR := Color(0.92, 0.96, 1.0, 0.75)
const PUFF_DURATION: float = 0.6
const PUFF_RISE: float = 26.0
const MAX_PUFFS: int = 20
const ELLIPSE_POINTS: int = 32

var origin: Vector2 = Vector2.ZERO
var field: Node2D  # field_view.gd (칸의 화면 자리)
var _sprites: Array[Sprite2D] = []
var _puffs: Array[Dictionary] = []  # {"at", "t"}
var _clock: float = 0.0


func _ready() -> void:
	Night.farmer_sprayed.connect(_on_sprayed)


func _process(delta: float) -> void:
	_clock += delta
	var count := Night.farmers.size() if Night.active else 0
	while _sprites.size() < count:
		var sprite := Sprite2D.new()
		sprite.texture = TEXTURE
		sprite.scale = Vector2.ONE * SCALE
		sprite.offset = -TEXTURE.get_size() * BASE + TEXTURE.get_size() * 0.5
		add_child(sprite)
		_sprites.append(sprite)
	for i in _sprites.size():
		var sprite := _sprites[i]
		sprite.visible = i < count
		if sprite.visible:
			var bob := absf(sin(_clock * BOB_SPEED + i)) * BOB_HEIGHT
			sprite.position = Iso.to_screen(origin, Night.farmers[i]) - Vector2(0.0, bob)
	for puff in _puffs:
		puff["t"] = float(puff["t"]) + delta / PUFF_DURATION
	_puffs = _puffs.filter(func(puff: Dictionary) -> bool: return float(puff["t"]) < 1.0)
	queue_redraw()


func _on_sprayed(index: int) -> void:
	if _puffs.size() < MAX_PUFFS:
		_puffs.append({"at": field.cell_screen(index), "t": 0.0})


func _draw() -> void:
	if not Night.active:
		return
	var radii := Iso.ellipse_radii(Balance.FARMER_RADIUS)
	for spot in Night.farmers:
		var center := Iso.to_screen(origin, spot)
		var points := PackedVector2Array()
		for k in ELLIPSE_POINTS:
			var angle := TAU * k / ELLIPSE_POINTS
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, AURA)
		points.append(points[0])
		draw_polyline(points, AURA_RIM, 2.0, true)
	for puff in _puffs:
		var t := float(puff["t"])
		var at: Vector2 = puff["at"]
		var color := PUFF_COLOR
		color.a *= 1.0 - t
		draw_circle(at + Vector2(0.0, -30.0 - PUFF_RISE * t), 6.0 + 8.0 * t, color)

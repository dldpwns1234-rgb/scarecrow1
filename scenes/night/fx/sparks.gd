extends Control
## 밤 화면의 알갱이 (방장 2026-10-14 "가득 차는 뽕맛"): 작물이 시들면 그 자리에서 금빛·풀빛 생기 알갱이가 튀어 오르다 떨어지며 사라진다.
## 풍작(combo_meter.gd의 burst)이면 밭 가운데에서 크게 터진다. 수박이 터지면(crop_burst) 붉은 즙이, 해바라기 씨앗이 튀면(seeds_flung) 검은 씨앗이 이웃 칸으로 난다. 알갱이 수에 상한을 둬 한꺼번에 시들어도 무겁지 않다.
## field(field_view.gd)의 cell_screen으로 자리를 얻는다. Night 시그널만 받는 연출이다. 상수는 연출용이다

const PER_WITHER: int = 7
const PER_BURST: int = 70
const MAX_SPARKS: int = 420
const LIFE := Vector2(0.45, 0.9)          # 초
const SPEED := Vector2(80.0, 220.0)       # 픽셀/초
const BURST_SPEED := Vector2(220.0, 560.0)
const GRAVITY: float = 520.0
const RADIUS := Vector2(2.0, 4.5)
const COLORS: Array[Color] = [Color("f2d27a"), Color("9ad14f"), Color("fff3c4"), Color("c8f08a"), Color("e8505b"), Color("ff8a8f"), Color("3a2a1e")]
const GOLD_COLORS: int = 4               # 앞의 넷이 생기 알갱이 색, 그다음 둘이 수박 즙, 마지막이 씨앗
const JUICE_COLOR_FROM: int = 4
const SEED_COLOR: int = 6
const PER_JUICE: int = 26
const SEED_FLIGHT: float = 0.45          # 씨앗이 이웃 칸에 닿는 시간

var field: Node2D                         # field_view.gd (cell_screen)
var _sparks: Array[PackedFloat32Array] = []  # x, y, vx, vy, 남은 수명, 처음 수명, 반지름, 색 번호
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Night.crop_withered.connect(_on_withered.unbind(1))
	Night.night_started.connect(func() -> void: _sparks.clear())
	if Night.has_signal("crop_burst"):
		Night.connect("crop_burst", _on_burst_crop)
	if Night.has_signal("seeds_flung"):
		Night.connect("seeds_flung", _on_seeds)


func _on_withered(index: int) -> void:
	if field == null or not field.has_method("cell_screen"):
		return
	_spawn(field.call("cell_screen", index), PER_WITHER, SPEED, -PI * 0.85, -PI * 0.15)


## 수박이 터졌다: 붉은 즙이 사방으로 (반경이 클수록 멀리)
func _on_burst_crop(index: int, radius: float) -> void:
	if field == null:
		return
	var scale := clampf(radius, 1.0, 3.0)
	_spawn(field.call("cell_screen", index), roundi(PER_JUICE * scale), SPEED * scale, 0.0, TAU, JUICE_COLOR_FROM, 2)


## 해바라기 씨앗: 이웃 칸마다 하나씩 포물선으로
func _on_seeds(index: int, targets: PackedInt32Array) -> void:
	if field == null:
		return
	var at: Vector2 = field.call("cell_screen", index)
	for target in targets:
		var to: Vector2 = field.call("cell_screen", target)
		var velocity := (to - at) / SEED_FLIGHT - Vector2(0.0, GRAVITY * SEED_FLIGHT * 0.5)  # 중력을 받아 그 칸에 떨어지게
		_add(at, velocity, SEED_FLIGHT, 3.0, SEED_COLOR)


## 풍작: 한 점에서 사방으로 크게. scale은 알갱이 수 배율 (그 밤의 풍작이 거듭될수록 커진다)
func burst_at(at: Vector2, scale: float = 1.0) -> void:
	_spawn(at, roundi(PER_BURST * scale), BURST_SPEED * sqrt(scale), 0.0, TAU)


func _spawn(at: Vector2, count: int, speed: Vector2, angle_from: float, angle_to: float, color_from: int = 0, color_count: int = GOLD_COLORS) -> void:
	for i in count:
		var angle := _rng.randf_range(angle_from, angle_to)
		var velocity := Vector2.from_angle(angle) * _rng.randf_range(speed.x, speed.y)
		_add(at, velocity, _rng.randf_range(LIFE.x, LIFE.y), _rng.randf_range(RADIUS.x, RADIUS.y), color_from + _rng.randi() % color_count)


func _add(at: Vector2, velocity: Vector2, life: float, radius: float, color: int) -> void:
	if _sparks.size() >= MAX_SPARKS:
		_sparks.remove_at(0)
	_sparks.append(PackedFloat32Array([at.x, at.y, velocity.x, velocity.y, life, life, radius, float(color)]))


func _process(delta: float) -> void:
	if _sparks.is_empty():
		return
	delta = minf(delta, Balance.MAX_DELTA)
	var alive: Array[PackedFloat32Array] = []
	for s in _sparks:
		s[4] -= delta
		if s[4] <= 0.0:
			continue
		s[3] += GRAVITY * delta
		s[0] += s[2] * delta
		s[1] += s[3] * delta
		alive.append(s)
	_sparks = alive
	queue_redraw()


func _draw() -> void:
	for s in _sparks:
		var t := s[4] / s[5]
		draw_circle(Vector2(s[0], s[1]), s[6] * (0.5 + 0.5 * t), Color(COLORS[int(s[7])], t))

extends Node2D
## 밤 밭 위의 스킬·작물 연출 (판 안 좌표, night_screen.gd): 수박이 터지는 둥근 파동(Night.crop_burst), 해바라기 씨앗이 날아가는 호(seeds_flung),
## 포도 덩굴·연쇄 시듦이 옆 작물을 치는 번개(chain_struck), 수확의 낫이 밭을 가로지르는 은빛 낫질, 썩은 비 동안 떨어지는 보랏빛 빗방울,
## 어둠의 장막 동안 밭을 덮는 어스름. 그리기만 한다 (피해는 Night가 이미 줬다). 한꺼번에 그리는 수에 상한을 둔다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const BURST_COLOR := Color(1.0, 0.55, 0.45, 0.85)
const BURST_SECONDS: float = 0.45
const SEED_COLOR := Color(0.98, 0.85, 0.3)
const SEED_SECONDS: float = 0.5
const SEED_ARC: float = 60.0         # 씨앗이 솟는 높이
const CHAIN_COLOR := Color(0.8, 1.0, 0.55, 0.95)
const CHAIN_SECONDS: float = 0.28
const CHAIN_JITTER: float = 7.0
const REAP_COLOR := Color(0.92, 0.94, 1.0, 0.85)
const REAP_SECONDS: float = 0.55
const RAIN_COLOR := Color(0.8, 0.62, 1.0, 0.95)
const RAIN_DROPS: int = 120
const RAIN_LENGTH := Vector2(-3.0, 16.0)
const RAIN_FALL: float = 140.0       # 빗방울이 떨어지는 거리 (판 좌표)
const RAIN_SPEED: float = 1.6        # 초당 한 번 떨어지는 빈도
const VEIL_COLOR := Color(0.12, 0.08, 0.22, 0.32)
const MAX_EFFECTS: int = 60
const LIFT := Vector2(0.0, -22.0)    # 작물 몸통께 (밑동보다 조금 위)

var field: Node2D  # field_view.gd (cell_local)
var _effects: Array[Dictionary] = []  # {"kind", "t", "seconds", ...}
var _clock: float = 0.0
var _drawn: bool = false  # 지난 프레임에 무언가 그렸다 (다 사라진 뒤 한 번 더 지운다)
var _drops: PackedVector2Array = PackedVector2Array()  # 빗방울의 격자 자리 (0~1 비율)와 박자


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in RAIN_DROPS:
		_drops.append(Vector2(rng.randf(), rng.randf()))
		_drops.append(Vector2(rng.randf(), 0.0))
	Night.crop_burst.connect(_on_burst)
	Night.seeds_flung.connect(_on_seeds)
	Night.chain_struck.connect(_on_chain)
	Night.skill_used.connect(_on_skill)
	Night.night_started.connect(_effects.clear)


func _add(effect: Dictionary) -> void:
	if _effects.size() < MAX_EFFECTS:
		effect["t"] = 0.0
		_effects.append(effect)


func _on_burst(index: int, radius: float) -> void:
	_add({"kind": "burst", "seconds": BURST_SECONDS, "at": field.cell_local(index), "radii": Iso.ellipse_radii(radius)})


func _on_seeds(index: int, targets: PackedInt32Array) -> void:
	for target in targets:
		_add({"kind": "seed", "seconds": SEED_SECONDS, "from": field.cell_local(index) + LIFT * 2.0, "to": field.cell_local(target) + LIFT})


func _on_chain(from: int, to: int) -> void:
	_add({"kind": "chain", "seconds": CHAIN_SECONDS, "from": field.cell_local(from) + LIFT, "to": field.cell_local(to) + LIFT, "seed": randi()})


func _on_skill(skill: int) -> void:
	if skill == Balance.Skill.REAP:
		_add({"kind": "reap", "seconds": REAP_SECONDS})


func _process(delta: float) -> void:
	_clock += delta
	for effect in _effects:
		effect["t"] = float(effect["t"]) + delta / float(effect["seconds"])
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return float(effect["t"]) < 1.0)
	var busy := Night.active and (not _effects.is_empty() or Night.is_skill_active(Balance.Skill.VEIL) or Night.is_skill_active(Balance.Skill.RAIN))
	if busy or _drawn:
		queue_redraw()  # 그릴 것이 있을 때만 (없는데 매 프레임 다시 그리면 헛일)
	_drawn = busy


func _draw() -> void:
	if not Night.active:
		return
	var n := float(Night.field_size)
	if Night.is_skill_active(Balance.Skill.VEIL):
		draw_colored_polygon(_diamond(n), VEIL_COLOR)
	if Night.is_skill_active(Balance.Skill.RAIN):
		_draw_rain(n)
	for effect in _effects:
		var t := float(effect["t"])
		match String(effect["kind"]):
			"burst":
				_draw_ring(effect["at"], (effect["radii"] as Vector2) * (0.3 + 0.7 * t), BURST_COLOR * Color(1, 1, 1, 1.0 - t), 4.0 * (1.0 - t) + 1.0)
			"seed":
				var from: Vector2 = effect["from"]
				var to: Vector2 = effect["to"]
				draw_circle(from.lerp(to, t) + Vector2(0.0, -SEED_ARC * sin(PI * t)), 4.0, SEED_COLOR)
			"chain":
				_draw_bolt(effect["from"], effect["to"], int(effect["seed"]), CHAIN_COLOR * Color(1, 1, 1, 1.0 - t))
			"reap":
				_draw_reap(n, t)


func _diamond(n: float) -> PackedVector2Array:
	return PackedVector2Array([Iso.to_screen(Vector2.ZERO, Vector2(0, 0)), Iso.to_screen(Vector2.ZERO, Vector2(n, 0)),
		Iso.to_screen(Vector2.ZERO, Vector2(n, n)), Iso.to_screen(Vector2.ZERO, Vector2(0, n))])


func _draw_ring(at: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in 33:
		var angle := TAU * k / 32.0
		points.append(at + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)


## 꺾인 번개 한 줄 (같은 효과는 같은 꺾임)
func _draw_bolt(from: Vector2, to: Vector2, seed_value: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points := PackedVector2Array([from])
	var side := (to - from).orthogonal().normalized()
	for k in range(1, 4):
		points.append(from.lerp(to, k / 4.0) + side * rng.randf_range(-CHAIN_JITTER, CHAIN_JITTER))
	points.append(to)
	draw_polyline(points, color, 2.5, true)


## 수확의 낫: 밭 왼쪽 위 끝에서 오른쪽 아래 끝으로 은빛 초승달이 휩쓸고 지나간다
func _draw_reap(n: float, t: float) -> void:
	var a := Iso.to_screen(Vector2.ZERO, Vector2(0, n))
	var b := Iso.to_screen(Vector2.ZERO, Vector2(n, 0))
	var center := a.lerp(b, t)
	var radius := Iso.TILE_W * n * 0.35
	var color := REAP_COLOR * Color(1, 1, 1, sin(PI * t))
	draw_arc(center + Vector2(0.0, radius * 0.6), radius, -PI * 0.85, -PI * 0.15, 32, color, 6.0, true)
	draw_arc(center + Vector2(0.0, radius * 0.6), radius * 0.92, -PI * 0.8, -PI * 0.2, 32, color * Color(1, 1, 1, 0.5), 3.0, true)


## 썩은 비: 밭 위 고정된 자리에서 빗방울이 박자를 달리해 떨어진다
func _draw_rain(n: float) -> void:
	for i in RAIN_DROPS:
		var spot := _drops[i * 2]
		var phase := fmod(_clock * RAIN_SPEED + _drops[i * 2 + 1].x, 1.0)
		var ground := Iso.to_screen(Vector2.ZERO, spot * n)
		var top := ground + Vector2(0.0, -RAIN_FALL * (1.0 - phase))
		draw_line(top, top + RAIN_LENGTH, RAIN_COLOR * Color(1, 1, 1, 0.4 + 0.6 * phase), 3.0)
		if phase > 0.9:  # 땅에 닿으며 작게 튄다
			_draw_ring(ground, Vector2(8.0, 4.0) * (phase - 0.9) * 10.0, RAIN_COLOR * Color(1, 1, 1, 0.6), 1.5)

extends Node2D
## 밤 밭의 그림 (GDD 4절): 아이소메트릭 땅(마름모 칸과 흙 옆면)과 칸마다 작물 그림. Night의 시그널을 받아 그리기만 한다.
## 작물은 체력이 줄수록 병든 색으로 물들고, 맞으면 번쩍이며 움찔하고, 시들면 시든 그림으로 바뀌며 땅이 썩은 색이 된다. 번진 작물은 보랏빛, 다시 자란 작물은 작게 솟아난다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const TEXTURES: Array[Texture2D] = [  # Balance.Crop 순서
	preload("res://assets/sprites/crops/wheat.svg"),
	preload("res://assets/sprites/crops/corn.svg"),
	preload("res://assets/sprites/crops/pumpkin.svg"),
	preload("res://assets/sprites/crops/golden.svg"),
]
const DEAD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/crops/wheat_dead.svg"),
	preload("res://assets/sprites/crops/corn_dead.svg"),
	preload("res://assets/sprites/crops/pumpkin_dead.svg"),
	preload("res://assets/sprites/crops/golden_dead.svg"),
]
const CROP_SCALE: float = 0.42          # 그림(96px × 가져오기 1.5배)을 칸 폭에 맞춘다
const CROP_BASE := Vector2(0.5, 0.94)   # 그림 안에서 밑동 자리 (크기 비율)
const GRASS := [Color("3f6b3a"), Color("44733e")]  # 달빛 아래 풀 (체크무늬)
const BLIGHT := Color("4a4232")         # 시든 칸
const ROT_GROUND := Color("4d3f5c")     # 번짐에 걸린 칸
const SIDE_LEFT := Color("4b3524")      # 흙 옆면
const SIDE_RIGHT := Color("3a291c")
const SIDE_DEPTH: float = 16.0
const EDGE := Color(0.0, 0.0, 0.0, 0.18)
const SICK := Color("9a8f6e")           # 체력이 바닥에 가까울 때 작물 색
const ROT_TINT := Color("c8a0e8")       # 번진 작물
const HIT_FLASH := Color(1.6, 1.6, 1.4)
const HIT_DURATION: float = 0.18
const HIT_SQUASH := Vector2(1.08, 0.9)
const WITHER_DROP: float = 4.0
const REGROW_START: float = 0.2
const REGROW_DURATION: float = 0.35

var origin: Vector2 = Vector2.ZERO
var _ground: Node2D
var _crops: Node2D
var _sprites: Array[Sprite2D] = []  # 칸 번호 순서
var _tweens: Array[Tween] = []


func _ready() -> void:
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_crops = Node2D.new()
	add_child(_crops)
	_sprites.resize(Night.cell_count())
	_tweens.resize(Night.cell_count())
	for index in _draw_order():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.scale = Vector2.ONE * CROP_SCALE
		_crops.add_child(sprite)
		_sprites[index] = sprite
	Night.night_started.connect(rebuild)
	Night.crop_hit.connect(_on_hit)
	Night.crop_withered.connect(_on_withered)
	Night.crop_infected.connect(_on_infected)
	Night.crop_regrown.connect(_on_regrown)
	rebuild()


## 밭을 옮긴다 (화면 크기가 바뀌면 night_screen.gd가 부른다)
func set_origin(value: Vector2) -> void:
	origin = value
	for i in _sprites.size():
		_place(i)
	_ground.queue_redraw()


## 칸 가운데의 화면 자리 (작물 밑동)
func cell_screen(index: int) -> Vector2:
	return Iso.to_screen(origin, Night.cell_position(index))


## 밤이 시작되면 새로 심은 밭으로 그림을 다시 맞춘다
func rebuild() -> void:
	for i in _sprites.size():
		var sprite := _sprites[i]
		var kind := Night.kinds[i]
		sprite.visible = kind != Night.EMPTY
		if kind == Night.EMPTY:
			continue
		sprite.texture = TEXTURES[kind] if Night.is_alive(i) else DEAD_TEXTURES[kind]
		sprite.modulate = Color.WHITE
		_place(i)
	_ground.queue_redraw()


## 밑동을 칸 가운데에 둔다 (offset으로 밑동을 기준점에 맞춰서 움찔·쓰러짐이 밑동을 축으로 돈다)
func _place(index: int) -> void:
	var sprite := _sprites[index]
	if sprite.texture == null:
		return
	sprite.offset = -sprite.texture.get_size() * CROP_BASE
	sprite.position = cell_screen(index)
	sprite.scale = Vector2.ONE * CROP_SCALE


## 뒤(화면 위쪽)부터 앞으로 그리는 칸 순서: x + y가 작은 칸이 먼저
func _draw_order() -> Array[int]:
	var order: Array[int] = []
	for i in Night.cell_count():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := Night.cell_position(a)
		var pb := Night.cell_position(b)
		return pa.x + pa.y < pb.x + pb.y or (is_equal_approx(pa.x + pa.y, pb.x + pb.y) and pa.x < pb.x))
	return order


func _health_color(index: int) -> Color:
	var share := Night.hp[index] / maxf(Night.max_hp[index], 1e-9)
	var base := Color.WHITE.lerp(SICK, 1.0 - share)
	return base * ROT_TINT if Night.infected[index] == 1 else base


func _on_hit(index: int, _hp: float, _damage: float) -> void:
	if not Night.is_alive(index):
		return
	var sprite := _sprites[index]
	if _tweens[index] != null:
		_tweens[index].kill()
	var rest := _health_color(index)
	sprite.modulate = HIT_FLASH
	sprite.scale = Vector2.ONE * CROP_SCALE * HIT_SQUASH
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate", rest, HIT_DURATION)
	tween.tween_property(sprite, "scale", Vector2.ONE * CROP_SCALE, HIT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[index] = tween


func _on_withered(index: int, _rest: float) -> void:
	var sprite := _sprites[index]
	if _tweens[index] != null:
		_tweens[index].kill()
	sprite.texture = DEAD_TEXTURES[Night.kinds[index]]
	sprite.modulate = Color.WHITE
	_place(index)
	sprite.position.y += WITHER_DROP
	_ground.queue_redraw()


## 다시 자라는 뿌리: 새 작물이 작게 솟아난다
func _on_regrown(index: int) -> void:
	var sprite := _sprites[index]
	if _tweens[index] != null:
		_tweens[index].kill()
	sprite.texture = TEXTURES[Night.kinds[index]]
	sprite.modulate = Color.WHITE
	_place(index)
	sprite.scale = Vector2.ONE * CROP_SCALE * REGROW_START
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * CROP_SCALE, REGROW_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[index] = tween
	_ground.queue_redraw()


func _on_infected(index: int) -> void:
	_sprites[index].modulate = _health_color(index)
	_ground.queue_redraw()


func _draw_ground() -> void:
	var n := Balance.FIELD_SIZE
	# 흙 옆면: 왼쪽 아래 모서리와 오른쪽 아래 모서리
	var left := Iso.to_screen(origin, Vector2(0, n))
	var bottom := Iso.to_screen(origin, Vector2(n, n))
	var right := Iso.to_screen(origin, Vector2(n, 0))
	var down := Vector2(0.0, SIDE_DEPTH)
	_ground.draw_colored_polygon(PackedVector2Array([left, bottom, bottom + down, left + down]), SIDE_LEFT)
	_ground.draw_colored_polygon(PackedVector2Array([bottom, right, right + down, bottom + down]), SIDE_RIGHT)
	for y in n:
		for x in n:
			var index := y * n + x
			var color: Color = GRASS[(x + y) % 2]
			if Night.kinds[index] != Night.EMPTY and not Night.is_alive(index):
				color = BLIGHT
			elif Night.infected[index] == 1:
				color = ROT_GROUND
			var polygon := Iso.tile_polygon(origin, x, y)
			_ground.draw_colored_polygon(polygon, color)
			polygon.append(polygon[0])
			_ground.draw_polyline(polygon, EDGE, 1.0)

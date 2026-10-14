extends Node2D
## 밤 밭의 그림 (GDD 4절): 아이소메트릭 땅(field_ground.gd)과 칸마다 작물 그림. Night의 시그널을 받아 그리기만 한다.
## 밭 크기는 밤마다 다를 수 있어(밭 단계로 넓어진다) 밤이 시작될 때 칸 수가 바뀌었으면 그림을 새로 만든다. night_screen.gd의 판(Node2D) 안에서 그리고, 판의 배율로 화면에 맞춘다.
## 작물은 체력이 줄수록 병든 색으로 물들고, 맞으면 번쩍이며 움찔하고, 시들면 시든 그림으로 바뀌며 땅이 썩은 색이 된다. 번진 작물은 보랏빛, 다시 자란 작물은 작게 솟아난다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FieldGround := preload("res://scenes/night/field_ground.gd")
const TEXTURES: Array[Texture2D] = [  # Balance.Crop 순서
	preload("res://assets/sprites/crops/wheat.svg"),
	preload("res://assets/sprites/crops/corn.svg"),
	preload("res://assets/sprites/crops/pumpkin.svg"),
	preload("res://assets/sprites/crops/golden.svg"),
	preload("res://assets/sprites/crops/turnip.svg"),
	preload("res://assets/sprites/crops/sunflower.svg"),
	preload("res://assets/sprites/crops/watermelon.svg"),
	preload("res://assets/sprites/crops/grape.svg"),
]
const DEAD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/crops/wheat_dead.svg"),
	preload("res://assets/sprites/crops/corn_dead.svg"),
	preload("res://assets/sprites/crops/pumpkin_dead.svg"),
	preload("res://assets/sprites/crops/golden_dead.svg"),
	preload("res://assets/sprites/crops/turnip_dead.svg"),
	preload("res://assets/sprites/crops/sunflower_dead.svg"),
	preload("res://assets/sprites/crops/watermelon_dead.svg"),
	preload("res://assets/sprites/crops/grape_dead.svg"),
]
const CROP_SCALE: float = 0.42          # 그림(96px × 가져오기 1.5배)을 칸 폭에 맞춘다
const CROP_BASE := Vector2(0.5, 0.94)   # 그림 안에서 밑동 자리 (크기 비율)
const SICK := Color("9a8f6e")           # 체력이 바닥에 가까울 때 작물 색
const ROT_TINT := Color("c8a0e8")       # 번진 작물
const HIT_FLASH := Color(1.6, 1.6, 1.4)
const HIT_DURATION: float = 0.18
const HIT_SQUASH := Vector2(1.08, 0.9)
const WITHER_DROP: float = 4.0
const REGROW_START: float = 0.2
const REGROW_DURATION: float = 0.35

var _ground: FieldGround
var _crops: Node2D
var _sprites: Array[Sprite2D] = []  # 칸 번호 순서
var _tweens: Array[Tween] = []


func _ready() -> void:
	_ground = FieldGround.new()
	add_child(_ground)
	_crops = Node2D.new()
	add_child(_crops)
	Night.night_started.connect(rebuild)
	Night.wave_started.connect(_on_wave.unbind(1))
	Night.crop_hit.connect(_on_hit)
	Night.crop_withered.connect(_on_withered)
	Night.crop_infected.connect(_on_infected)
	Night.crop_regrown.connect(_on_regrown)
	rebuild()


## 칸 가운데의 판 안 자리 (작물 밑동). 판 안의 그림(농부·까마귀)이 쓴다
func cell_local(index: int) -> Vector2:
	return Iso.to_screen(Vector2.ZERO, Night.cell_position(index))


## 칸 가운데의 밤 화면 자리: 판의 자리·배율을 씌운다. 판 밖의 연출(생기 글·알갱이)이 쓴다
func cell_screen(index: int) -> Vector2:
	var board := get_parent() as Node2D
	return board.transform * cell_local(index) if board != null else cell_local(index)


## 밤이 시작되면 새로 심은 밭으로 그림을 다시 맞춘다 (칸 수가 바뀌었으면 그림부터 새로)
func rebuild() -> void:
	if _sprites.size() != Night.cell_count():
		_make_sprites()
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


func _make_sprites() -> void:
	for tween in _tweens:
		if tween != null:
			tween.kill()
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	_tweens.clear()
	_sprites.resize(Night.cell_count())
	_tweens.resize(Night.cell_count())
	for index in _draw_order():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.scale = Vector2.ONE * CROP_SCALE
		_crops.add_child(sprite)
		_sprites[index] = sprite


## 밑동을 칸 가운데에 둔다 (offset으로 밑동을 기준점에 맞춰서 움찔·쓰러짐이 밑동을 축으로 돈다)
func _place(index: int) -> void:
	var sprite := _sprites[index]
	if sprite.texture == null:
		return
	sprite.offset = -sprite.texture.get_size() * CROP_BASE
	sprite.position = cell_local(index)
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


## 정복 뒤 새 물결: 밭 전체가 작게 솟아난다
func _on_wave() -> void:
	rebuild()
	for i in _sprites.size():
		if _sprites[i].visible:
			_on_regrown(i)


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


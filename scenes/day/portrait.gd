extends Control
## 낮 화면 왼쪽 위의 짚돌이 초상화: 숨 쉬듯 천천히 늘었다 준다. 계약을 맺은 뒤(첫 실행 장면)에는 어깨에 보랏빛 어둠의 까마귀가 앉아 있고,
## 엔딩(마지막 이야기 조각)을 본 뒤에는 그냥 까마귀가 된다. Story를 읽기만 한다. 상수는 배치·연출용이다

const SCARECROW := preload("res://icon.svg")
const CROW := preload("res://assets/sprites/crow.svg")
const SIZE := Vector2(150, 150)
const CROW_SIZE := Vector2(58, 58)
const SHOULDER := Vector2(0.76, 0.43)   # 짚돌이 그림에서 오른 어깨 자리 (비율, intro_card와 같다)
const CROW_FEET := Vector2(0.5, 0.74)
const DARK_TINT := Color(0.35, 0.22, 0.55)
const BREATH_SCALE: float = 1.03
const BREATH_SECONDS: float = 1.8

var _scarecrow: TextureRect
var _crow: TextureRect


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scarecrow = _figure(SCARECROW, SIZE)
	_scarecrow.pivot_offset = Vector2(SIZE.x * 0.5, SIZE.y)  # 발끝을 기준으로 숨 쉰다
	add_child(_scarecrow)
	_crow = _figure(CROW, CROW_SIZE)
	add_child(_crow)
	var breath := create_tween().set_loops()
	breath.tween_property(_scarecrow, "scale", Vector2(1.0, BREATH_SCALE), BREATH_SECONDS).set_trans(Tween.TRANS_SINE)
	breath.tween_property(_scarecrow, "scale", Vector2.ONE, BREATH_SECONDS).set_trans(Tween.TRANS_SINE)
	resized.connect(_layout)
	Story.story_changed.connect(_refresh)
	_layout()
	_refresh()


func _figure(texture: Texture2D, figure_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = figure_size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 초상화는 칸 가운데, 까마귀는 어깨 위
func _layout() -> void:
	_scarecrow.position = Vector2((size.x - SIZE.x) * 0.5, 0.0)
	_crow.position = _scarecrow.position + SHOULDER * SIZE - CROW_FEET * CROW_SIZE


func _refresh() -> void:
	_crow.visible = Story.intro_seen
	var ended := Story.seen_count >= Balance.FRAGMENTS.size()  # 엔딩을 봤다: 어둠은 그냥 까마귀가 되었다
	_crow.modulate = Color.WHITE if ended else DARK_TINT

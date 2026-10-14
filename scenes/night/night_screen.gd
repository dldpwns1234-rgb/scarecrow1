extends Control
## 밤: 밭 (GDD 4절). 밤하늘, 아이소메트릭 밭(field_view), 역병 구름(cloud_view), 까마귀(crow_view), 휴식 연출(rest_fx), 위쪽 글(night_hud).
## 커서나 손가락을 움직이면 그 자리로 구름을 옮긴다 (Night.set_cloud). 규칙은 Night 오토로드가 돌리고 이 화면은 입력과 그림만 맡는다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FieldView := preload("res://scenes/night/field_view.gd")
const CloudView := preload("res://scenes/night/cloud_view.gd")
const CrowView := preload("res://scenes/night/crow_view.gd")
const RestFx := preload("res://scenes/night/rest_fx.gd")
const NightHud := preload("res://scenes/night/night_hud.gd")

const SKY_TOP := Color("0d1424")
const SKY_BOTTOM := Color("23304a")
const STAR_COLOR := Color(1.0, 0.96, 0.85, 0.8)
const STAR_COUNT: int = 70
const MOON := Color("f3ecd2")
const MOON_POSITION := Vector2(0.86, 0.2)  # 화면 비율
const MOON_RADIUS: float = 34.0
const FIELD_DROP: float = 34.0       # 밭 가운데를 화면 가운데보다 이만큼 아래에 (위쪽 글 자리)
const SIDE_DEPTH: float = 16.0
const TOUCH_LIFT: float = 70.0       # 손가락으로 끌 때 구름을 손가락보다 위에 둔다 (손에 가려지지 않게)

var _field: FieldView
var _cloud: CloudView
var _crows: CrowView
var _fx: RestFx
var _hud: NightHud
var _stars: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 2026
	for i in STAR_COUNT:
		_stars.append(Vector2(star_rng.randf(), star_rng.randf() * 0.45))
	_field = FieldView.new()
	add_child(_field)
	_cloud = CloudView.new()
	add_child(_cloud)
	_crows = CrowView.new()
	_crows.field = _field
	add_child(_crows)
	_fx = RestFx.new()
	_fx.field = _field
	add_child(_fx)
	_hud = NightHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var field := Iso.field_size(Balance.FIELD_SIZE)
	var top := (size.y - field.y - SIDE_DEPTH) * 0.5 + FIELD_DROP
	var origin := Vector2(size.x * 0.5, top)
	_field.set_origin(origin)
	_cloud.origin = origin
	_fx.target = _hud.rest_target()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not Night.active:
		return
	if event is InputEventScreenDrag or event is InputEventScreenTouch:
		_move_cloud(event.position - Vector2(0.0, TOUCH_LIFT))
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != InputEvent.DEVICE_ID_EMULATION:
		_move_cloud(event.position)  # 터치가 흉내 낸 마우스 이벤트는 건너뛴다 (손가락 위치로 두 번 옮겨 떨린다)


func _move_cloud(screen: Vector2) -> void:
	Night.set_cloud(Iso.to_grid(_field.origin, screen))


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for star in _stars:
		draw_circle(Vector2(star.x * size.x, star.y * size.y), 1.4, STAR_COLOR)
	draw_circle(MOON_POSITION * size, MOON_RADIUS, MOON)
	draw_circle(MOON_POSITION * size + Vector2(12.0, -8.0), MOON_RADIUS * 0.85, SKY_TOP.lerp(SKY_BOTTOM, MOON_POSITION.y))  # 초승달

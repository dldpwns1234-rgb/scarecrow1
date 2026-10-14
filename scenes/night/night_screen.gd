extends Control
## 밤: 밭 (GDD 4절). 밤하늘, 아이소메트릭 밭(field_view), 농부(farmer_view), 역병 구름(cloud_view), 까마귀(crow_view), 생기 연출(rest_fx), 위쪽 글(night_hud).
## 마우스는 커서 자리로 구름을 옮기고, 손가락은 아무 데나 대고 끌면 끈 만큼 구름이 따라온다 (손가락이 구름을 가리지 않게, 방장 2026-10-14).
## 규칙은 Night 오토로드가 돌리고 이 화면은 입력과 그림만 맡는다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FieldView := preload("res://scenes/night/field_view.gd")
const CloudView := preload("res://scenes/night/cloud_view.gd")
const FarmerView := preload("res://scenes/night/farmer_view.gd")
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

var _field: FieldView
var _cloud: CloudView
var _farmers: FarmerView
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
	_farmers = FarmerView.new()
	_farmers.field = _field
	add_child(_farmers)
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
	_farmers.origin = origin
	_fx.target = _hud.rest_target()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not Night.active:
		return
	if event is InputEventScreenDrag:
		Night.set_cloud(Night.cloud + Iso.to_grid(Vector2.ZERO, event.relative))  # 끈 만큼만 (가장자리에서 막혀도 되돌아올 때 바로 따라온다)
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

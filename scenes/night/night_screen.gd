extends Control
## 밤: 밭 (GDD 4절). 밤하늘, 판(밭 field_view·농부 farmer_view·역병 구름 cloud_view·까마귀 crow_view·스킬과 작물 연출 skill_fx), 생기 연출(rest_fx), 위쪽 글(night_hud).
## 판은 격자 (0, 0) 꼭짓점을 원점으로 그리는 Node2D다. 밭이 넓어지면(밭 단계, 방장 2026-10-14) 밤마다 판의 배율을 줄여 화면에 맞춘다.
## 마우스는 커서 자리로 구름을 옮기고, 손가락은 아무 데나 대고 끌면 끈 만큼 구름이 따라온다 (손가락이 구름을 가리지 않게, 방장 2026-10-14).
## 규칙은 Night 오토로드가 돌리고 이 화면은 입력과 그림만 맡는다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const FieldView := preload("res://scenes/night/field_view.gd")
const CloudView := preload("res://scenes/night/cloud_view.gd")
const FarmerView := preload("res://scenes/night/farmer_view.gd")
const CrowView := preload("res://scenes/night/crow_view.gd")
const SkillFx := preload("res://scenes/night/skill_fx.gd")
const RestFx := preload("res://scenes/night/rest_fx.gd")
const NightHud := preload("res://scenes/night/night_hud.gd")
const NightFx := preload("res://scenes/night/fx/night_fx.gd")

const SKY_TOP := Color("0d1424")
const SKY_BOTTOM := Color("23304a")
const STAR_COLOR := Color(1.0, 0.96, 0.85, 0.8)
const STAR_COUNT: int = 70
const MOON := Color("f3ecd2")
const MOON_POSITION := Vector2(0.86, 0.2)  # 화면 비율
const MOON_RADIUS: float = 34.0
const FIELD_DROP: float = 34.0       # 밭 가운데를 화면 가운데보다 이만큼 아래에 (위쪽 글 자리)
const SIDE_DEPTH: float = 16.0
const MAX_FIELD_WIDTH: float = 960.0  # 밭이 이보다 넓어지면 판을 줄인다 (오른쪽 풍작 막대 자리)
const FIELD_ROOM_Y: float = 170.0     # 밭 높이로 쓰지 않는 세로 (위쪽 글·아래 여백)

var _board: Node2D
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
	_board = Node2D.new()
	add_child(_board)
	_field = FieldView.new()
	_board.add_child(_field)
	_farmers = FarmerView.new()
	_farmers.field = _field
	_board.add_child(_farmers)
	_cloud = CloudView.new()
	_board.add_child(_cloud)
	_crows = CrowView.new()
	_crows.field = _field
	_board.add_child(_crows)
	var skill_fx := SkillFx.new()
	skill_fx.field = _field
	_board.add_child(skill_fx)
	_fx = RestFx.new()
	_fx.field = _field
	add_child(_fx)
	var juice := NightFx.new()  # 풍작 콤보·알갱이·번쩍임 (윤슬 scenes/night/fx/). 위쪽 글을 가리지 않게 _hud 앞에
	juice.field = _field
	add_child(juice)
	_hud = NightHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	resized.connect(_layout)
	Night.night_started.connect(_layout)
	_layout()


## 판의 배율과 자리: 밭이 MAX_FIELD_WIDTH·남은 높이에 들어가게 줄이고, 가운데에서 FIELD_DROP만큼 아래에 둔다
func _layout() -> void:
	var field := Iso.field_size(Night.field_size) + Vector2(0.0, SIDE_DEPTH)
	var zoom := minf(1.0, minf(MAX_FIELD_WIDTH / field.x, maxf(size.y - FIELD_ROOM_Y, 1.0) / field.y))
	_board.scale = Vector2.ONE * zoom
	_board.position = Vector2(size.x * 0.5, (size.y - field.y * zoom) * 0.5 + FIELD_DROP)
	_fx.target = _hud.rest_target()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not Night.active:
		return
	if event is InputEventScreenDrag:  # 끈 만큼만 (가장자리에서 막혀도 되돌아올 때 바로 따라온다)
		Night.set_cloud(Night.cloud + Iso.to_grid(Vector2.ZERO, event.relative / _board.scale.x))
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != InputEvent.DEVICE_ID_EMULATION:
		_move_cloud(event.position)  # 터치가 흉내 낸 마우스 이벤트는 건너뛴다 (손가락 위치로 두 번 옮겨 떨린다)


func _move_cloud(screen: Vector2) -> void:
	Night.set_cloud(Iso.to_grid(Vector2.ZERO, _board.transform.affine_inverse() * screen))


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	for star in _stars:
		draw_circle(Vector2(star.x * size.x, star.y * size.y), 1.4, STAR_COLOR)
	draw_circle(MOON_POSITION * size, MOON_RADIUS, MOON)
	draw_circle(MOON_POSITION * size + Vector2(12.0, -8.0), MOON_RADIUS * 0.85, SKY_TOP.lerp(SKY_BOTTOM, MOON_POSITION.y))  # 초승달

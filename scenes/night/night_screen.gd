extends Control
## 밤: 밭 (GDD 4절). 아래부터 배경(하늘·달·언덕·들판 night_backdrop), 판(밭 field_view·공기 night_ambience·날씨 weather_view·농부 farmer_view·역병 구름 cloud_view·까마귀 crow_view·
## 스킬과 작물 연출 skill_fx·도깨비불 wisp_view), 생기 연출(rest_fx), 풍작 콤보(윤슬 fx/), 가장자리 어둡게, 위쪽 글(night_hud).
## 판은 격자 (0, 0) 꼭짓점을 원점으로 그리는 Node2D다. 밭이 넓어지면(밭 단계, 방장 2026-10-14) 밤마다 판의 배율을 줄여 화면에 맞춘다.
## 마우스는 커서 자리로 구름을 옮기고, 손가락은 대는 순간부터 구름이 손가락보다 TOUCH_LIFT 위에 떠서 따라온다 (방장 2026-10-15 #639: 끈 만큼 따라오게 해도
## 구름 위에 손가락을 대고 끌면 가려졌다). 손가락이 한 번 닿으면 밭을 TOUCH_RAISE만큼 올려 밭 맨 아래 칸을 칠 때도 손가락이 화면 안에 있게 한다.
## 규칙은 Night 오토로드가 돌리고 이 화면은 입력과 그림만 맡는다. 상수는 배치·연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const NightBackdrop := preload("res://scenes/night/night_backdrop.gd")
const FieldView := preload("res://scenes/night/field_view.gd")
const NightAmbience := preload("res://scenes/night/night_ambience.gd")
const CloudView := preload("res://scenes/night/cloud_view.gd")
const FarmerView := preload("res://scenes/night/farmer_view.gd")
const CrowView := preload("res://scenes/night/crow_view.gd")
const SkillFx := preload("res://scenes/night/skill_fx.gd")
const WispView := preload("res://scenes/night/wisp_view.gd")
const WeatherView := preload("res://scenes/night/weather_view.gd")
const RestFx := preload("res://scenes/night/rest_fx.gd")
const NightHud := preload("res://scenes/night/night_hud.gd")
const NightFx := preload("res://scenes/night/fx/night_fx.gd")

const FIELD_DROP: float = 34.0       # 밭 가운데를 화면 가운데보다 이만큼 아래에 (위쪽 글 자리)
const SIDE_DEPTH: float = 16.0
const MAX_FIELD_WIDTH: float = 960.0  # 밭이 이보다 넓어지면 판을 줄인다 (오른쪽 풍작 막대 자리)
const FIELD_ROOM_Y: float = 170.0     # 밭 높이로 쓰지 않는 세로 (위쪽 글·아래 여백)
const VIGNETTE := Color(0.0, 0.0, 0.03, 0.6)  # 화면 가장자리 어둡게 (가운데는 맑게)
const VIGNETTE_CLEAR: float = 0.55   # 가운데에서 이만큼(반지름 비율)까지는 맑다
const TOUCH_LIFT: float = 110.0      # 손가락보다 이만큼(화면 px) 위에 구름 (1280×720 기준 손끝 너비 1cm쯤 ≈ 90px)
const TOUCH_RAISE: float = 40.0      # 손가락으로 할 때 밭을 이만큼 올린다 (밭 아래 끝 + TOUCH_LIFT가 화면 안에)

var _board: Node2D
var _field: FieldView
var _cloud: CloudView
var _farmers: FarmerView
var _crows: CrowView
var _fx: RestFx
var _hud: NightHud
var _touch: bool = false  # 손가락이 한 번이라도 닿았다 (밭을 올리고 구름을 손가락 위에)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var backdrop := NightBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_board = Node2D.new()
	add_child(_board)
	_field = FieldView.new()
	_board.add_child(_field)
	_board.add_child(NightAmbience.new())
	_board.add_child(WeatherView.new())  # 달빛·빗줄기·얼음 조각 (구름·농부 뒤)
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
	_board.add_child(WispView.new())  # 구름 위에 (잡히는 순간이 보이게)
	_fx = RestFx.new()
	_fx.field = _field
	add_child(_fx)
	var juice := NightFx.new()  # 풍작 콤보·알갱이·번쩍임 (윤슬 scenes/night/fx/). 위쪽 글을 가리지 않게 _hud 앞에
	juice.field = _field
	add_child(juice)
	add_child(_vignette())
	_hud = NightHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	resized.connect(_layout)
	Night.night_started.connect(_layout)
	_layout()


## 화면 가장자리를 어둡게 덮는 둥근 그라데이션 (가운데 밭에 눈이 가게)
func _vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, VIGNETTE_CLEAR, 1.0])
	gradient.colors = PackedColorArray([Color(VIGNETTE, 0.0), Color(VIGNETTE, 0.0), VIGNETTE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 1.05)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## 판의 배율과 자리: 밭이 MAX_FIELD_WIDTH·남은 높이에 들어가게 줄이고, 가운데에서 FIELD_DROP만큼 아래에 둔다
func _layout() -> void:
	var field := Iso.field_size(Night.field_size) + Vector2(0.0, SIDE_DEPTH)
	var zoom := minf(1.0, minf(MAX_FIELD_WIDTH / field.x, maxf(size.y - FIELD_ROOM_Y, 1.0) / field.y))
	_board.scale = Vector2.ONE * zoom
	_board.position = Vector2(size.x * 0.5, (size.y - field.y * zoom) * 0.5 + FIELD_DROP - (TOUCH_RAISE if _touch else 0.0))
	_fx.target = _hud.rest_target()


func _gui_input(event: InputEvent) -> void:
	if not Night.active:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _touch:
			_touch = true
			_layout()
		if event is InputEventScreenDrag or (event as InputEventScreenTouch).pressed:
			_move_cloud(event.position - Vector2(0.0, TOUCH_LIFT))  # 구름은 늘 손가락 위
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != InputEvent.DEVICE_ID_EMULATION:
		_move_cloud(event.position)  # 터치가 흉내 낸 마우스 이벤트는 건너뛴다 (손가락 위치로 두 번 옮겨 떨린다)


func _move_cloud(screen: Vector2) -> void:
	Night.set_cloud(Iso.to_grid(Vector2.ZERO, _board.transform.affine_inverse() * screen))

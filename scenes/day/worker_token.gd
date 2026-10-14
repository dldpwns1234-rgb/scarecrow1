extends PanelContainer
## 아지트의 일꾼 토큰 하나 (hideout.gd): 그림(까마귀·지친 허수아비)과 이름. 끌어서 일자리 줄이나 쉬는 줄에 놓는다 (_get_drag_data).
## 맞는 일자리(두 몫)에서 일하면 그림 오른쪽 위에 금색 '×2'. 누르면 tapped를 내고, 아지트가 '고른 일꾼'으로 기억한 뒤 일자리 줄을 누르면 그 자리에 놓는다 (폰에서 끌기가 불편할 때). 상수는 배치용이다

signal tapped(worker: int)

const CROW := preload("res://assets/sprites/crow.svg")
const SCARECROW := preload("res://assets/sprites/neighbor.svg")
const SIZE := Vector2(68, 84)   # 칸이 넷까지 늘어도 한 줄에 들어가게
const PICTURE := Vector2(48, 48)
const NAME_FONT_SIZE: int = 16
const SELECTED_COLOR := Color("e9c46a")
const TAP_SLOP: float = 12.0  # 이만큼 안에서 떼면 누른 것 (끌기와 구분)
const BADGE_FONT_SIZE: int = 15
const BADGE_POSITION := Vector2(30, -10)  # 그림 안에서 (그림은 컨테이너가 아니라 자리가 그대로다)

var worker: int = -1
var _picture: TextureRect
var _name: Label
var _border: StyleBoxFlat
var _badge: Label
var _press_at := Vector2.INF


func _init(worker_index: int) -> void:
	worker = worker_index
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.custom_minimum_size = PICTURE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_picture)
	_badge = Label.new()  # 두 몫 표시
	_badge.text = "×2"
	_badge.position = BADGE_POSITION
	_badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	_badge.add_theme_color_override("font_color", SELECTED_COLOR)
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_picture.add_child(_badge)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_name)
	_border = StyleBoxFlat.new()  # 고른 일꾼 테두리 (연출용 색)
	_border.draw_center = false
	_border.border_color = SELECTED_COLOR
	_border.set_border_width_all(3)
	_border.set_corner_radius_all(10)


func _ready() -> void:
	_picture.texture = CROW if Workers.worker_kind(worker) == Balance.Worker.CROW else SCARECROW
	_name.text = Workers.worker_name(worker)


## 맞는 일자리에서 두 몫으로 일하는지
func set_double(on: bool) -> void:
	_badge.visible = on


func set_selected(on: bool) -> void:
	if on:
		add_theme_stylebox_override("panel", _border)
	else:
		remove_theme_stylebox_override("panel")


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_at = button.position
	elif _press_at != Vector2.INF and button.position.distance_to(_press_at) <= TAP_SLOP:
		_press_at = Vector2.INF
		tapped.emit(worker)
		accept_event()


## 끌기: 일꾼 번호를 넘기고 같은 그림을 손가락 아래에 띄운다
func _get_drag_data(_at_position: Vector2) -> Variant:
	_press_at = Vector2.INF
	var preview := TextureRect.new()
	preview.texture = _picture.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = PICTURE
	preview.position = -PICTURE * 0.5
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"worker": worker}

extends PanelContainer
## 아지트의 일자리 한 줄 (hideout.gd): 그림, 이름·효과(맞는 일꾼), 칸(일하는 일꾼 토큰과 빈 칸), 헛간 확장 버튼.
## 일꾼 토큰을 끌어 놓거나(_drop_data), 일꾼을 고른 뒤 줄을 누르면(pressed) 그 일자리에 놓는다. 표시는 hideout이 refresh()로 시킨다. 상수는 배치용이다

signal pressed(job: int)
signal token_tapped(worker: int)

const WorkerToken := preload("res://scenes/day/worker_token.gd")
const KoreanText := preload("res://scenes/ui/korean_text.gd")
const ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/ui/job_watch.svg"),
	preload("res://assets/sprites/ui/job_spores.svg"),
	preload("res://assets/sprites/ui/job_carry.svg"),
]
const GAP: int = 10
const ICON_SIZE := Vector2(52, 52)
const INFO_WIDTH: float = 220.0
const NOTE_CHARS: int = 14  # 설명 한 줄의 글자 수 (INFO_WIDTH와 글꼴 크기에 맞춤)
const EXPAND_SIZE := Vector2(110, 56)
const NOTE_COLOR := Color("b8bcc8")
const EMPTY_COLOR := Color(1, 1, 1, 0.06)
const NOTE_FONT_SIZE: int = 18

var job: int = 0
var _slots: HBoxContainer
var _expand: Button
var _tokens: Array[Control] = []


func _init(job_index: int) -> void:
	job = job_index
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, GAP)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICONS[job]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(INFO_WIDTH, 0.0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := Label.new()
	title.text = Balance.job_name(job)
	info.add_child(title)
	var note := Label.new()
	note.text = KoreanText.wrap(Balance.job_note(job), NOTE_CHARS) + _favored_text()
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	info.add_child(note)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", GAP / 2)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_slots)
	_expand = Button.new()
	_expand.custom_minimum_size = EXPAND_SIZE
	_expand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_expand.pressed.connect(func() -> void: Workers.expand(job))
	row.add_child(_expand)


func _favored_text() -> String:
	match int(Balance.JOBS[job]["favored"]):
		Balance.Worker.CROW:
			return "\n까마귀는 두 몫"
		Balance.Worker.SCARECROW:
			return "\n허수아비는 두 몫"
	return ""


## 칸을 다시 채운다: 일하는 일꾼 토큰, 그다음 빈 칸. selected는 고른 일꾼 (-1이면 없음)
func refresh(selected: int) -> void:
	for token in _tokens:
		token.queue_free()
	_tokens.clear()
	for w in Workers.worker_count():
		if Workers.worker_job(w) == job:
			var token := WorkerToken.new(w)
			token.tapped.connect(token_tapped.emit)
			_slots.add_child(token)
			token.set_selected(w == selected)
			_tokens.append(token)
	for i in Workers.slots_of(job) - Workers.used(job):
		var empty := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = EMPTY_COLOR
		style.set_corner_radius_all(10)
		empty.add_theme_stylebox_override("panel", style)
		empty.custom_minimum_size = WorkerToken.SIZE
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots.add_child(empty)
		_tokens.append(empty)
	var maxed := Workers.extra_slots[job] >= Balance.MAX_EXTRA_SLOTS
	_expand.text = "칸 최대" if maxed else "칸 +1\n생기 %s" % Num.format(Workers.expand_cost(job))
	_expand.disabled = not Workers.can_expand(job)
	_expand.theme_type_variation = "AccentButton" if not _expand.disabled else ""


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(job)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("worker")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Workers.assign(int((data as Dictionary)["worker"]), job)

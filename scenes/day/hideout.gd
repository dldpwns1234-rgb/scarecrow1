extends VBoxContainer
## 낮 화면 오른쪽 [아지트] 칸 (GDD 8절 M2, 대화방 #419): 일자리 세 줄(job_row.gd)과 아래의 쉬는 일꾼 줄.
## 일꾼 토큰(worker_token.gd)을 끌어 일자리 줄에 놓거나, 토큰을 눌러 고른 뒤 일자리 줄을 누른다. 쉬는 줄에 놓거나 고른 뒤 쉬는 줄을 누르면 쉬게 한다.
## Workers의 함수만 부르고 workers_changed를 받아 다시 그린다. 상수는 배치용이다

const RefreshGate := preload("res://scenes/ui/refresh_gate.gd")
const JobRow := preload("res://scenes/day/job_row.gd")
const WorkerToken := preload("res://scenes/day/worker_token.gd")
const KoreanText := preload("res://scenes/ui/korean_text.gd")

const GAP: int = 10
const ROW_HEIGHT: float = 112.0
const REST_HEIGHT: float = 112.0
const NOTE_COLOR := Color("b8bcc8")
const NOTE_FONT_SIZE: int = 18

var _gate: RefreshGate
var _rows: Array[JobRow] = []
var _rest: HBoxContainer
var _rest_panel: PanelContainer
var _hint: Label
var _selected: int = -1  # 고른 일꾼 (누르고 놓기)


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	for job in Balance.JOBS.size():
		var row := JobRow.new(job)
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		row.pressed.connect(_on_job_pressed)
		row.token_tapped.connect(_on_token_tapped)
		add_child(row)
		_rows.append(row)
	_rest_panel = PanelContainer.new()
	_rest_panel.custom_minimum_size = Vector2(0.0, REST_HEIGHT)
	_rest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_rest_panel.gui_input.connect(_on_rest_input)
	add_child(_rest_panel)
	var rest_row := HBoxContainer.new()
	rest_row.add_theme_constant_override("separation", GAP)
	rest_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest_panel.add_child(rest_row)
	var rest_title := Label.new()
	rest_title.text = "  쉬는 일꾼"
	rest_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_row.add_child(rest_title)
	_rest = HBoxContainer.new()
	_rest.add_theme_constant_override("separation", GAP / 2)
	_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_row.add_child(_rest)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	_hint.add_theme_color_override("font_color", NOTE_COLOR)
	add_child(_hint)
	_rest_panel.set_drag_forwarding(Callable(), _can_drop_rest, _drop_rest)
	Workers.workers_changed.connect(_on_changed)
	Game.vitality_changed.connect(_gate.queue.unbind(1))
	_refresh()


func _on_changed() -> void:
	_selected = -1
	_gate.queue()


func _refresh() -> void:
	for row in _rows:
		row.refresh(_selected)
	for child in _rest.get_children():
		child.queue_free()
	var resting := 0
	for w in Workers.worker_count():
		if Workers.worker_job(w) < 0:
			var token := WorkerToken.new(w)
			token.tapped.connect(_on_token_tapped)
			_rest.add_child(token)
			token.set_selected(w == _selected)
			resting += 1
	if _selected >= 0:
		var name := Workers.worker_name(_selected)
		_hint.text = "%s%s 놓을 일자리를 누른다 (쉬는 줄을 누르면 쉰다)" % [name, KoreanText.particle(name, "을", "를")]
	elif Workers.worker_count() == 0:
		_hint.text = "아직 일꾼이 없다"
	else:
		_hint.text = "일꾼을 끌어 일자리에 놓는다 (또는 누르고 일자리를 누른다)  ·  쉬는 일꾼 %d" % resting


func _on_token_tapped(worker: int) -> void:
	_selected = -1 if _selected == worker else worker
	_refresh()


func _on_job_pressed(job: int) -> void:
	if _selected < 0:
		return
	var worker := _selected
	_selected = -1
	if not Workers.assign(worker, job):
		_refresh()  # 칸이 다 찼다


func _on_rest_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and _selected >= 0:
		var worker := _selected
		_selected = -1
		Workers.unassign(worker)
		_refresh()


func _can_drop_rest(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("worker")


func _drop_rest(_at_position: Vector2, data: Variant) -> void:
	Workers.unassign(int((data as Dictionary)["worker"]))


## 칩을 보일지: 아지트가 열렸으면
static func is_open() -> bool:
	return Workers.is_open()


## 칩에 점: 쉬는 일꾼이 있고 빈 칸이 있으면
static func has_dot() -> bool:
	var free := 0
	for job in Balance.JOBS.size():
		free += Workers.slots_of(job) - Workers.used(job)
	return free > 0 and Workers.jobs.has(-1)

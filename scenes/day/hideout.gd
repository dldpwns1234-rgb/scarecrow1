extends VBoxContainer
## 낮 화면 오른쪽 [아지트] 칸 (GDD 8절 M2, 대화방 #419): 일자리 세 줄(job_row.gd)과 아래의 쉬는 일꾼 줄.
## 일꾼 토큰(worker_token.gd)을 끌어 일자리 줄에 놓거나, 토큰을 눌러 고른 뒤 일자리 줄을 누른다. 칸이 다 찼으면 그 자리의 일꾼과 바꾼다
## (방장 2026-10-14: 까악이를 놓은 뒤 허수아비를 같은 일자리에 놓으면 아무 반응이 없었다). 쉬는 줄에 놓거나 고른 뒤 쉬는 줄을 누르면 쉬게 한다.
## Workers의 함수만 부르고 workers_changed를 받아 다시 그린다. 생기가 바뀔 때는 확장 버튼만 고친다
## (생기 나르기로 생기가 매 프레임 늘면 토큰을 프레임마다 다시 만들어, 누른 토큰이 손을 떼기 전에 사라졌다. 별빛이 찾음 #451). 상수는 배치용이다

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
var _notice: String = ""  # 다음 그리기에 한 번 보일 알림 (자리를 바꿨다)


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	for job in Balance.JOBS.size():
		var row := JobRow.new(job)
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		row.pressed.connect(_on_job_pressed)
		row.token_tapped.connect(_on_token_tapped)
		row.dropped.connect(_place)
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
	Game.vitality_changed.connect(_on_vitality_changed.unbind(1))
	_refresh()


func _on_vitality_changed() -> void:
	if is_visible_in_tree():
		for row in _rows:
			row.refresh_expand()


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
	if not _notice.is_empty():
		_hint.text = _notice
		_notice = ""
	elif _selected >= 0:
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
	_place(worker, job)


## 일꾼을 일자리에 놓는다. 칸이 다 찼으면 그 자리의 첫 일꾼과 바꾼다 (그 일꾼은 옮겨 온 자리로, 쉬던 일꾼이면 쉬는 줄로)
func _place(worker: int, job: int) -> void:
	if Workers.worker_job(worker) == job or Workers.assign(worker, job):
		return
	var from := Workers.worker_job(worker)
	var occupant := -1
	for w in Workers.worker_count():
		if Workers.worker_job(w) == job:
			occupant = w
			break
	if occupant < 0:
		return
	Workers.unassign(occupant)
	Workers.assign(worker, job)
	if from >= 0:
		Workers.assign(occupant, from)
	var name := Workers.worker_name(occupant)
	_notice = "%s%s 자리를 바꿨다" % [name, KoreanText.particle(name, "과", "와")]
	_gate.queue()


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

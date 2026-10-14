extends "res://autoload/sfx/player.gd"
## 효과음 (GDD 9절). 게임 오토로드의 시그널만 받아 소리를 낸다. 게임 상태는 바꾸지 않는다. 재생·버스·웹 잠금은 sfx/player.gd(1부)에 있다.
## 밤: 구름이 칠 때 '쿵'(pulse), 작물이 시들 때 바스락과 동전(wither), 번질 때 보글(spread), 까마귀가 쫄 때 까악(crow), 밭 정복(clear).
## 낮·밤 전환: 밤이 시작될 때(night_start), 새벽이 올 때(dawn). 배경음도 낮(day)·밤(night) 곡으로 바꾼다. 업그레이드 구매(buy)는 버튼을 누른 그 프레임에 오른 레벨에만 낸다
## (불러오기·데이터 초기화가 레벨을 바꿀 때는 조용하다). 버튼은 트리에 들어올 때 pressed를 잇는다 (화면 파일을 고치지 않는다)

var _levels: Dictionary = {}   # 업그레이드 번호 → 마지막으로 본 레벨
var _button_frame: int = -1    # 마지막으로 버튼이 눌린 프레임
var _pending: bool = false     # 버튼 시그널보다 먼저 레벨이 올랐다 (같은 프레임이면 버튼이 오면 낸다)
var _pending_frame: int = -1
var _was_night: bool = false  # 새벽 소리는 밤에서 낮으로 넘어올 때만 (데이터 초기화의 낮은 조용하다)


func _ready() -> void:
	super()
	Night.pulsed.connect(play.bind("pulse"))
	Night.crop_withered.connect(func(_index: int, _rest: float) -> void: play("wither"))
	Night.crop_infected.connect(func(_index: int) -> void: play("spread"))
	Night.crow_pecked.connect(func(_index: int) -> void: play("crow"))
	Night.field_cleared.connect(func(_level: int) -> void: play("clear"))
	Game.phase_changed.connect(_on_phase_changed)
	Upgrades.upgrade_changed.connect(_on_upgrade_changed)
	get_tree().node_added.connect(_on_node_added)
	set_process_input(not unlocked)
	set_music_track("night" if Game.is_night() else "day")


## 웹이면 첫 누름이 소리를 연다 (브라우저의 자동 재생 막기). 열린 뒤에는 입력을 보지 않는다
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		unlock()
		set_process_input(false)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(note_button_press)


## 버튼이 눌렸다. 같은 프레임에 먼저 오른 레벨이 있으면 지금 소리를 낸다
func note_button_press() -> void:
	_button_frame = Engine.get_process_frames()
	if _pending and _pending_frame == _button_frame:
		play("buy")
	_pending = false


func _on_phase_changed(phase: int) -> void:
	var night := phase == Game.Phase.NIGHT
	set_music_track("night" if night else "day")
	if night:
		play("night_start")
	elif _was_night:
		play("dawn")
	_was_night = night


## 레벨이 오른 그 프레임에 버튼이 눌렸으면 구매 소리. 버튼 시그널이 나중에 오면 기다렸다가 낸다
func _on_upgrade_changed(index: int, level: int) -> void:
	var before: int = _levels.get(index, 0)
	_levels[index] = level
	if level <= before:
		return
	var frame := Engine.get_process_frames()
	if frame == _button_frame:
		play("buy")
	else:
		_pending = true
		_pending_frame = frame

extends "res://autoload/sfx/layers.gd"
## 효과음 (GDD 9절). 게임 오토로드의 시그널만 받아 소리를 낸다. 게임 상태는 바꾸지 않는다. 재생·버스·웹 잠금은 sfx/player.gd(1부), 밤 곡의 겹은 sfx/layers.gd(2부)에 있다.
## 밤: 구름이 칠 때 '쿵'(pulse), 작물이 시들 때 바스락과 동전(wither), 번질 때 보글(spread), 까마귀가 쫄 때 까악(crow), 밭 정복(clear).
## 낮·밤 전환: 밤이 시작될 때(night_start), 새벽이 올 때(dawn). 배경음도 낮(day)·밤(night)·수확일 밤(harvest) 곡으로 바꾼다. 겨울잠(sleep). 역병 폭풍의 큰 박자(storm), 농부가 약을 침(spray), 작물이 다시 자람(sprout), 밤 스킬 여덟(skill_*), 수박 터짐(burst)·해바라기 씨앗(seeds)·덩굴 번개(zap). 업그레이드 구매(buy)는 버튼을 누른 그 프레임에 오른 레벨에만 낸다
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
	Winter.slept.connect(func(_reward: float) -> void: play("sleep"))
	Night.storm_pulsed.connect(play.bind("storm"))
	Night.farmer_sprayed.connect(func(_index: int) -> void: play("spray"))
	Night.crop_regrown.connect(func(_index: int) -> void: play("sprout"))
	Night.skill_used.connect(_on_skill_used)
	for pair: Array in [["crop_burst", "burst"], ["seeds_flung", "seeds"], ["chain_struck", "zap"]]:
		if Night.has_signal(pair[0]):  # 수박 터짐·해바라기 씨앗·덩굴 번개 (인자는 쓰지 않는다)
			Night.connect(pair[0], func(_a: Variant = null, _b: Variant = null) -> void: play(pair[1]))
	Game.phase_changed.connect(_on_phase_changed)
	Night.field_level_changed.connect(func(_level: int, _best: int) -> void: refresh_layers())
	Upgrades.upgrade_changed.connect(_on_upgrade_changed)
	get_tree().node_added.connect(_on_node_added)
	set_process_input(not unlocked)
	set_music_track(_track())


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
	if night:
		refresh_layers(true)  # 곡이 페이드로 들어오니 겹은 바로 맞춘다
	set_music_track(_track())
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


## 지금 들려야 할 곡: 낮, 밤, 수확일 밤 (5의 배수 단계)
func _track() -> String:
	if not Game.is_night():
		return "day"
	return "harvest" if Balance.is_harvest(Night.field_level) else "night"


const SKILL_CUES: PackedStringArray = ["skill_storm", "skill_flock", "skill_sigh", "skill_tide", "skill_veil", "skill_reap", "skill_rain", "skill_chain"]  # Balance.Skill 순서


## 밤 스킬을 쓴 순간 (켜 둔 동안 역병 폭풍의 큰 박자는 storm이 따로 난다)
func _on_skill_used(skill: int) -> void:
	if skill >= 0 and skill < SKILL_CUES.size():
		play(SKILL_CUES[skill])

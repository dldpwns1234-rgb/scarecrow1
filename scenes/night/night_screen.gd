extends Control
## 밤: 밭 (GDD 4절). ★뼈대의 자리표다★ 별빛이 아이소메트릭 밭·역병 구름·작물·번짐으로 바꾼다.
## 지금은 남은 시간과 이번 밤 휴식을 보이고, 가운데 버튼을 누를 때마다 작물 하나가 시든 것으로 친다. 시간이 끝나면 Game.finish_night().
## 밤의 규칙: 작물이 시들면 Game.add_rest(), 시간이 끝나면 Game.finish_night(). 남은 시간은 밤 쪽이 잰다 (Game.night_seconds()가 길이)

const PLACEHOLDER_CROP_REST: float = 1.0  # 자리표 버튼 한 번의 휴식 (별빛의 작물 공식으로 바뀐다)
const MARGIN: int = 24
const STATUS_FONT_SIZE: int = 28

var _time_left: float = 0.0
var _status: Label


func _ready() -> void:
	var status_margin := MarginContainer.new()
	status_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side: String in ["margin_left", "margin_right", "margin_top"]:
		status_margin.add_theme_constant_override(side, MARGIN)
	add_child(status_margin)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	status_margin.add_child(_status)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var button := Button.new()
	button.text = "작물 하나 시들게 하기\n(자리표: 별빛이 밭으로 바꾼다)"
	button.custom_minimum_size = Vector2(480, 160)
	button.pressed.connect(Game.add_rest.bind(PLACEHOLDER_CROP_REST))
	center.add_child(button)
	Game.phase_changed.connect(_on_phase_changed.unbind(1))


func _on_phase_changed() -> void:
	if Game.is_night():
		_time_left = Game.night_seconds()


func _process(delta: float) -> void:
	if not Game.is_night():
		return
	_time_left -= minf(delta, Balance.MAX_DELTA)
	_status.text = "밤  ·  남은 시간 %d초  ·  이번 밤 휴식 +%s" % [ceili(maxf(_time_left, 0.0)), Num.format(Game.night_haul)]
	if _time_left <= 0.0:
		Game.finish_night()

extends GridContainer
## 밤 화면 왼쪽 아래의 스킬 버튼 (방장 2026-10-14). 연 스킬만 네 칸씩 줄지어 보이고, 누르면(또는 1~8) Night.use_skill. 지속형은 켜진 동안 금색 막이 줄고,
## 쿨타임이면 남은 초를 보인다. 줄이 늘면 위로 쌓인다 (아래 왼쪽 모서리 bottom_left는 night_hud가 정한다). 표시만 하고 규칙은 Night가 맡는다. 상수는 배치·연출용이다

const BUTTON_SIZE := Vector2(132, 52)
const FONT_SIZE: int = 16
const GAP: int = 8
const COLUMNS: int = 4
const ACTIVE_COLOR := Color(0.95, 0.8, 0.35, 0.45)
const COOLDOWN_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]

var bottom_left: Vector2 = Vector2.ZERO
var _buttons: Array[Button] = []
var _fills: Array[ColorRect] = []


func _ready() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", GAP)
	add_theme_constant_override("v_separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for skill in Balance.SKILLS.size():
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(Night.use_skill.bind(skill))
		var fill := ColorRect.new()  # 지속 막(금색) 또는 쿨타임 막(어두움). 버튼 아래에서부터 찬다
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(fill)
		add_child(button)
		_buttons.append(button)
		_fills.append(fill)


func _unhandled_key_input(event: InputEvent) -> void:
	if not Night.active or not event.is_pressed():
		return
	var index := KEYS.find((event as InputEventKey).keycode)
	if index >= 0 and index < _buttons.size():
		Night.use_skill(index)


func _process(_delta: float) -> void:
	if not Night.active or Night.cooldown_left.is_empty():
		visible = false
		return
	var shown := 0
	for skill in _buttons.size():
		var button := _buttons[skill]
		button.visible = Night.is_skill_unlocked(skill)
		if not button.visible:
			continue
		shown += 1
		var level := Night.skill_level(skill)
		var share := 0.0
		var color := COOLDOWN_COLOR
		var state := "%d 준비" % (skill + 1)
		if Night.is_skill_active(skill):
			share = Night.active_left[skill] / maxf(Balance.skill_duration(skill, level), 0.01)
			color = ACTIVE_COLOR
			state = "%.0f초 남음" % ceilf(Night.active_left[skill])
		elif Night.cooldown_left[skill] > 0.0:
			share = Night.cooldown_left[skill] / maxf(Balance.skill_cooldown(skill, level), 0.01)
			state = "%.0f초" % ceilf(Night.cooldown_left[skill])
		button.text = "%s\n%s" % [Balance.skill_name(skill), state]
		button.theme_type_variation = "AccentButton" if Night.can_use(skill) else ""
		var fill := _fills[skill]
		fill.color = color
		fill.size = Vector2(button.size.x, button.size.y * share)
		fill.position = Vector2(0.0, button.size.y * (1.0 - share))
	visible = shown > 0
	size = get_combined_minimum_size()  # 줄 수가 바뀌어도 아래 모서리를 지킨다 (버튼 높이는 글꼴·테마 여백으로 정해진다)
	position = bottom_left - Vector2(0.0, size.y)

extends Control
## 밤 화면 연출 층 (윤슬, 방장 2026-10-14 "가득 차는 뽕맛"): 생기 알갱이(sparks.gd), 스킬 이름(skill_callout.gd), 풍작 콤보(combo_meter.gd)를 얹고,
## 새 밤의 이름(night_title.gd)도 띄운다. 풍작이 터지면 밭 가운데에서 알갱이를 크게 터뜨리고, 화면을 하얗게 번쩍이고, 밤 화면을 잠깐 흔들고, '풍작!'을 띄운다.
## night_screen.gd가 field를 넘겨 붙인다. 입력은 받지 않는다. Night 시그널만 받는 연출이다. 상수는 연출용이다

const Sparks := preload("res://scenes/night/fx/sparks.gd")
const ComboMeter := preload("res://scenes/night/fx/combo_meter.gd")
const SkillCallout := preload("res://scenes/night/fx/skill_callout.gd")
const NightTitle := preload("res://scenes/night/fx/night_title.gd")

const FLASH_ALPHA: float = 0.28
const FLASH_SECONDS: float = 0.35
const SHAKE_PIXELS: float = 7.0
const SHAKE_STEPS: int = 6
const SHAKE_STEP_SECONDS: float = 0.035
const BANNER_COLOR := Color("f2d27a")
const BANNER_FONT_SIZE: int = 54
const BANNER_SECONDS: float = 0.9
const GROW_PER_LEVEL: float = 0.35  # 풍작이 거듭될수록 터짐·글이 커진다
const MAX_GROW: float = 2.4

var field: Node2D:
	set(value):
		field = value
		if _sparks != null:
			_sparks.field = value
var _sparks: Sparks
var _meter: ComboMeter
var _flash: ColorRect
var _banner: Label
var _shake: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks = Sparks.new()
	_sparks.field = field
	add_child(_sparks)
	add_child(SkillCallout.new())  # 저절로 터진 스킬 이름
	add_child(NightTitle.new())  # 밭 단계 팔레트가 바뀐 밤의 이름
	_meter = ComboMeter.new()
	_meter.burst.connect(_on_burst)
	add_child(_meter)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.97, 0.85, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	_banner.add_theme_color_override("font_color", BANNER_COLOR)
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)


func _on_burst(level: int) -> void:
	var center := size * 0.5
	if field != null and field.has_method("field_center"):
		center = field.call("field_center")
	var grow := minf(1.0 + GROW_PER_LEVEL * (level - 1), MAX_GROW)
	_sparks.burst_at(center, grow)
	_flash.color.a = minf(FLASH_ALPHA * sqrt(grow), 0.5)
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_SECONDS)
	_banner.text = "풍작!" if level == 1 else "풍작 ×%d!" % level
	_banner.modulate.a = 1.0
	var size_up := sqrt(grow)  # 글꼴 크기를 바꾸면 그 크기의 글자를 새로 그려 프레임이 튀어서, 크기는 scale로 키운다
	_banner.scale = Vector2.ONE * 1.3 * size_up
	_banner.pivot_offset = size * 0.5
	var banner := create_tween().set_parallel(true)
	banner.tween_property(_banner, "scale", Vector2.ONE * size_up, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner.tween_property(_banner, "modulate:a", 0.0, BANNER_SECONDS).set_delay(0.3)
	_shake_screen()


## 밤 화면(부모)을 몇 번 흔들고 제자리로
func _shake_screen() -> void:
	var screen := get_parent() as Control
	if screen == null:
		return
	if _shake != null:
		_shake.kill()
	var home := Vector2.ZERO
	_shake = create_tween()
	for i in SHAKE_STEPS:
		var fade := 1.0 - float(i) / SHAKE_STEPS
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * fade
		_shake.tween_property(screen, "position", home + offset, SHAKE_STEP_SECONDS)
	_shake.tween_property(screen, "position", home, SHAKE_STEP_SECONDS)

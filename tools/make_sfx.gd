extends "res://tools/sfx_recipes.gd"
## 효과음을 코드로 합성해 assets/sfx/<이름>.wav로 저장한다. Sfx 오토로드(autoload/sfx.gd)가 같은 이름으로 튼다.
##
##   godot --headless --path . --script tools/make_sfx.gd
##
## 소리는 여기와 tools/sfx_recipes.gd(2부: 늘어난 소리들의 레시피)의 함수와 상수가 원본이다. .wav는 손으로 고치지 않는다: 고친 뒤 다시 돌려서 함께 커밋하고 `--headless --import`.
## 합성 도구는 회귀 용사의 tools/synth.gd 그대로. 톤: 밤 밭의 조용한 장난 (낮은 쿵, 바스락, 보글, 까악, 풀벌레 같은 종). 자주 나는 소리일수록 작고 짧다

const OUT_DIR := "res://assets/sfx/"

## 이름 → [길이(초), 정규화 최고 진폭]
const SOUNDS: Dictionary = {
	"pulse": [0.35, 0.4],
	"wither": [0.3, 0.35],
	"spread": [0.35, 0.35],
	"crow": [0.45, 0.45],
	"night_start": [1.6, 0.55],
	"dawn": [1.4, 0.55],
	"clear": [1.5, 0.65],
	"buy": [0.18, 0.32],
	"sleep": [2.4, 0.55],
	"storm": [1.3, 0.6],
	"spray": [0.4, 0.3],
	"sprout": [0.3, 0.28],
	"skill_storm": [1.4, 0.6],
	"skill_flock": [0.9, 0.5],
	"skill_sigh": [1.2, 0.55],
	"skill_tide": [1.0, 0.5],
	"chain": [0.35, 0.4],
	"bumper": [1.6, 0.65],
	"skill_veil": [1.4, 0.5],
	"skill_reap": [0.8, 0.55],
	"skill_rain": [1.8, 0.45],
	"skill_chain": [0.7, 0.5],
	"burst": [0.5, 0.5],
	"seeds": [0.35, 0.3],
	"zap": [0.25, 0.3],
	"wisp": [1.0, 0.45],
	"wisp_catch": [1.2, 0.6],
	"wisp_fade": [0.9, 0.35],
	"feat": [1.2, 0.5],
}

const TAIL_FADE: float = 0.25  # 소리 길이의 마지막 이만큼을 서서히 줄인다 (잘린 꼬리가 딸깍하지 않게)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for sound_name: String in SOUNDS:
		var spec: Array = SOUNDS[sound_name]
		var s := Synth.new(spec[0], false, sound_name.hash())
		call("_" + sound_name, s)
		s.fade_tail(TAIL_FADE)
		s.normalize(spec[1])
		var err := s.save(OUT_DIR + sound_name + ".wav")
		if err != OK:
			failed += 1
			push_error("%s 저장 실패: %s" % [sound_name, error_string(err)])
	print("효과음 %d개 저장 (실패 %d)" % [SOUNDS.size() - failed, failed])
	quit(0 if failed == 0 else 1)


## 구름이 칠 때: 낮고 부드러운 쿵과 퍼지는 숨(포자). 0.5초마다 나니 아주 둥글게
func _pulse(s: Synth) -> void:
	s.tone(0.0, 0.18, 95.0, 60.0, 0.8, 0.004, 0.09)
	s.noise(0.0, 0.3, 0.3, 500.0, 180.0, 0.02, 0.12)


## 작물이 시든다: 마른 잎 바스락(내려가는 잡음)과 작은 동전 하나 (휴식이 나온다)
func _wither(s: Synth) -> void:
	s.noise(0.0, 0.2, 0.55, 2400.0, 700.0, 0.003, 0.06)
	s.bell(0.05, _n(14.0), 0.25, 0.05)


## 번진다: 보글 두 번 (올라가는 짧은 음)
func _spread(s: Synth) -> void:
	s.tone(0.0, 0.07, _n(-5.0), _n(2.0), 0.45, 0.003, 0.04, Synth.Wave.SOFT, 0.02)
	s.tone(0.1, 0.07, _n(-2.0), _n(5.0), 0.35, 0.003, 0.04, Synth.Wave.SOFT, 0.02)
	s.noise(0.0, 0.2, 0.15, 900.0, 600.0, 0.01, 0.05)


## 까마귀: 거친 '까악' 두 번 (잡음 섞인 내려가는 삼각파)
func _crow(s: Synth) -> void:
	for i in 2:
		var start := 0.18 * i
		s.tone(start, 0.12, 820.0, 560.0, 0.5, 0.005, 0.07, Synth.Wave.TRIANGLE, 0.03)
		s.noise(start, 0.12, 0.35, 2000.0, 1200.0, 0.005, 0.06)


## 밤이 시작된다: 낮게 깔리는 바람과 단조 두 음, 멀리 부엉이
func _night_start(s: Synth) -> void:
	s.noise(0.0, 1.4, 0.25, 300.0, 700.0, 0.4, 0.6)
	s.tone(0.0, 1.0, _n(-15.0), _n(-15.0), 0.3, 0.3, 0.8, Synth.Wave.SOFT, 0.4)
	s.tone(0.0, 1.0, _n(-12.0), _n(-12.0), 0.25, 0.3, 0.8, Synth.Wave.SOFT, 0.4)
	s.tone(0.55, 0.18, _n(-3.0), _n(-5.0), 0.3, 0.02, 0.12, Synth.Wave.SOFT, 0.1)
	s.tone(0.8, 0.3, _n(-5.0), _n(-7.0), 0.3, 0.02, 0.2, Synth.Wave.SOFT, 0.15)


## 새벽: 올라가는 맑은 종 셋과 따뜻한 받침 화음 (짚돌이가 쉰다)
func _dawn(s: Synth) -> void:
	var notes: PackedFloat32Array = [0.0, 4.0, 7.0]
	for i in notes.size():
		s.bell(0.15 * i, _n(notes[i]), 0.45, 0.35)
	s.tone(0.0, 1.0, _n(-12.0), _n(-12.0), 0.2, 0.4, 0.7, Synth.Wave.SOFT, 0.4)
	s.tone(0.0, 1.0, _n(-5.0), _n(-5.0), 0.15, 0.4, 0.7, Synth.Wave.SOFT, 0.4)


## 밭 정복: 짓궂은 팡파르 (내려갔다 올라가는 종과 북)
func _clear(s: Synth) -> void:
	var notes: PackedFloat32Array = [7.0, 3.0, 7.0, 12.0, 15.0]
	for i in notes.size():
		s.bell(0.1 * i, _n(notes[i]), 0.5 if i < 4 else 0.7, 0.18 if i < 4 else 0.45)
	s.tone(0.0, 0.4, 110.0, 70.0, 0.6, 0.003, 0.2)
	s.tone(0.4, 0.4, 110.0, 70.0, 0.5, 0.003, 0.2)


## 업그레이드 구매: 작은 동전 딸깍 (회귀 용사와 같다)
func _buy(s: Synth) -> void:
	s.bell(0.0, _n(16.0), 0.5, 0.04)
	s.bell(0.03, _n(21.0), 0.3, 0.035)

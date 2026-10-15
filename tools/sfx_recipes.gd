extends SceneTree
## 효과음 합성 2부: 밤이 깊어지며 늘어난 소리들의 레시피 (겨울잠·폭풍·농부·스킬 여덟·풍작 콤보·수박·해바라기·덩굴·도깨비불·업적).
## tools/make_sfx.gd가 상속해 같은 이름(_소리이름)으로 부른다. 200줄 규칙 때문에 나눴다. 게임에는 들어가지 않는다

const Synth := preload("res://tools/synth.gd")
const C5: float = 72.0  # MIDI 음 번호 기준


static func _n(offset: float) -> float:
	return Synth.midi(C5 + offset)


## 겨울잠: 잦아드는 눈바람, 위에서 아래로 천천히 내려앉는 종 넷, 따뜻하고 낮은 받침 화음 (짚돌이가 처음으로 잠든다)
func _sleep(s: Synth) -> void:
	s.noise(0.0, 2.2, 0.22, 900.0, 250.0, 0.3, 1.2)
	var notes: PackedFloat32Array = [12.0, 7.0, 4.0, 0.0]
	for i in notes.size():
		s.bell(0.25 * i, _n(notes[i]), 0.4, 0.45)
	s.tone(0.3, 1.6, _n(-24.0), _n(-24.0), 0.25, 0.5, 1.2, Synth.Wave.SOFT, 0.5)
	s.tone(0.3, 1.6, _n(-17.0), _n(-17.0), 0.18, 0.5, 1.2, Synth.Wave.SOFT, 0.5)


## 역병 폭풍 (10초마다 구름이 부풀어 크게 친다): 깊은 쿵, 부풀었다 가라앉는 바람, 낮은 단조 두 음
func _storm(s: Synth) -> void:
	s.tone(0.0, 0.5, 70.0, 38.0, 0.9, 0.005, 0.35)
	s.noise(0.0, 1.2, 0.5, 250.0, 1400.0, 0.08, 0.45)
	s.tone(0.05, 0.7, _n(-27.0), _n(-29.0), 0.3, 0.05, 0.5, Synth.Wave.SOFT, 0.3)
	s.tone(0.05, 0.7, _n(-21.0), _n(-23.0), 0.22, 0.05, 0.5, Synth.Wave.SOFT, 0.3)


## 농부가 약을 친다 (번짐을 씻어 낸다): 짧은 분무 '치익'. 자주 나니 작고 고음을 깎는다
func _spray(s: Synth) -> void:
	s.noise(0.0, 0.35, 0.6, 3200.0, 1800.0, 0.01, 0.12)
	s.noise(0.12, 0.2, 0.3, 2600.0, 1500.0, 0.01, 0.06)


## 작물이 다시 자란다 (다시 자라는 뿌리·농부가 다시 심음): 작게 올라가는 '뿅'과 잎 바스락
func _sprout(s: Synth) -> void:
	s.tone(0.0, 0.1, _n(-5.0), _n(4.0), 0.4, 0.004, 0.06, Synth.Wave.SOFT, 0.03)
	s.noise(0.02, 0.12, 0.15, 1800.0, 900.0, 0.005, 0.04)


## 스킬 '역병 폭풍'을 켠다: 부풀어 오르는 바람과 올라가는 낮은 두 음 (켜 둔 동안의 큰 박자는 storm)
func _skill_storm(s: Synth) -> void:
	s.noise(0.0, 1.3, 0.5, 300.0, 2000.0, 0.5, 2.0)
	s.tone(0.0, 1.0, _n(-29.0), _n(-24.0), 0.3, 0.3, 1.5, Synth.Wave.SOFT, 0.3)
	s.tone(0.0, 1.0, _n(-22.0), _n(-17.0), 0.22, 0.3, 1.5, Synth.Wave.SOFT, 0.3)


## 스킬 '까마귀 떼': 높이가 다른 까악 넷이 겹친다
func _skill_flock(s: Synth) -> void:
	var pitches: PackedFloat32Array = [1.0, 1.18, 0.9, 1.3]
	for i in pitches.size():
		var start := 0.13 * i
		s.tone(start, 0.11, 820.0 * pitches[i], 560.0 * pitches[i], 0.4, 0.005, 0.07, Synth.Wave.TRIANGLE, 0.03)
		s.noise(start, 0.11, 0.25, 2000.0, 1200.0, 0.005, 0.06)
	s.noise(0.0, 0.8, 0.2, 900.0, 600.0, 0.05, 0.3)  # 날갯짓 바람


## 스킬 '짚돌이의 한숨': 길게 내려가는 숨(걸러 낸 잡음)과 낮은 쿵, 맨 끝에 작은 종
func _skill_sigh(s: Synth) -> void:
	s.noise(0.0, 0.9, 0.55, 1400.0, 300.0, 0.15, 0.6)
	s.tone(0.55, 0.4, 90.0, 55.0, 0.8, 0.004, 0.25)
	s.bell(0.6, _n(-5.0), 0.2, 0.3)


## 스킬 '역병 파도': 빠르게 번지는 보글 여섯과 밀려가는 물결 소리
func _skill_tide(s: Synth) -> void:
	for i in 6:
		var start := 0.07 * i
		s.tone(start, 0.06, _n(-7.0 + i), _n(0.0 + i), 0.35, 0.003, 0.04, Synth.Wave.SOFT, 0.02)
	s.noise(0.0, 0.9, 0.35, 500.0, 1600.0, 0.2, 0.4)


## 풍작 콤보의 연쇄음: 짧고 맑은 퉁김. 재생할 때 5음 음계로 높이를 올린다 (scenes/night/fx/combo_meter.gd)
func _chain(s: Synth) -> void:
	s.pluck(0.0, _n(-5.0), 0.5, 0.07)
	s.bell(0.0, _n(7.0), 0.15, 0.06)


## 풍작 (콤보 막대가 꽉 참): 아래에서 위로 쏟아지는 종 화음, 휙 하는 바람, 낮은 쿵
func _bumper(s: Synth) -> void:
	s.tone(0.0, 0.4, 100.0, 55.0, 0.7, 0.004, 0.25)
	s.noise(0.0, 0.6, 0.35, 600.0, 2400.0, 0.02, 0.25)
	var notes: PackedFloat32Array = [0.0, 4.0, 7.0, 12.0, 16.0, 19.0]
	for i in notes.size():
		s.bell(0.05 * i, _n(notes[i]), 0.4, 0.5 if i == notes.size() - 1 else 0.25)


## 스킬 '어둠의 장막' (지키는 이들이 잠든다): 내려앉는 숨결과 느린 자장가 종 셋
func _skill_veil(s: Synth) -> void:
	s.noise(0.0, 1.2, 0.3, 1200.0, 250.0, 0.2, 0.8)
	var notes: PackedFloat32Array = [7.0, 4.0, 0.0]
	for i in notes.size():
		s.bell(0.2 + 0.3 * i, _n(notes[i] - 12.0), 0.3, 0.5)


## 스킬 '수확의 낫': 날카롭게 가르는 휙과 우수수 쓰러지는 바스락
func _skill_reap(s: Synth) -> void:
	s.noise(0.0, 0.25, 0.7, 6000.0, 1500.0, 0.005, 0.08)
	s.tone(0.0, 0.15, 1800.0, 600.0, 0.25, 0.002, 0.06, Synth.Wave.TRIANGLE, 0.03)
	for i in 5:
		s.noise(0.15 + 0.08 * i, 0.15, 0.25, 2200.0, 800.0, 0.003, 0.05)


## 스킬 '썩은 비': 후드득 듣다 쏴아 쏟아지는 빗소리
func _skill_rain(s: Synth) -> void:
	s.noise(0.0, 1.7, 0.35, 2500.0, 3500.0, 0.4, 2.0)
	for i in 14:
		s.noise(0.1 * i, 0.04, 0.4, 4000.0, 2500.0, 0.002, 0.015)


## 스킬 '연쇄 시듦': 덩굴을 타고 번지는 찌릿 셋
func _skill_chain(s: Synth) -> void:
	for i in 3:
		s.tone(0.12 * i, 0.1, _n(5.0 + 4.0 * i), _n(-2.0 + 4.0 * i), 0.3, 0.002, 0.06, Synth.Wave.TRIANGLE, 0.02)
		s.noise(0.12 * i, 0.08, 0.2, 5000.0, 3000.0, 0.002, 0.03)


## 수박이 터진다: 축축한 퍽과 튀는 물방울
func _burst(s: Synth) -> void:
	s.tone(0.0, 0.12, 180.0, 70.0, 0.7, 0.002, 0.07)
	s.noise(0.0, 0.3, 0.5, 1600.0, 500.0, 0.003, 0.09)
	for i in 3:
		s.tone(0.08 + 0.05 * i, 0.04, _n(8.0 + 3.0 * i), _n(12.0 + 3.0 * i), 0.2, 0.002, 0.025, Synth.Wave.SOFT, 0.02)


## 해바라기 씨앗이 튄다: 작은 톡톡 넷
func _seeds(s: Synth) -> void:
	for i in 4:
		s.tone(0.06 * i, 0.02, _n(19.0 - i), _n(17.0 - i), 0.35, 0.001, 0.015, Synth.Wave.TRIANGLE, 0.01)


## 덩굴 번개가 옆 작물을 친다: 짧은 찌릿 (자주 나니 아주 작게)
func _zap(s: Synth) -> void:
	s.tone(0.0, 0.08, _n(14.0), _n(4.0), 0.35, 0.002, 0.04, Synth.Wave.TRIANGLE, 0.02)
	s.noise(0.0, 0.1, 0.2, 6000.0, 3000.0, 0.002, 0.03)


## 도깨비불이 떴다: 공기 같은 쉿 소리 위로 살짝 어긋난 높은 종 둘이 떠오른다 (밭 어딘가에 뭔가 있다)
func _wisp(s: Synth) -> void:
	s.noise(0.0, 0.7, 0.12, 2800.0, 5200.0, 0.15, 0.35)
	s.bell(0.05, _n(12.0), 0.3, 0.6)
	s.bell(0.05, _n(12.0) * 1.006, 0.2, 0.6)
	s.bell(0.3, _n(19.0), 0.28, 0.5)


## 도깨비불을 잡았다: 위로 쏟아지는 반짝이 일곱과 휘익 올라가는 바람
func _wisp_catch(s: Synth) -> void:
	s.noise(0.0, 0.5, 0.2, 900.0, 4800.0, 0.05, 0.25)
	var notes: PackedFloat32Array = [0.0, 4.0, 7.0, 12.0, 16.0, 19.0, 24.0]
	for i in notes.size():
		s.bell(0.045 * i, _n(notes[i]), 0.32, 0.6 if i == notes.size() - 1 else 0.3)
	s.tone(0.0, 0.9, _n(-12.0), _n(-12.0), 0.15, 0.05, 0.5, Synth.Wave.SOFT, 0.4)


## 도깨비불이 꺼졌다: 내려앉는 작은 종 둘과 잦아드는 숨
func _wisp_fade(s: Synth) -> void:
	s.noise(0.0, 0.6, 0.08, 3000.0, 900.0, 0.05, 0.3)
	s.bell(0.0, _n(7.0), 0.2, 0.35)
	s.bell(0.18, _n(0.0), 0.16, 0.45)


## 업적이 열렸다: 종이 넘기는 사각 소리와 따뜻한 종 둘, 낮은 받침
func _feat(s: Synth) -> void:
	s.noise(0.0, 0.12, 0.15, 2400.0, 1200.0, 0.005, 0.05)
	s.bell(0.08, _n(7.0), 0.3, 0.45)
	s.bell(0.2, _n(12.0), 0.32, 0.7)
	s.tone(0.08, 0.8, _n(-5.0), _n(-5.0), 0.16, 0.03, 0.5, Synth.Wave.SOFT, 0.4)

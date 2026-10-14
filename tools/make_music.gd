extends SceneTree
## 배경음 두 곡을 코드로 합성해 assets/music/<이름>.wav로 저장한다. 8마디 반복 곡이고 꼬리를 앞으로 감아 이음매 없이 돈다.
##
##   godot --headless --path . --script tools/make_music.gd
##
## day: 낮의 헛간. 바장조 자장가 (F → Dm → Bb → C), 하프 분산화음과 피리 선율. 72 BPM, 26.7초. 지친 짚돌이가 꾸벅이는 따뜻한 오후
## night: 밤의 밭. 라 단조 (Dm → Bb → Gm → A, Dm → Eb → Cm → A), 레·라 지속음, 낮은 오카리나와 반딧불 같은 높은 종. 60 BPM, 32초.
##   밤에는 구름이 0.5초마다 '쿵' 하므로 박이 또렷한 소리(북·빠른 분산화음)를 넣지 않는다
## 회귀 용사의 make_music.gd를 옮겨 와 곡과 반딧불 종(bells)만 바꿨다. 곡은 여기 상수가 원본이다. .wav는 손으로 고치지 않는다.
## 고친 뒤 다시 돌리고 `--headless --import`, 함께 커밋한다. .wav.import의 edit/loop_mode는 2(앞으로 반복)여야 한다 (Sfx가 다시 확인한다)

const Synth := preload("res://tools/synth.gd")
const OUT_DIR := "res://assets/music/"
const BEATS_PER_BAR: int = 4
const PEAK: float = 0.6  # 곡 전체 최고 진폭. 음량은 Music 버스와 설정이 정한다

## 마디마다 [베이스 음, 화음 음들]. 음은 MIDI 번호
const DAY := {
	"bpm": 72.0,
	"bars": [
		[41, [53, 57, 60]], [38, [50, 53, 57]], [46, [53, 58, 62]], [48, [52, 55, 60]],
		[41, [53, 57, 60]], [45, [52, 57, 60]], [46, [53, 58, 62]], [48, [52, 55, 58]],
	],
	## [마디, 박, 음, 길이(박)]: 바장조의 느린 피리
	"melody": [
		[0, 0.0, 72, 1.5], [0, 1.5, 74, 0.5], [0, 2.0, 77, 1.0], [0, 3.0, 76, 1.0],
		[1, 0.0, 74, 2.0], [1, 2.0, 72, 1.0], [1, 3.0, 69, 1.0],
		[2, 0.0, 70, 1.0], [2, 1.0, 74, 1.0], [2, 2.0, 77, 1.5], [2, 3.5, 79, 0.5],
		[3, 0.0, 76, 2.0], [3, 2.0, 72, 2.0],
		[4, 0.0, 72, 1.0], [4, 1.0, 77, 1.0], [4, 2.0, 81, 2.0],
		[5, 0.0, 79, 1.5], [5, 1.5, 77, 0.5], [5, 2.0, 76, 2.0],
		[6, 0.0, 74, 1.0], [6, 1.0, 77, 1.0], [6, 2.0, 74, 1.0], [6, 3.0, 70, 1.0],
		[7, 0.0, 72, 3.0], [7, 3.0, 67, 1.0],
	],
	"melody_attack": 0.06, "melody_tau": 1.6,
	"arp_step": 0.5,                       # 하프는 8분음표
	"arp": [0, 1, 2, 3, 2, 1, 2, 1],       # 화음 음 번호 (3 = 맨 아래 음의 옥타브 위). 한 옥타브 올려 퉁긴다
	"arp_amp": 0.14, "arp_tau": 0.35,
	"melody_amp": 0.18, "pad_amp": 0.07, "bass_amp": 0.26,
	"drone": [], "bells": [],
	"echo": [0.4167, 0.28],
}

const NIGHT := {
	"bpm": 60.0,
	"bars": [
		[38, [50, 53, 57]], [34, [50, 53, 58]], [31, [50, 55, 58]], [33, [49, 52, 57]],
		[38, [50, 53, 57]], [39, [51, 55, 58]], [36, [48, 51, 55]], [33, [49, 52, 57]],
	],
	## 낮은 오카리나. 길게 끄는 음 몇 개뿐이다
	"melody": [
		[0, 0.0, 69, 3.0], [1, 0.0, 70, 2.0], [1, 2.0, 69, 2.0], [2, 0.0, 67, 4.0],
		[3, 0.0, 64, 3.0], [3, 3.0, 61, 1.0],
		[4, 0.0, 69, 2.0], [4, 2.0, 74, 2.0], [5, 0.0, 72, 3.0], [5, 3.0, 70, 1.0],
		[6, 0.0, 67, 4.0], [7, 0.0, 69, 4.0],
	],
	"melody_attack": 0.25, "melody_tau": 2.5,
	"arp_step": 2.0,                       # 두 박에 한 번 느리게 퉁긴다
	"arp": [0, 2],
	"arp_amp": 0.1, "arp_tau": 0.6,
	"melody_amp": 0.15, "pad_amp": 0.08, "bass_amp": 0.22,
	"drone": [38, 45],                     # 레·라(D·A) 지속음
	## [마디, 박, 음]: 반딧불처럼 드문드문 반짝이는 높은 종 (화음 안의 음)
	"bells": [
		[0, 2.5, 86], [1, 1.5, 82], [2, 3.0, 86], [3, 1.0, 85],
		[4, 2.5, 89], [5, 0.5, 87], [6, 2.0, 84], [7, 3.5, 88],
	],
	"echo": [0.5, 0.35],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for entry: Array in [["day", DAY], ["night", NIGHT]]:
		var err := _render(entry[1]).save(OUT_DIR + str(entry[0]) + ".wav")
		if err != OK:
			failed += 1
			push_error("%s 저장 실패: %s" % [entry[0], error_string(err)])
	print("배경음 2곡 저장 (실패 %d)" % failed)
	quit(0 if failed == 0 else 1)


func _render(song: Dictionary) -> Synth:
	var beat: float = 60.0 / float(song["bpm"])
	var bar_length := beat * BEATS_PER_BAR
	var bars: Array = song["bars"]
	var s := Synth.new(bar_length * bars.size(), true, 11)
	for b in bars.size():
		var start := b * bar_length
		var chord: Array = bars[b][1]
		_bar_bed(s, song, start, bar_length, float(bars[b][0]), chord)
		_arpeggio(s, song, start, beat, chord)
	for note: Array in song["melody"]:
		var at := float(note[0]) * bar_length + float(note[1]) * beat
		var f := Synth.midi(float(note[2]))
		s.tone(at, float(note[3]) * beat * 0.9, f, f, float(song["melody_amp"]),
			float(song["melody_attack"]), float(song["melody_tau"]), Synth.Wave.SOFT, 0.25)
	for bell: Array in song["bells"]:
		s.bell(float(bell[0]) * bar_length + float(bell[1]) * beat, Synth.midi(float(bell[2])), 0.09, 0.5)
	var echo: Array = song["echo"]
	s.echo(float(echo[0]), float(echo[1]))
	s.normalize(PEAK)
	return s


## 마디의 바탕: 화음 패드(느린 attack, 다음 마디로 겹쳐 사라짐), 베이스(첫 박과 셋째 박), 지속음
func _bar_bed(s: Synth, song: Dictionary, start: float, bar_length: float, bass: float, chord: Array) -> void:
	for note: Variant in chord:
		var f := Synth.midi(float(note))
		s.tone(start, bar_length, f, f, float(song["pad_amp"]), 0.6, 4.0, Synth.Wave.SOFT, 0.8)
	var bf := Synth.midi(bass)
	var half := bar_length * 0.5
	s.tone(start, half, bf, bf, float(song["bass_amp"]), 0.02, 1.2, Synth.Wave.SOFT, 0.3)
	s.tone(start + half, half, bf, bf, float(song["bass_amp"]) * 0.7, 0.02, 1.2, Synth.Wave.SOFT, 0.3)
	for note: Variant in song["drone"]:
		var df := Synth.midi(float(note))
		s.tone(start, bar_length, df, df, 0.08, 0.5, 20.0, Synth.Wave.SOFT, 0.5)


## 하프 분산화음: 화음 음을 한 옥타브 올려 정해진 순서로 퉁긴다 (3은 맨 아래 음의 옥타브 위)
func _arpeggio(s: Synth, song: Dictionary, start: float, beat: float, chord: Array) -> void:
	var step := float(song["arp_step"]) * beat
	var pattern: Array = song["arp"]
	for i in pattern.size():
		var index := int(pattern[i])
		var note := float(chord[index % chord.size()]) + 12.0 * (2.0 if index >= chord.size() else 1.0)
		s.pluck(start + i * step, Synth.midi(note), float(song["arp_amp"]), float(song["arp_tau"]))

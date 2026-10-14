extends Node
## 소리 설정: 효과음과 배경음의 켬/끔과 음량 (회귀 용사에서 옮겨 오며 시트 높이는 뺐다).
## 게임 수치가 아니라 듣는 방식이라 데이터 초기화에서만 기본값으로 돌아간다. 저장은 Save가 "prefs" 절로 한다. 소리는 Sfx가 버스에 건다

signal audio_changed()  # 효과음·배경음의 켬/끔이나 음량이 바뀌었다

const DEFAULT_SFX_VOLUME: float = 0.8    # 0~1. 버스 음량은 Sfx가 dB로 바꾼다
const DEFAULT_MUSIC_VOLUME: float = 0.5  # 배경음은 효과음보다 낮게 시작한다

var sfx_on: bool = true
var music_on: bool = true
var sfx_volume: float = DEFAULT_SFX_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME


func set_sfx_on(on: bool) -> void:
	if on != sfx_on:
		sfx_on = on
		audio_changed.emit()


func set_music_on(on: bool) -> void:
	if on != music_on:
		music_on = on
		audio_changed.emit()


func reset() -> void:
	_set_audio(true, true, DEFAULT_SFX_VOLUME, DEFAULT_MUSIC_VOLUME)


func to_dict() -> Dictionary:
	return {"sfx_on": sfx_on, "music_on": music_on, "sfx_volume": sfx_volume, "music_volume": music_volume}


## 없는 필드는 기본값으로
func from_dict(data: Dictionary) -> void:
	_set_audio(bool(data.get("sfx_on", true)), bool(data.get("music_on", true)),
		float(data.get("sfx_volume", DEFAULT_SFX_VOLUME)), float(data.get("music_volume", DEFAULT_MUSIC_VOLUME)))


## 소리 설정 넷을 한꺼번에 바꾸고 바뀌었으면 한 번만 알린다. 음량은 0~1로 자른다
func _set_audio(new_sfx_on: bool, new_music_on: bool, new_sfx_volume: float, new_music_volume: float) -> void:
	var before := [sfx_on, music_on, sfx_volume, music_volume]
	sfx_on = new_sfx_on
	music_on = new_music_on
	sfx_volume = clampf(new_sfx_volume, 0.0, 1.0)
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	if before != [sfx_on, music_on, sfx_volume, music_volume]:
		audio_changed.emit()

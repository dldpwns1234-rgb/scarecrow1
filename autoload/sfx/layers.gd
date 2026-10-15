extends "res://autoload/sfx/player.gd"
## Sfx 2부: 밤 곡의 겹 (방장 #587, 장르 조사 제안 3: Gnorp처럼 밤이 깊어질수록 음악이 한 겹씩 쌓인다). autoload/sfx.gd가 상속한다.
## 밤 곡(assets/music/night_layers.tres, AudioStreamSynchronized)은 겹 다섯을 늘 함께 틀고, 여기서 겹마다 음량만 올리고 내린다:
## 바탕은 늘, 하프·오카리나·높은 현은 그 밤의 밭 단계가 LAYER_FROM에 닿으면, 반딧불 종은 풍작이 터지면(swell) 잠깐 부푼다.
## 낮 곡·수확일 곡은 겹이 없다. 겹 파일은 tools/make_music.gd가 만든다. 상수는 연출용이다

const NIGHT_LAYERS: PackedStringArray = ["bed", "harp", "melody", "counter", "bells"]  # tools/make_music.gd와 같은 순서
const LAYER_FROM := {"harp": 2, "melody": 8, "counter": 25}  # 그 밤의 밭 단계가 이만큼이면 들어오는 겹 (25 = 감독관이 오는 단계)
const LAYER_FADE: float = 2.0      # 겹이 들어오고 나가는 초
const SWELL_SECONDS: float = 6.0   # 풍작이 터지면 반딧불 종이 이만큼 울린다

var _layer_on: Dictionary = {}     # 겹 이름 → 켜져 있는지
var _layer_tweens: Dictionary = {} # 겹 이름 → 음량 Tween
var _swell_left: float = 0.0


func _ready() -> void:
	super()
	var night := _night_stream()
	for i in (night.stream_count if night != null else 0):
		var wav := night.get_sync_stream(i) as AudioStreamWAV
		if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			push_warning("밤 곡 겹 %s의 반복이 꺼져 있다 (.wav.import의 edit/loop_mode=2)" % NIGHT_LAYERS[i])
	refresh_layers(true)


func _process(delta: float) -> void:
	if _swell_left <= 0.0:
		return
	_swell_left -= minf(delta, Balance.MAX_DELTA)
	if _swell_left <= 0.0:
		refresh_layers()


## 지금 들려야 할 겹인가: 바탕은 늘, 반딧불 종은 풍작 뒤 잠깐, 나머지는 그 밤의 밭 단계로
func layer_wanted(layer: String) -> bool:
	match layer:
		"bed":
			return true
		"bells":
			return _swell_left > 0.0
	return Night.field_level >= int(LAYER_FROM.get(layer, 0))


func is_layer_on(layer: String) -> bool:
	return bool(_layer_on.get(layer, false))


## 풍작이 터졌다 (밤 연출 층의 combo_meter가 부른다): 반딧불 종 겹을 잠깐 부풀린다
func swell() -> void:
	_swell_left = SWELL_SECONDS
	refresh_layers()


## 겹 음량을 지금 들려야 할 대로 맞춘다. instant면 페이드 없이 (밤이 시작될 때: 곡이 페이드로 들어오니 겹은 바로)
func refresh_layers(instant: bool = false) -> void:
	var night := _night_stream()
	for i in NIGHT_LAYERS.size():
		var layer := NIGHT_LAYERS[i]
		var on := layer_wanted(layer)
		if _layer_on.has(layer) and _layer_on[layer] == on and not instant:
			continue
		_layer_on[layer] = on
		if night == null or i >= night.stream_count:
			continue
		var target := 0.0 if on else SILENT_DB
		if _layer_tweens.has(layer):
			(_layer_tweens[layer] as Tween).kill()
			_layer_tweens.erase(layer)
		if instant or _silent:
			night.set_sync_stream_volume(i, target)
			continue
		var tween := create_tween()
		tween.tween_method(func(db: float) -> void: night.set_sync_stream_volume(i, db), night.get_sync_stream_volume(i), target, LAYER_FADE)
		_layer_tweens[layer] = tween


func _night_stream() -> AudioStreamSynchronized:
	var player: AudioStreamPlayer = _music.get("night")
	return player.stream as AudioStreamSynchronized if player != null else null

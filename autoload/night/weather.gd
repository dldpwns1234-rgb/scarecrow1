extends "res://autoload/night/wisp.gd"
## Night 3.6부: 철마다 날씨 (방장 2026-10-15 #587, 장르 조사 제안 7). 밤이 시작할 때 겨울잠 횟수로 이번 철의 날씨를 정한다 (Balance.season_weathers).
## 엔딩(약속된 휴식 백 년) 뒤엔 날씨가 둘씩 겹친다 (제안 10).
## 서리: 심을 때 작물 일부가 얼어붙는다 (체력·생기가 오르고, 시들면 깨지며 옆 작물을 친다). 장마: 비가 오락가락하고, 오는 동안 구름이 커지고 더 잘 번진다.
## 보름달: 달빛 원이 밭 위를 천천히 떠돌고, 그 안에서 시든 작물의 생기가 오른다. 날씨 rng는 밭 rng와 따로 굴려 밭 배치·번짐은 날씨가 없을 때와 같다.
## 화면은 weathers·has_weather()·frost·raining·moon·moon_radius()를 읽어 그린다

signal rain_changed(raining: bool)
signal frost_shattered(index: int)  # 얼어붙은 작물이 시들며 깨졌다

var weathers: int = 0                      # 이번 밤의 날씨 묶음 (1 << Balance.Weather). 첫 철은 0
var frost: PackedByteArray = PackedByteArray()  # 얼어붙은 작물이면 1
var raining: bool = false
var moon: Vector2 = Vector2.ZERO           # 달빛 원 가운데 (격자 단위)
var _weather_rng := RandomNumberGenerator.new()
var _rain_clock: float = 0.0
var _moon_heading: float = 0.0


func has_weather(weather: int) -> bool:
	return (weathers & (1 << weather)) != 0


func is_frosted(index: int) -> bool:
	return index < frost.size() and frost[index] == 1


func moon_radius() -> float:
	return Balance.moon_radius(field_size)


func in_moonlight(index: int) -> bool:
	return has_weather(Balance.Weather.MOON) and cell_position(index).distance_to(moon) <= moon_radius()


## 밤이 시작할 때 밭을 심기 전에 (서리는 심을 때 정한다). begin이 밭 rng의 시드를 정한 뒤 부른다
func _choose_weather() -> void:
	weathers = Balance.season_weathers(Winter.sleeps, Game.promised_rest_seconds() >= Balance.HUNDRED_YEARS_SECONDS)
	_weather_rng.seed = rng.seed + 104729
	raining = false
	_rain_clock = _weather_rng.randf() * Balance.RAIN_EVERY
	var size := float(Balance.field_size(field_level))
	moon = Vector2(_weather_rng.randf_range(0.3, 0.7), _weather_rng.randf_range(0.3, 0.7)) * size
	_moon_heading = _weather_rng.randf() * TAU


func _clear_field() -> void:
	super()
	frost = PackedByteArray()
	frost.resize(cell_count())


## 서리: 심은 작물 일부가 얼어붙는다 (체력 ×2.5)
func _grow(index: int) -> void:
	super(index)
	if index >= frost.size():
		return
	frost[index] = 0
	if has_weather(Balance.Weather.FROST) and _weather_rng.randf() < Balance.FROST_SHARE:
		frost[index] = 1
		max_hp[index] *= Balance.FROST_HP
		hp[index] = max_hp[index]


## 칸 몫에 서리 ×4, 달빛 ×3
func _cell_factor(index: int, rotten: bool) -> float:
	var factor := super(index, rotten)
	if is_frosted(index):
		factor *= Balance.FROST_VITALITY
	if in_moonlight(index):
		factor *= Balance.MOON_VITALITY
	return factor


## 장마: 비 오는 동안 구름이 커진다
func cloud_radius() -> float:
	return super() * (Balance.RAIN_RADIUS if raining else 1.0)


## 장마: 비 오는 동안 옆 칸으로 더 번진다 (번지는 곰팡이와 따로 굴린다)
func _spread_from(index: int) -> void:
	super(index)
	if not raining:
		return
	for n in neighbors(index):
		if is_alive(n) and infected[n] == 0 and _weather_rng.randf() < Balance.RAIN_SPREAD:
			_infect(n)


## 서리: 얼어붙은 작물이 시들면 깨지며 옆 작물에 구름 피해 1초 몫
func _after_wither(index: int) -> void:
	super(index)
	if not is_frosted(index):
		return
	frost[index] = 0
	frost_shattered.emit(index)
	var hit := cloud_dps() * Balance.FROST_SHATTER_SECONDS
	for n in neighbors(index):
		if is_alive(n):
			_damage(n, hit * guard(n))


func _tick_weather(dt: float) -> void:
	if has_weather(Balance.Weather.MONSOON):
		_rain_clock += dt
		var wet := fmod(_rain_clock, Balance.RAIN_EVERY) < Balance.RAIN_SECONDS
		if wet != raining:
			raining = wet
			rain_changed.emit(raining)
	if has_weather(Balance.Weather.MOON):
		_moon_heading += _weather_rng.randf_range(-1.0, 1.0) * Balance.MOON_TURN * dt
		var next := moon + Vector2.from_angle(_moon_heading) * Balance.MOON_SPEED * dt
		var size := float(field_size)
		var inside := Vector2(clampf(next.x, 0.5, size - 0.5), clampf(next.y, 0.5, size - 0.5))
		if inside != next:
			_moon_heading = (Vector2.ONE * size * 0.5 - inside).angle()
		moon = inside

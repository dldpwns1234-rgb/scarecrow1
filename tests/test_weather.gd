extends "res://tests/test_case.gd"
## 철마다 날씨 (방장 2026-10-15 #587, 장르 조사 제안 7): 겨울잠 횟수로 정하는 날씨, 서리(얼어붙은 작물·깨짐), 장마(비·구름 반경·번짐), 보름달(떠도는 달빛),
## 날씨가 밭 배치를 바꾸지 않기


func run() -> void:
	_test_order()
	_test_frost()
	_test_monsoon()
	_test_moon()
	_test_beyond()
	_test_field_rng()
	_fresh()
	Winter.reset()
	Night.reset()


func _start(sleeps: int, level: int = 8, seed: int = 6) -> void:
	_fresh()
	Winter.reset()
	Night.reset()
	Winter.sleeps = sleeps
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = level
	Night.field_level = level
	Game.start_night()
	Night.begin(seed)
	Night.time_left = 999.0
	Night.set_cloud(Vector2(-99.0, -99.0))


func _test_order() -> void:
	_equal(Balance.season_weathers(0), 0, "첫 철엔 날씨가 없다")
	_equal(Balance.season_weathers(1), 1 << Balance.Weather.FROST, "둘째 철 서리")
	_equal(Balance.season_weathers(2), 1 << Balance.Weather.MONSOON, "셋째 철 장마")
	_equal(Balance.season_weathers(3), 1 << Balance.Weather.MOON, "넷째 철 보름달")
	_equal(Balance.season_weathers(4), 1 << Balance.Weather.FROST, "그 뒤로는 차례로 돈다")
	_equal(Balance.season_weathers(3, true), (1 << Balance.Weather.MOON) | (1 << Balance.Weather.FROST), "엔딩 뒤엔 다음 날씨가 겹친다")
	_equal(Balance.season_weathers(0, true), 0, "엔딩 뒤라도 첫 철엔 없다")
	_equal(Balance.weathers_name(Balance.season_weathers(1, true)), "서리·장마", "겹친 이름")
	_equal(Balance.weathers_banner(Balance.season_weathers(1, true)).begins_with("도전 겨울"), true, "겹치면 도전 겨울")
	_equal(Balance.weathers_banner(Balance.season_weathers(2)).begins_with("장마: "), true, "하나면 설명")
	_close(Balance.moon_radius(4), Balance.MOON_MIN_RADIUS, "좁은 밭에서도 달빛은 1.5칸")
	_close(Balance.moon_radius(20), 20.0 * Balance.MOON_RADIUS_SHARE, "넓은 밭이면 달빛도 넓다")


func _test_frost() -> void:
	_start(1)
	_equal(Night.weathers, 1 << Balance.Weather.FROST, "겨울잠 한 번 뒤엔 서리")
	var frosted := 0
	var cell := -1
	for i in Night.cell_count():
		if Night.is_frosted(i):
			frosted += 1
			cell = i if cell < 0 else cell
	var share := float(frosted) / float(Night.first_planted)
	_equal(share > 0.04 and share < 0.25, true, "심긴 작물의 열에 하나쯤 얼어붙는다 (%.2f)" % share)
	var normal := Balance.crop_hp(Night.kinds[cell], Night.field_level, 0) * Balance.harvest_hp(Night.field_level)
	_close(Night.max_hp[cell], normal * Balance.FROST_HP, "얼어붙은 작물은 체력 ×2.5")
	var frozen := Night.crop_vitality(cell)
	Night.frost[cell] = 0
	_close(frozen, Night.crop_vitality(cell) * Balance.FROST_VITALITY, "얼어붙은 작물은 생기 ×4")
	Night.frost[cell] = 1
	var neighbor := -1
	for n in Night.neighbors(cell):
		if Night.is_alive(n) and not Night.is_frosted(n) and Night.max_hp[n] > Night.cloud_dps() * 2.0:
			neighbor = n
	if neighbor < 0:
		Night.kinds[Night.neighbors(cell)[0]] = Balance.Crop.PUMPKIN
		neighbor = Night.neighbors(cell)[0]
		Night.max_hp[neighbor] = 1e9
	Night.hp[neighbor] = Night.max_hp[neighbor]
	var shattered := [-1]
	Night.frost_shattered.connect(func(index: int) -> void: shattered[0] = index, CONNECT_ONE_SHOT)
	Night._damage(cell, 1e30)
	_equal(shattered[0], cell, "시들면 깨진다")
	_close(Night.max_hp[neighbor] - Night.hp[neighbor], Night.cloud_dps() * Balance.FROST_SHATTER_SECONDS * Night.guard(neighbor), "깨지며 옆 작물에 구름 피해 1초 몫")
	_equal(Night.is_frosted(cell), false, "깨지면 서리가 사라진다")
	Night.stop()


func _test_monsoon() -> void:
	_start(2)
	_equal(Night.weathers, 1 << Balance.Weather.MONSOON, "겨울잠 두 번 뒤엔 장마")
	var dry := Night.cloud_radius()
	var rained := false
	for step in int(Balance.RAIN_EVERY / 0.05) + 2:
		Night.tick(0.05)
		if Night.raining:
			rained = true
			break
	_equal(rained, true, "장마엔 비가 온다")
	_close(Night.cloud_radius(), dry * Balance.RAIN_RADIUS, "비 오는 동안 구름 ×1.3")
	var infected := 0
	for i in Night.cell_count():
		if Night.is_alive(i) and Night.infected[i] == 0:
			Night._spread_from(i)
	for i in Night.cell_count():
		infected += Night.infected[i]
	_equal(infected > 0, true, "비 오는 동안엔 번지는 곰팡이 없이도 번진다")
	Night.stop()


func _test_moon() -> void:
	_start(3)
	_equal(Night.weathers, 1 << Balance.Weather.MOON, "겨울잠 세 번 뒤엔 보름달")
	var cell := 0
	while not Night.is_alive(cell):
		cell += 1
	Night.moon = Night.cell_position(cell)
	var lit := Night.crop_vitality(cell)
	Night.moon = Night.cell_position(cell) + Vector2.ONE * 99.0
	_close(lit, Night.crop_vitality(cell) * Balance.MOON_VITALITY, "달빛 안에서 시든 작물은 생기 ×3")
	Night.moon = Vector2.ONE * Night.field_size * 0.5
	var start := Night.moon
	var size := float(Night.field_size)
	var inside := true
	for step in 400:
		Night.tick(0.05)
		inside = inside and Night.moon.x >= 0.5 and Night.moon.y >= 0.5 and Night.moon.x <= size - 0.5 and Night.moon.y <= size - 0.5
	_equal(Night.moon != start and inside, true, "달빛은 밭 안을 떠돈다")
	Night.stop()


func _test_beyond() -> void:
	_start(2)
	_equal(Night.weathers, 1 << Balance.Weather.MONSOON, "엔딩 전엔 하나")
	Night.stop()
	_fresh()
	Winter.reset()
	Night.reset()
	Winter.sleeps = 2
	Game.offered = 1e19  # 약속된 휴식 백 년 너머
	Game.start_night()
	_equal(Night.has_weather(Balance.Weather.MONSOON) and Night.has_weather(Balance.Weather.MOON), true, "엔딩 뒤 셋째 철: 장마에 보름달이 겹친다")
	Night.stop()


## 날씨는 밭 rng를 굴리지 않는다 (철 작물이 섞이면 배치는 달라지니, 같은 칸을 심을 때 밭 rng가 같은 만큼 굴렀는지 본다)
func _test_field_rng() -> void:
	_start(1, 8, 11)
	var before := Night.rng.state
	Night._choose_weather()
	_equal(Night.rng.state == before, true, "날씨를 고를 때 밭 rng는 그대로")
	var cell := 0
	Night.rng.state = before
	Night._grow(cell)
	var frosty := Night.rng.state
	Night.weathers = 0
	Night.rng.state = before
	Night._grow(cell)
	_equal(Night.rng.state == frosty, true, "서리를 굴려도 밭 rng는 같은 만큼 구른다")
	Night.stop()

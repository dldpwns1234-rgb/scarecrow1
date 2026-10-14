extends "res://tests/test_case.gd"
## 밤 한 판 (GDD 4절): 심기, 구름 박자 피해, 시듦과 휴식, 번짐과 번짐 피해, 까마귀, 밭 정복과 다음 단계, 시간 끝, 밭 단계 저장

const SEED: int = 7


func run() -> void:
	_test_plant()
	_test_cloud()
	_test_spread()
	_test_crow()
	_test_clear()
	_test_timeout()
	_test_save()
	_fresh()
	Night.reset()


## 밤을 시작하고 고정 시드로 다시 심는다 (Game이 밤으로 바뀌면 Night가 무작위로 한 번 심는다)
func _start(seed: int = SEED) -> void:
	_fresh()
	Night.reset()
	Game.start_night()
	Night.begin(seed)


func _first_crop(kind: int = -1) -> int:
	for i in Night.cell_count():
		if Night.is_alive(i) and (kind < 0 or Night.kinds[i] == kind):
			return i
	return -1


func _test_plant() -> void:
	_start()
	_equal(Night.active, true, "밤이 시작되면 밭이 돈다")
	_equal(Night.crops_total > Night.cell_count() * 0.75 and Night.crops_total <= Night.cell_count(), true, "칸의 90% 안팎에 작물")
	var wheat := _first_crop(Balance.Crop.WHEAT)
	_close(Night.max_hp[wheat], Balance.crop_hp(Balance.Crop.WHEAT, 1), "밀 체력")
	_close(Balance.crop_hp(Balance.Crop.WHEAT, 3), 10.0 * 2.4 * 2.4, "밭 단계마다 체력 ×2.4")
	_close(Balance.crop_rest(Balance.Crop.PUMPKIN, 2), 50.0, "밭 단계마다 휴식 ×2")
	var weights := Balance.crop_weights(5)
	_close(weights[0] + weights[1] + weights[2], 1.0, "작물 비율의 합은 1")
	_close(Balance.crop_weights(100)[0], Balance.MIN_WHEAT_WEIGHT, "밀은 바닥 아래로 내려가지 않는다")
	_close(Night.time_left, Game.night_seconds(), "밤 길이")


func _test_cloud() -> void:
	_start()
	var target := _first_crop(Balance.Crop.PUMPKIN)
	Night.set_cloud(Night.cell_position(target))
	_equal(Night.in_cloud(target), true, "구름 가운데 칸")
	var far := -1
	for i in Night.cell_count():
		if Night.is_alive(i) and Night.cell_position(i).distance_to(Night.cloud) > 3.0:
			far = i
			break
	Night.tick(Balance.CLOUD_TICK)
	_close(Night.hp[target], Night.max_hp[target] - Night.cloud_dps() * Balance.CLOUD_TICK, "한 박자에 구름 피해 × 박자")
	_close(Night.hp[far], Night.max_hp[far], "구름 밖은 그대로")
	Night.set_cloud(Vector2(-5.0, 99.0))
	_equal(Night.cloud, Vector2(0.0, float(Balance.FIELD_SIZE)), "구름은 밭 밖으로 나가지 않는다")
	# 시듦: 휴식 = 작물 휴식 × 썩은 냄새 배율
	Upgrades.levels[Balance.Upgrade.ROT_VALUE] = 5
	var wheat := _first_crop(Balance.Crop.WHEAT)
	var before := Game.rest
	Night._damage(wheat, 1e9)
	_equal(Night.is_alive(wheat), false, "체력이 다하면 시든다")
	_close(Game.rest - before, Balance.crop_rest(Balance.Crop.WHEAT, 1) * 2.0, "휴식 × (1 + 0.2 × 5)")
	_close(Game.night_haul, Game.rest - before, "이번 밤 휴식에 든다")
	_equal(Night.withered, 1, "시든 수")


func _test_spread() -> void:
	_start()
	_close(Balance.spread_chance(0), 0.0, "번지는 곰팡이 없으면 번지지 않는다")
	_close(Balance.spread_chance(4), 0.2, "레벨당 +5%p")
	var source := -1
	for i in Night.cell_count():
		var full := Night.is_alive(i)
		for n in Night.neighbors(i):
			full = full and Night.is_alive(n)
		if full and Night.neighbors(i).size() == 4:
			source = i
			break
	Night._damage(source, 1e9)
	var none := 0
	for n in Night.neighbors(source):
		none += Night.infected[n]
	_equal(none, 0, "레벨 0이면 아무도 안 걸린다")
	_start()
	Upgrades.levels[Balance.Upgrade.SPREAD] = 20  # 확률 1 (상한)
	Night._damage(source, 1e9)
	var all := 0
	for n in Night.neighbors(source):
		all += Night.infected[n]
	_equal(all, 4, "확률 1이면 이웃 넷이 다 걸린다")
	var sick := Night.neighbors(source)[0]
	Night.set_cloud(Vector2(-99.0, -99.0))  # 구름 피해 없이 번짐 피해만
	var before := Night.hp[sick]
	Night.tick(Balance.CLOUD_TICK)
	_close(before - Night.hp[sick], Balance.rot_dps(Night.cloud_dps(), 0) * Balance.CLOUD_TICK, "번진 작물은 구름 밖에서도 썩는다")
	_close(Balance.rot_dps(10.0, 2), 10.0 * (0.3 + 0.3), "썩은 뿌리 레벨당 구름의 15%")


func _test_crow() -> void:
	_close(Balance.crow_damage(4.0, 2), 4.0 * 2.0 * 2.0, "부리 2레벨: 구름 피해 × 2 × (1 + 1)")
	_fresh()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.CROW] = 2
	Game.start_night()
	Night.begin(SEED)
	Night.set_cloud(Vector2(-99.0, -99.0))
	var pecks: Array[int] = []
	var on_peck := func(index: int) -> void: pecks.append(index)
	Night.crow_pecked.connect(on_peck)
	Night.tick(Balance.CROW_INTERVAL)
	Night.crow_pecked.disconnect(on_peck)
	_equal(pecks.size(), 2, "까마귀 두 마리가 한 간격에 한 번씩")
	var hurt := 0
	for i in Night.cell_count():
		if Night.kinds[i] != Night.EMPTY and Night.hp[i] < Night.max_hp[i]:
			hurt += 1
	_equal(hurt >= 1, true, "쪼인 작물은 체력이 준다")


func _test_clear() -> void:
	_start()
	var levels: Array[int] = []
	var on_clear := func(level: int) -> void: levels.append(level)
	Night.field_cleared.connect(on_clear)
	var need := ceili(Night.crops_total * Balance.CLEAR_RATIO)
	var killed := 0
	for i in Night.cell_count():
		if killed >= need - 1:
			break
		if Night.is_alive(i):
			Night._damage(i, 1e9)
			killed += 1
	_equal(Night.active, true, "정복 직전까지는 밤이 이어진다")
	Night._damage(_first_crop(), 1e9)
	Night.field_cleared.disconnect(on_clear)
	_equal(levels, [1], "90%가 시들면 정복")
	_equal(Night.alive_count(), 0, "남은 작물이 저절로 쓰러진다")
	_equal(Night.active, false, "밤이 끝난다")
	_equal(Game.is_night(), false, "낮으로 돌아온다")
	_equal(Night.best_level, 2, "다음 단계가 열린다")
	_equal(Night.field_level, 2, "다음 밤은 새 단계")
	_equal(Night.choose_level(1), true, "낮은 단계를 고를 수 있다")
	_equal(Night.choose_level(3), false, "안 열린 단계는 못 고른다")


func _test_timeout() -> void:
	_start()
	var length := Night.time_left
	Night.tick(length - 0.1)
	_equal(Game.is_night(), true, "시간이 남았으면 밤")
	Night.tick(0.2)
	_equal(Game.is_night(), false, "시간이 다 되면 낮")
	_equal(Game.nights, 1, "밤 수")
	_close(Game.last_haul, Game.night_haul, "이번 밤 기록")


func _test_save() -> void:
	_fresh()
	Night.reset()
	Night.best_level = 4
	Night.field_level = 3
	var data := Save.to_dict()
	_equal(data.has("night"), true, "저장에 밤(밭 단계)이 든다")
	Save.reset_data()
	_equal(Night.best_level, 1, "초기화")
	Save.from_dict(data)
	_equal(Night.best_level, 4, "열린 단계 복원")
	_equal(Night.field_level, 3, "고른 단계 복원")
	Night.from_dict({"best_level": 2, "field_level": 9})
	_equal(Night.field_level, 2, "고른 단계는 열린 단계를 넘지 않는다")
	Night.from_dict({})
	_equal(Night.best_level, 1, "옛 저장은 1단계")

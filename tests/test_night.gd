extends "res://tests/test_case.gd"
## 밤 한 판 (GDD 4절): 심기(듬성듬성·빽빽한 밭), 구름 박자 피해(어스름), 시듦과 생기(비옥한 어둠·탐스러운 호박·썩은 냄새), 번짐과 번짐 피해,
## 까마귀(검은 깃털), 다시 자라기, 밭 정복과 다음 단계, 시간 끝, 밭 단계 저장

const SEED: int = 7


func run() -> void:
	_test_plant()
	_test_cloud()
	_test_spread()
	_test_crow()
	_test_regrow()
	_test_clear()
	_test_timeout()
	_test_save()
	_fresh()
	Night.reset()


## 밤을 시작하고 고정 시드로 다시 심는다 (Game이 밤으로 바뀌면 Night가 무작위로 한 번 심는다). full이면 빽빽한 밭 최대로 칸을 다 채운다
func _start(full: bool = true, seed: int = SEED) -> void:
	_fresh()
	Night.reset()
	if full:
		Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Game.start_night()
	Night.begin(seed)


func _first_crop(kind: int = -1) -> int:
	for i in Night.cell_count():
		if Night.is_alive(i) and (kind < 0 or Night.kinds[i] == kind):
			return i
	return -1


func _test_plant() -> void:
	_start(false)
	_equal(Night.active, true, "밤이 시작되면 밭이 돈다")
	_equal(Night.crops_total > Night.cell_count() * 0.15 and Night.crops_total < Night.cell_count() * 0.45, true, "첫 밭은 듬성듬성 (30% 안팎)")
	_equal(Night.first_planted, Night.crops_total, "처음 심은 수")
	_close(Balance.field_fill(10), 1.0, "빽빽한 밭 10레벨이면 꽉 찬다")
	_close(Night.time_left, Game.night_seconds(), "밤 길이")
	_close(Game.night_seconds(), 20.0, "첫 밤은 20초")
	_start()
	_equal(Night.crops_total, Night.cell_count(), "빽빽한 밭 최대면 모든 칸에")
	var wheat := _first_crop(Balance.Crop.WHEAT)
	_close(Night.max_hp[wheat], Balance.crop_hp(Balance.Crop.WHEAT, 1), "밀 체력")
	_close(Balance.crop_hp(Balance.Crop.WHEAT, 3), 10.0 * pow(Balance.FIELD_HP_GROWTH, 2), "밭 단계마다 체력 ×성장")
	_close(Balance.crop_vitality(Balance.Crop.PUMPKIN, 2), 25.0 * Balance.FIELD_VITALITY_GROWTH, "밭 단계마다 생기 ×성장")
	_close(Balance.crop_hp(Balance.Crop.WHEAT, 1, 2), 10.0 * 1.6 * 1.6, "비옥한 어둠: 체력 ×1.6씩")
	_close(Balance.crop_vitality(Balance.Crop.WHEAT, 1, 2), 4.0, "비옥한 어둠: 생기 ×2씩")
	_close(Balance.crop_vitality(Balance.Crop.PUMPKIN, 1, 0, 4), 25.0 * 2.0, "탐스러운 호박: 호박 생기 +25%씩")
	_close(Balance.crop_vitality(Balance.Crop.WHEAT, 1, 0, 4), 1.0, "탐스러운 호박은 밀에는 안 듣는다")
	for level: int in [1, 5, 100]:
		var weights := Balance.crop_weights(level, 10)
		_close(weights[0] + weights[1] + weights[2], 1.0, "작물 비율의 합은 1 (단계 %d)" % level)
	_close(Balance.crop_weights(1, 5)[2], 0.05 + 0.1, "탐스러운 호박 5레벨: 호박 +10%p")
	_equal(Balance.crop_weights(100, 10)[0] >= Balance.MIN_WHEAT_WEIGHT * 0.5, true, "밀은 바닥 아래로 내려가지 않는다")


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
	_close(Balance.cloud_tick(4), Balance.CLOUD_TICK * 0.8, "어스름 4레벨: 박자 20% 빨리")
	Night.set_cloud(Vector2(-5.0, 99.0))
	_equal(Night.cloud, Vector2(0.0, float(Balance.FIELD_SIZE)), "구름은 밭 밖으로 나가지 않는다")
	# 시듦: 생기 = 작물 생기 × 썩은 냄새 배율
	Upgrades.levels[Balance.Upgrade.ROT_VALUE] = 5
	var wheat := _first_crop(Balance.Crop.WHEAT)
	var before := Game.vitality
	Night._damage(wheat, 1e9)
	_equal(Night.is_alive(wheat), false, "체력이 다하면 시든다")
	_close(Game.vitality - before, Balance.crop_vitality(Balance.Crop.WHEAT, 1) * 2.0, "생기 × (1 + 0.2 × 5)")
	_close(Game.night_haul, Game.vitality - before, "이번 밤 생기에 든다")
	_close(Game.offered, Game.vitality, "바친 생기 합에도 든다")
	_equal(Night.withered, 1, "시든 수")


func _test_spread() -> void:
	_start()
	_close(Balance.spread_chance(0), 0.0, "번지는 곰팡이 없으면 번지지 않는다")
	_close(Balance.spread_chance(4), 0.2, "레벨당 +5%p")
	var source := 5 * Balance.FIELD_SIZE + 5  # 꽉 찬 밭의 가운데 칸 (이웃 넷)
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
	_start()
	Upgrades.levels[Balance.Upgrade.CROW] = 2
	Upgrades.levels[Balance.Upgrade.FEATHER] = 20  # 확률 1
	Night.begin(SEED)
	Night.set_cloud(Vector2(-99.0, -99.0))
	var pecks: Array[int] = []
	var on_peck := func(index: int) -> void: pecks.append(index)
	Night.crow_pecked.connect(on_peck)
	Night.tick(Balance.CROW_INTERVAL)
	Night.crow_pecked.disconnect(on_peck)
	_equal(pecks.size(), 2, "까마귀 두 마리가 한 간격에 한 번씩")
	_equal(Night.hp[pecks[0]] < Night.max_hp[pecks[0]], true, "쪼인 작물은 체력이 준다")
	_equal(Night.infected[pecks[0]] == 1 or not Night.is_alive(pecks[0]), true, "검은 깃털: 쪼인 작물이 번짐에 걸린다")


func _test_regrow() -> void:
	_close(Balance.regrow_delay(0), 0.0, "다시 자라는 뿌리가 없으면 안 자란다")
	_close(Balance.regrow_delay(3), 12.0 * 0.85 * 0.85, "레벨마다 15% 빨리")
	_start()
	var cell := _first_crop()
	Night._damage(cell, 1e9)
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(Balance.REGROW_BASE_DELAY + 0.1)
	_equal(Night.is_alive(cell), false, "0레벨이면 시든 칸은 그대로")
	_start()
	Upgrades.levels[Balance.Upgrade.REGROW] = 1
	Night._damage(cell, 1e9)
	Night.set_cloud(Vector2(-99.0, -99.0))
	var grown: Array[int] = []
	var on_grow := func(index: int) -> void: grown.append(index)
	Night.crop_regrown.connect(on_grow)
	Night.tick(Balance.REGROW_BASE_DELAY - 0.1)
	_equal(grown.is_empty(), true, "시간이 차기 전엔 안 자란다")
	Night.tick(0.2)
	Night.crop_regrown.disconnect(on_grow)
	_equal(grown, [cell], "시든 칸에 새 작물")
	_equal(Night.is_alive(cell), true, "다시 산다")
	_close(Night.hp[cell], Night.max_hp[cell], "체력 가득")
	_equal(Night.alive_count(), Night.first_planted, "남은 작물 수에 다시 든다")


func _test_clear() -> void:
	_start()
	var levels: Array[int] = []
	var on_clear := func(level: int) -> void: levels.append(level)
	Night.field_cleared.connect(on_clear)
	var floor_left := floori(Night.first_planted * (1.0 - Balance.CLEAR_RATIO))
	for i in Night.cell_count():
		if Night.alive_count() <= floor_left + 1:
			break
		if Night.is_alive(i):
			Night._damage(i, 1e9)
	_equal(Night.active, true, "정복 직전까지는 밤이 이어진다")
	Night._damage(_first_crop(), 1e9)
	Night.field_cleared.disconnect(on_clear)
	_equal(levels, [1], "남은 작물이 10% 아래면 정복")
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
	_start()
	Night.stop()
	_equal(Game.is_night() or Night.active, false, "새벽까지 쉬기: 밤을 일찍 끝낸다")


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

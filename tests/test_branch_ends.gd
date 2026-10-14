extends "res://tests/test_case.gd"
## 어둠의 나무 갈래 끝 칸: 역병 폭풍(큰 박자), 새벽 전 몰아치기(밤 끝 피해 ×2), 풍요의 저주(수확일 생기), 까마귀 왕(값진 작물부터)


func run() -> void:
	_test_storm()
	_test_frenzy()
	_test_bounty_and_king()
	_fresh()
	Night.reset()


func _start(level: int = 1) -> void:
	_fresh()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = level
	Night.field_level = level
	Game.start_night()
	Night.begin(4)


func _test_storm() -> void:
	_close(Balance.storm_interval(0), 0.0, "없으면 폭풍이 없다")
	_close(Balance.storm_interval(3), 8.0, "3레벨: 8초마다")
	_start()
	Upgrades.levels[Balance.Upgrade.STORM] = 1
	Night.begin(4)
	var storms: Array[int] = []
	var on_storm := func() -> void: storms.append(1)
	Night.storm_pulsed.connect(on_storm)
	var center := 5 * Balance.FIELD_SIZE + 5
	Night.set_cloud(Night.cell_position(center))
	var far := 5 * Balance.FIELD_SIZE + 7  # 두 칸 옆: 보통 반경(1) 밖, 폭풍 반경(2) 안
	Night.tick(9.9)
	_equal(storms.size(), 0, "10초 전에는 폭풍이 없다")
	_close(Night.hp[far], Night.max_hp[far], "보통 박자는 두 칸 옆에 안 닿는다")
	Night.tick(0.6)
	Night.storm_pulsed.disconnect(on_storm)
	_equal(storms.size(), 1, "10초마다 폭풍 박자")
	_equal(Night.hp[far] < Night.max_hp[far], true, "폭풍 박자는 반경 두 배")


func _test_frenzy() -> void:
	_close(Balance.frenzy_seconds(0), 0.0, "없으면 몰아치기가 없다")
	_close(Balance.frenzy_seconds(3), 7.0, "3레벨: 밤 끝 7초")
	_start()
	Upgrades.levels[Balance.Upgrade.FRENZY] = 1
	_equal(Night.in_frenzy(), false, "밤 처음에는 아니다")
	var pumpkin := -1
	for i in Night.cell_count():
		if Night.kinds[i] == Balance.Crop.PUMPKIN:
			pumpkin = i
			break
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(Night.time_left - 4.9)
	_equal(Night.in_frenzy(), true, "밤 끝 5초 동안 몰아친다")
	Night.set_cloud(Night.cell_position(pumpkin))
	var before := Night.hp[pumpkin]
	Night.tick(Balance.CLOUD_TICK)
	_close(before - Night.hp[pumpkin], Night.cloud_dps() * Balance.CLOUD_TICK * Balance.FRENZY_MULTIPLIER, "몰아치는 동안 구름 피해 ×2")
	Night.stop()


func _test_bounty_and_king() -> void:
	_close(Balance.harvest_vitality(10, 2), Balance.HARVEST_VITALITY * 2.0, "풍요의 저주 2레벨: 수확일 생기 +100%")
	_close(Balance.harvest_vitality(11, 2), 1.0, "보통 밤엔 안 든다")
	_start()
	Upgrades.levels[Balance.Upgrade.CROW] = 1
	Upgrades.levels[Balance.Upgrade.CROW_KING] = 1
	Upgrades.levels[Balance.Upgrade.GOLDEN] = 10
	Night.begin(4)
	var best := -1
	for i in Night.cell_count():
		if Night.is_alive(i) and (best < 0 or Night.crop_vitality(i) > Night.crop_vitality(best)):
			best = i
	var pecks: Array[int] = []
	var on_peck := func(index: int) -> void: pecks.append(index)
	Night.crow_pecked.connect(on_peck)
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(Balance.CROW_INTERVAL)
	Night.crow_pecked.disconnect(on_peck)
	_equal(pecks, [best], "까마귀 왕: 생기가 가장 많은 작물을 쫀다")
	_equal(Night.kinds[best] == Balance.Crop.GOLDEN or Night.kinds[best] == Balance.Crop.PUMPKIN, true, "황금 이삭이나 호박")
	Night.stop()

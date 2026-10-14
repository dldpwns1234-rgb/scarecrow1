extends "res://tests/test_case.gd"
## 겨울잠 (회귀): 조건, 꿈 조각 공식, 내려놓음과 남는 것, 새 철의 시작(겨울 씨앗·기억하는 손), 꿈의 상점 비용과 효과, 저장


func run() -> void:
	_test_reward()
	_test_perform()
	_test_shop()
	_test_save()
	_clean()


func _clean() -> void:
	_fresh()
	Night.reset()
	Winter.reset()


func _test_reward() -> void:
	_equal(Balance.can_winter(11), false, "11단계는 아직")
	_equal(Balance.can_winter(12), true, "12단계부터 겨울잠")
	_close(Balance.shard_reward(11), 0.0, "조건 미달은 0")
	_close(Balance.shard_reward(12), Balance.SHARD_BASE, "12단계에 기본 조각")
	_close(Balance.shard_reward(20), floor(Balance.SHARD_BASE * pow(Balance.SHARD_GROWTH, 8)), "20단계")
	_equal(is_inf(Balance.shard_reward(Balance.MAX_FIELD_LEVEL)), false, "꿈 조각은 무한대가 되지 않는다")


func _test_perform() -> void:
	_clean()
	_equal(Winter.can_sleep(), false, "1단계에서는 못 잔다")
	Night.best_level = 15
	Night.field_level = 14
	Game.vitality = 5000.0
	Game.offered = 9000.0
	Game.nights = 30
	Upgrades.levels[Balance.Upgrade.TOXIN] = 20
	Upgrades.levels[Balance.Upgrade.RADIUS] = 7
	Game.start_night()
	_equal(Winter.can_sleep(), false, "밤에는 못 잔다")
	Game.finish_night()
	Game.vitality = 5000.0
	var reward := Winter.shard_reward()
	_equal(Winter.perform(), true, "겨울잠")
	_close(Winter.shards, reward, "꿈 조각을 받는다")
	_equal(Winter.sleeps, 1, "겨울잠 횟수")
	_close(Game.vitality, 0.0, "생기는 내려놓는다")
	_close(Game.offered, 9000.0 + 0.0, "바친 생기 합(약속된 휴식)은 남는다")
	_equal(Game.nights, 31, "밤 수는 남는다")
	_equal(Upgrades.level(Balance.Upgrade.TOXIN), 0, "어둠의 나무는 비운다")
	_equal(Upgrades.level(Balance.Upgrade.RADIUS), 0, "기억하는 손이 없으면 0")
	_equal(Night.best_level, 1, "밭은 1단계부터")
	_equal(Night.field_level, 1, "고른 단계도")
	# 겨울 씨앗·기억하는 손을 들고 다시
	Winter.dream_levels[Balance.Dream.WINTER_SEED] = 2
	Winter.dream_levels[Balance.Dream.HANDS] = 3
	Night.best_level = 12
	_equal(Winter.perform(), true, "두 번째 겨울잠")
	_equal(Night.best_level, 1 + 3 * 2, "겨울 씨앗 2레벨: 7단계까지 열고 시작")
	_equal(Night.field_level, Night.best_level, "가장 높은 단계로")
	for index: int in [Balance.Upgrade.RADIUS, Balance.Upgrade.LONG_NIGHT, Balance.Upgrade.DENSE]:
		_equal(Upgrades.level(index), 3, "%s 3레벨을 들고 시작" % Balance.upgrade_name(index))


func _test_shop() -> void:
	_clean()
	var D: int = Balance.Dream.DEEP_SLEEP
	var base := float(Balance.DREAMS[D]["base_cost"])
	var growth := float(Balance.DREAMS[D]["growth"])
	_close(Balance.dream_cost(D, 0), base, "깊은 잠 첫 레벨")
	_close(Balance.dream_cost(D, 4), floor(base * pow(growth, 4)), "레벨마다 ×성장")
	_close(Balance.dream_cost(Balance.Dream.DREAM_CROW, 1), floor(5.0 * float(Balance.DREAMS[Balance.Dream.DREAM_CROW]["growth"])), "꿈의 까마귀 5 × 성장")
	_equal(Winter.buy(Balance.Dream.DEEP_SLEEP), false, "조각이 없으면 못 산다")
	Winter.shards = 10.0
	_equal(Winter.buy(Balance.Dream.DEEP_SLEEP), true, "깊은 잠")
	_equal(Winter.buy(Balance.Dream.DEEP_SLEEP), true, "깊은 잠 2")
	_close(Winter.shards, 10.0 - Balance.dream_cost(D, 0) - Balance.dream_cost(D, 1), "두 레벨 값만큼 줄었다")
	var deep := pow(Balance.DEEP_SLEEP_MULTIPLIER, 2)
	_close(Winter.damage_multiplier(), deep, "구름 피해 ×배율씩")
	_close(Night.cloud_dps(), Balance.cloud_dps(0) * deep, "밤의 구름 피해에 든다")
	Winter.dream_levels[Balance.Dream.DREAM_HARVEST] = 3
	_close(Winter.vitality_multiplier(), pow(Balance.DREAM_HARVEST_MULTIPLIER, 3), "꿈속 수확 ×배율씩")
	Winter.dream_levels[Balance.Dream.SLEEPWALK] = 2
	_close(Game.night_seconds(), Balance.NIGHT_BASE_SECONDS + 4.0, "몽유: 밤 +2초씩")
	Winter.dream_levels[Balance.Dream.DREAM_CROW] = Balance.dream_max_level(Balance.Dream.DREAM_CROW)
	_equal(Winter.can_buy(Balance.Dream.DREAM_CROW), false, "최대면 못 산다")
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Game.start_night()
	Night.begin(3)
	_close(Night.crop_vitality(0), pow(Balance.DREAM_HARVEST_MULTIPLIER, 3) * Balance.crop_vitality(Night.kinds[0], 1), "작물 생기에 꿈속 수확이 든다")
	_equal(Night._crow_left.size(), Balance.dream_max_level(Balance.Dream.DREAM_CROW), "꿈의 까마귀가 밤에 난다")
	Night.stop()


func _test_save() -> void:
	_clean()
	Winter.shards = 12.0
	Winter.sleeps = 2
	Winter.dream_levels[Balance.Dream.HANDS] = 4
	var data := Save.to_dict()
	_equal(data.has("winter"), true, "저장에 겨울잠이 든다")
	Save.reset_data()
	_close(Winter.shards, 0.0, "초기화")
	Save.from_dict(data)
	_close(Winter.shards, 12.0, "꿈 조각 복원")
	_equal(Winter.sleeps, 2, "횟수 복원")
	_equal(Winter.level(Balance.Dream.HANDS), 4, "레벨 복원")
	Winter.from_dict({"dream_levels": [-3, 2, 99]})
	_equal(Winter.level(Balance.Dream.DEEP_SLEEP), 0, "음수는 0")
	_equal(Winter.level(Balance.Dream.WINTER_SEED), Balance.dream_max_level(Balance.Dream.WINTER_SEED), "상한을 넘으면 상한")
	_equal(Winter.level(Balance.Dream.DREAM_CROW), 0, "모자란 항목은 0")

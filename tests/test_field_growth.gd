extends "res://tests/test_case.gd"
## 넓어지는 밭과 새 작물·스킬 (방장 2026-10-14 #456): 밭 크기, 무더기·덩굴 따라 심기, 해바라기 씨앗·수박 터짐·포도 덩굴,
## 어둠의 장막·수확의 낫·썩은 비·연쇄 시듦, 연쇄 도중에 정복하면 새 물결은 치지 않는다


func run() -> void:
	_test_size()
	_test_cluster()
	_test_crop_habits()
	_test_veil()
	_test_reap_and_rain()
	_test_chain()
	_fresh()
	Night.reset()


## 빽빽한 밭 최대로 이 단계의 밤을 시작한다 (1단계는 지키는 이가 없다)
func _start(level: int = 1, seed: int = 3) -> void:
	_fresh()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = level
	Night.field_level = level
	Game.start_night()
	Night.begin(seed)
	Night.time_left = 999.0
	Night.set_cloud(Vector2(-99.0, -99.0))


func _cell(x: int, y: int) -> int:
	return y * Night.field_size + x


## 칸에 작물을 바꿔 심는다 (체력은 그 작물의 최대)
func _set_crop(index: int, crop: int, share: float = 1.0) -> void:
	Night.kinds[index] = crop
	Night.max_hp[index] = Balance.crop_hp(crop, Night.field_level)
	Night.hp[index] = Night.max_hp[index] * share
	Night.infected[index] = 0


func _test_size() -> void:
	_equal(Balance.field_size(1), Balance.FIELD_BASE_SIZE, "첫 밭은 8 × 8")
	_equal(Balance.field_size(4), Balance.FIELD_BASE_SIZE + 1, "3단계마다 한 줄씩")
	_equal(Balance.field_size(31), Balance.FIELD_MAX_SIZE, "31단계에 가장 넓다")
	_equal(Balance.field_size(800), Balance.FIELD_MAX_SIZE, "더는 넓어지지 않는다")
	_start(13)
	_equal(Night.field_size, 12, "13단계 밤: 12 × 12")
	_equal(Night.cell_count(), 144, "칸 수")
	_equal(Night.crops_total, 144, "빽빽한 밭이면 모든 칸에")
	Night.set_cloud(Vector2(99.0, 99.0))
	_equal(Night.cloud, Vector2(12.0, 12.0), "구름은 넓어진 밭 끝까지")
	_start(1)
	_equal(Night.field_size, 8, "다음 밤이 1단계면 다시 8 × 8")


func _test_cluster() -> void:
	var grapes := 0
	var follow := 0
	for seed in 6:
		_start(30, seed)
		for i in Night.cell_count():
			if Night.kinds[i] == Balance.Crop.GRAPE and i % Night.field_size > 0:
				grapes += 1
				follow += 1 if Night.kinds[i - 1] == Balance.Crop.GRAPE else 0
	var share := Balance.crop_weights(30)[Balance.Crop.GRAPE]
	_equal(grapes > 0 and float(follow) / grapes > share * 2.0, true, "포도는 덩굴로 줄지어 심긴다 (왼쪽도 포도 %d / %d)" % [follow, grapes])


func _test_crop_habits() -> void:
	_start(1)
	# 수박: 둘레 1.5칸 작물마다 수박 최대 체력의 35%
	var melon := _cell(3, 3)
	_set_crop(melon, Balance.Crop.WATERMELON)
	for y in range(2, 6):
		for x in range(2, 6):
			if _cell(x, y) != melon:
				_set_crop(_cell(x, y), Balance.Crop.PUMPKIN)
	var bursts: Array[int] = []
	var on_burst := func(index: int, _radius: float) -> void: bursts.append(index)
	Night.crop_burst.connect(on_burst)
	Night._damage(melon, Night.hp[melon])
	Night.crop_burst.disconnect(on_burst)
	_equal(bursts, [melon], "수박이 터진다")
	var pumpkin_hp := Balance.crop_hp(Balance.Crop.PUMPKIN, 1)
	_close(Night.hp[_cell(4, 4)], pumpkin_hp - Night.max_hp[melon] * Balance.BURST_SHARE, "대각선 옆 호박도 맞는다")
	_close(Night.hp[_cell(5, 3)], pumpkin_hp, "두 칸 떨어진 호박은 멀쩡하다")
	# 해바라기: 둘레의 작물 둘이 번짐에 걸린다
	_start(1)
	var flower := _cell(4, 4)
	_set_crop(flower, Balance.Crop.SUNFLOWER)
	Night._damage(flower, Night.hp[flower])
	var infected := 0
	for i in Night.cell_count():
		infected += Night.infected[i]
	_equal(infected, Balance.SEED_COUNT, "씨앗이 튀어 둘이 번진다")
	# 포도: 이어진 옆 포도가 제 체력의 50%를 잃고, 그게 시들면 다음 포도로 이어진다
	_start(1)
	for x in 4:
		_set_crop(_cell(x, 1), Balance.Crop.GRAPE, 1.0 if x != 1 else 0.4)
	Night._damage(_cell(0, 1), Night.hp[_cell(0, 1)])
	_equal(Night.is_alive(_cell(1, 1)), false, "체력이 반 아래인 옆 포도는 덩굴을 타고 시든다")
	_close(Night.hp[_cell(2, 1)], Night.max_hp[_cell(2, 1)] * (1.0 - Balance.VINE_SHARE), "그다음 포도도 반을 잃는다")
	_close(Night.hp[_cell(3, 1)], Night.max_hp[_cell(3, 1)], "끊긴 덩굴 너머는 멀쩡하다")


func _test_veil() -> void:
	_start(40)
	_equal(Night.farmers.size() > 0, true, "40단계엔 지키는 이가 있다")
	Upgrades.levels[Balance.Upgrade.VEIL] = 1
	Night.farmers[0] = Night.cell_position(_cell(5, 5))
	_equal(Night.guard(_cell(5, 5)) < 1.0, true, "깨어 있으면 약을 친다")
	_equal(Night.use_skill(Balance.Skill.VEIL), true, "어둠의 장막을 켠다")
	_close(Night.guard(_cell(5, 5)), 1.0, "잠든 이는 약을 못 친다")
	var before := Night.farmers.duplicate()
	Night.tick(1.0)
	_equal(Night.farmers, before, "잠든 이는 걷지 않는다")
	Night.tick(Balance.skill_duration(Balance.Skill.VEIL, 1))
	_equal(Night.is_skill_active(Balance.Skill.VEIL), false, "장막이 걷힌다")


func _test_reap_and_rain() -> void:
	_start(1)
	Upgrades.levels[Balance.Upgrade.REAP] = 1
	_set_crop(_cell(1, 1), Balance.Crop.PUMPKIN, 0.2)
	_set_crop(_cell(6, 6), Balance.Crop.PUMPKIN, 0.5)
	var before := Night.withered
	_equal(Night.use_skill(Balance.Skill.REAP), true, "수확의 낫")
	_equal(Night.is_alive(_cell(1, 1)), false, "30% 아래는 밭 어디서든 쓰러진다")
	_equal(Night.is_alive(_cell(6, 6)), true, "반 남은 작물은 버틴다")
	_equal(Night.withered, before + 1, "하나만")
	_close(Balance.reap_share(9), Balance.REAP_MAX_SHARE, "낫은 60%까지")
	_start(1)
	Upgrades.levels[Balance.Upgrade.RAIN] = 1
	var cell := _cell(2, 5)
	_set_crop(cell, Balance.Crop.PUMPKIN)
	_equal(Night.use_skill(Balance.Skill.RAIN), true, "썩은 비")
	Night.tick(0.01)
	_close(Night.max_hp[cell] - Night.hp[cell], Balance.rain_dps(Night.cloud_dps(), 1) * Balance.CLOUD_TICK, "구름 밖에도 박자마다 내린다")


func _test_chain() -> void:
	_start(1)
	Upgrades.levels[Balance.Upgrade.CHAIN] = 1
	for i in Night.cell_count():
		_set_crop(i, Balance.Crop.PUMPKIN)
	_equal(Night.use_skill(Balance.Skill.CHAIN), true, "연쇄 시듦")
	var hits: Array[int] = []
	var on_chain := func(_from: int, to: int) -> void: hits.append(to)
	Night.chain_struck.connect(on_chain)
	Night._damage(_cell(3, 3), Night.hp[_cell(3, 3)])
	Night.chain_struck.disconnect(on_chain)
	_equal(hits.size(), 4, "옆 넷을 친다")
	_close(Night.hp[_cell(4, 3)], Night.max_hp[_cell(4, 3)] * (1.0 - Balance.chain_share(1)), "제 체력의 30%")
	# 연쇄로 정복하면 남은 일은 버리고, 새로 심긴 물결은 멀쩡하다
	_start(1)
	Upgrades.levels[Balance.Upgrade.CHAIN] = 1
	for i in Night.cell_count():
		_set_crop(i, Balance.Crop.WHEAT, 0.01)
	Night.use_skill(Balance.Skill.CHAIN)
	Night._damage(_cell(0, 0), 1.0)
	_equal(Night.waves, 1, "연쇄가 밭을 정복한다")
	var full := true
	for i in Night.cell_count():
		if Night.is_alive(i) and Night.hp[i] < Night.max_hp[i]:
			full = false
	_equal(full, true, "새 물결은 연쇄를 맞지 않는다")

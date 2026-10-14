extends "res://tests/test_case.gd"
## 농부와 수확일 (GDD 8절 M3): 농부 수, 수확일 배율, 농부 둘레의 약(피해 절반·번짐 씻기), 다시 심기, 걸음, 수확일 정복 보너스,
## 맞수(스며드는 독·까마귀 소란), 황금 이삭


func run() -> void:
	_test_counts()
	_test_guard_and_spray()
	_test_replant_and_walk()
	_test_harvest()
	_test_counters()
	_test_guardians()
	_fresh()
	Night.reset()


## level 단계의 꽉 찬 밭으로 밤을 시작한다
func _start(level: int) -> void:
	_fresh()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = level
	Night.field_level = level
	Game.start_night()
	Night.begin(5)


func _test_counts() -> void:
	_equal(Balance.farmer_count(4), 0, "4단계까지는 농부가 없다")
	_equal(Balance.farmer_count(6), 1, "5단계부터 한 명")
	_equal(Balance.farmer_count(5), 2, "수확일엔 한 명 더")
	_equal(Balance.farmer_count(16), 2, "15단계부터 둘")
	_equal(Balance.farmer_count(31), 3, "30단계부터 셋")
	_equal(Balance.is_harvest(10), true, "5의 배수는 수확일")
	_equal(Balance.is_harvest(11), false, "아니면 보통 밤")
	_start(3)
	_equal(Night.farmers.size(), 0, "3단계 밤엔 농부가 안 나온다")
	_start(7)
	_equal(Night.farmers.size(), 1, "7단계 밤엔 한 명")


func _test_guard_and_spray() -> void:
	_start(7)
	var spot := Night.cell_position(5 * Night.field_size + 5)
	Night.farmers[0] = spot
	Night._farmer_targets[0] = spot
	var near := 5 * Night.field_size + 5
	var far := 0
	_close(Night.guard(near), Balance.FARMER_GUARD, "둘레 안은 피해 절반")
	_close(Night.guard(far), 1.0, "둘레 밖은 그대로")
	Night.set_cloud(Night.cell_position(near))
	var before := Night.hp[near]
	Night.tick(Balance.CLOUD_TICK)
	_close(before - Night.hp[near], Night.cloud_dps() * Balance.CLOUD_TICK * Balance.FARMER_GUARD, "약 친 작물은 구름 피해 절반")
	Night.infected[near] = 1
	Night.farmers[0] = spot
	Night._farmer_targets[0] = spot
	Night.tick(0.01)
	_equal(Night.infected[near], 0, "농부가 지나가면 번짐을 씻어 낸다")


func _test_replant_and_walk() -> void:
	_start(7)
	var cell := 5 * Night.field_size + 5
	var spot := Night.cell_position(cell)
	Night._damage(cell, 1e12)
	_equal(Night.is_alive(cell), false, "시들었다")
	Night.farmers[0] = spot
	Night._farmer_targets[0] = spot
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(Balance.FARMER_REPLANT_INTERVAL + 0.05)
	_equal(Night.is_alive(cell), true, "농부가 둘레의 시든 칸에 다시 심는다")
	_start(7)
	var from := Night.farmers[0]
	Night._farmer_targets[0] = from + Vector2(5.0, 0.0)
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(1.0)
	_close(Night.farmers[0].distance_to(from), Balance.FARMER_SPEED, "농부는 초당 1.5칸 걷는다")


func _test_harvest() -> void:
	_close(Balance.harvest_hp(10), Balance.HARVEST_HP, "수확일 체력 배율")
	_close(Balance.harvest_vitality(11), 1.0, "보통 밤은 1")
	_start(10)
	var wheat := -1
	for i in Night.cell_count():
		if Night.kinds[i] == Balance.Crop.WHEAT:
			wheat = i
			break
	_close(Night.max_hp[wheat], Balance.crop_hp(Balance.Crop.WHEAT, 10) * Balance.HARVEST_HP, "수확일 작물은 단단하다")
	_close(Night.crop_vitality(wheat), Balance.crop_vitality(Balance.Crop.WHEAT, 10) * Balance.HARVEST_VITALITY, "수확일 작물은 값지다")
	Night.farmers.clear()  # 정복 계산만 보려고 농부를 뺀다
	for i in Night.cell_count():
		if Night.withered >= Night.clear_target() - 1:
			break
		if Night.is_alive(i):
			Night._damage(i, 1e30)
	var last := -1
	for i in Night.cell_count():
		if Night.is_alive(i):
			last = i
			break
	var harvest := 0.0  # 정복하면 다음 단계가 열려 field_level이 바뀌므로 그 전에 잰다
	for i in Night.cell_count():
		if Night.kinds[i] != Night.EMPTY:
			harvest += Night.crop_vitality(i)
	Night._damage(last, 1e30)
	_equal(Night.cleared, true, "수확일 정복")
	_close(Game.night_haul, harvest * (1.0 + Balance.HARVEST_CLEAR_BONUS), "정복하면 이번 물결 생기 +50%")
	Night.stop()


func _test_counters() -> void:
	_close(Balance.farmer_guard(2), Balance.FARMER_GUARD + 0.2, "스며드는 독 2레벨: 약 친 작물 피해 ×0.7")
	_close(Balance.farmer_guard(9), 1.0, "약이 안 듣는 데서 멈춘다")
	_start(7)
	var spot := Night.cell_position(5 * Night.field_size + 5)
	Night.farmers[0] = spot
	Night._farmer_targets[0] = spot
	var near := 5 * Night.field_size + 5
	Upgrades.levels[Balance.Upgrade.SEEP] = 3
	_close(Night.guard(near), Balance.FARMER_GUARD + 0.3, "밤에도 스며드는 독이 든다")
	# 까마귀 소란: 쪼면 농부가 멈추고, 멈춘 농부는 약을 못 친다
	Upgrades.levels[Balance.Upgrade.RACKET] = 5
	Night._peck()
	_equal(Night.is_stunned(0), true, "까마귀가 쪼면 농부가 멈춘다")
	_close(Night.guard(near), 1.0, "멈춘 농부 둘레는 약이 없다")
	Night.set_cloud(Vector2(-99.0, -99.0))
	Night.tick(Balance.racket_stun(5) + 0.05)
	_equal(Night.is_stunned(0), false, "시간이 지나면 다시 걷는다")
	# 황금 이삭
	_close(Balance.golden_chance(4), Balance.GOLDEN_BASE_CHANCE + 0.02, "황금 이삭 레벨당 +0.5%p")
	_fresh()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Upgrades.levels[Balance.Upgrade.GOLDEN] = 10
	var golden := 0
	for seed in 20:
		Game.start_night()
		Night.begin(seed)
		for i in Night.cell_count():
			golden += 1 if Night.kinds[i] == Balance.Crop.GOLDEN else 0
		Night.stop()
	var cells := 20 * Night.cell_count()
	_equal(golden > cells * 0.03 and golden < cells * 0.09, true, "황금 이삭 6%% 안팎 (%d / %d)" % [golden, cells])
	_close(Balance.crop_vitality(Balance.Crop.GOLDEN, 1) / Balance.crop_vitality(Balance.Crop.PUMPKIN, 1), 10.0, "황금 이삭은 호박의 10배 생기")


func _test_guardians() -> void:
	var G := Balance.Guardian
	_equal(Balance.guardians(4), [] as Array[int], "4단계엔 아무도 없다")
	_equal(Balance.guardians(7), [G.FARMER] as Array[int], "7단계: 농부")
	_equal(Balance.guardians(41), [G.INSPECTOR, G.INSPECTOR, G.INSPECTOR] as Array[int], "40단계부터 감독관")
	_equal(Balance.guardians(91)[0], G.OFFICIAL, "90단계부터 관리")
	_equal(Balance.guardians(150).back(), G.GODDESS, "150단계 수확일: 마지막 한 명이 여신")
	_equal(Balance.guardians(151).has(G.GODDESS), false, "수확일이 아니면 여신이 없다")
	_equal(Balance.guardians(145).has(G.GODDESS), false, "150 전 수확일엔 여신이 없다")
	_close(Balance.guardian_guard(G.GODDESS, 0), 0.3, "여신의 약이 가장 세다")
	_start(150)
	_equal(Night.farmer_kinds.back(), G.GODDESS, "밤에도 여신이 나온다")
	var near := 5 * Night.field_size + 5
	for f in Night.farmers.size():
		Night.farmers[f] = Night.cell_position(near)
		Night._farmer_targets[f] = Night.cell_position(near)
	_close(Night.guard(near), 0.3, "여럿이 겹치면 가장 센 약")
	Night.stop()

extends "res://tests/test_case.gd"
## 어둠의 나무 둘째 묶음 (방장 2026-10-15 #529): 스킬마다 센·잦은 칸, 메아리 포자·두 번 치는 구름, 끈적한 포자·무성한 뿌리·썩은 고기·물결의 기세(생기),
## 새벽 미루기·수확의 달(정복), 까마귀 둥지, 지키는 이 맞서기(노려보기·썩은 약통·늦잠), 작물마다 칸


func run() -> void:
	_test_skill_nodes()
	_test_cloud_nodes()
	_test_vitality_nodes()
	_test_conquest_nodes()
	_test_guardian_nodes()
	_test_crop_nodes()
	_fresh()
	Night.reset()


func _start(level: int = 1, seed: int = 5) -> void:
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


func _test_skill_nodes() -> void:
	var need := Balance.skill_need(Balance.Skill.STORM, 1)
	_equal(Balance.skill_need(Balance.Skill.STORM, 1, 2), int(need * (1.0 - 2.0 * Balance.OFTEN_CUT)), "잦은 폭풍: 타수 10%씩 덜")
	_close(Balance.skill_chance(Balance.Skill.REAP, 1, 2) - Balance.skill_chance(Balance.Skill.REAP, 1), 0.02, "잦은 낫: 확률 +1%p씩")
	_close(Balance.storm_damage(2), Balance.STORM_DAMAGE + 2.0 * Balance.STORM_POWER_STEP, "거센 폭풍")
	_close(Balance.flock_speed(1), Balance.FLOCK_SPEED + Balance.FLOCK_POWER_STEP, "더 많은 떼")
	_close(Balance.sigh_damage(10.0, 1, 1), Balance.sigh_damage(10.0, 2), "깊은 한숨은 한숨 레벨 하나만큼")
	_close(Balance.skill_duration(Balance.Skill.VEIL, 1, 2), Balance.skill_duration(Balance.Skill.VEIL, 1) + 3.0, "두꺼운 장막: +1.5초씩")
	_equal(Balance.skill_power_upgrade(Balance.Skill.CHAIN), Balance.Upgrade.CHAIN_POWER, "스킬마다 센 칸")
	_equal(Balance.skill_often_upgrade(Balance.Skill.RAIN), Balance.Upgrade.RAIN_OFTEN, "스킬마다 잦은 칸")
	_start()
	Upgrades.levels[Balance.Upgrade.STORM] = 1
	Upgrades.levels[Balance.Upgrade.STORM_POWER] = 3
	var dps := Night.cloud_dps()
	Night.use_skill(Balance.Skill.STORM)
	_close(Night.cloud_dps(), dps * Balance.storm_damage(3), "켜진 폭풍이 센 칸을 쓴다")
	Night.stop()


func _test_cloud_nodes() -> void:
	_close(Balance.double_chance(5), 5.0 * Balance.DOUBLE_CHANCE_PER_LEVEL, "두 번 치는 구름")
	_start()
	Upgrades.levels[Balance.Upgrade.ECHO] = 2
	var center := _cell(4, 4)
	Night.set_cloud(Night.cell_position(center))
	var band := _cell(6, 4)  # 두 칸 옆: 반경(1) 밖, 반경 + 띠(1) 안
	var far := _cell(7, 4)
	var before := Night.hp[band]
	Night.tick(Night._tick + 0.01)
	var hit := Night.cloud_dps() * Night._tick
	_close(before - Night.hp[band], minf(before, hit * Balance.echo_share(2)), "메아리 포자: 띠의 작물도 몫만큼")
	_close(Night.hp[far], Night.max_hp[far], "띠 밖은 멀쩡하다")
	Night.stop()


func _test_vitality_nodes() -> void:
	_start()
	var cell := _cell(2, 2)
	var plain := Night.crop_vitality(cell)
	Upgrades.levels[Balance.Upgrade.STICKY] = 2
	_close(Night.crop_vitality(cell, true), plain * Balance.sticky_multiplier(2), "끈적한 포자: 번진 채 시들면")
	_close(Night.crop_vitality(cell), plain, "번지지 않았으면 그대로")
	Upgrades.levels[Balance.Upgrade.ROOTS] = 3
	Night.regrown[cell] = 1
	_close(Night.crop_vitality(cell), plain * Balance.roots_multiplier(3), "무성한 뿌리: 다시 자란 작물")
	Night.regrown[cell] = 0
	Upgrades.levels[Balance.Upgrade.WAVES] = 2
	Night.waves = 3
	_close(Night.crop_vitality(cell), plain * Balance.waves_multiplier(2, 3), "물결의 기세: 물결 수만큼")
	Night.waves = 0
	Night.stop()
	# 썩은 고기: 까마귀가 쪼아 시든 작물
	_start()
	Upgrades.levels[Balance.Upgrade.CROW] = 1
	Upgrades.levels[Balance.Upgrade.CARRION] = 2
	Upgrades.levels[Balance.Upgrade.BEAK] = Balance.upgrade_max_level(Balance.Upgrade.BEAK)
	var gains: Array[float] = []
	var expected: Array[float] = []
	var on_wither := func(index: int, vitality: float) -> void:
		if Night._kill_bonus > 1.0:  # 까마귀가 쪼아 시든 것만 (구름은 밭 모서리로 붙들려 (0, 0) 칸을 친다)
			gains.append(vitality)
			expected.append(Night.crop_vitality(index) / Night._kill_bonus * Balance.carrion_multiplier(2))
	for i in Night.cell_count():
		if Night.is_alive(i):
			Night.hp[i] = 0.01  # 한 번 쪼면 시든다
	Night.crop_withered.connect(on_wither)
	Night._setup_critters()
	Night.tick(Balance.CROW_INTERVAL + 0.01)
	Night.crop_withered.disconnect(on_wither)
	_equal(gains.size() > 0, true, "까마귀가 쪼아 시들게 했다")
	if gains.size() > 0:
		_close(gains[0], expected[0], "썩은 고기: 생기 +30%씩")
	_equal(Night._crow_left.size() >= 1, true, "까마귀가 난다")
	Night.stop()


func _test_conquest_nodes() -> void:
	_close(Balance.harvest_clear_bonus(2), Balance.HARVEST_CLEAR_BONUS + 2.0 * Balance.HARVEST_MOON_PER_LEVEL, "수확의 달")
	_start()
	Upgrades.levels[Balance.Upgrade.DAWN] = 3
	Night.time_left = 10.0
	for i in Night.cell_count():
		if Night.is_alive(i):
			Night.hp[i] = 0.0001
	Night.set_cloud(Night.cell_position(_cell(0, 0)))
	Upgrades.levels[Balance.Upgrade.RADIUS] = Balance.upgrade_max_level(Balance.Upgrade.RADIUS)
	Upgrades.levels[Balance.Upgrade.RAIN] = 1
	Night.use_skill(Balance.Skill.RAIN)  # 밭 전체에 내려 한 번에 정복
	Night.tick(0.01)
	_equal(Night.waves >= 1, true, "정복")
	_equal(Night.time_left > 10.0, true, "새벽 미루기: 정복하면 밤이 늘어난다 (%.1f초)" % Night.time_left)
	Night.stop()
	_start()
	Upgrades.levels[Balance.Upgrade.NEST] = 2
	Upgrades.levels[Balance.Upgrade.CROW] = 1
	Night._setup_critters()
	_equal(Night._crow_left.size(), 3, "까마귀 둥지: 까마귀 +1씩")
	Night.stop()


func _test_guardian_nodes() -> void:
	_close(Balance.scare_factor(2), 1.0 - 2.0 * Balance.SCARE_PER_LEVEL, "노려보는 허수아비")
	_close(Balance.scare_factor(99), Balance.GUARD_FLOOR, "걸음은 바닥까지만 준다")
	_close(Balance.replant_factor(2), 1.0 + 2.0 * Balance.LATE_SLEEPER_PER_LEVEL, "늦잠")
	_start(10)
	_equal(Night.farmers.size() > 0, true, "10단계엔 지키는 이가 있다")
	var radius := Night.guard_radius(0)
	Upgrades.levels[Balance.Upgrade.ROTTEN_SPRAY] = 2
	_close(Night.guard_radius(0), radius * Balance.spray_radius_factor(2), "썩은 약통: 약 둘레가 준다")
	Night.stop()


func _test_crop_nodes() -> void:
	_equal(Balance.seed_count(2), Balance.SEED_COUNT + 2, "씨앗 터뜨리기")
	_close(Balance.burst_damage(10.0, 2), Balance.burst_damage(10.0, 0) * (1.0 + 2.0 * Balance.BURST_PER_LEVEL), "물 많은 수박")
	_close(Balance.vine_damage(10.0, 1), Balance.vine_damage(10.0, 0) * (1.0 + Balance.VINE_PER_LEVEL), "포도 넝쿨")
	_close(Balance.cluster_chance(Balance.Crop.TURNIP, 2), Balance.BLOB_CHANCE + 2.0 * Balance.TURNIP_CLUSTER_PER_LEVEL, "줄줄이 순무: 더 몰려 심긴다")
	for crop: int in [Balance.Crop.WHEAT, Balance.Crop.CORN, Balance.Crop.GOLDEN, Balance.Crop.GRAPE]:
		var step := float(Balance.CROPS[crop]["bonus_step"])
		_close(Balance.crop_vitality(crop, 1, 0, 3), Balance.crop_vitality(crop, 1) * (1.0 + 3.0 * step), "%s 칸: 생기 +%d%%씩" % [Balance.crop_name(crop), roundi(step * 100.0)])
	_start()
	var wheat := -1
	for i in Night.cell_count():
		if Night.kinds[i] == Balance.Crop.WHEAT:
			wheat = i
			break
	var plain := Night.crop_vitality(wheat)
	Upgrades.levels[Balance.Upgrade.WHEAT] = 2
	_close(Night.crop_vitality(wheat), plain * (1.0 + 2.0 * float(Balance.CROPS[Balance.Crop.WHEAT]["bonus_step"])), "밭의 밀에 누런 밀이 든다")
	Night.stop()

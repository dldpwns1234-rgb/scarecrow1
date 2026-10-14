extends "res://tests/test_case.gd"
## 어둠의 나무 갈래 끝 칸과 밤 스킬: 역병 폭풍·한숨·역병 파도·까마귀 떼(스킬, 타수형·확률형으로 저절로 터진다), 새벽 전 몰아치기(밤 끝 피해 ×2), 풍요의 저주(수확일 생기), 까마귀 왕(값진 작물부터)


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
	_close(Balance.skill_duration(Balance.Skill.STORM, 0), 0.0, "없으면 폭풍이 없다")
	_close(Balance.skill_duration(Balance.Skill.STORM, 3), 8.0, "3레벨: 8초 동안")
	_equal(Balance.skill_need(Balance.Skill.STORM, 3), 96, "3레벨: 96타면 터진다")
	_equal(Balance.skill_need(Balance.Skill.STORM, 99), Balance.MIN_NEED, "타수에는 바닥이 있다")
	_close(Balance.skill_chance(Balance.Skill.REAP, 3), 0.06, "낫 3레벨: 시들 때 6%")
	_close(Balance.skill_rest(Balance.Skill.REAP, 99), Balance.MIN_REST, "쉬는 시간에도 바닥")
	_start()
	_equal(Night.use_skill(Balance.Skill.STORM), false, "칸을 안 샀으면 못 쓴다")
	Upgrades.levels[Balance.Upgrade.STORM] = 1
	var storms: Array[int] = []
	var on_storm := func() -> void: storms.append(1)
	Night.storm_pulsed.connect(on_storm)
	var center := 5 * Night.field_size + 5
	Night.set_cloud(Night.cell_position(center))
	var far := 5 * Night.field_size + 6  # 한 칸 옆: 보통 반경(1) 끝, 폭풍 반경(1.8) 안
	var radius := Night.cloud_radius()
	var dps := Night.cloud_dps()
	Night.time_left = 999.0  # 다시 차오를 때까지 밤이 이어지게
	_equal(Night.use_skill(Balance.Skill.STORM), true, "역병 폭풍을 켠다")
	Night.storm_pulsed.disconnect(on_storm)
	_equal(storms.size(), 1, "켜는 순간 신호")
	_close(Night.cloud_radius(), radius * Balance.STORM_RADIUS, "켜 둔 동안 반경 ×1.8")
	_close(Night.cloud_dps(), dps * Balance.STORM_DAMAGE, "켜 둔 동안 피해 ×1.5")
	_equal(Night.use_skill(Balance.Skill.STORM), false, "켜져 있으면 또 못 쓴다")
	Night.tick(Balance.skill_duration(Balance.Skill.STORM, 1) + 0.1)
	_equal(Night.is_skill_active(Balance.Skill.STORM), false, "6초 뒤 꺼진다")
	_close(Night.cloud_radius(), radius, "반경이 돌아온다")
	_equal(Night.charge[Balance.Skill.STORM], 0, "터지면 타수는 0부터")
	Night._count_cloud_hits(Balance.skill_need(Balance.Skill.STORM, 1) - 1)
	_equal(Night.is_skill_active(Balance.Skill.STORM), false, "한 타 모자라면 아직")
	Night._count_cloud_hits(1)
	_equal(Night.is_skill_active(Balance.Skill.STORM), true, "타수가 다 차면 저절로 켜진다")
	Night._count_cloud_hits(5)
	_equal(Night.charge[Balance.Skill.STORM], 0, "켜진 동안은 타수를 세지 않는다")
	Night.time_left = 999.0
	Night.tick(Balance.skill_duration(Balance.Skill.STORM, 1) + 0.1)
	var target := _first_alive()
	Night.set_cloud(Night.cell_position(target))
	var charge := Night.charge[Balance.Skill.STORM]
	Night.tick(Night._tick + 0.01)
	_equal(Night.charge[Balance.Skill.STORM] > charge, true, "구름이 작물을 치면 타수가 찬다")
	Night.stop()
	_test_wither_trigger()
	_test_other_skills()


## 확률형: 시들 때마다 굴려 터지고, 터진 뒤엔 쉰다
func _test_wither_trigger() -> void:
	_start()
	Upgrades.levels[Balance.Upgrade.REAP] = 1
	var fired: Array[int] = []
	var on_used := func(skill: int) -> void: fired.append(skill)
	Night.skill_used.connect(on_used)
	var rolls := 0
	while fired.is_empty() and rolls < 2000:
		Night._roll_wither_skills()
		rolls += 1
	_equal(fired, [Balance.Skill.REAP], "시들 때 확률로 낫이 터진다 (%d번째)" % rolls)
	_close(Night.rest_left[Balance.Skill.REAP], Balance.skill_rest(Balance.Skill.REAP, 1), "터진 뒤 쉰다")
	for i in 500:
		Night._roll_wither_skills()
	_equal(fired.size(), 1, "쉬는 동안은 안 터진다")
	Night.tick(Balance.skill_rest(Balance.Skill.REAP, 1) + 0.1)
	_close(Night.rest_left[Balance.Skill.REAP], 0.0, "쉬는 시간이 지나면 다시 굴린다")
	Night.skill_used.disconnect(on_used)
	Night.stop()


func _test_other_skills() -> void:
	# 짚돌이의 한숨: 구름 안 작물에 한꺼번에
	_start()
	Upgrades.levels[Balance.Upgrade.SIGH] = 2
	var center := 5 * Night.field_size + 5
	Night.set_cloud(Night.cell_position(center))
	var before := Night.hp[center]
	_equal(Night.use_skill(Balance.Skill.SIGH), true, "한숨")
	_close(before - Night.hp[center], minf(before, Balance.sigh_damage(Night.cloud_dps(), 2)), "구름 피해 12초 몫 (2레벨)")
	_equal(Night.is_skill_active(Balance.Skill.SIGH), false, "즉발형은 켜진 채로 남지 않는다")
	# 역병 파도: 살아 있는 작물의 25%가 번진다
	_start()
	Upgrades.levels[Balance.Upgrade.TIDE] = 1
	_equal(Night.use_skill(Balance.Skill.TIDE), true, "역병 파도")
	var sick := 0
	for i in Night.cell_count():
		sick += Night.infected[i]
	_equal(sick, ceili(Night.alive_count() * Balance.tide_share(1)), "25%가 번짐에 걸린다")
	# 까마귀 떼: 까마귀가 없으면 셋이 날아들고, 끝나면 돌아간다
	_start()
	Upgrades.levels[Balance.Upgrade.FLOCK] = 1
	Night.set_cloud(Vector2(-99.0, -99.0))
	var pecks: Array[int] = []
	var on_peck := func(index: int) -> void: pecks.append(index)
	Night.crow_pecked.connect(on_peck)
	_equal(Night.use_skill(Balance.Skill.FLOCK), true, "까마귀 떼")
	Night.tick(Balance.CROW_INTERVAL / Balance.FLOCK_SPEED + 0.01)
	_equal(pecks.size(), Balance.FLOCK_SUMMONED, "날아든 셋이 네 배 빨리 쫀다")
	Night.tick(Balance.skill_duration(Balance.Skill.FLOCK, 1))
	var after := pecks.size()
	Night.tick(Balance.CROW_INTERVAL * 2.0)
	Night.crow_pecked.disconnect(on_peck)
	_equal(pecks.size(), after, "끝나면 돌아간다")
	Night.stop()


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


## 살아 있는 첫 작물 (없으면 -1)
func _first_alive() -> int:
	for i in Night.cell_count():
		if Night.is_alive(i):
			return i
	return -1

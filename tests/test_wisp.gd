extends "res://tests/test_case.gd"
## 도깨비불 (방장 2026-10-15 #587, 장르 조사 제안 6): 뜨는 확률과 가뭄 막기, 나타남·떠돌기·사라짐, 구름으로 덮어 잡기, 보상 넷(잔치·주머니·장난·꿈 부스러기),
## 밭 rng와 따로 굴리기


func run() -> void:
	_test_formulas()
	_test_chance()
	_test_appear_and_fade()
	_test_catch()
	_test_boons()
	_test_field_rng()
	_fresh()
	Winter.reset()
	Night.reset()


func _start(nights: int, seed: int = 5) -> void:
	_fresh()
	Winter.reset()
	Night.reset()
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = 10
	Night.field_level = 10
	Game.nights = nights
	Game.start_night()  # 밤으로 바뀌면 Night가 한 번 심는다. 그 뒤 시드를 고정해 다시 심는다
	Night._drought = Balance.WISP_DROUGHT  # 이번 밤엔 꼭 뜬다
	Night.begin(seed)
	Night.time_left = 999.0


## 도깨비불이 나타날 때까지 시간을 흘린다
func _until_up() -> void:
	for step in 2000:
		if Night.is_wisp_up():
			return
		Night.tick(0.05)


func _test_formulas() -> void:
	_close(Balance.wisp_chance(0, 0), 0.0, "첫 밤들엔 안 뜬다")
	_close(Balance.wisp_chance(Balance.WISP_AFTER_NIGHTS, 0), Balance.WISP_CHANCE, "그 뒤로는 밤마다 확률")
	_close(Balance.wisp_chance(5, Balance.WISP_DROUGHT), 1.0, "가뭄이 길면 꼭 뜬다")
	_close(Balance.boon_weight(Balance.Boon.PRANK, false, true), 0.0, "열린 스킬이 없으면 장난은 없다")
	_close(Balance.boon_weight(Balance.Boon.DREAM, true, false), 0.0, "겨울잠 전엔 꿈 부스러기가 없다")
	_close(Balance.boon_weight(Balance.Boon.FEAST, false, false), 50.0, "잔치는 늘 있다")
	_close(Balance.purse_vitality(100.0), 150.0, "주머니: 밭 한 판 반 몫")
	_close(Balance.dream_crumbs(10.0), 1.0, "꿈 부스러기는 적어도 1")
	_close(Balance.dream_crumbs(1000.0), 30.0, "꿈 부스러기: 받을 조각의 3%")


func _test_chance() -> void:
	_fresh()
	Night.reset()
	var seen := 0
	for n in 20:  # 낮인 채로 심기만 한다 (Game.start_night는 Night를 한 번 더 심어 가뭄을 두 번 센다)
		Game.nights = 0
		Night.begin(100 + n)
		seen += 1 if Night._wisp_pending else 0
		Night.stop()
	_equal(seen, 0, "지난 밤이 둘 안이면 한 번도 안 뜬다")
	var dry := 0
	var longest := 0
	var count := 0
	for n in 60:
		Game.nights = 10
		Night.begin(200 + n)
		if Night._wisp_pending:
			count += 1
			dry = 0
		else:
			dry += 1
			longest = maxi(longest, dry)
		Night.stop()
	_equal(longest <= Balance.WISP_DROUGHT, true, "뜰 수 있는 밤을 셋 넘게 거르지 않는다")
	_equal(count > 12 and count < 40, true, "60밤에 스물 남짓 뜬다 (%d)" % count)


func _test_appear_and_fade() -> void:
	_start(5)
	_equal(Night._wisp_pending, true, "가뭄 끝이라 이번 밤엔 뜬다")
	Night.set_cloud(Vector2.ZERO)
	_until_up()
	_equal(Night.is_wisp_up(), true, "정한 때에 나타난다")
	var size := float(Night.field_size)
	_equal(Night.wisp.distance_to(Night.cloud) >= Night.cloud_radius(), true, "구름 밖에 나타난다")
	var faded := [false]
	Night.wisp_faded.connect(func() -> void: faded[0] = true, CONNECT_ONE_SHOT)
	var inside := true
	for step in int(Balance.WISP_LIFETIME / 0.05) + 5:
		Night.set_cloud(Vector2.ZERO)  # 구름은 모서리에 둔다 (잡지 않는다)
		Night.tick(0.05)
		var w := Night.wisp
		inside = inside and w.x >= 0.5 and w.y >= 0.5 and w.x <= size - 0.5 and w.y <= size - 0.5
	_equal(inside, true, "떠도는 동안 밭 안에 있다")
	_equal(Night.is_wisp_up(), false, "못 잡으면 사라진다")
	_equal(faded[0] or Night.wisp.distance_to(Vector2.ZERO) <= Night.cloud_radius(), true, "사라지면 알린다")
	Night.stop()


func _test_catch() -> void:
	_start(5)
	_until_up()
	var caught := [-1]
	Night.wisp_caught.connect(func(boon: int, _amount: float) -> void: caught[0] = boon, CONNECT_ONE_SHOT)
	for step in 20:
		Night.set_cloud(Night.wisp)
		Night.tick(0.05)
	_equal(Night.is_wisp_up(), false, "구름으로 덮으면 잡힌다")
	_equal(caught[0] == Balance.Boon.FEAST or caught[0] == Balance.Boon.PURSE, true, "스킬·겨울잠이 없으면 잔치나 주머니")
	Night.stop()


func _test_boons() -> void:
	_start(5)
	var cell := 0
	while not Night.is_alive(cell):
		cell += 1
	Feats.wisps = 1
	Feats._check()  # 보상을 받으며 열릴 업적을 미리 연다 (업적마다 생기 +2%)
	var plain := Night.crop_vitality(cell)
	Night._grant(Balance.Boon.FEAST)
	_close(Night.crop_vitality(cell), plain * Balance.FEAST_MULTIPLIER, "잔치 동안 생기 배율")
	Night.set_cloud(Vector2(-99.0, -99.0))
	for step in int(Balance.FEAST_SECONDS / 0.05) + 2:
		Night.tick(0.05)
	_close(Night.crop_vitality(cell), plain, "잔치가 끝나면 그대로")
	var field := Night._field_value()
	var before := Game.vitality
	Night._grant(Balance.Boon.PURSE)
	_close(Game.vitality - before, field * Balance.PURSE_FIELDS, "주머니: 밭 한 판 반 몫 생기")
	Upgrades.levels[Balance.Upgrade.STORM] = 1
	Night._grant(Balance.Boon.PRANK)
	_equal(Night.is_skill_active(Balance.Skill.STORM), true, "장난: 열린 스킬이 터진다")
	Winter.sleeps = 1
	Night.best_level = 40
	var shards := Winter.shards
	Night._grant(Balance.Boon.DREAM)
	_close(Winter.shards - shards, Balance.dream_crumbs(Balance.shard_reward(40)), "꿈 부스러기: 꿈 조각")
	Night.stop()


func _test_field_rng() -> void:
	_start(0, 9)
	var calm := Night.kinds.duplicate()
	Night.stop()
	_start(5, 9)
	_equal(Night.kinds == calm, true, "도깨비불이 떠도 밭 배치는 같다")
	Night.stop()

extends "res://tests/test_case.gd"
## 작물 숙련과 업적 (방장 2026-10-15 #587, 장르 조사 제안 8·9): 숙련 레벨 공식, 시들 때 오르는 숙련과 생기 배율, 기록이 목표에 닿으면 열리는 업적,
## 업적 배율, id로 저장·불러오기, 겨울잠을 넘어 남기


func run() -> void:
	_test_formulas()
	_test_mastery()
	_test_achievements()
	_test_save()
	_fresh()
	Winter.reset()
	Night.reset()


func _start(level: int = 3, seed: int = 4) -> void:
	_fresh()
	Winter.reset()
	Night.reset()
	Night.best_level = level
	Night.field_level = level
	Game.start_night()
	Night.begin(seed)
	Night.time_left = 999.0
	Night.set_cloud(Vector2(-99.0, -99.0))


func _test_formulas() -> void:
	_equal(Balance.mastery_level(49.0), 0, "숙련: 50 전엔 0")
	_equal(Balance.mastery_level(50.0), 1, "숙련 1: 50")
	_equal(Balance.mastery_level(199.0), 1, "숙련 1: 200 전")
	_equal(Balance.mastery_level(200.0), 2, "숙련 2: 200")
	_equal(Balance.mastery_level(800.0), 3, "숙련 3: 800")
	_equal(Balance.mastery_level(1e30), Balance.MASTERY_MAX, "숙련 상한")
	_close(Balance.mastery_goal(3), 800.0, "숙련 3의 목표")
	_close(Balance.mastery_multiplier(4), 1.2, "숙련 4: 그 작물 생기 +20%")
	_close(Balance.feats_multiplier(10), 1.2, "업적 10개: 모든 생기 +20%")
	var ids := {}
	for entry in Balance.ACHIEVEMENTS:
		ids[entry["id"]] = true
	_equal(ids.size(), Balance.ACHIEVEMENTS.size(), "업적 id는 겹치지 않는다")


func _test_mastery() -> void:
	_start()
	var cell := 0
	while not Night.is_alive(cell):
		cell += 1
	var crop := Night.kinds[cell]
	var plain := Night.crop_vitality(cell)
	var changed := [-1]
	Feats.mastery_changed.connect(func(kind: int, level: int) -> void: changed[0] = kind * 100 + level, CONNECT_ONE_SHOT)
	Feats.withered[crop] = Balance.MASTERY_FIRST - 1.0
	Night._damage(cell, 1e30)
	_equal(Feats.mastery(crop), 1, "시든 수가 50에 닿으면 숙련 1")
	_equal(changed[0], crop * 100 + 1, "숙련이 오르면 알린다")
	_close(Feats.mastery_multiplier(crop), 1.0 + Balance.MASTERY_PER_LEVEL, "그 작물만 생기 +5%")
	var other := (crop + 1) % Balance.CROPS.size()
	_close(Feats.mastery_multiplier(other), 1.0, "다른 작물은 그대로")
	Night.regrown[cell] = 0
	Night.hp[cell] = Night.max_hp[cell]
	_close(Night.crop_vitality(cell), plain * (1.0 + Balance.MASTERY_PER_LEVEL), "숙련이 시든 작물의 생기에 붙는다")
	Night.stop()
	Winter.sleeps = 0
	Night.best_level = Balance.WINTER_MIN_LEVEL
	Winter.perform()
	_equal(Feats.mastery(crop), 1, "겨울잠을 넘어 남는다")


func _test_achievements() -> void:
	_fresh()
	Winter.reset()
	Night.reset()
	var opened: Array[int] = []
	var record := func(index: int) -> void: opened.append(index)
	Feats.achievement_unlocked.connect(record)
	Game.start_night()
	Night.stop()  # 밤 하나를 보내면 '첫 흉년'
	_equal(opened.has(_index("night_1")), true, "밤을 한 번 보내면 첫 흉년")
	_equal(Feats.unlocked_count(), opened.size(), "연 수를 센다")
	_close(Feats.vitality_multiplier(), Balance.feats_multiplier(opened.size()), "업적마다 생기 +2%")
	var before := opened.size()
	Feats._check()
	_equal(opened.size(), before, "한 번 연 업적은 다시 안 연다")
	Feats.wisps = 39
	Night.wisp_caught.emit(Balance.Boon.FEAST, 5.0)
	_equal(Feats.wisps, 40, "잡은 도깨비불을 센다")
	_equal(opened.has(_index("wisp_40")) and opened.has(_index("wisp_10")), true, "도깨비불 40번이면 단골·친구가 함께 열린다")
	Game.offered = 1e19  # 약속된 휴식 백 년 너머, 천 년 전
	Feats._check()
	_equal(opened.has(_index("rest_100")) and not opened.has(_index("rest_1000")), true, "약속된 휴식으로 여는 업적 (엔딩 뒤 목표)")
	Feats.achievement_unlocked.disconnect(record)


func _test_save() -> void:
	_fresh()
	Feats.withered[Balance.Crop.GOLDEN] = 900.0
	Feats.wisps = 3
	Feats.unlocked[_index("sleep_1")] = true
	var data := Feats.to_dict()
	_equal(data["achievements"], ["sleep_1"], "업적은 id로 저장한다")
	Feats.reset()
	Feats.from_dict(data)
	_equal(Feats.mastery(Balance.Crop.GOLDEN), 3, "불러오면 숙련을 다시 센다")
	_equal(Feats.wisps, 3, "도깨비불 수")
	_equal(Feats.unlocked[_index("sleep_1")] and Feats.unlocked_count() == 1, true, "업적을 id로 찾는다")
	Feats.from_dict({"achievements": ["없는_업적"], "withered": [-5.0]})
	_equal(Feats.unlocked_count() == 0 and Feats.withered[0] == 0.0, true, "망가진 저장은 버린다")


func _index(id: String) -> int:
	for i in Balance.ACHIEVEMENTS.size():
		if Balance.ACHIEVEMENTS[i]["id"] == id:
			return i
	return -1

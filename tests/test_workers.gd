extends "res://tests/test_case.gd"
## 아지트 일꾼 (GDD 8절 M2): 열림과 합류(밭 기록·겨울잠), 배치·옮기기·칸, 헛간 확장, 효과(망보기·포자 말리기·생기 나르기), 겨울잠을 넘어 남기, 저장


func run() -> void:
	_test_roster()
	_test_assign()
	_test_effects()
	_test_save()
	_clean()


func _clean() -> void:
	_fresh()
	Night.reset()
	Winter.reset()
	Workers.reset()


func _test_roster() -> void:
	_clean()
	_equal(Workers.is_open(), false, "처음엔 아지트가 닫혀 있다")
	_equal(Workers.worker_count(), 0, "일꾼 없음")
	Night.start_season(10)  # 밭 10단계가 열렸다
	_equal(Workers.is_open(), true, "밭 기록 10단계에 연다")
	_equal(Workers.worker_count(), 2, "까마귀 하나와 허수아비 하나")
	_equal(Workers.worker_kind(0), Balance.Worker.CROW, "까마귀가 앞")
	_equal(Workers.worker_kind(1), Balance.Worker.SCARECROW, "허수아비가 뒤")
	_equal(Workers.worker_name(1), Balance.SCARECROW_NAMES[0], "이름")
	Workers.assign(1, Balance.Job.DRY)
	Night.start_season(20)
	_equal(Workers.worker_count(), 3, "20단계에 허수아비 하나 더")
	_equal(Workers.worker_job(1), Balance.Job.DRY, "있던 배치는 그대로")
	Night.best_level = 12
	Winter.perform()
	_equal(Workers.worker_count(), 4, "겨울잠마다 까마귀 하나 더")
	_equal(Workers.best_ever, 20, "밭 기록은 겨울잠을 넘어 남는다")
	_equal(Workers.worker_job(2), Balance.Job.DRY, "까마귀가 앞에 끼어도 허수아비 배치는 따라간다")


func _test_assign() -> void:
	_clean()
	Night.start_season(20)
	_equal(Workers.assign(0, Balance.Job.WATCH), true, "까마귀를 망보기에")
	_equal(Workers.assign(1, Balance.Job.WATCH), false, "칸이 하나라 다 찼다")
	_equal(Workers.used(Balance.Job.WATCH), 1, "쓴 칸")
	_equal(Workers.assign(0, Balance.Job.CARRY), true, "다른 일자리로 옮긴다")
	_equal(Workers.used(Balance.Job.WATCH), 0, "옮기면 앞 칸이 빈다")
	Workers.unassign(0)
	_equal(Workers.worker_job(0), -1, "쉬게 한다")
	_equal(Workers.can_expand(Balance.Job.WATCH), false, "생기가 없으면 확장 못 한다")
	Game.vitality = 1e9
	_equal(Workers.expand(Balance.Job.WATCH), true, "헛간 확장")
	_close(Game.vitality, 1e9 - Balance.EXPAND_BASE_COST, "비용")
	_close(Workers.expand_cost(Balance.Job.WATCH), Balance.EXPAND_BASE_COST * Balance.EXPAND_GROWTH, "다음 확장은 ×40")
	_equal(Workers.slots_of(Balance.Job.WATCH), 2, "칸 둘")
	_equal(Workers.assign(1, Balance.Job.WATCH), true, "이제 하나 더")


func _test_effects() -> void:
	_clean()
	Night.start_season(10)
	_close(Workers.shares(Balance.Job.WATCH), 0.0, "아무도 없으면 0")
	Workers.assign(0, Balance.Job.WATCH)  # 까마귀: 망보기에 두 몫
	_equal(Workers.watch_goldens(), 2, "까마귀는 망보기에 두 몫")
	Workers.assign(1, Balance.Job.DRY)    # 허수아비: 포자 말리기에 두 몫
	_close(Workers.dry_multiplier(), 1.0 + 0.15 * 2.0, "허수아비는 포자 말리기에 두 몫")
	_close(Night.cloud_dps(), Balance.cloud_dps(0) * 1.3, "구름 피해에 든다")
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Game.start_night()
	Night.begin(9)
	var golden := 0
	for i in Night.cell_count():
		golden += 1 if Night.kinds[i] == Balance.Crop.GOLDEN else 0
	_equal(golden >= 2, true, "망보기만큼 황금 이삭이 더 심긴다")
	Night.stop()
	Workers.assign(0, Balance.Job.CARRY)
	Game.last_haul = 1000.0
	var before := Game.vitality
	Workers._process(1.0 / 60.0 * 10.0)
	_close(Game.vitality - before, 1000.0 * 0.01 / 6.0, "생기 나르기: 낮에 초당 지난 밤의 1%")
	Game.start_night()
	before = Game.vitality
	Workers._process(1.0)
	_close(Game.vitality, before, "밤에는 나르지 않는다")
	Night.stop()


func _test_save() -> void:
	_clean()
	Night.start_season(20)
	Workers.extra_slots[Balance.Job.DRY] = 1
	Workers.assign(1, Balance.Job.DRY)
	Workers.assign(2, Balance.Job.DRY)
	var data := Save.to_dict()
	_equal(data.has("workers"), true, "저장에 아지트가 든다")
	Save.reset_data()
	_equal(Workers.worker_count(), 0, "초기화")
	Save.from_dict(data)
	_equal(Workers.best_ever, 20, "밭 기록 복원")
	_equal(Workers.worker_job(2), Balance.Job.DRY, "배치 복원")
	_equal(Workers.slots_of(Balance.Job.DRY), 2, "칸 복원")
	Workers.from_dict({"best_ever": 20, "jobs": [1, 1, 1], "extra_slots": [99]})
	_equal(Workers.used(Balance.Job.DRY), 1, "칸을 넘는 배치는 쉰다")
	_equal(Workers.extra_slots[0], Balance.MAX_EXTRA_SLOTS, "확장 상한")

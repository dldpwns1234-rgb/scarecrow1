extends "res://tests/test_case.gd"
## 저장·불러오기·내보내기·가져오기·초기화와 옛·망가진 저장 (CLAUDE.md 저장 규칙)


func run() -> void:
	_fresh()
	Game.rest = 123.0
	Game.nights = 4
	Game.best_haul = 77.0
	Upgrades.levels[Balance.Upgrade.TOXIN] = 3
	var data := Save.to_dict()
	_equal(data.has("save_version"), true, "save_version 필수")
	_fresh()
	Save.from_dict(data)
	_close(Game.rest, 123.0, "휴식 복원")
	_equal(Game.nights, 4, "밤 수 복원")
	_close(Game.best_haul, 77.0, "최고 기록 복원")
	_equal(Upgrades.level(Balance.Upgrade.TOXIN), 3, "업그레이드 복원")
	_equal(Game.is_night(), false, "불러오면 낮")

	var text := Save.export_string()
	_fresh()
	_equal(Save.import_string(text), true, "가져오기")
	_close(Game.rest, 123.0, "가져온 휴식")
	_equal(Save.import_string("이건 저장이 아니다"), false, "엉뚱한 글은 거절")
	_equal(Save.import_string(Marshalls.utf8_to_base64("{\"rest\": 1}")), false, "save_version 없는 JSON은 거절")

	Save.from_dict({"save_version": 1, "game": {"rest": -5.0}, "upgrades": {"levels": [999, "x"]}})
	_close(Game.rest, 0.0, "음수 휴식은 0")
	_equal(Upgrades.level(Balance.Upgrade.RADIUS), Balance.upgrade_max_level(Balance.Upgrade.RADIUS), "상한을 넘는 레벨은 상한으로")
	_equal(Upgrades.level(Balance.Upgrade.LONG_NIGHT), 0, "없는 칸은 0")
	Save.from_dict({"save_version": 1})
	_close(Game.rest, 0.0, "빈 저장은 처음 상태")

	Game.rest = 50.0
	Save.save_game()
	_fresh()
	_equal(Save.load_game(), true, "파일에서 불러오기")
	_close(Game.rest, 50.0, "파일의 휴식")
	Save.reset_data()
	_close(Game.rest, 0.0, "데이터 초기화")
	_fresh()

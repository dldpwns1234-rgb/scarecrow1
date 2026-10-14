extends "res://tests/test_case.gd"
## 효과음과 소리 설정: 시그널에 소리가 붙는지, 같은 소리의 최소 간격, 꺼짐, 구매는 버튼 프레임에만, 새벽은 밤 뒤에만, 소리 설정 저장


func run() -> void:
	_fresh()
	Prefs.reset()
	Sfx.unlocked = true
	Sfx.reset_limits()
	Game.start_night()
	_equal(int(Sfx.played.get("night_start", 0)), 1, "밤이 시작되면 소리")
	Night.pulsed.emit()
	Night.pulsed.emit()
	_equal(int(Sfx.played.get("pulse", 0)), 1, "최소 간격 안의 같은 소리는 하나만")
	Night.crop_withered.emit(0, 1.0)
	_equal(int(Sfx.played.get("wither", 0)), 1, "시듦 소리")
	Game.finish_night()
	_equal(int(Sfx.played.get("dawn", 0)), 1, "새벽 소리")
	Save.reset_data()
	_equal(int(Sfx.played.get("dawn", 0)), 1, "데이터 초기화의 낮은 조용하다")

	Game.vitality = 1000.0
	Upgrades.buy(Balance.Upgrade.RADIUS)
	_equal(int(Sfx.played.get("buy", 0)), 0, "버튼 없이 오른 레벨은 조용하다")
	Sfx.reset_limits()
	Sfx.note_button_press()
	Upgrades.buy(Balance.Upgrade.TOXIN)
	_equal(int(Sfx.played.get("buy", 0)), 1, "버튼을 누른 프레임에 오른 레벨은 구매 소리")

	Prefs.set_sfx_on(false)
	Sfx.reset_limits()
	Night.crow_pecked.emit(0)
	_equal(int(Sfx.played.get("crow", 0)), 0, "효과음을 끄면 조용하다")
	var data := Save.to_dict()
	Prefs.reset()
	Save.from_dict(data)
	_equal(Prefs.sfx_on, false, "소리 설정 저장")
	Prefs.reset()
	_equal(Prefs.sfx_on, true, "기본은 켬")
	Sfx.unlocked = not OS.has_feature("web")
	_fresh()

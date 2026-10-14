extends "res://tests/test_case.gd"
## 효과음과 소리 설정: 시그널에 소리가 붙는지, 낮·밤 곡, 같은 소리의 최소 간격, 꺼짐, 구매는 버튼 프레임에만, 새벽은 밤 뒤에만, 소리 설정 저장


func run() -> void:
	_fresh()
	Prefs.reset()
	Sfx.unlocked = true
	Sfx.reset_limits()
	Game.start_night()
	_equal(int(Sfx.played.get("night_start", 0)), 1, "밤이 시작되면 소리")
	_equal(Sfx.music_track, "harvest" if Balance.is_harvest(Night.field_level) else "night", "밤에는 밤 곡 (수확일이면 수확일 곡)")
	Night.pulsed.emit()
	Night.pulsed.emit()
	_equal(int(Sfx.played.get("pulse", 0)), 1, "최소 간격 안의 같은 소리는 하나만")
	Night.crop_withered.emit(0, 1.0)
	_equal(int(Sfx.played.get("wither", 0)), 1, "시듦 소리")
	Game.finish_night()
	_equal(int(Sfx.played.get("dawn", 0)), 1, "새벽 소리")
	_equal(Sfx.music_track, "day", "낮에는 낮 곡")
	Night.best_level = Balance.HARVEST_INTERVAL
	Night.choose_level(Balance.HARVEST_INTERVAL)
	Game.start_night()
	_equal(Sfx.music_track, "harvest", "수확일 밤에는 수확일 곡")
	Game.finish_night()
	Night.reset()
	Winter.slept.emit(1.0)
	_equal(int(Sfx.played.get("sleep", 0)), 1, "겨울잠 소리")
	Night.storm_pulsed.emit()
	_equal(int(Sfx.played.get("storm", 0)), 1, "역병 폭풍 소리")
	Night.farmer_sprayed.emit(0)
	Night.crop_regrown.emit(0)
	_equal([int(Sfx.played.get("spray", 0)), int(Sfx.played.get("sprout", 0))], [1, 1], "약 치기·다시 자람 소리")
	for skill in Balance.SKILLS.size():
		Night.skill_used.emit(skill)
	_equal(int(Sfx.played.get("skill_storm", 0)) + int(Sfx.played.get("skill_flock", 0)) + int(Sfx.played.get("skill_sigh", 0)) + int(Sfx.played.get("skill_tide", 0)), Balance.SKILLS.size(), "스킬마다 소리")
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

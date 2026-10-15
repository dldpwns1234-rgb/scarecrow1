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
	_layers()
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
	var skill_sounds := 0
	for cue in Sfx.SKILL_CUES:
		skill_sounds += int(Sfx.played.get(cue, 0))
	_equal(skill_sounds, Balance.SKILLS.size(), "스킬마다 소리")
	Night.crop_burst.emit(0, 1.5)
	Night.seeds_flung.emit(0, PackedInt32Array([1]))
	Night.chain_struck.emit(0, 1)
	_equal([int(Sfx.played.get("burst", 0)), int(Sfx.played.get("seeds", 0)), int(Sfx.played.get("zap", 0))], [1, 1, 1], "수박 터짐·해바라기 씨앗·덩굴 번개 소리")
	Sfx.play("chain", 2.0)
	_close(Sfx.last_pitch, 2.0, "높이를 주면 흔들지 않고 그 높이 (풍작 콤보의 연쇄음)")
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


## 밤 곡의 겹: 바탕은 늘, 하프·오카리나·높은 현은 밭 단계로, 반딧불 종은 풍작 뒤 잠깐
func _layers() -> void:
	Sfx._swell_left = 0.0  # 앞 스위트(도깨비불)가 부풀린 반딧불 종을 비운다
	Night.best_level = 30
	Night.choose_level(1)
	Game.start_night()
	_equal(Sfx.is_layer_on("bed"), true, "바탕 겹은 늘")
	_equal(Sfx.is_layer_on("harp"), false, "첫 밭에는 하프가 없다")
	Game.finish_night()
	Night.choose_level(9)
	_equal(Sfx.is_layer_on("harp") and Sfx.is_layer_on("melody"), true, "밭이 깊어지면 하프·오카리나가 들어온다")
	_equal(Sfx.is_layer_on("counter"), false, "높은 현은 감독관이 오는 25단계부터")
	Night.choose_level(26)
	_equal(Sfx.is_layer_on("counter"), true, "25단계를 넘으면 높은 현")
	_equal(Sfx.is_layer_on("bells"), false, "반딧불 종은 풍작 전엔 조용")
	Sfx.swell()
	_equal(Sfx.is_layer_on("bells"), true, "풍작이 터지면 반딧불 종")
	for i in ceili(Sfx.SWELL_SECONDS / Balance.MAX_DELTA) + 1:  # 한 프레임은 MAX_DELTA까지만 센다
		Sfx._process(Balance.MAX_DELTA)
	_equal(Sfx.is_layer_on("bells"), false, "조금 지나면 다시 조용")
	var night := (load(Sfx.MUSIC_FILES["night"]) as AudioStreamSynchronized)
	_equal(night != null and night.stream_count == Sfx.NIGHT_LAYERS.size(), true, "밤 곡은 겹 다섯을 묶은 것")

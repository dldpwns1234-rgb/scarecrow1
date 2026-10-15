extends Node
## 작물 숙련과 업적 (방장 2026-10-15 #587, 장르 조사 제안 8·9). 겨울잠을 넘어 남는 기록: 작물마다 시든 수, 잡은 도깨비불, 터진 스킬, 한 밤 가장 많은 물결, 연 업적.
## 기록이 업적 목표에 닿으면 연다 (밤이 끝날 때·물결이 바뀔 때·겨울잠·도깨비불을 잡을 때 잰다). 숙련은 시든 수가 다음 목표에 닿는 순간 오른다.
## 효과는 Night가 vitality_multiplier()·mastery_multiplier()로 묻는다. 수치는 Balance(balance/feats.gd). 화면(도감·업적 탭)은 윤슬: 시그널과 아래 조회 함수만 쓴다

signal achievement_unlocked(index: int)    # Balance.ACHIEVEMENTS 순서
signal mastery_changed(crop: int, level: int)

var withered: Array[float] = []   # 작물 종류마다 시든 수 (Balance.Crop 순서)
var wisps: int = 0                # 잡은 도깨비불
var skills: int = 0               # 터진 스킬
var best_waves: int = 0           # 한 밤에 가장 많이 정복한 수
var unlocked: Array[bool] = []    # 업적마다 열렸는지
var _mastery: Array[int] = []     # 작물마다 숙련 (시든 수에서 다시 셀 수 있지만 시듦마다 로그를 피한다)
var _next: Array[float] = []      # 작물마다 다음 숙련에 닿는 시든 수
var _count: int = 0               # 연 업적 수


func _ready() -> void:
	reset()
	Night.crop_withered.connect(_on_withered.unbind(1))
	Night.skill_used.connect(_on_skill.unbind(1))
	Night.wisp_caught.connect(_on_wisp.unbind(2))
	Night.wave_started.connect(_on_wave)
	Game.night_finished.connect(_check.unbind(1))
	Winter.slept.connect(_check.unbind(1))


## 데이터 초기화에서만 부른다
func reset() -> void:
	withered.clear()
	withered.resize(Balance.CROPS.size())
	withered.fill(0.0)
	wisps = 0
	skills = 0
	best_waves = 0
	unlocked.clear()
	unlocked.resize(Balance.ACHIEVEMENTS.size())
	unlocked.fill(false)
	_count = 0
	_rebuild_mastery()


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for i in unlocked.size():
		if unlocked[i]:
			ids.append(Balance.ACHIEVEMENTS[i]["id"])
	return {"withered": withered.duplicate(), "wisps": wisps, "skills": skills, "best_waves": best_waves, "achievements": ids}


## 없는 필드는 0으로. 업적은 id로 찾는다 (표에서 빠진 id는 버린다)
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("withered", [])
	if saved is Array:
		for i in mini((saved as Array).size(), withered.size()):
			withered[i] = Balance.cap(maxf(float(saved[i]), 0.0))
	wisps = maxi(int(data.get("wisps", 0)), 0)
	skills = maxi(int(data.get("skills", 0)), 0)
	best_waves = maxi(int(data.get("best_waves", 0)), 0)
	var ids: Variant = data.get("achievements", [])
	if ids is Array:
		for i in Balance.ACHIEVEMENTS.size():
			if (ids as Array).has(Balance.ACHIEVEMENTS[i]["id"]):
				unlocked[i] = true
				_count += 1
	_rebuild_mastery()


func mastery(crop: int) -> int:
	return _mastery[crop]


## 작물 숙련 합 (업적 목표)
func mastery_total() -> int:
	var total := 0
	for level in _mastery:
		total += level
	return total


func unlocked_count() -> int:
	return _count


## 업적이 모든 생기에 곱하는 값
func vitality_multiplier() -> float:
	return Balance.feats_multiplier(_count)


## 숙련이 그 작물의 생기에 곱하는 값
func mastery_multiplier(crop: int) -> float:
	return Balance.mastery_multiplier(_mastery[crop]) if crop >= 0 and crop < _mastery.size() else 1.0


## 업적 하나의 지금 기록 (화면의 진행 막대용)
func stat_value(stat: int) -> float:
	match stat:
		Balance.Stat.NIGHTS:
			return float(Game.nights)
		Balance.Stat.BEST_LEVEL:
			return float(maxi(Workers.best_ever, Night.best_level))
		Balance.Stat.OFFERED:
			return Game.offered
		Balance.Stat.WITHERED:
			var total := 0.0
			for count in withered:
				total += count
			return total
		Balance.Stat.BEST_HAUL:
			return maxf(Game.best_haul, Game.night_haul)
		Balance.Stat.WAVES:
			return float(best_waves)
		Balance.Stat.SLEEPS:
			return float(Winter.sleeps)
		Balance.Stat.WISPS:
			return float(wisps)
		Balance.Stat.SKILLS:
			return float(skills)
		Balance.Stat.MASTERY:
			return float(mastery_total())
		Balance.Stat.REST:
			return Game.promised_rest_seconds()
	return 0.0


## 기록이 목표에 닿은 업적을 연다
func _check() -> void:
	for i in Balance.ACHIEVEMENTS.size():
		if unlocked[i]:
			continue
		var entry: Dictionary = Balance.ACHIEVEMENTS[i]
		if stat_value(int(entry["stat"])) >= float(entry["goal"]):
			unlocked[i] = true
			_count += 1
			achievement_unlocked.emit(i)


func _on_withered(index: int) -> void:
	var crop := Night.kinds[index]
	if crop < 0 or crop >= withered.size():
		return
	withered[crop] += 1.0
	if withered[crop] >= _next[crop] and _mastery[crop] < Balance.MASTERY_MAX:
		_mastery[crop] = Balance.mastery_level(withered[crop])
		_next[crop] = Balance.mastery_goal(_mastery[crop] + 1)
		mastery_changed.emit(crop, _mastery[crop])


func _on_skill() -> void:
	skills += 1


func _on_wisp() -> void:
	wisps += 1
	_check()


func _on_wave(waves: int) -> void:
	best_waves = maxi(best_waves, waves)
	_check()


func _rebuild_mastery() -> void:
	_mastery.clear()
	_next.clear()
	for crop in withered.size():
		var level := Balance.mastery_level(withered[crop])
		_mastery.append(level)
		_next.append(Balance.mastery_goal(level + 1))

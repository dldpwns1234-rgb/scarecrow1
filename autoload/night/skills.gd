extends "res://autoload/night/critters.gd"
## Night 2.5부: 밤 스킬 (방장 2026-10-14: 역병 폭풍을 지속형으로, 스킬을 다양하게. 2026-10-15: 누르지 않고 저절로 터지게). 어둠의 나무 칸을 사면 열린다.
## 타수형은 구름이 친 작물 수(night.gd의 _pulse가 _count_cloud_hits, 작물 하나가 한 타)를 세어 다 차면, 확률형은 작물이 시들 때(night/crops.gd가 _roll_wither_skills) 확률로 터진다.
## 역병 폭풍(켜 둔 동안 구름 반경·피해↑), 까마귀 떼(켜 둔 동안 까마귀가 빨리 쫌), 짚돌이의 한숨(구름 안에 한꺼번에), 역병 파도(작물 일부가 번짐),
## 어둠의 장막(켜 둔 동안 지키는 이가 잠듦), 수확의 낫(약한 작물을 한꺼번에), 썩은 비(켜 둔 동안 밭 전체에), 연쇄 시듦(켜 둔 동안 시들면 옆으로. night/crops.gd).
## 화면은 charge·rest_left·active_left를 읽어 게이지만 그린다. 시듦·번짐(_damage·_infect)은 night/waves.gd가 채운다

signal skill_used(skill: int)
signal skill_ended(skill: int)  # 지속형이 끝났다
signal storm_pulsed()           # 역병 폭풍을 켰다 (소리·구름 연출)

var charge: Array[int] = []           # 타수형이 센 박자 (Balance.Skill 순서). 밤마다 0에서
var rest_left: Array[float] = []      # 확률형이 터진 뒤 쉬는 남은 초
var active_left: Array[float] = []    # 지속형이 켜져 남은 초
var _summoned: int = 0                # 까마귀 떼가 불러온 임시 까마귀 수
var _rain_left: float = 0.0           # 썩은 비가 다음에 내리기까지 남은 초


func skill_level(skill: int) -> int:
	return Upgrades.level(Balance.skill_upgrade(skill))


func is_skill_unlocked(skill: int) -> bool:
	return skill_level(skill) > 0


func is_skill_active(skill: int) -> bool:
	return skill < active_left.size() and active_left[skill] > 0.0


## 스킬을 터뜨린다 (타수·확률이 차면 저절로 부른다. 테스트·캡처는 바로 부른다). 밤이 아니거나, 안 열렸거나, 켜져 있으면 false
func use_skill(skill: int) -> bool:
	if not active or not is_skill_unlocked(skill) or is_skill_active(skill):
		return false
	var level := skill_level(skill)
	charge[skill] = 0
	rest_left[skill] = Balance.skill_rest(skill, level)
	active_left[skill] = Balance.skill_duration(skill, level)
	match skill:
		Balance.Skill.STORM:
			storm_pulsed.emit()
		Balance.Skill.FLOCK:
			if _crow_left.is_empty():
				_summoned = Balance.FLOCK_SUMMONED
				for i in _summoned:
					_crow_left.append(Balance.CROW_INTERVAL * float(i + 1) / float(_summoned) / Balance.FLOCK_SPEED)
		Balance.Skill.SIGH:
			_sigh(level)
		Balance.Skill.TIDE:
			_tide(level)
		Balance.Skill.REAP:
			_reap(level)
		Balance.Skill.RAIN:
			_rain_left = 0.0
	skill_used.emit(skill)
	return true


## 구름 반경: 역병 폭풍 동안 ×1.8
func cloud_radius() -> float:
	return super() * (Balance.STORM_RADIUS if is_skill_active(Balance.Skill.STORM) else 1.0)


## 구름 피해: 역병 폭풍 동안 ×1.5
func cloud_dps() -> float:
	return Balance.cap(super() * (Balance.STORM_DAMAGE if is_skill_active(Balance.Skill.STORM) else 1.0))


## 구름 박자 하나가 작물 hits개를 쳤다: 켜져 있지 않은 타수형마다 그만큼 차고, 다 차면 터진다 (몰린 곳을 칠수록 빨리 찬다)
func _count_cloud_hits(hits: int) -> void:
	for skill in charge.size():
		if not Balance.counts_hits(skill) or not is_skill_unlocked(skill) or is_skill_active(skill):
			continue
		charge[skill] += hits
		if charge[skill] >= Balance.skill_need(skill, skill_level(skill)):
			use_skill(skill)


## 작물 하나가 시들었다: 쉬지 않는 확률형마다 굴린다
func _roll_wither_skills() -> void:
	for skill in rest_left.size():
		if not active or Balance.counts_hits(skill) or not is_skill_unlocked(skill) or is_skill_active(skill) or rest_left[skill] > 0.0:
			continue
		if rng.randf() < Balance.skill_chance(skill, skill_level(skill)):
			use_skill(skill)


## 밤 시작: 타수는 0에서, 확률형은 쉬지 않고
func _reset_skills() -> void:
	charge.clear()
	rest_left.clear()
	active_left.clear()
	for i in Balance.SKILLS.size():
		charge.append(0)
		rest_left.append(0.0)
		active_left.append(0.0)
	_summoned = 0
	_rain_left = 0.0


func _tick_skills(dt: float) -> void:
	if is_skill_active(Balance.Skill.RAIN):
		_rain_left -= dt
		while active and _rain_left <= 0.0:
			_rain_left += Balance.CLOUD_TICK
			_rain(Balance.CLOUD_TICK)
	for skill in rest_left.size():
		rest_left[skill] = maxf(rest_left[skill] - dt, 0.0)
		if active_left[skill] > 0.0:
			active_left[skill] -= dt
			if active_left[skill] <= 0.0:
				active_left[skill] = 0.0
				_end_skill(skill)


func _end_skill(skill: int) -> void:
	if skill == Balance.Skill.FLOCK and _summoned > 0:
		_crow_left.resize(maxi(_crow_left.size() - _summoned, 0))
		_summoned = 0
	skill_ended.emit(skill)


func _crow_speed() -> float:
	return Balance.FLOCK_SPEED if is_skill_active(Balance.Skill.FLOCK) else 1.0


func _veiled() -> bool:
	return is_skill_active(Balance.Skill.VEIL)


## 짚돌이의 한숨: 구름 안 작물에 한꺼번에 (지키는 이의 약은 듣는다)
func _sigh(level: int) -> void:
	var damage := Balance.sigh_damage(cloud_dps(), level)
	var radius := cloud_radius()
	for i in kinds.size():
		if active and is_alive(i) and cell_position(i).distance_to(cloud) <= radius:
			_damage(i, damage * guard(i))


## 역병 파도: 살아 있는 작물 중 일부(무작위)가 번짐에 걸린다
func _tide(level: int) -> void:
	var candidates: Array[int] = []
	for i in kinds.size():
		if is_alive(i) and infected[i] == 0:
			candidates.append(i)
	var count := ceili(alive_count() * Balance.tide_share(level))
	for _i in mini(count, candidates.size()):
		var pick := rng.randi_range(0, candidates.size() - 1)
		_infect(candidates[pick])
		candidates.remove_at(pick)


## 수확의 낫: 체력이 최대의 몫 아래로 준 작물을 밭 어디서든 쓰러뜨린다 (고른 뒤 친다: 도중에 정복하면 새 물결은 안 친다)
func _reap(level: int) -> void:
	var share := Balance.reap_share(level)
	var picks: Array[int] = []
	for i in kinds.size():
		if is_alive(i) and hp[i] <= max_hp[i] * share:
			picks.append(i)
	var wave := waves_cleared()
	for i in picks:
		if not active or waves_cleared() != wave:
			return
		if is_alive(i):
			_damage(i, hp[i])


## 썩은 비 한 번: 살아 있는 작물마다 (지키는 이의 약은 듣는다)
func _rain(seconds: float) -> void:
	var amount := Balance.rain_dps(cloud_dps(), skill_level(Balance.Skill.RAIN)) * seconds
	for i in kinds.size():
		if active and is_alive(i):
			_damage(i, amount * guard(i))


## night/waves.gd가 채운다 (이번 밤에 정복한 수)
func waves_cleared() -> int:
	return 0

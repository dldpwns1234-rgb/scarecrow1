extends "res://autoload/night/critters.gd"
## Night 2.5부: 밤 스킬 (방장 2026-10-14: 역병 폭풍을 지속형으로, 스킬을 다양하게). 어둠의 나무 칸을 사면 열리고 밤마다 쿨타임 없이 시작한다.
## 역병 폭풍(켜 둔 동안 구름 반경·피해↑), 까마귀 떼(켜 둔 동안 까마귀가 빨리 쫌), 짚돌이의 한숨(구름 안에 한꺼번에), 역병 파도(작물 일부가 번짐).
## 화면은 use_skill()을 부르고 cooldown_left·active_left를 읽어 그린다. 시듦·번짐(_damage·_infect)은 night/waves.gd가 채운다

signal skill_used(skill: int)
signal skill_ended(skill: int)  # 지속형이 끝났다
signal storm_pulsed()           # 역병 폭풍을 켰다 (소리·구름 연출)

var cooldown_left: Array[float] = []  # 스킬마다 남은 쿨타임 (Balance.Skill 순서)
var active_left: Array[float] = []    # 지속형이 켜져 남은 초
var _summoned: int = 0                # 까마귀 떼가 불러온 임시 까마귀 수


func skill_level(skill: int) -> int:
	return Upgrades.level(Balance.skill_upgrade(skill))


func is_skill_unlocked(skill: int) -> bool:
	return skill_level(skill) > 0


func is_skill_active(skill: int) -> bool:
	return skill < active_left.size() and active_left[skill] > 0.0


func can_use(skill: int) -> bool:
	return active and is_skill_unlocked(skill) and cooldown_left[skill] <= 0.0 and not is_skill_active(skill)


## 스킬을 쓴다. 못 쓰면 false
func use_skill(skill: int) -> bool:
	if not can_use(skill):
		return false
	var level := skill_level(skill)
	cooldown_left[skill] = Balance.skill_cooldown(skill, level)
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
	skill_used.emit(skill)
	return true


## 구름 반경: 역병 폭풍 동안 ×1.8
func cloud_radius() -> float:
	return super() * (Balance.STORM_RADIUS if is_skill_active(Balance.Skill.STORM) else 1.0)


## 구름 피해: 역병 폭풍 동안 ×1.5
func cloud_dps() -> float:
	return Balance.cap(super() * (Balance.STORM_DAMAGE if is_skill_active(Balance.Skill.STORM) else 1.0))


## 밤 시작: 모든 스킬이 바로 쓸 수 있다
func _reset_skills() -> void:
	cooldown_left.clear()
	active_left.clear()
	for i in Balance.SKILLS.size():
		cooldown_left.append(0.0)
		active_left.append(0.0)
	_summoned = 0


func _tick_skills(dt: float) -> void:
	for skill in cooldown_left.size():
		cooldown_left[skill] = maxf(cooldown_left[skill] - dt, 0.0)
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

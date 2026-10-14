extends "res://autoload/balance/farmer.gd"
## Balance 2.6부: 밤 스킬 (방장 2026-10-14: 역병 폭풍이 한 번 크게 치고 끝나 밋밋하다, 스킬을 다양하게). 어둠의 나무 칸을 사면 열리고, 레벨마다 세진다.
## 밤마다 쿨타임 없이 시작한다. 지속형은 켜 둔 동안 효과, 즉발형은 누르는 순간 효과. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

enum Skill { STORM, FLOCK, SIGH, TIDE }
## upgrade: 여는 칸. duration 0이면 즉발. 레벨마다 지속 +duration_step, 쿨타임 −cooldown_step (1레벨 값이 기본)
const SKILLS: Array[Dictionary] = [
	{"name": "역병 폭풍", "note": "구름이 부풀어 반경 ×1.8, 피해 ×1.5", "upgrade": Upgrade.STORM, "duration": 6.0, "duration_step": 1.0, "cooldown": 30.0, "cooldown_step": 2.0},
	{"name": "까마귀 떼", "note": "까마귀가 네 배 빨리 쫀다 (없으면 셋이 날아든다)", "upgrade": Upgrade.FLOCK, "duration": 5.0, "duration_step": 1.0, "cooldown": 35.0, "cooldown_step": 2.0},
	{"name": "짚돌이의 한숨", "note": "구름 안 작물에 구름 피해 8초 몫을 한꺼번에", "upgrade": Upgrade.SIGH, "duration": 0.0, "duration_step": 0.0, "cooldown": 15.0, "cooldown_step": 1.0},
	{"name": "역병 파도", "note": "살아 있는 작물의 25%가 번짐에 걸린다", "upgrade": Upgrade.TIDE, "duration": 0.0, "duration_step": 0.0, "cooldown": 40.0, "cooldown_step": 3.0},
]
const STORM_RADIUS: float = 1.8          # 역병 폭풍 동안 구름 반경 배율
const STORM_DAMAGE: float = 1.5          # 역병 폭풍 동안 구름 피해 배율
const FLOCK_SPEED: float = 4.0           # 까마귀 떼 동안 쪼는 빠르기 배율
const FLOCK_SUMMONED: int = 3            # 까마귀가 없으면 날아드는 수
const SIGH_SECONDS: float = 8.0          # 한숨: 구름 피해 이만큼(초) 몫 (레벨마다 +4초)
const SIGH_SECONDS_PER_LEVEL: float = 4.0
const TIDE_SHARE: float = 0.25           # 역병 파도: 살아 있는 작물 중 이만큼 (레벨마다 +5%p)
const TIDE_SHARE_PER_LEVEL: float = 0.05
const MIN_COOLDOWN: float = 5.0


func skill_name(skill: int) -> String:
	return SKILLS[skill]["name"]


func skill_note(skill: int) -> String:
	return SKILLS[skill]["note"]


func skill_upgrade(skill: int) -> int:
	return SKILLS[skill]["upgrade"]


func is_lasting(skill: int) -> bool:
	return float(SKILLS[skill]["duration"]) > 0.0


## 지속 시간 (초). 즉발형이면 0
func skill_duration(skill: int, level: int) -> float:
	if level <= 0 or not is_lasting(skill):
		return 0.0
	return float(SKILLS[skill]["duration"]) + float(SKILLS[skill]["duration_step"]) * (level - 1)


func skill_cooldown(skill: int, level: int) -> float:
	return maxf(float(SKILLS[skill]["cooldown"]) - float(SKILLS[skill]["cooldown_step"]) * maxi(level - 1, 0), MIN_COOLDOWN)


## 한숨의 피해 = 구름 초당 피해 × (8 + 4 × (레벨 − 1))초
func sigh_damage(cloud: float, level: int) -> float:
	return cap(cloud * (SIGH_SECONDS + SIGH_SECONDS_PER_LEVEL * maxi(level - 1, 0)))


## 역병 파도가 번지게 하는 비율
func tide_share(level: int) -> float:
	return minf(TIDE_SHARE + TIDE_SHARE_PER_LEVEL * maxi(level - 1, 0), 1.0)

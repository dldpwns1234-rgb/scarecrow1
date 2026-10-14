extends "res://autoload/balance/farmer.gd"
## Balance 2.6부: 밤 스킬 (방장 2026-10-14: 역병 폭풍이 한 번 크게 치고 끝나 밋밋하다, 스킬을 다양하게. 2026-10-15: 누르지 않고 저절로 터지게).
## 어둠의 나무 칸을 사면 열리고, 레벨마다 세진다. 타수형(hits)은 구름이 친 작물 수(작물 하나가 한 타)를 세어 need에 닿으면 터지고, 확률형(wither)은 작물이 시들 때마다
## chance로 터진 뒤 rest초 동안 쉰다. 지속형은 켜진 동안 효과(그동안 타수를 세지 않는다), 즉발형은 터지는 순간 효과. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

enum Skill { STORM, FLOCK, SIGH, TIDE, VEIL, REAP, RAIN, CHAIN }
## upgrade: 여는 칸. duration 0이면 즉발. 레벨마다 지속 +duration_step, 필요한 타수 −need_step, 확률 +chance_step, 쉬는 시간 −rest_step (1레벨 값이 기본)
const SKILLS: Array[Dictionary] = [
	{"name": "역병 폭풍", "note": "구름이 부풀어 반경 ×1.8, 피해 ×1.5", "upgrade": Upgrade.STORM, "duration": 6.0, "duration_step": 1.0, "trigger": "hits", "need": 120, "need_step": 12},
	{"name": "까마귀 떼", "note": "까마귀가 네 배 빨리 쫀다 (없으면 셋이 날아든다)", "upgrade": Upgrade.FLOCK, "duration": 5.0, "duration_step": 1.0, "trigger": "hits", "need": 180, "need_step": 18},
	{"name": "짚돌이의 한숨", "note": "구름 안 작물에 구름 피해 8초 몫을 한꺼번에", "upgrade": Upgrade.SIGH, "duration": 0.0, "duration_step": 0.0, "trigger": "hits", "need": 80, "need_step": 8},
	{"name": "역병 파도", "note": "살아 있는 작물의 25%가 번짐에 걸린다", "upgrade": Upgrade.TIDE, "duration": 0.0, "duration_step": 0.0, "trigger": "wither", "chance": 0.03, "chance_step": 0.01, "rest": 20.0, "rest_step": 2.0},
	{"name": "어둠의 장막", "note": "지키는 이들이 잠든다 (약·심기 멈춤)", "upgrade": Upgrade.VEIL, "duration": 6.0, "duration_step": 1.0, "trigger": "hits", "need": 180, "need_step": 18},
	{"name": "수확의 낫", "note": "체력이 30% 아래인 작물을 한꺼번에 쓰러뜨린다", "upgrade": Upgrade.REAP, "duration": 0.0, "duration_step": 0.0, "trigger": "wither", "chance": 0.04, "chance_step": 0.01, "rest": 12.0, "rest_step": 1.0},
	{"name": "썩은 비", "note": "밭 전체에 구름 피해의 25%가 내린다", "upgrade": Upgrade.RAIN, "duration": 8.0, "duration_step": 1.0, "trigger": "hits", "need": 220, "need_step": 22},
	{"name": "연쇄 시듦", "note": "작물이 시들면 옆 작물마다 제 체력의 30%를 잃는다", "upgrade": Upgrade.CHAIN, "duration": 6.0, "duration_step": 1.0, "trigger": "wither", "chance": 0.02, "chance_step": 0.005, "rest": 20.0, "rest_step": 2.0},
]
const STORM_RADIUS: float = 1.8          # 역병 폭풍 동안 구름 반경 배율
const STORM_DAMAGE: float = 1.5          # 역병 폭풍 동안 구름 피해 배율
const FLOCK_SPEED: float = 4.0           # 까마귀 떼 동안 쪼는 빠르기 배율
const FLOCK_SUMMONED: int = 3            # 까마귀가 없으면 날아드는 수
const SIGH_SECONDS: float = 8.0          # 한숨: 구름 피해 이만큼(초) 몫 (레벨마다 +4초)
const SIGH_SECONDS_PER_LEVEL: float = 4.0
const TIDE_SHARE: float = 0.25           # 역병 파도: 살아 있는 작물 중 이만큼 (레벨마다 +5%p)
const TIDE_SHARE_PER_LEVEL: float = 0.05
const REAP_SHARE: float = 0.3           # 수확의 낫: 체력이 최대의 이만큼 아래인 작물 (레벨마다 +5%p, 60%까지)
const REAP_SHARE_PER_LEVEL: float = 0.05
const REAP_MAX_SHARE: float = 0.6
const RAIN_SHARE: float = 0.25          # 썩은 비: 밭 전체에 구름 초당 피해의 이만큼 (레벨마다 +5%p). 구름 박자마다 내린다
const RAIN_SHARE_PER_LEVEL: float = 0.05
const CHAIN_SHARE: float = 0.3          # 연쇄 시듦: 옆 작물이 제 최대 체력의 이만큼을 잃는다 (레벨마다 +5%p)
const CHAIN_SHARE_PER_LEVEL: float = 0.05
const MIN_NEED: int = 30               # 타수형이 터지는 데 드는 타수의 바닥
const MAX_CHANCE: float = 0.5           # 확률형의 천장
const MIN_REST: float = 4.0             # 확률형이 터진 뒤 쉬는 시간의 바닥 (연쇄로 한 프레임에 수십 개가 시들어도 한 번만)


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


## 구름 박자를 세어 터지는지 (아니면 작물이 시들 때 확률로)
func counts_hits(skill: int) -> bool:
	return SKILLS[skill]["trigger"] == "hits"


## 타수형: 터지는 데 드는 박자 수
func skill_need(skill: int, level: int) -> int:
	if not counts_hits(skill):
		return 0
	return maxi(int(SKILLS[skill]["need"]) - int(SKILLS[skill]["need_step"]) * maxi(level - 1, 0), MIN_NEED)


## 확률형: 작물 하나가 시들 때 터질 확률
func skill_chance(skill: int, level: int) -> float:
	if counts_hits(skill) or level <= 0:
		return 0.0
	return minf(float(SKILLS[skill]["chance"]) + float(SKILLS[skill]["chance_step"]) * (level - 1), MAX_CHANCE)


## 확률형: 터진 뒤 쉬는 초 (타수형은 0)
func skill_rest(skill: int, level: int) -> float:
	if counts_hits(skill):
		return 0.0
	return maxf(float(SKILLS[skill]["rest"]) - float(SKILLS[skill]["rest_step"]) * maxi(level - 1, 0), MIN_REST)


## 한숨의 피해 = 구름 초당 피해 × (8 + 4 × (레벨 − 1))초
func sigh_damage(cloud: float, level: int) -> float:
	return cap(cloud * (SIGH_SECONDS + SIGH_SECONDS_PER_LEVEL * maxi(level - 1, 0)))


## 역병 파도가 번지게 하는 비율
func tide_share(level: int) -> float:
	return minf(TIDE_SHARE + TIDE_SHARE_PER_LEVEL * maxi(level - 1, 0), 1.0)


## 수확의 낫: 이 몫 아래로 체력이 준 작물을 쓰러뜨린다
func reap_share(level: int) -> float:
	return minf(REAP_SHARE + REAP_SHARE_PER_LEVEL * maxi(level - 1, 0), REAP_MAX_SHARE)


## 썩은 비: 밭 전체 작물 하나가 받는 초당 피해
func rain_dps(cloud: float, level: int) -> float:
	return cap(cloud * (RAIN_SHARE + RAIN_SHARE_PER_LEVEL * maxi(level - 1, 0)))


## 연쇄 시듦: 옆 작물이 잃는 제 최대 체력의 몫
func chain_share(level: int) -> float:
	return minf(CHAIN_SHARE + CHAIN_SHARE_PER_LEVEL * maxi(level - 1, 0), 1.0)

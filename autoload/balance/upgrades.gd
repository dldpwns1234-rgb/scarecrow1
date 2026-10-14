extends "res://autoload/balance/core.gd"
## Balance 1부: 어둠의 나무 (GDD 6절, 방장 2026-10-14). 생기로 산다. 가운데 '어둠의 계약'에서 네 갈래로 뻗는다:
## 위 = 역병 구름, 왼쪽 = 밤의 시간, 오른쪽 = 밭 살찌우기(상대 스펙: 작물이 단단해지지만 생기가 더 크게 는다), 아래 = 까마귀 사역마.
## requires는 그 업그레이드를 1레벨 이상 가져야 나타나고 열린다는 뜻 (-1이면 뿌리, 갈래 방향은 "branch"). requires는 늘 앞 번호다 (화면 배치가 기댄다).
## 효과의 공식은 balance/night.gd가 레벨을 받아 계산한다. 저장 순서라 새 업그레이드는 뒤에만 붙인다 (첫 배포 전에 한 번 다시 짰다, 2026-10-14)

enum Upgrade { RADIUS, LONG_NIGHT, FERTILE, CROW, TOXIN, SPREAD, ROT, REGROW, DUSK, DENSE, ROT_VALUE, PUMPKIN, BEAK, FEATHER }
const UPGRADES: Array[Dictionary] = [
	# 네 갈래의 뿌리
	{"name": "넓은 구름", "note": "역병 구름 반경 +10%", "max_level": 10, "base_cost": 10.0, "growth": 1.6, "requires": -1, "branch": "up"},
	{"name": "긴 밤", "note": "밤 +3초", "max_level": 10, "base_cost": 15.0, "growth": 1.7, "requires": -1, "branch": "left"},
	{"name": "비옥한 어둠", "note": "작물 체력 ×1.6, 생기 ×2", "max_level": 10, "base_cost": 40.0, "growth": 2.4, "requires": -1, "branch": "right"},
	{"name": "까마귀", "note": "까마귀 한 마리가 2초마다 작물을 쫀다", "max_level": 5, "base_cost": 120.0, "growth": 2.5, "requires": -1, "branch": "down"},
	# 위: 역병 구름
	{"name": "독한 포자", "note": "구름 피해 ×1.3", "max_level": 0, "base_cost": 15.0, "growth": 1.35, "requires": Upgrade.RADIUS},
	{"name": "번지는 곰팡이", "note": "시든 작물이 옆 작물로 번질 확률 +5%p", "max_level": 10, "base_cost": 80.0, "growth": 1.9, "requires": Upgrade.TOXIN},
	{"name": "썩은 뿌리", "note": "번진 작물이 받는 피해 +구름의 15%", "max_level": 10, "base_cost": 150.0, "growth": 1.8, "requires": Upgrade.SPREAD},
	# 왼쪽: 밤의 시간
	{"name": "다시 자라는 뿌리", "note": "시든 칸에 새 작물이 자란다 (12초, 레벨마다 15% 빨리)", "max_level": 10, "base_cost": 60.0, "growth": 1.9, "requires": Upgrade.LONG_NIGHT},
	{"name": "어스름", "note": "구름이 치는 박자 5% 빨리", "max_level": 8, "base_cost": 90.0, "growth": 2.0, "requires": Upgrade.LONG_NIGHT},
	# 오른쪽: 밭 살찌우기
	{"name": "빽빽한 밭", "note": "작물을 심는 칸 +7%p", "max_level": 10, "base_cost": 30.0, "growth": 1.75, "requires": Upgrade.FERTILE},
	{"name": "썩은 냄새", "note": "작물 하나의 생기 +20%", "max_level": 0, "base_cost": 25.0, "growth": 1.55, "requires": Upgrade.FERTILE},
	{"name": "탐스러운 호박", "note": "호박이 더 자주 (+2%p), 호박 생기 +25%", "max_level": 10, "base_cost": 100.0, "growth": 1.8, "requires": Upgrade.DENSE},
	# 아래: 까마귀 사역마
	{"name": "날카로운 부리", "note": "까마귀가 쪼는 피해 +50%", "max_level": 10, "base_cost": 200.0, "growth": 1.7, "requires": Upgrade.CROW},
	{"name": "검은 깃털", "note": "쪼인 작물이 번짐에 걸릴 확률 +15%p", "max_level": 6, "base_cost": 300.0, "growth": 2.0, "requires": Upgrade.BEAK},
]


func upgrade_name(index: int) -> String:
	return UPGRADES[index]["name"]


func upgrade_note(index: int) -> String:
	return UPGRADES[index]["note"]


## 0이면 상한 없음
func upgrade_max_level(index: int) -> int:
	return UPGRADES[index]["max_level"]


func upgrade_requires(index: int) -> int:
	return UPGRADES[index]["requires"]


## 다음 레벨 비용 (level → level + 1): 내림(기본 × 성장^level)
func upgrade_cost(index: int, level: int) -> float:
	var entry: Dictionary = UPGRADES[index]
	return cap(floor(float(entry["base_cost"]) * pow(float(entry["growth"]), level)))

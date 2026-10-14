extends "res://autoload/balance/core.gd"
## Balance 1부: 낮의 업그레이드 나무 (GDD 6절). 휴식으로 산다. requires는 그 업그레이드를 1레벨 이상 가져야 열린다는 뜻 (-1이면 처음부터).
## 효과의 공식(구름 반경·피해·밤 길이·작물 값·번짐·까마귀)은 balance/night.gd가 레벨을 받아 계산한다. 저장 순서라 새 업그레이드는 뒤에만 붙인다

enum Upgrade { RADIUS, TOXIN, LONG_NIGHT, ROT_VALUE, SPREAD, ROT, CROW, BEAK }
const UPGRADES: Array[Dictionary] = [
	{"name": "넓은 구름", "note": "역병 구름 반경 +10%", "max_level": 10, "base_cost": 10.0, "growth": 1.6, "requires": -1},
	{"name": "독한 포자", "note": "구름 피해 +25%", "max_level": 0, "base_cost": 15.0, "growth": 1.5, "requires": -1},
	{"name": "긴 밤", "note": "밤 +5초", "max_level": 10, "base_cost": 30.0, "growth": 1.8, "requires": Upgrade.RADIUS},
	{"name": "썩은 냄새", "note": "작물 하나의 휴식 +20%", "max_level": 0, "base_cost": 25.0, "growth": 1.55, "requires": Upgrade.TOXIN},
	{"name": "번지는 곰팡이", "note": "시든 작물이 옆 작물로 번질 확률 +5%p", "max_level": 10, "base_cost": 80.0, "growth": 1.9, "requires": Upgrade.ROT_VALUE},
	{"name": "썩은 뿌리", "note": "번진 작물이 받는 피해 +구름의 15%", "max_level": 10, "base_cost": 150.0, "growth": 1.8, "requires": Upgrade.SPREAD},
	{"name": "까마귀", "note": "까마귀 한 마리가 2초마다 작물을 쫀다", "max_level": 5, "base_cost": 200.0, "growth": 2.5, "requires": Upgrade.LONG_NIGHT},
	{"name": "날카로운 부리", "note": "까마귀가 쪼는 피해 +50%", "max_level": 10, "base_cost": 300.0, "growth": 1.7, "requires": Upgrade.CROW},
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

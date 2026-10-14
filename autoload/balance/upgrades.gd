extends "res://autoload/balance/core.gd"
## Balance 1부: 낮의 업그레이드 나무 (GDD 6절). 휴식으로 산다. requires는 그 업그레이드를 1레벨 이상 가져야 열린다는 뜻 (-1이면 처음부터).
## 수치는 첫 자리표다. 효과의 실제 공식(구름 반경·피해·밤 길이·작물 값·번짐)은 밤 공식 쪽에서 레벨을 읽어 쓴다

enum Upgrade { RADIUS, TOXIN, LONG_NIGHT, ROT_VALUE, SPREAD }
const UPGRADES: Array[Dictionary] = [
	{"name": "넓은 구름", "note": "역병 구름 반경 +10%", "max_level": 10, "base_cost": 10.0, "growth": 1.6, "requires": -1},
	{"name": "독한 포자", "note": "구름 피해 +25%", "max_level": 0, "base_cost": 15.0, "growth": 1.5, "requires": -1},
	{"name": "긴 밤", "note": "밤 +5초", "max_level": 10, "base_cost": 30.0, "growth": 1.8, "requires": Upgrade.RADIUS},
	{"name": "썩은 냄새", "note": "작물 하나의 휴식 +20%", "max_level": 0, "base_cost": 25.0, "growth": 1.55, "requires": Upgrade.TOXIN},
	{"name": "번지는 곰팡이", "note": "시든 작물이 옆 작물로 번질 확률 +5%p", "max_level": 10, "base_cost": 80.0, "growth": 1.9, "requires": Upgrade.ROT_VALUE},
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

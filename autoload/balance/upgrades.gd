extends "res://autoload/balance/core.gd"
## Balance 1부: 어둠의 나무 (GDD 6절, 방장 2026-10-14). 생기로 산다. 가운데 '어둠의 계약'에서 네 갈래로 뻗는다:
## 위 = 역병 구름, 왼쪽 = 밤의 시간, 오른쪽 = 밭 살찌우기(상대 스펙: 작물이 단단해지지만 생기가 더 크게 는다), 아래 = 까마귀 사역마.
## requires는 그 업그레이드를 1레벨 이상 가져야 나타나고 열린다는 뜻 (-1이면 뿌리, 갈래 방향은 "branch"). requires는 늘 앞 번호다 (화면 배치가 기댄다).
## 효과의 공식은 balance/night.gd가 레벨을 받아 계산한다. 저장 순서라 새 업그레이드는 뒤에만 붙인다 (첫 배포 전에 한 번 다시 짰다, 2026-10-14).
## 상한 있는 칸은 비용이 가파르게(×2.2~4) 오른다: 완만하면 15분 안에 다 팔려 수입이 폭발했다 (docs/BALANCE_SIM.md)

enum Upgrade { RADIUS, LONG_NIGHT, FERTILE, CROW, TOXIN, SPREAD, ROT, REGROW, DUSK, DENSE, ROT_VALUE, PUMPKIN, BEAK, FEATHER, RACKET, SEEP, GOLDEN, STORM, FRENZY, BOUNTY, CROW_KING, FLOCK, SIGH, TIDE, VEIL, REAP, RAIN, CHAIN }
const UPGRADES: Array[Dictionary] = [
	# 네 갈래의 뿌리
	{"name": "넓은 구름", "note": "역병 구름 반경 +10%", "max_level": 10, "base_cost": 10.0, "growth": 2.2, "requires": -1, "branch": "up"},
	{"name": "긴 밤", "note": "밤 +3초", "max_level": 10, "base_cost": 15.0, "growth": 2.3, "requires": -1, "branch": "left"},
	{"name": "비옥한 어둠", "note": "작물 체력 ×1.5, 생기 ×1.7", "max_level": 10, "base_cost": 40.0, "growth": 3.2, "requires": -1, "branch": "right"},
	{"name": "까마귀", "note": "까마귀 한 마리가 2초마다 작물을 쫀다", "max_level": 5, "base_cost": 120.0, "growth": 4.0, "requires": -1, "branch": "down"},
	# 위: 역병 구름
	{"name": "독한 포자", "note": "구름 피해 ×1.3", "max_level": 0, "base_cost": 15.0, "growth": 1.38, "requires": Upgrade.RADIUS},
	{"name": "번지는 곰팡이", "note": "시든 작물이 옆 작물로 번질 확률 +5%p", "max_level": 10, "base_cost": 80.0, "growth": 2.6, "requires": Upgrade.TOXIN},
	{"name": "썩은 뿌리", "note": "번진 작물이 받는 피해 +구름의 15%", "max_level": 10, "base_cost": 150.0, "growth": 2.6, "requires": Upgrade.SPREAD},
	# 왼쪽: 밤의 시간
	{"name": "다시 자라는 뿌리", "note": "시든 칸에 새 작물이 자란다 (15초, 레벨마다 10% 빨리)", "max_level": 8, "base_cost": 60.0, "growth": 2.8, "requires": Upgrade.LONG_NIGHT},
	{"name": "어스름", "note": "구름이 치는 박자 5% 빨리", "max_level": 8, "base_cost": 90.0, "growth": 3.0, "requires": Upgrade.LONG_NIGHT},
	# 오른쪽: 밭 살찌우기
	{"name": "빽빽한 밭", "note": "작물을 심는 칸 +7%p", "max_level": 10, "base_cost": 30.0, "growth": 2.2, "requires": Upgrade.FERTILE},
	{"name": "썩은 냄새", "note": "작물 하나의 생기 +20%", "max_level": 0, "base_cost": 25.0, "growth": 1.55, "requires": Upgrade.FERTILE},
	{"name": "탐스러운 호박", "note": "호박이 더 자주 (+2%p), 호박 생기 +25%", "max_level": 10, "base_cost": 100.0, "growth": 2.6, "requires": Upgrade.DENSE},
	# 아래: 까마귀 사역마
	{"name": "날카로운 부리", "note": "까마귀가 쪼는 피해 +50%", "max_level": 10, "base_cost": 200.0, "growth": 2.4, "requires": Upgrade.CROW},
	{"name": "검은 깃털", "note": "쪼인 작물이 번짐에 걸릴 확률 +15%p", "max_level": 6, "base_cost": 300.0, "growth": 3.5, "requires": Upgrade.BEAK},
	# 농부에 맞서는 칸과 황금 작물 (M3)
	{"name": "까마귀 소란", "note": "까마귀가 쫄 때마다 농부 하나가 0.4초 멈춘다 (멈춘 농부는 약을 못 친다)", "max_level": 5, "base_cost": 2000.0, "growth": 3.0, "requires": Upgrade.BEAK},
	{"name": "스며드는 독", "note": "농부가 약 친 작물도 피해가 덜 줄어든다 (+10%p)", "max_level": 5, "base_cost": 3000.0, "growth": 3.0, "requires": Upgrade.ROT},
	{"name": "황금 이삭", "note": "황금 작물이 더 자주 (+0.5%p). 황금 작물은 생기가 아주 많다", "max_level": 10, "base_cost": 500.0, "growth": 2.4, "requires": Upgrade.PUMPKIN},
	# 갈래 끝 칸 (후반에 고를 거리)
	{"name": "역병 폭풍", "note": "스킬: 6초 동안 구름이 부풀어 반경 ×1.8, 피해 ×1.5 (쿨타임 30초. 레벨마다 지속 +1초, 쿨타임 −2초)", "max_level": 5, "base_cost": 3000.0, "growth": 3.5, "requires": Upgrade.TOXIN},
	{"name": "새벽 전 몰아치기", "note": "밤 끝 5초 동안 구름 피해 ×2 (레벨마다 +1초)", "max_level": 5, "base_cost": 5e4, "growth": 4.0, "requires": Upgrade.DUSK},
	{"name": "풍요의 저주", "note": "수확일 작물 생기 +50%", "max_level": 0, "base_cost": 2e4, "growth": 1.8, "requires": Upgrade.GOLDEN},
	{"name": "까마귀 왕", "note": "까마귀가 생기가 많은 작물(황금 이삭·호박)부터 노린다", "max_level": 1, "base_cost": 2e5, "growth": 1.0, "requires": Upgrade.RACKET},
	# 스킬 칸 (방장 2026-10-14: 스킬을 다양하게). 역병 폭풍도 스킬이다
	{"name": "까마귀 떼", "note": "스킬: 5초 동안 까마귀가 네 배 빨리 쫀다, 없으면 셋이 날아든다 (쿨타임 35초)", "max_level": 5, "base_cost": 2500.0, "growth": 3.5, "requires": Upgrade.CROW},
	{"name": "짚돌이의 한숨", "note": "스킬: 구름 안 작물에 구름 피해 8초 몫을 한꺼번에 (쿨타임 15초. 레벨마다 +4초 몫)", "max_level": 5, "base_cost": 400.0, "growth": 3.0, "requires": Upgrade.LONG_NIGHT},
	{"name": "역병 파도", "note": "스킬: 살아 있는 작물의 25%가 번짐에 걸린다 (쿨타임 40초. 레벨마다 +5%p)", "max_level": 5, "base_cost": 4000.0, "growth": 3.5, "requires": Upgrade.SPREAD},
	# 스킬 칸 둘째 묶음 (방장 2026-10-14: 더 다양한 스킬)
	{"name": "어둠의 장막", "note": "스킬: 6초 동안 지키는 이들이 잠든다. 약도 심기도 멈춘다 (쿨타임 40초. 레벨마다 지속 +1초, 쿨타임 −3초)", "max_level": 5, "base_cost": 2e4, "growth": 3.5, "requires": Upgrade.RACKET},
	{"name": "수확의 낫", "note": "스킬: 체력이 30% 아래인 작물을 밭 어디서든 한꺼번에 쓰러뜨린다 (쿨타임 25초. 레벨마다 +5%p)", "max_level": 5, "base_cost": 1500.0, "growth": 3.2, "requires": Upgrade.SIGH},
	{"name": "썩은 비", "note": "스킬: 8초 동안 밭 전체에 구름 피해의 25%가 내린다 (쿨타임 45초. 레벨마다 지속 +1초, +5%p)", "max_level": 5, "base_cost": 8000.0, "growth": 3.5, "requires": Upgrade.ROT},
	{"name": "연쇄 시듦", "note": "스킬: 6초 동안 작물이 시들면 옆 작물마다 제 체력의 30%를 잃는다 (쿨타임 35초. 레벨마다 지속 +1초, +5%p)", "max_level": 5, "base_cost": 1.5e4, "growth": 3.5, "requires": Upgrade.TIDE},
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

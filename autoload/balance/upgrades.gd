extends "res://autoload/balance/core.gd"
## Balance 1부: 어둠의 나무 (GDD 6절, 방장 2026-10-14). 생기로 산다. 가운데 '어둠의 계약'에서 네 갈래로 뻗는다:
## 위 = 역병 구름, 왼쪽 = 밤의 시간, 오른쪽 = 밭 살찌우기(상대 스펙: 작물이 단단해지지만 생기가 더 크게 는다), 아래 = 까마귀 사역마.
## requires는 그 업그레이드를 1레벨 이상 가져야 나타나고 열린다는 뜻 (-1이면 뿌리, 갈래 방향은 "branch"). requires는 늘 앞 번호다 (화면 배치가 기댄다).
## 효과의 공식은 balance/night.gd가 레벨을 받아 계산한다. 저장 순서라 새 업그레이드는 뒤에만 붙인다 (첫 배포 전에 한 번 다시 짰다, 2026-10-14).
## 상한 있는 칸은 비용이 가파르게 오른다: 완만하면 15분 안에 다 팔려 수입이 폭발했다 (docs/BALANCE_SIM.md).
## 숫자 줄이기 (방장 2026-10-15 #529: 조·경·자가 너무 일찍 나온다): 생기 수입의 단계 성장을 ×1.8에서 크게 줄였다. 상한 있는 칸은 같은 밭 단계에서 살 수 있게
## 옛 성장 g를 g^0.115로, 옛 비용 X를 20 × (X / 20)^0.115로 눌렀다. 벽을 만드는 독한 포자와 더하기 칸(썩은 냄새·풍요의 저주)은 옛 비용 그대로

enum Upgrade { RADIUS, LONG_NIGHT, FERTILE, CROW, TOXIN, SPREAD, ROT, REGROW, DUSK, DENSE, ROT_VALUE, PUMPKIN, BEAK, FEATHER, RACKET, SEEP, GOLDEN, STORM, FRENZY, BOUNTY, CROW_KING, FLOCK, SIGH, TIDE, VEIL, REAP, RAIN, CHAIN, ECHO, DOUBLE, STICKY, STORM_POWER, STORM_OFTEN, TIDE_POWER, TIDE_OFTEN, RAIN_POWER, RAIN_OFTEN, CHAIN_POWER, CHAIN_OFTEN, DAWN, ROOTS, WAVES, FRENZY_POWER, SIGH_POWER, SIGH_OFTEN, REAP_POWER, REAP_OFTEN, WHEAT, CORN, TURNIP, SUNFLOWER, MELON, GRAPE, GOLDEN_RUSH, HARVEST_MOON, NEST, CARRION, SCARE, ROTTEN_SPRAY, LATE_SLEEPER, FLOCK_POWER, FLOCK_OFTEN, VEIL_POWER, VEIL_OFTEN }
const UPGRADES: Array[Dictionary] = [
	# 네 갈래의 뿌리
	{"name": "넓은 구름", "note": "역병 구름 반경 +10%", "max_level": 10, "base_cost": 10.0, "growth": 1.095, "requires": -1, "branch": "up"},
	{"name": "긴 밤", "note": "밤 +3초", "max_level": 10, "base_cost": 15.0, "growth": 1.101, "requires": -1, "branch": "left"},
	{"name": "비옥한 어둠", "note": "작물 체력 ×1.20, 생기 ×1.28 (레벨마다)", "max_level": 10, "base_cost": 22.0, "growth": 1.143, "requires": -1, "branch": "right"},
	{"name": "까마귀", "note": "까마귀 한 마리가 2초마다 작물을 쫀다", "max_level": 5, "base_cost": 25.0, "growth": 1.173, "requires": -1, "branch": "down"},
	# 위: 역병 구름
	{"name": "독한 포자", "note": "구름 피해 ×1.30 (레벨마다, 복리)", "max_level": 0, "base_cost": 15.0, "growth": 1.38, "requires": Upgrade.RADIUS},
	{"name": "번지는 곰팡이", "note": "시든 작물이 옆 작물로 번질 확률 +5%p", "max_level": 10, "base_cost": 23.0, "growth": 1.116, "requires": Upgrade.TOXIN},
	{"name": "썩은 뿌리", "note": "번진 작물이 받는 피해 +구름의 15%", "max_level": 10, "base_cost": 25.0, "growth": 1.116, "requires": Upgrade.SPREAD},
	# 왼쪽: 밤의 시간
	{"name": "다시 자라는 뿌리", "note": "시든 칸에 새 작물이 자란다 (15초, 레벨마다 10% 빨리)", "max_level": 8, "base_cost": 23.0, "growth": 1.126, "requires": Upgrade.LONG_NIGHT},
	{"name": "어스름", "note": "구름이 치는 박자 5% 빨리", "max_level": 8, "base_cost": 24.0, "growth": 1.135, "requires": Upgrade.LONG_NIGHT},
	# 오른쪽: 밭 살찌우기
	{"name": "빽빽한 밭", "note": "작물을 심는 칸 +7%p", "max_level": 10, "base_cost": 21.0, "growth": 1.095, "requires": Upgrade.FERTILE},
	{"name": "썩은 냄새", "note": "작물 하나의 생기 +20%", "max_level": 0, "base_cost": 25.0, "growth": 1.55, "requires": Upgrade.FERTILE},
	{"name": "탐스러운 호박", "note": "호박이 더 자주 (+2%p), 호박 생기 +25%", "max_level": 10, "base_cost": 24.0, "growth": 1.116, "requires": Upgrade.DENSE},
	# 아래: 까마귀 사역마
	{"name": "날카로운 부리", "note": "까마귀가 쪼는 피해 +50%", "max_level": 10, "base_cost": 26.0, "growth": 1.106, "requires": Upgrade.CROW},
	{"name": "검은 깃털", "note": "쪼인 작물이 번짐에 걸릴 확률 +15%p", "max_level": 6, "base_cost": 27.0, "growth": 1.155, "requires": Upgrade.BEAK},
	# 농부에 맞서는 칸과 황금 작물 (M3)
	{"name": "까마귀 소란", "note": "까마귀가 쫄 때마다 농부 하나가 0.4초 멈춘다 (멈춘 농부는 약을 못 친다)", "max_level": 5, "base_cost": 34.0, "growth": 1.135, "requires": Upgrade.BEAK},
	{"name": "스며드는 독", "note": "농부가 약 친 작물도 피해가 덜 줄어든다 (+10%p)", "max_level": 5, "base_cost": 36.0, "growth": 1.135, "requires": Upgrade.ROT},
	{"name": "황금 이삭", "note": "황금 작물이 더 자주 (+0.5%p). 황금 작물은 생기가 아주 많다", "max_level": 10, "base_cost": 29.0, "growth": 1.106, "requires": Upgrade.PUMPKIN},
	# 갈래 끝 칸 (후반에 고를 거리)
	{"name": "역병 폭풍", "note": "스킬: 구름이 작물을 120번 치면 저절로 6초 동안 구름이 부풀어 반경 ×1.8, 피해 ×1.5 (레벨마다 12타 덜, 지속 +1초)", "max_level": 5, "base_cost": 36.0, "growth": 1.155, "requires": Upgrade.TOXIN},
	{"name": "새벽 전 몰아치기", "note": "밤 끝 5초 동안 구름 피해 ×2 (레벨마다 +1초)", "max_level": 5, "base_cost": 49.0, "growth": 1.173, "requires": Upgrade.DUSK},
	{"name": "풍요의 저주", "note": "수확일 작물 생기 +50%", "max_level": 0, "base_cost": 2e+04, "growth": 1.8, "requires": Upgrade.GOLDEN},
	{"name": "까마귀 왕", "note": "까마귀가 생기가 많은 작물(황금 이삭·호박)부터 노린다", "max_level": 1, "base_cost": 58.0, "growth": 1.0, "requires": Upgrade.RACKET},
	# 스킬 칸 (방장 2026-10-14: 스킬을 다양하게. 10-15: 누르지 않고 구름 타수·시들 때 확률로 저절로). 역병 폭풍도 스킬이다
	{"name": "까마귀 떼", "note": "스킬: 구름이 작물을 180번 치면 저절로 5초 동안 까마귀가 네 배 빨리 쫀다, 없으면 셋이 날아든다 (레벨마다 18타 덜, 지속 +1초)", "max_level": 5, "base_cost": 35.0, "growth": 1.155, "requires": Upgrade.CROW},
	{"name": "짚돌이의 한숨", "note": "스킬: 구름이 작물을 80번 치면 저절로 구름 안 작물에 구름 피해 8초 몫을 한꺼번에 (레벨마다 8타 덜, +4초 몫)", "max_level": 5, "base_cost": 28.0, "growth": 1.135, "requires": Upgrade.LONG_NIGHT},
	{"name": "역병 파도", "note": "스킬: 작물이 시들 때마다 3% 확률로 살아 있는 작물의 25%가 번짐에 걸린다 (터지면 20초 쉼. 레벨마다 +1%p, +5%p)", "max_level": 5, "base_cost": 37.0, "growth": 1.155, "requires": Upgrade.SPREAD},
	# 스킬 칸 둘째 묶음 (방장 2026-10-14: 더 다양한 스킬)
	{"name": "어둠의 장막", "note": "스킬: 구름이 작물을 180번 치면 저절로 6초 동안 지키는 이들이 잠든다. 약도 심기도 멈춘다 (레벨마다 18타 덜, 지속 +1초)", "max_level": 5, "base_cost": 44.0, "growth": 1.155, "requires": Upgrade.RACKET},
	{"name": "수확의 낫", "note": "스킬: 작물이 시들 때마다 4% 확률로 체력이 30% 아래인 작물을 밭 어디서든 한꺼번에 쓰러뜨린다 (터지면 12초 쉼. 레벨마다 +1%p, +5%p)", "max_level": 5, "base_cost": 33.0, "growth": 1.143, "requires": Upgrade.SIGH},
	{"name": "썩은 비", "note": "스킬: 구름이 작물을 220번 치면 저절로 8초 동안 밭 전체에 구름 피해의 25%가 내린다 (레벨마다 22타 덜, 지속 +1초, +5%p)", "max_level": 5, "base_cost": 40.0, "growth": 1.155, "requires": Upgrade.ROT},
	{"name": "연쇄 시듦", "note": "스킬: 작물이 시들 때마다 2% 확률로 6초 동안 시드는 작물의 옆 작물마다 제 체력의 30%를 잃는다 (터지면 20초 쉼. 레벨마다 +0.5%p, 지속 +1초, +5%p)", "max_level": 5, "base_cost": 43.0, "growth": 1.155, "requires": Upgrade.TIDE},
	# 위: 역병 구름 둘째 묶음 (방장 2026-10-15: 나무를 두세 배로)
	{"name": "메아리 포자", "note": "구름 둘레 한 칸 띠의 작물도 구름 피해의 15%씩 맞는다", "max_level": 5, "base_cost": 30.0, "growth": 1.135, "requires": Upgrade.RADIUS},
	{"name": "두 번 치는 구름", "note": "구름이 칠 때 8%씩 확률로 한 번 더 친다", "max_level": 5, "base_cost": 33.0, "growth": 1.143, "requires": Upgrade.TOXIN},
	{"name": "끈적한 포자", "note": "번진 채 시든 작물의 생기 +25%씩", "max_level": 8, "base_cost": 31.0, "growth": 1.126, "requires": Upgrade.ROT},
	{"name": "거센 폭풍", "note": "역병 폭풍 동안 피해 +20%p씩", "max_level": 5, "base_cost": 40.0, "growth": 1.155, "requires": Upgrade.STORM},
	{"name": "잦은 폭풍", "note": "역병 폭풍에 드는 타수 10%씩 덜", "max_level": 5, "base_cost": 40.0, "growth": 1.155, "requires": Upgrade.STORM},
	{"name": "높은 파도", "note": "역병 파도가 번지게 하는 작물 +5%p씩", "max_level": 5, "base_cost": 41.0, "growth": 1.155, "requires": Upgrade.TIDE},
	{"name": "잦은 파도", "note": "역병 파도가 터질 확률 +1%p씩", "max_level": 5, "base_cost": 41.0, "growth": 1.155, "requires": Upgrade.TIDE},
	{"name": "장대비", "note": "썩은 비 피해 +5%p씩", "max_level": 5, "base_cost": 44.0, "growth": 1.155, "requires": Upgrade.RAIN},
	{"name": "잦은 비", "note": "썩은 비에 드는 타수 10%씩 덜", "max_level": 5, "base_cost": 44.0, "growth": 1.155, "requires": Upgrade.RAIN},
	{"name": "깊은 연쇄", "note": "연쇄 시듦 피해 +20%씩", "max_level": 5, "base_cost": 48.0, "growth": 1.155, "requires": Upgrade.CHAIN},
	{"name": "잦은 연쇄", "note": "연쇄 시듦이 터질 확률 +0.5%p씩", "max_level": 5, "base_cost": 48.0, "growth": 1.155, "requires": Upgrade.CHAIN},
	# 왼쪽: 밤의 시간 둘째 묶음
	{"name": "새벽 미루기", "note": "밭을 정복할 때마다 밤 +1초씩", "max_level": 5, "base_cost": 27.0, "growth": 1.135, "requires": Upgrade.LONG_NIGHT},
	{"name": "무성한 뿌리", "note": "다시 자란 작물의 생기 +25%씩", "max_level": 8, "base_cost": 28.0, "growth": 1.116, "requires": Upgrade.REGROW},
	{"name": "물결의 기세", "note": "물결이 거듭될 때마다 생기 +10%씩 (물결 수만큼 쌓인다)", "max_level": 5, "base_cost": 34.0, "growth": 1.143, "requires": Upgrade.DAWN},
	{"name": "광란", "note": "새벽 전 몰아치기 피해 배율 +0.5씩", "max_level": 4, "base_cost": 56.0, "growth": 1.173, "requires": Upgrade.FRENZY},
	{"name": "깊은 한숨", "note": "짚돌이의 한숨 +4초 몫씩", "max_level": 5, "base_cost": 33.0, "growth": 1.143, "requires": Upgrade.SIGH},
	{"name": "잦은 한숨", "note": "한숨에 드는 타수 10%씩 덜", "max_level": 5, "base_cost": 33.0, "growth": 1.143, "requires": Upgrade.SIGH},
	{"name": "날 선 낫", "note": "수확의 낫이 쓰러뜨리는 체력 기준 +5%p씩", "max_level": 5, "base_cost": 38.0, "growth": 1.143, "requires": Upgrade.REAP},
	{"name": "잦은 낫", "note": "수확의 낫이 터질 확률 +1%p씩", "max_level": 5, "base_cost": 38.0, "growth": 1.143, "requires": Upgrade.REAP},
	# 오른쪽: 작물마다 살찌우기
	{"name": "누런 밀", "note": "밀 생기 +30%씩", "max_level": 10, "base_cost": 23.0, "growth": 1.106, "requires": Upgrade.FERTILE},
	{"name": "알찬 옥수수", "note": "옥수수 생기 +25%씩", "max_level": 10, "base_cost": 25.0, "growth": 1.106, "requires": Upgrade.WHEAT},
	{"name": "줄줄이 순무", "note": "순무가 더 몰려 심기고(+5%p) 순무 생기 +20%씩", "max_level": 6, "base_cost": 27.0, "growth": 1.116, "requires": Upgrade.DENSE},
	{"name": "씨앗 터뜨리기", "note": "해바라기 씨앗 +1개씩", "max_level": 4, "base_cost": 32.0, "growth": 1.143, "requires": Upgrade.TURNIP},
	{"name": "물 많은 수박", "note": "수박이 터질 때 피해 +25%씩", "max_level": 5, "base_cost": 37.0, "growth": 1.143, "requires": Upgrade.PUMPKIN},
	{"name": "포도 넝쿨", "note": "포도 덩굴 피해 +25%, 포도 생기 +20%씩", "max_level": 5, "base_cost": 41.0, "growth": 1.143, "requires": Upgrade.MELON},
	{"name": "황금 바람", "note": "황금 이삭 생기 +25%씩", "max_level": 10, "base_cost": 34.0, "growth": 1.116, "requires": Upgrade.GOLDEN},
	{"name": "수확의 달", "note": "수확일을 정복하면 얹는 생기 +25%p씩", "max_level": 4, "base_cost": 49.0, "growth": 1.155, "requires": Upgrade.BOUNTY},
	# 아래: 까마귀와 지키는 이 맞서기
	{"name": "까마귀 둥지", "note": "까마귀 +1", "max_level": 3, "base_cost": 36.0, "growth": 1.203, "requires": Upgrade.FEATHER},
	{"name": "썩은 고기", "note": "까마귀가 쪼아 시든 작물의 생기 +30%씩", "max_level": 6, "base_cost": 31.0, "growth": 1.126, "requires": Upgrade.BEAK},
	{"name": "노려보는 허수아비", "note": "지키는 이가 8%씩 느리게 걷는다", "max_level": 5, "base_cost": 37.0, "growth": 1.135, "requires": Upgrade.RACKET},
	{"name": "썩은 약통", "note": "지키는 이가 약 치는 둘레 −8%씩", "max_level": 5, "base_cost": 40.0, "growth": 1.135, "requires": Upgrade.SCARE},
	{"name": "늦잠", "note": "지키는 이가 다시 심는 간격 +20%씩", "max_level": 5, "base_cost": 46.0, "growth": 1.135, "requires": Upgrade.VEIL},
	{"name": "더 많은 떼", "note": "까마귀 떼 동안 빠르기 +1배씩", "max_level": 5, "base_cost": 40.0, "growth": 1.155, "requires": Upgrade.FLOCK},
	{"name": "잦은 떼", "note": "까마귀 떼에 드는 타수 10%씩 덜", "max_level": 5, "base_cost": 40.0, "growth": 1.155, "requires": Upgrade.FLOCK},
	{"name": "두꺼운 장막", "note": "어둠의 장막 +1.5초씩", "max_level": 5, "base_cost": 50.0, "growth": 1.155, "requires": Upgrade.VEIL},
	{"name": "잦은 장막", "note": "어둠의 장막에 드는 타수 10%씩 덜", "max_level": 5, "base_cost": 50.0, "growth": 1.155, "requires": Upgrade.VEIL},
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

extends "res://autoload/balance/branches.gd"
## Balance 2.6부: 도깨비불 (방장 2026-10-15 #587, 장르 조사 제안 6: 쿠키 클리커의 황금 쿠키, Idle Slayer의 상자). 밤 몇 판에 한 번 밭 위를 떠도는 불을 구름으로 덮으면 짧고 큰 보상을 준다.
## 놓쳐도 손해는 없다. 보상은 그때의 밭과 함께 커지게 배율이나 '밭 몇 판 몫'으로 준다 (고정 값이면 몇 단계 뒤 쓸모없어진다).
## 처음엔 셋째 밤부터·35%·잔치 ×5 8초·주머니 세 판 몫이었는데, 봇이 잡으면 초반 수입이 두 배 넘게 붙어 5단계까지 10분 → 6분이었다 (방장 #543: 초반이 너무 쉽다).
## 보상을 줄여도(30%·×3·한 판 반) 평소 밤 생기가 20분에 25배였다: 잡는 밤마다 2.5배라 초반 구매가 앞당겨진다. 그래서 보상은 두고 드물게 (황금 쿠키처럼 5분에 한 번꼴)

const WISP_AFTER_NIGHTS: int = 4        # 지난 밤이 이만큼 넘어야 뜬다 (첫 밤들은 구름 끌기를 익힌다)
const WISP_CHANCE: float = 0.15         # 밤마다 뜰 확률
const WISP_DROUGHT: int = 8             # 뜰 수 있는 밤을 이만큼 거르면 다음 밤엔 꼭 뜬다
const WISP_EARLIEST: float = 3.0        # 밤이 시작하고 이 초 뒤부터 나타난다
const WISP_LIFETIME: float = 7.0        # 떠 있는 초
const WISP_CATCH_SECONDS: float = 0.35  # 구름 안에 이만큼 머물면 잡힌다 (머문 시간은 빠져나가도 줄지 않는다)
const WISP_SPEED: float = 0.9           # 떠도는 빠르기 (칸/초)
const WISP_TURN: float = 2.5            # 방향을 트는 빠르기 (라디안/초)
const WISP_SPAWN_GAP: float = 1.5       # 나타날 때 구름 가장자리에서 이만큼(칸) 떨어진다 (나타나자마자 잡히지 않게)

enum Boon { FEAST, PURSE, PRANK, DREAM }
## weight: 고를 몫 (못 받는 보상은 빼고 고른다). 장난은 열린 스킬이 있어야, 꿈 부스러기는 겨울잠을 한 번 잔 뒤에
const BOONS: Array[Dictionary] = [
	{"name": "도깨비 잔치", "weight": 50.0},
	{"name": "도깨비 주머니", "weight": 30.0},
	{"name": "도깨비 장난", "weight": 20.0},
	{"name": "꿈 부스러기", "weight": 15.0},
]
const FEAST_MULTIPLIER: float = 3.0     # 잔치: 그동안 시든 작물의 생기 ×3
const FEAST_SECONDS: float = 7.0
const PURSE_FIELDS: float = 1.5         # 주머니: 이번 밭에 심긴 작물을 모두 시들게 한 생기의 한 판 반 몫
const DREAM_SHARE: float = 0.03         # 꿈 부스러기: 지금 겨울잠에 들면 받을 꿈 조각의 3% (적어도 1)


## 이번 밤에 도깨비불이 뜰 확률. nights는 지난 밤 수, drought는 뜰 수 있었는데 안 뜬 밤 수
func wisp_chance(nights: int, drought: int) -> float:
	if nights < WISP_AFTER_NIGHTS:
		return 0.0
	return 1.0 if drought >= WISP_DROUGHT else WISP_CHANCE


func boon_name(boon: int) -> String:
	return BOONS[boon]["name"]


## 보상을 고를 몫. 받을 수 없는 보상은 0
func boon_weight(boon: int, skills_open: bool, slept: bool) -> float:
	if boon == Boon.PRANK and not skills_open:
		return 0.0
	if boon == Boon.DREAM and not slept:
		return 0.0
	return float(BOONS[boon]["weight"])


## 주머니가 주는 생기: 밭 한 판 몫(심긴 작물을 모두 시들게 한 생기) × 1.5
func purse_vitality(field_value: float) -> float:
	return cap(field_value * PURSE_FIELDS)


## 꿈 부스러기: 지금 겨울잠에 들면 받을 꿈 조각의 3%, 적어도 1
func dream_crumbs(full_reward: float) -> float:
	return cap(maxf(floor(full_reward * DREAM_SHARE), 1.0))

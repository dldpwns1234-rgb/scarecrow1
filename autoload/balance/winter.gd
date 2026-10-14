extends "res://autoload/balance/night.gd"
## Balance 3부: 겨울잠 (회귀, GDD 8절 M4). 열린 밭 단계가 WINTER_MIN_LEVEL 이상이면 겨울잠에 들어 생기·어둠의 나무·밭 단계를 내려놓고 꿈 조각을 받는다.
## 꿈 조각으로 꿈의 상점(영구 강화)을 산다. 비용 = 내림(기본 × 성장^레벨). 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)
## 비용 1·2·3…에 ×2 배율이면 첫 겨울잠의 199조각으로 피해·생기가 ×4천씩 붙어 둘째 철이 78단계까지 내달렸다

const WINTER_MIN_LEVEL: int = 12        # 겨울잠 조건: 열린 밭 단계 12 이상 (봇은 17분쯤)
const SHARD_BASE: float = 3.0           # 꿈 조각 = 내림(3 × 1.3^(열린 단계 − 12)): 12단계 3, 20단계 24, 25단계 90, 30단계 340
const SHARD_GROWTH: float = 1.3

enum Dream { DEEP_SLEEP, DREAM_HARVEST, WINTER_SEED, HANDS, DREAM_CROW, SLEEPWALK }
const DREAMS: Array[Dictionary] = [
	{"name": "깊은 잠", "note": "구름 피해 ×1.6", "max_level": 0, "base_cost": 1.0, "growth": 2.0},
	{"name": "꿈속 수확", "note": "생기 ×1.6", "max_level": 0, "base_cost": 1.0, "growth": 2.0},
	{"name": "겨울 씨앗", "note": "겨울잠 뒤 밭 3단계를 더 열고 시작", "max_level": 5, "base_cost": 2.0, "growth": 2.0},
	{"name": "기억하는 손", "note": "겨울잠 뒤 넓은 구름·긴 밤·빽빽한 밭을 1레벨씩 들고 시작", "max_level": 5, "base_cost": 1.0, "growth": 1.8},
	{"name": "꿈의 까마귀", "note": "까마귀 +1 (어둠의 나무와 따로)", "max_level": 3, "base_cost": 5.0, "growth": 3.0},
	{"name": "몽유", "note": "밤 +2초", "max_level": 5, "base_cost": 1.0, "growth": 1.6},
]
const DEEP_SLEEP_MULTIPLIER: float = 1.6
const DREAM_HARVEST_MULTIPLIER: float = 1.6
const WINTER_SEED_LEVELS: int = 3
const SLEEPWALK_SECONDS: float = 2.0


## 겨울잠에 들 수 있는지 (열린 밭 단계)
func can_winter(best_level: int) -> bool:
	return best_level >= WINTER_MIN_LEVEL


## 지금 겨울잠에 들면 받는 꿈 조각. 조건 미달이면 0
func shard_reward(best_level: int) -> float:
	if not can_winter(best_level):
		return 0.0
	return cap(floor(SHARD_BASE * pow(SHARD_GROWTH, best_level - WINTER_MIN_LEVEL)))


func dream_name(index: int) -> String:
	return DREAMS[index]["name"]


func dream_note(index: int) -> String:
	return DREAMS[index]["note"]


## 0이면 상한 없음
func dream_max_level(index: int) -> int:
	return DREAMS[index]["max_level"]


## 다음 레벨 비용: 내림(기본 × 성장^레벨) 조각
func dream_cost(index: int, level: int) -> float:
	var entry: Dictionary = DREAMS[index]
	return cap(floor(float(entry["base_cost"]) * pow(float(entry["growth"]), level)))


## 깊은 잠: 구름 피해 배율 (번짐·까마귀도 구름 피해를 따라간다)
func dream_damage_multiplier(deep_level: int) -> float:
	return cap(pow(DEEP_SLEEP_MULTIPLIER, deep_level))


## 꿈속 수확: 생기 배율
func dream_vitality_multiplier(harvest_level: int) -> float:
	return cap(pow(DREAM_HARVEST_MULTIPLIER, harvest_level))


## 겨울잠 뒤 열고 시작하는 밭 단계
func winter_start_level(seed_level: int) -> int:
	return 1 + WINTER_SEED_LEVELS * seed_level


## 몽유: 밤에 더하는 초
func sleepwalk_seconds(level: int) -> float:
	return SLEEPWALK_SECONDS * level

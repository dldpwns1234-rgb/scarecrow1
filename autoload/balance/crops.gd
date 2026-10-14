extends "res://autoload/balance/upgrades.gd"
## Balance 1.5부: 밭 크기와 작물 (GDD 4절). 밭은 단계가 오르면 한 줄씩 넓어지고, 작물은 단계마다 새 종류가 섞여 든다 (방장 2026-10-14: 작물 종류 더, 농지가 점점 크게).
## 새 작물은 저마다 버릇이 있다: 순무는 무더기로, 포도는 덩굴로 줄지어 심기고, 해바라기는 시들면 씨앗이 튀어 번지고, 수박은 터져 둘레를 친다.
## 체력·생기는 모든 작물이 밭 단계마다 같은 비율로 자란다. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

const FIELD_BASE_SIZE: int = 8         # 첫 밭 8 × 8칸
const FIELD_GROW_LEVELS: int = 3       # 밭 단계 3마다 한 줄씩 넓어진다
const FIELD_MAX_SIZE: int = 18         # 31단계에 18 × 18칸 (화면은 칸을 줄여 그린다)

enum Crop { WHEAT, CORN, PUMPKIN, GOLDEN, TURNIP, SUNFLOWER, WATERMELON, GRAPE }
## from: 섞여 들기 시작하는 밭 단계 (0이면 처음부터 비율 표대로, 황금 이삭은 확률로만). weight: 다 섞여 든 뒤의 몫 (밀·옥수수·호박과 함께 나눈다).
## cluster: blob이면 위·왼쪽 이웃이 같은 작물일 때 그대로 따라 심기고(무더기), line이면 왼쪽 이웃만 따라 심긴다(덩굴)
const CROPS: Array[Dictionary] = [
	{"name": "밀", "hp": 10.0, "vitality": 1.0},
	{"name": "옥수수", "hp": 30.0, "vitality": 3.5},
	{"name": "호박", "hp": 90.0, "vitality": 12.0},       # 처음엔 200이라 너무 오래 때려야 했다 (방장 2026-10-14)
	{"name": "황금 이삭", "hp": 60.0, "vitality": 120.0},  # 아주 가끔 심긴다. 찾아가 시들게 하는 재미 (회귀 용사의 보물 요정)
	{"name": "순무", "hp": 14.0, "vitality": 1.6, "from": 3, "weight": 0.1, "cluster": "blob"},
	{"name": "해바라기", "hp": 45.0, "vitality": 5.5, "from": 6, "weight": 0.1},
	{"name": "수박", "hp": 150.0, "vitality": 21.0, "from": 10, "weight": 0.07},
	{"name": "포도", "hp": 55.0, "vitality": 7.0, "from": 16, "weight": 0.1, "cluster": "line"},
]
const CROP_FADE_LEVELS: float = 3.0         # 새 작물은 이만큼의 단계에 걸쳐 제 몫까지 늘어난다
const BLOB_CHANCE: float = 0.3             # 무더기 작물 옆 칸(오른쪽·아래)이 같은 작물로 심길 확률 (0.55면 무더기가 밭을 덮었다)
const LINE_CHANCE: float = 0.6             # 덩굴 작물 오른쪽 칸이 같은 작물로 심길 확률 (덩굴 길이 평균 2.5칸)
const SEED_COUNT: int = 2                   # 해바라기: 시들면 둘레의 작물 둘이 번짐에 걸린다
const SEED_RADIUS: float = 2.5
const BURST_SHARE: float = 0.35             # 수박: 시들면 둘레(1.5칸) 작물마다 수박 최대 체력의 35% 피해
const BURST_RADIUS: float = 1.5
const VINE_SHARE: float = 0.5               # 포도: 시들면 이어진 옆 포도마다 그 포도 최대 체력의 50% 피해 (덩굴을 타고 이어 시든다)
const GOLDEN_BASE_CHANCE: float = 0.01      # 심기는 작물 하나가 황금 이삭일 확률 1%
const GOLDEN_CHANCE_PER_LEVEL: float = 0.005  # 황금 이삭(업그레이드): 레벨당 +0.5%p
## 밭 단계 1의 작물 비율 (밀·옥수수·호박). 단계가 오를 때마다 밀에서 CROP_SHIFT씩 덜어 옥수수·호박에 반씩 준다
const CROP_WEIGHTS: Array[float] = [0.7, 0.25, 0.05]
const CROP_SHIFT: float = 0.04
const MIN_WHEAT_WEIGHT: float = 0.2
const PUMPKIN_WEIGHT_PER_LEVEL: float = 0.02  # 탐스러운 호박: 레벨당 호박 비율 +2%p (밀에서 덜어 온다)
const PUMPKIN_VITALITY_PER_LEVEL: float = 0.25  # 탐스러운 호박: 레벨당 호박 생기 +25%
const FIELD_HP_GROWTH: float = 2.2     # 밭 단계마다 작물 체력 ×2.2
const FIELD_VITALITY_GROWTH: float = 1.8  # 밭 단계마다 생기 ×1.8 (체력보다 덜 올라 업그레이드가 필요하다. docs/BALANCE_SIM.md)
const FERTILE_HP: float = 1.5          # 비옥한 어둠(상대 스펙): 레벨당 작물 체력 ×1.5, 생기 ×1.7 (복리). ×1.6·×2는 다시 자라기와 겹쳐 수입이 폭발했다
const FERTILE_VITALITY: float = 1.7


## 밭 한 변의 칸 수: 8에서 시작해 단계 3마다 한 줄씩, 18까지
func field_size(field_level: int) -> int:
	@warning_ignore("integer_division")
	return mini(FIELD_BASE_SIZE + maxi(field_level - 1, 0) / FIELD_GROW_LEVELS, FIELD_MAX_SIZE)


## 이 밭 단계의 작물 체력 (비옥한 어둠 포함)
func crop_hp(crop: int, field_level: int, fertile_level: int = 0) -> float:
	return cap(float(CROPS[crop]["hp"]) * pow(FIELD_HP_GROWTH, field_level - 1) * pow(FERTILE_HP, fertile_level))


## 작물 하나를 시들게 하면 받는 생기 (비옥한 어둠·탐스러운 호박 포함, 썩은 냄새 배율 전)
func crop_vitality(crop: int, field_level: int, fertile_level: int = 0, pumpkin_level: int = 0) -> float:
	var value := float(CROPS[crop]["vitality"]) * pow(FIELD_VITALITY_GROWTH, field_level - 1) * pow(FERTILE_VITALITY, fertile_level)
	if crop == Crop.PUMPKIN:
		value *= 1.0 + PUMPKIN_VITALITY_PER_LEVEL * pumpkin_level
	return cap(value)


func crop_name(crop: int) -> String:
	return CROPS[crop]["name"]


## 이 작물이 따라 심기는 방식 ("blob"·"line", 없으면 "")
func crop_cluster(crop: int) -> String:
	return CROPS[crop].get("cluster", "")


## 옆 칸이 이 작물을 따라 심길 확률 (무더기·덩굴이 아니면 0)
func cluster_chance(crop: int) -> float:
	match crop_cluster(crop):
		"blob":
			return BLOB_CHANCE
		"line":
			return LINE_CHANCE
	return 0.0


## 이 밭 단계에서 이 작물이 섞여 들었는지 (밀·옥수수·호박은 늘)
func crop_unlocked(crop: int, field_level: int) -> bool:
	return crop != Crop.GOLDEN and field_level >= int(CROPS[crop].get("from", 1))


## 밭 단계의 작물 비율 (작물 순서, 합 1, 황금 이삭은 0). 밀에서 덜어 옥수수·호박에 주고(탐스러운 호박은 호박에 더),
## 새 작물은 섞여 드는 단계부터 CROP_FADE_LEVELS에 걸쳐 제 몫까지 늘어난 뒤 전체를 다시 나눈다
func crop_weights(field_level: int, pumpkin_level: int = 0) -> Array[float]:
	var moved := minf(CROP_SHIFT * (field_level - 1), CROP_WEIGHTS[0] - MIN_WHEAT_WEIGHT)
	var wheat := CROP_WEIGHTS[0] - moved
	var pumpkin_extra := minf(PUMPKIN_WEIGHT_PER_LEVEL * pumpkin_level, wheat - MIN_WHEAT_WEIGHT * 0.5)
	var weights: Array[float] = []
	weights.resize(CROPS.size())
	weights.fill(0.0)
	weights[Crop.WHEAT] = wheat - pumpkin_extra
	weights[Crop.CORN] = CROP_WEIGHTS[1] + moved * 0.5
	weights[Crop.PUMPKIN] = CROP_WEIGHTS[2] + moved * 0.5 + pumpkin_extra
	var total := 1.0
	for crop in CROPS.size():
		var from := int(CROPS[crop].get("from", 0))
		if from > 0 and field_level >= from:
			weights[crop] = float(CROPS[crop]["weight"]) * minf(float(field_level - from + 1) / CROP_FADE_LEVELS, 1.0)
			total += weights[crop]
	for crop in CROPS.size():
		weights[crop] /= total
	return weights


## 심기는 작물 하나가 황금 이삭일 확률
func golden_chance(golden_level: int) -> float:
	return GOLDEN_BASE_CHANCE + GOLDEN_CHANCE_PER_LEVEL * golden_level

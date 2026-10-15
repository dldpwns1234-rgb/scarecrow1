extends "res://autoload/balance/upgrades.gd"
## Balance 1.5부: 밭 크기와 작물 (GDD 4절). 밭은 단계가 오르면 한 줄씩 넓어지고, 작물은 단계마다 새 종류가 섞여 든다 (방장 2026-10-14: 작물 종류 더, 농지가 점점 크게).
## 새 작물은 저마다 버릇이 있다: 순무는 무더기로, 포도는 덩굴로 줄지어 심기고, 해바라기는 시들면 씨앗이 튀어 번지고, 수박은 터져 둘레를 친다.
## 체력·생기는 모든 작물이 밭 단계마다 같은 비율로 자란다. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

const FIELD_BASE_SIZE: int = 8         # 첫 밭 8 × 8칸
const FIELD_GROW_LEVELS: int = 3       # 밭 단계 3마다 한 줄씩 넓어진다
const FIELD_MAX_SIZE: int = 18         # 31단계에 18 × 18칸 (화면은 칸을 줄여 그린다)

enum Crop { WHEAT, CORN, PUMPKIN, GOLDEN, TURNIP, SUNFLOWER, WATERMELON, GRAPE }
## from: 섞여 들기 시작하는 밭 단계 (0이면 처음부터 비율 표대로, 황금 이삭은 확률로만). weight: 다 섞여 든 뒤의 몫 (밀·옥수수·호박과 함께 나눈다).
## cluster: blob이면 위·왼쪽 이웃이 같은 작물일 때 그대로 따라 심기고(무더기), line이면 왼쪽 이웃만 따라 심긴다(덩굴).
## bonus: 그 작물의 생기를 레벨마다 bonus_step씩 올리는 어둠의 나무 칸 (방장 2026-10-15 #529: 작물마다 칸. 해바라기·수박의 칸은 버릇을 키운다).
## 몫은 숫자 곡선을 맞추며 처음의 0.3배로 줄였다 (#555: 칸이 한꺼번에 팔리면 생기 배율이 곱해져 10~20분에 10만 배가 뛰었다)
const CROPS: Array[Dictionary] = [
	{"name": "밀", "hp": 10.0, "vitality": 1.0, "bonus": Upgrade.WHEAT, "bonus_step": 0.09},
	{"name": "옥수수", "hp": 30.0, "vitality": 3.5, "bonus": Upgrade.CORN, "bonus_step": 0.075},
	{"name": "호박", "hp": 90.0, "vitality": 12.0, "bonus": Upgrade.PUMPKIN, "bonus_step": 0.075},       # 처음엔 200이라 너무 오래 때려야 했다 (방장 2026-10-14)
	{"name": "황금 이삭", "hp": 60.0, "vitality": 120.0, "bonus": Upgrade.GOLDEN_RUSH, "bonus_step": 0.075},  # 아주 가끔 심긴다. 찾아가 시들게 하는 재미 (회귀 용사의 보물 요정)
	{"name": "순무", "hp": 14.0, "vitality": 1.6, "from": 3, "weight": 0.1, "cluster": "blob", "bonus": Upgrade.TURNIP, "bonus_step": 0.06},
	{"name": "해바라기", "hp": 45.0, "vitality": 5.5, "from": 6, "weight": 0.1},
	{"name": "수박", "hp": 150.0, "vitality": 21.0, "from": 10, "weight": 0.07},
	{"name": "포도", "hp": 55.0, "vitality": 7.0, "from": 16, "weight": 0.1, "cluster": "line", "bonus": Upgrade.GRAPE, "bonus_step": 0.06},
]
const CROP_FADE_LEVELS: float = 3.0         # 새 작물은 이만큼의 단계에 걸쳐 제 몫까지 늘어난다
const BLOB_CHANCE: float = 0.3             # 무더기 작물 옆 칸(오른쪽·아래)이 같은 작물로 심길 확률 (0.55면 무더기가 밭을 덮었다)
const LINE_CHANCE: float = 0.6             # 덩굴 작물 오른쪽 칸이 같은 작물로 심길 확률 (덩굴 길이 평균 2.5칸)
const TURNIP_CLUSTER_PER_LEVEL: float = 0.05  # 줄줄이 순무: 무더기 확률 +5%p씩
const SEED_COUNT: int = 2                   # 해바라기: 시들면 둘레의 작물 둘이 번짐에 걸린다 (씨앗 터뜨리기: +1개씩)
const SEED_RADIUS: float = 2.5
const BURST_SECONDS: float = 4.0            # 수박: 시들면 둘레(1.5칸) 작물마다 구름 피해 4초 몫 (물 많은 수박: +25%씩).
const BURST_PER_LEVEL: float = 0.25        # 최대 체력의 몫으로 치면 단계와 상관없이 밭이 무너져 벽이 사라졌다 (2026-10-15 봇)
const BURST_RADIUS: float = 1.5
const VINE_SECONDS: float = 3.0             # 포도: 시들면 이어진 옆 포도마다 구름 피해 3초 몫 (덩굴을 타고 이어 시든다. 포도 넝쿨: +25%씩)
const VINE_PER_LEVEL: float = 0.25
const GOLDEN_BASE_CHANCE: float = 0.01      # 심기는 작물 하나가 황금 이삭일 확률 1%
const GOLDEN_CHANCE_PER_LEVEL: float = 0.005  # 황금 이삭(업그레이드): 레벨당 +0.5%p
## 밭 단계 1의 작물 비율 (밀·옥수수·호박). 단계가 오를 때마다 밀에서 CROP_SHIFT씩 덜어 옥수수·호박에 반씩 준다
const CROP_WEIGHTS: Array[float] = [0.7, 0.25, 0.05]
const CROP_SHIFT: float = 0.04
const MIN_WHEAT_WEIGHT: float = 0.2
const PUMPKIN_WEIGHT_PER_LEVEL: float = 0.02  # 탐스러운 호박: 레벨당 호박 비율 +2%p (밀에서 덜어 온다)
const FIELD_HP_GROWTH: float = 1.35  # 밭 단계마다 작물 체력 (옛 ×2.2. 독한 포자의 비용과 함께 벽을 만든다: 단계마다 비용이 수입보다 이만큼 빨리 오른다)
const FIELD_VITALITY_GROWTH: float = 1.05  # 밭 단계마다 생기 (옛 ×1.8. 방장 2026-10-15 #529: 50단계면 조였다. 수입이 단계로 덜 오르고 업그레이드로 오른다)
const FERTILE_HP: float = 1.1  # 비옥한 어둠(상대 스펙): 레벨당 작물 체력·생기 배율 (복리). 옛 ×1.6·×2는 다시 자라기와 겹쳐 수입이 폭발했다
const FERTILE_VITALITY: float = 1.15


## 밭 한 변의 칸 수: 8에서 시작해 단계 3마다 한 줄씩, 18까지
func field_size(field_level: int) -> int:
	@warning_ignore("integer_division")
	return mini(FIELD_BASE_SIZE + maxi(field_level - 1, 0) / FIELD_GROW_LEVELS, FIELD_MAX_SIZE)


## 이 밭 단계의 작물 체력 (비옥한 어둠 포함)
func crop_hp(crop: int, field_level: int, fertile_level: int = 0) -> float:
	return cap(float(CROPS[crop]["hp"]) * pow(FIELD_HP_GROWTH, field_level - 1) * pow(FERTILE_HP, fertile_level))


## 작물 하나를 시들게 하면 받는 생기 (비옥한 어둠과 그 작물의 칸 포함, 썩은 냄새 배율 전). bonus_level은 그 작물의 칸 레벨
func crop_vitality(crop: int, field_level: int, fertile_level: int = 0, bonus_level: int = 0) -> float:
	var value := float(CROPS[crop]["vitality"]) * pow(FIELD_VITALITY_GROWTH, field_level - 1) * pow(FERTILE_VITALITY, fertile_level)
	value *= 1.0 + float(CROPS[crop].get("bonus_step", 0.0)) * bonus_level
	return cap(value)


## 그 작물의 생기를 올리는 칸 (없으면 -1)
func crop_bonus_upgrade(crop: int) -> int:
	return CROPS[crop].get("bonus", -1)


func crop_name(crop: int) -> String:
	return CROPS[crop]["name"]


## 이 작물이 따라 심기는 방식 ("blob"·"line", 없으면 "")
func crop_cluster(crop: int) -> String:
	return CROPS[crop].get("cluster", "")


## 옆 칸이 이 작물을 따라 심길 확률 (무더기·덩굴이 아니면 0). 줄줄이 순무가 무더기를 키운다
func cluster_chance(crop: int, turnip_level: int = 0) -> float:
	match crop_cluster(crop):
		"blob":
			return BLOB_CHANCE + TURNIP_CLUSTER_PER_LEVEL * turnip_level
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


## 해바라기 씨앗 수 (씨앗 터뜨리기)
func seed_count(level: int) -> int:
	return SEED_COUNT + level


## 수박이 터질 때 둘레 작물 하나가 받는 피해 (물 많은 수박)
func burst_damage(cloud: float, level: int) -> float:
	return cap(cloud * BURST_SECONDS * (1.0 + BURST_PER_LEVEL * level))


## 포도 덩굴이 옆 포도에 주는 피해 (포도 넝쿨)
func vine_damage(cloud: float, level: int) -> float:
	return cap(cloud * VINE_SECONDS * (1.0 + VINE_PER_LEVEL * level))

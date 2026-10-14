extends "res://autoload/balance/upgrades.gd"
## Balance 2부: 밤 한 판의 공식 (GDD 4절). 밭 격자, 작물 표와 밭 단계, 역병 구름(반경·피해·박자), 번짐, 까마귀, 휴식 배율.
## 좌표는 격자 단위다 (칸 하나 = 1). 구름은 격자 위의 원이고 화면은 아이소메트릭으로 눌러 그린다 (scenes/night/).
## 업그레이드 레벨은 인자로 받는다 (Night가 Upgrades에서 읽어 넘긴다). 수치는 시뮬레이션(tools/sim_night.gd)으로 맞춘다

const FIELD_SIZE: int = 12             # 밭 12 × 12칸
const FIELD_FILL: float = 0.9          # 작물이 심긴 칸의 비율 (나머지는 맨땅)
const CLEAR_RATIO: float = 0.9         # 이만큼 시들면 밭 정복: 남은 작물이 저절로 쓰러지고 다음 밭 단계가 열린다
const MAX_FIELD_LEVEL: int = 100

enum Crop { WHEAT, CORN, PUMPKIN }
const CROPS: Array[Dictionary] = [
	{"name": "밀", "hp": 10.0, "rest": 1.0},
	{"name": "옥수수", "hp": 45.0, "rest": 5.0},
	{"name": "호박", "hp": 200.0, "rest": 25.0},
]
## 밭 단계 1의 작물 비율 (밀·옥수수·호박). 단계가 오를 때마다 밀에서 CROP_SHIFT씩 덜어 옥수수·호박에 반씩 준다
const CROP_WEIGHTS: Array[float] = [0.7, 0.25, 0.05]
const CROP_SHIFT: float = 0.04
const MIN_WHEAT_WEIGHT: float = 0.2
const FIELD_HP_GROWTH: float = 2.4     # 밭 단계마다 작물 체력 ×2.4
const FIELD_REST_GROWTH: float = 2.0   # 밭 단계마다 휴식 ×2 (체력보다 덜 올라 업그레이드가 필요하다)

const CLOUD_TICK: float = 0.5          # 구름은 이 간격(초)마다 원 안의 작물을 한꺼번에 친다 (곡괭이질처럼 박자가 보이게)
const CLOUD_BASE_RADIUS: float = 1.0   # 칸
const CLOUD_RADIUS_PER_LEVEL: float = 0.1   # 넓은 구름: 레벨당 기본 반경의 +10%
const CLOUD_BASE_DPS: float = 3.0      # 원 안 작물 하나가 받는 초당 피해
const CLOUD_DPS_PER_LEVEL: float = 0.25     # 독한 포자: 레벨당 기본 피해의 +25%

const SPREAD_PER_LEVEL: float = 0.05   # 번지는 곰팡이: 시든 작물이 옆 칸(상하좌우)마다 번질 확률 +5%p
const ROT_BASE_SHARE: float = 0.3      # 번짐에 걸린 작물이 받는 초당 피해 = 구름 피해 × (0.3 + 썩은 뿌리 0.15/레벨)
const ROT_SHARE_PER_LEVEL: float = 0.15

const CROW_INTERVAL: float = 2.0       # 까마귀 한 마리가 쪼는 간격 (초)
const CROW_PECK_SHARE: float = 2.0     # 한 번 쪼는 피해 = 구름 피해(초당) × 2 × (1 + 날카로운 부리 0.5/레벨)
const BEAK_PER_LEVEL: float = 0.5

const REST_PER_LEVEL: float = 0.2      # 썩은 냄새: 레벨당 휴식 +20%


## 이 밭 단계의 작물 체력
func crop_hp(crop: int, field_level: int) -> float:
	return cap(float(CROPS[crop]["hp"]) * pow(FIELD_HP_GROWTH, field_level - 1))


## 이 밭 단계의 작물 하나를 시들게 하면 받는 휴식 (업그레이드 배율 전)
func crop_rest(crop: int, field_level: int) -> float:
	return cap(float(CROPS[crop]["rest"]) * pow(FIELD_REST_GROWTH, field_level - 1))


func crop_name(crop: int) -> String:
	return CROPS[crop]["name"]


## 밭 단계의 작물 비율 (밀·옥수수·호박의 합 1)
func crop_weights(field_level: int) -> Array[float]:
	var moved := minf(CROP_SHIFT * (field_level - 1), CROP_WEIGHTS[0] - MIN_WHEAT_WEIGHT)
	return [CROP_WEIGHTS[0] - moved, CROP_WEIGHTS[1] + moved * 0.5, CROP_WEIGHTS[2] + moved * 0.5]


## 구름 반경 (칸): 1 × (1 + 0.1 × 넓은 구름)
func cloud_radius(radius_level: int) -> float:
	return CLOUD_BASE_RADIUS * (1.0 + CLOUD_RADIUS_PER_LEVEL * radius_level)


## 원 안 작물 하나가 받는 초당 피해: 3 × (1 + 0.25 × 독한 포자)
func cloud_dps(toxin_level: int) -> float:
	return cap(CLOUD_BASE_DPS * (1.0 + CLOUD_DPS_PER_LEVEL * toxin_level))


## 시든 작물이 옆 칸 하나로 번질 확률
func spread_chance(spread_level: int) -> float:
	return minf(SPREAD_PER_LEVEL * spread_level, 1.0)


## 번짐에 걸린 작물의 초당 피해
func rot_dps(cloud: float, rot_level: int) -> float:
	return cap(cloud * (ROT_BASE_SHARE + ROT_SHARE_PER_LEVEL * rot_level))


## 까마귀 수 = 까마귀 레벨
func crow_count(crow_level: int) -> int:
	return crow_level


## 까마귀가 한 번 쪼는 피해
func crow_damage(cloud: float, beak_level: int) -> float:
	return cap(cloud * CROW_PECK_SHARE * (1.0 + BEAK_PER_LEVEL * beak_level))


## 휴식 배율: 1 + 0.2 × 썩은 냄새
func rest_multiplier(rot_value_level: int) -> float:
	return 1.0 + REST_PER_LEVEL * rot_value_level

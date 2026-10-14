extends "res://autoload/balance/upgrades.gd"
## Balance 2부: 밤 한 판의 공식 (GDD 4절). 밭 격자, 작물 표와 밭 단계, 심는 비율, 역병 구름(반경·피해·박자), 번짐, 까마귀, 다시 자라기, 생기.
## 좌표는 격자 단위다 (칸 하나 = 1). 구름은 격자 위의 원이고 화면은 아이소메트릭으로 눌러 그린다 (scenes/night/).
## 업그레이드 레벨은 인자로 받는다 (Night가 Upgrades에서 읽어 넘긴다). 수치는 시뮬레이션(tools/sim_night.gd)으로 맞춘다 (docs/BALANCE_SIM.md)

const FIELD_SIZE: int = 12             # 밭 12 × 12칸
const BASE_FILL: float = 0.3           # 첫 밭은 듬성듬성 (방장 2026-10-14: 구름을 어디로 끌지 고르는 재미)
const FILL_PER_LEVEL: float = 0.07     # 빽빽한 밭: 레벨당 심는 비율 +7%p (10레벨이면 꽉 찬다)
const CLEAR_RATIO: float = 0.9         # 시든 작물이 처음 심은 수의 이만큼에 닿으면 밭 정복 (다시 자란 작물이 시든 것도 친다. 남은 수로 재면 다시 자라기가 정복을 막았다)
const MAX_FIELD_LEVEL: int = 200

enum Crop { WHEAT, CORN, PUMPKIN, GOLDEN }
const CROPS: Array[Dictionary] = [
	{"name": "밀", "hp": 10.0, "vitality": 1.0},
	{"name": "옥수수", "hp": 45.0, "vitality": 5.0},
	{"name": "호박", "hp": 200.0, "vitality": 25.0},
	{"name": "황금 이삭", "hp": 60.0, "vitality": 200.0},  # 아주 가끔 심긴다. 찾아가 시들게 하는 재미 (회귀 용사의 보물 요정)
]
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

const CLOUD_TICK: float = 0.5          # 구름은 이 간격(초)마다 원 안의 작물을 한꺼번에 친다 (곡괭이질처럼 박자가 보이게)
const DUSK_TICK_CUT: float = 0.05      # 어스름: 레벨당 박자 간격 −5%
const CLOUD_BASE_RADIUS: float = 1.0   # 칸
const CLOUD_RADIUS_PER_LEVEL: float = 0.1   # 넓은 구름: 레벨당 기본 반경의 +10%
const CLOUD_BASE_DPS: float = 6.0      # 원 안 작물 하나가 받는 초당 피해 (밀이 2초 안에 시든다)
const TOXIN_MULTIPLIER: float = 1.3    # 독한 포자: 레벨당 구름 피해 ×1.3 (복리)

const SPREAD_PER_LEVEL: float = 0.05   # 번지는 곰팡이: 시든 작물이 옆 칸(상하좌우)마다 번질 확률 +5%p
const ROT_BASE_SHARE: float = 0.3      # 번짐에 걸린 작물이 받는 초당 피해 = 구름 피해 × (0.3 + 썩은 뿌리 0.15/레벨)
const ROT_SHARE_PER_LEVEL: float = 0.15

const CROW_INTERVAL: float = 2.0       # 까마귀 한 마리가 쪼는 간격 (초)
const CROW_PECK_SHARE: float = 2.0     # 한 번 쪼는 피해 = 구름 피해(초당) × 2 × (1 + 날카로운 부리 0.5/레벨)
const BEAK_PER_LEVEL: float = 0.5
const FEATHER_PER_LEVEL: float = 0.15  # 검은 깃털: 쪼인 작물이 번짐에 걸릴 확률 +15%p

const REGROW_BASE_DELAY: float = 15.0  # 다시 자라는 뿌리: 시든 칸에 이만큼(초) 뒤 새 작물 (레벨마다 ×0.9)
const REGROW_DELAY_STEP: float = 0.9
const VITALITY_PER_LEVEL: float = 0.2  # 썩은 냄새: 레벨당 생기 +20% (더하기. 복리로 두면 독한 포자와 함께 수입이 비용을 앞질러 벽이 사라졌다)


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


## 밭 단계의 작물 비율 (밀·옥수수·호박의 합 1). 탐스러운 호박은 밀에서 덜어 호박에 준다
func crop_weights(field_level: int, pumpkin_level: int = 0) -> Array[float]:
	var moved := minf(CROP_SHIFT * (field_level - 1), CROP_WEIGHTS[0] - MIN_WHEAT_WEIGHT)
	var wheat := CROP_WEIGHTS[0] - moved
	var pumpkin_extra := minf(PUMPKIN_WEIGHT_PER_LEVEL * pumpkin_level, wheat - MIN_WHEAT_WEIGHT * 0.5)
	return [wheat - pumpkin_extra, CROP_WEIGHTS[1] + moved * 0.5, CROP_WEIGHTS[2] + moved * 0.5 + pumpkin_extra]


## 심기는 작물 하나가 황금 이삭일 확률
func golden_chance(golden_level: int) -> float:
	return GOLDEN_BASE_CHANCE + GOLDEN_CHANCE_PER_LEVEL * golden_level


## 칸에 작물이 심길 확률: 0.3 + 0.07 × 빽빽한 밭
func field_fill(dense_level: int) -> float:
	return minf(BASE_FILL + FILL_PER_LEVEL * dense_level, 1.0)


## 구름 반경 (칸): 1 × (1 + 0.1 × 넓은 구름)
func cloud_radius(radius_level: int) -> float:
	return CLOUD_BASE_RADIUS * (1.0 + CLOUD_RADIUS_PER_LEVEL * radius_level)


## 원 안 작물 하나가 받는 초당 피해: 6 × 1.3^독한 포자
func cloud_dps(toxin_level: int) -> float:
	return cap(CLOUD_BASE_DPS * pow(TOXIN_MULTIPLIER, toxin_level))


## 구름 박자 간격 (초): 0.5 × (1 − 0.05 × 어스름)
func cloud_tick(dusk_level: int) -> float:
	return CLOUD_TICK * maxf(1.0 - DUSK_TICK_CUT * dusk_level, 0.2)


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


## 쪼인 작물이 번짐에 걸릴 확률
func feather_chance(feather_level: int) -> float:
	return minf(FEATHER_PER_LEVEL * feather_level, 1.0)


## 시든 칸이 다시 자라기까지 (초). 0레벨이면 다시 자라지 않는다 (0)
func regrow_delay(regrow_level: int) -> float:
	if regrow_level <= 0:
		return 0.0
	return REGROW_BASE_DELAY * pow(REGROW_DELAY_STEP, regrow_level - 1)


## 생기 배율: 1 + 0.2 × 썩은 냄새
func vitality_multiplier(rot_value_level: int) -> float:
	return 1.0 + VITALITY_PER_LEVEL * rot_value_level

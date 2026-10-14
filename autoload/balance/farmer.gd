extends "res://autoload/balance/night.gd"
## Balance 2.5부: 농부와 수확일 (GDD 8절 M3). 밭 5단계부터 농부가 밤에 밭을 걸어 다니며 둘레의 작물에 약을 치고(구름 피해 절반, 번짐 씻기)
## 시든 칸에 다시 심는다. 5의 배수 단계는 수확일(보스 밤): 작물이 단단하고 값지며 농부가 하나 더 나온다. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

const FARMER_FROM_LEVEL: int = 5         # 농부가 나오는 밭 단계
const FARMER_MORE_LEVELS: Array[int] = [15, 30]  # 이 단계부터 한 명씩 더
const FARMER_SPEED: float = 1.5          # 칸/초
const FARMER_RADIUS: float = 1.5         # 약을 치는 둘레 (칸)
const FARMER_GUARD: float = 0.5          # 둘레 안 작물이 받는 구름·번짐 피해 배율
const SEEP_PER_LEVEL: float = 0.1        # 스며드는 독: 레벨당 그 배율 +0.1 (5레벨이면 약이 안 듣는다)
const RACKET_STUN_PER_LEVEL: float = 0.4 # 까마귀 소란: 쫄 때마다 농부 하나가 레벨당 0.4초 멈춘다
const FARMER_REPLANT_INTERVAL: float = 4.0  # 이만큼(초)마다 둘레 안의 시든 칸 하나에 다시 심는다
const HARVEST_INTERVAL: int = 5          # 5의 배수 단계가 수확일
const HARVEST_HP: float = 3.0            # 수확일 작물 체력 ×3
const HARVEST_VITALITY: float = 3.0      # 수확일 작물 생기 ×3
const HARVEST_CLEAR_BONUS: float = 0.5   # 수확일을 정복하면 이번 밤 생기 +50%
const BOUNTY_PER_LEVEL: float = 0.5      # 풍요의 저주: 레벨당 수확일 생기 +50% (더하기. ×1.5 복리면 첫 철에 200단계 끝까지 내달렸다)


## 이 밭 단계에 나오는 농부 수 (수확일이면 한 명 더)
func farmer_count(field_level: int) -> int:
	if field_level < FARMER_FROM_LEVEL:
		return 0
	var count := 1
	for level in FARMER_MORE_LEVELS:
		if field_level >= level:
			count += 1
	return count + (1 if is_harvest(field_level) else 0)


## 농부 둘레 안 작물이 받는 피해 배율 (스며드는 독)
func farmer_guard(seep_level: int) -> float:
	return minf(FARMER_GUARD + SEEP_PER_LEVEL * seep_level, 1.0)


## 까마귀가 한 번 쫄 때 농부가 멈추는 초
func racket_stun(racket_level: int) -> float:
	return RACKET_STUN_PER_LEVEL * racket_level


## 수확일(보스 밤)인지
func is_harvest(field_level: int) -> bool:
	return field_level % HARVEST_INTERVAL == 0


## 수확일 작물 체력 배율
func harvest_hp(field_level: int) -> float:
	return HARVEST_HP if is_harvest(field_level) else 1.0


## 수확일 작물 생기 배율 (풍요의 저주: 레벨마다 +50%, 더하기)
func harvest_vitality(field_level: int, bounty_level: int = 0) -> float:
	return HARVEST_VITALITY * (1.0 + BOUNTY_PER_LEVEL * bounty_level) if is_harvest(field_level) else 1.0

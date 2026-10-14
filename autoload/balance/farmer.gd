extends "res://autoload/balance/night.gd"
## Balance 2.5부: 지키는 이들과 수확일 (GDD 2절 맞서는 쪽, 8절 M3). 밭 5단계부터 지키는 이가 밤에 밭을 걸어 다니며 둘레의 작물에 약을 치고
## (구름·번짐 피해 줄이기, 번짐 씻기) 시든 칸에 다시 심는다. 밭이 깊어질수록 농부 → 농협 감독관 → 농업부 관리로 바뀌고, 150단계부터 수확일 밤엔 풍년의 여신이 나온다.
## 5의 배수 단계는 수확일(보스 밤): 작물이 단단하고 값지며 지키는 이가 하나 더 나온다. 수치는 시뮬레이션으로 맞춘다 (docs/BALANCE_SIM.md)

enum Guardian { FARMER, INSPECTOR, OFFICIAL, GODDESS }
## from: 나오는 밭 단계. speed 칸/초, radius 약 둘레(칸), guard 둘레 안 피해 배율, replant 다시 심는 간격(초)
const GUARDIANS: Array[Dictionary] = [
	{"name": "농부", "from": 5, "speed": 1.5, "radius": 1.5, "guard": 0.5, "replant": 4.0},
	{"name": "농협 감독관", "from": 25, "speed": 1.6, "radius": 2.2, "guard": 0.45, "replant": 3.5},
	{"name": "농업부 관리", "from": 45, "speed": 2.4, "radius": 1.8, "guard": 0.4, "replant": 2.0},
	{"name": "풍년의 여신", "from": 70, "speed": 1.0, "radius": 3.0, "guard": 0.3, "replant": 1.0},  # 수확일 밤에만, 더하는 한 명이 여신
]
const FARMER_FROM_LEVEL: int = 5         # 지키는 이가 나오는 밭 단계
const FARMER_MORE_LEVELS: Array[int] = [15, 30]  # 이 단계부터 한 명씩 더
const FARMER_RADIUS: float = 1.5         # 농부의 둘레 (화면·테스트가 쓰는 기본값. 종류별 값은 GUARDIANS)
const FARMER_GUARD: float = 0.5
const FARMER_SPEED: float = 1.5
const FARMER_REPLANT_INTERVAL: float = 4.0
const SEEP_PER_LEVEL: float = 0.1        # 스며드는 독: 레벨당 둘레 안 피해 배율 +0.1
const RACKET_STUN_PER_LEVEL: float = 0.4 # 까마귀 소란: 쫄 때마다 지키는 이 하나가 레벨당 0.4초 멈춘다
const HARVEST_INTERVAL: int = 5          # 5의 배수 단계가 수확일
const HARVEST_HP: float = 1.5  # 수확일 작물 체력 배율 (옛 ×3. 단계마다 체력이 덜 오르니 줄였다)
const HARVEST_VITALITY: float = 2.0  # 수확일 작물 생기 배율 (보스 밤의 보상)
const HARVEST_CLEAR_BONUS: float = 0.5   # 수확일을 정복하면 이번 밤 생기 +50%
const BOUNTY_PER_LEVEL: float = 0.5      # 풍요의 저주: 레벨당 수확일 생기 +50% (더하기. ×1.5 복리면 첫 철에 200단계 끝까지 내달렸다)


## 이 밭 단계에 나오는 지키는 이 수 (수확일이면 한 명 더)
func farmer_count(field_level: int) -> int:
	if field_level < FARMER_FROM_LEVEL:
		return 0
	var count := 1
	for level in FARMER_MORE_LEVELS:
		if field_level >= level:
			count += 1
	return count + (1 if is_harvest(field_level) else 0)


## 이 밭 단계의 지키는 이들 (종류 목록). 여신이 열린 뒤 수확일엔 마지막 한 명이 여신, 나머지는 열린 가장 높은 종류
func guardians(field_level: int) -> Array[int]:
	var result: Array[int] = []
	var count := farmer_count(field_level)
	var tier: int = Guardian.FARMER
	for kind: int in [Guardian.INSPECTOR, Guardian.OFFICIAL]:
		if field_level >= int(GUARDIANS[kind]["from"]):
			tier = kind
	for i in count:
		var goddess := i == count - 1 and is_harvest(field_level) and field_level >= int(GUARDIANS[Guardian.GODDESS]["from"])
		result.append(Guardian.GODDESS if goddess else tier)
	return result


func guardian_name(kind: int) -> String:
	return GUARDIANS[kind]["name"]


func guardian_speed(kind: int) -> float:
	return GUARDIANS[kind]["speed"]


func guardian_radius(kind: int) -> float:
	return GUARDIANS[kind]["radius"]


func guardian_replant(kind: int) -> float:
	return GUARDIANS[kind]["replant"]


## 둘레 안 작물이 받는 피해 배율 (스며드는 독이 더한다)
func guardian_guard(kind: int, seep_level: int) -> float:
	return minf(float(GUARDIANS[kind]["guard"]) + SEEP_PER_LEVEL * seep_level, 1.0)


## 농부의 피해 배율 (옛 이름, 테스트가 쓴다)
func farmer_guard(seep_level: int) -> float:
	return guardian_guard(Guardian.FARMER, seep_level)


## 까마귀가 한 번 쫄 때 지키는 이가 멈추는 초
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

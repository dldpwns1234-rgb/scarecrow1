extends "res://autoload/balance/skills.gd"
## Balance 2.65부: 어둠의 나무 둘째 묶음의 효과 (방장 2026-10-15 #529: 나무를 두세 배로, 판마다 새로 사며 자라는 맛). 칸의 이름·비용은 balance/upgrades.gd,
## 작물마다 칸은 balance/crops.gd, 스킬마다 '센·잦은' 칸은 balance/skills.gd. 여기는 구름·시간·물결·까마귀·지키는 이 맞서기. 레벨은 인자로 받는다

const ECHO_SHARE_PER_LEVEL: float = 0.15     # 메아리 포자: 구름 둘레 한 칸 띠의 작물이 받는 구름 피해의 몫
const ECHO_WIDTH: float = 1.0                # 띠 너비 (칸)
const DOUBLE_CHANCE_PER_LEVEL: float = 0.08  # 두 번 치는 구름: 박자마다 한 번 더 칠 확률
const STICKY_PER_LEVEL: float = 0.25         # 끈적한 포자: 번진 채 시든 작물의 생기 +25%씩
const DAWN_SECONDS_PER_LEVEL: float = 1.0    # 새벽 미루기: 정복할 때마다 밤 +1초씩
const ROOTS_PER_LEVEL: float = 0.25          # 무성한 뿌리: 다시 자란 작물의 생기 +25%씩
const WAVES_PER_LEVEL: float = 0.1           # 물결의 기세: 물결 하나마다 생기 +10%씩 (물결 수만큼 쌓인다)
const FRENZY_POWER_PER_LEVEL: float = 0.5    # 광란: 몰아치기 피해 배율 +0.5씩
const HARVEST_MOON_PER_LEVEL: float = 0.25   # 수확의 달: 수확일 정복 보너스 +25%p씩
const CARRION_PER_LEVEL: float = 0.3         # 썩은 고기: 까마귀가 쪼아 시든 작물의 생기 +30%씩
const SCARE_PER_LEVEL: float = 0.08          # 노려보는 허수아비: 지키는 이 걸음 −8%씩
const ROTTEN_SPRAY_PER_LEVEL: float = 0.08   # 썩은 약통: 약 친 둘레 −8%씩
const LATE_SLEEPER_PER_LEVEL: float = 0.2    # 늦잠: 다시 심는 간격 +20%씩
const GUARD_FLOOR: float = 0.3               # 걸음·둘레가 아무리 줄어도 이만큼은 남는다


func echo_share(level: int) -> float:
	return ECHO_SHARE_PER_LEVEL * level


func double_chance(level: int) -> float:
	return minf(DOUBLE_CHANCE_PER_LEVEL * level, 1.0)


## 생기 배율: 번진 채 시든 작물 (끈적한 포자)
func sticky_multiplier(level: int) -> float:
	return 1.0 + STICKY_PER_LEVEL * level


func dawn_seconds(level: int) -> float:
	return DAWN_SECONDS_PER_LEVEL * level


## 생기 배율: 다시 자란 작물 (무성한 뿌리)
func roots_multiplier(level: int) -> float:
	return 1.0 + ROOTS_PER_LEVEL * level


## 생기 배율: 이번 밤에 정복한 물결 수만큼 (물결의 기세)
func waves_multiplier(level: int, waves: int) -> float:
	return 1.0 + WAVES_PER_LEVEL * level * waves


## 새벽 전 몰아치기의 피해 배율 (광란이 더한다)
func frenzy_multiplier(power_level: int) -> float:
	return FRENZY_MULTIPLIER + FRENZY_POWER_PER_LEVEL * power_level


## 수확일을 정복하면 이번 물결 생기에 얹는 몫 (수확의 달이 더한다)
func harvest_clear_bonus(moon_level: int) -> float:
	return HARVEST_CLEAR_BONUS + HARVEST_MOON_PER_LEVEL * moon_level


## 생기 배율: 까마귀가 쪼아 시든 작물 (썩은 고기)
func carrion_multiplier(level: int) -> float:
	return 1.0 + CARRION_PER_LEVEL * level


## 지키는 이 걸음 배율 (노려보는 허수아비)
func scare_factor(level: int) -> float:
	return maxf(1.0 - SCARE_PER_LEVEL * level, GUARD_FLOOR)


## 지키는 이 약 둘레 배율 (썩은 약통)
func spray_radius_factor(level: int) -> float:
	return maxf(1.0 - ROTTEN_SPRAY_PER_LEVEL * level, GUARD_FLOOR)


## 지키는 이 다시 심는 간격 배율 (늦잠)
func replant_factor(level: int) -> float:
	return 1.0 + LATE_SLEEPER_PER_LEVEL * level

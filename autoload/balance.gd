extends "res://autoload/balance/night.gd"
## Balance (오토로드): 모든 수치와 공식. 바깥에서는 Balance.만 쓴다. 200줄 규칙 때문에 balance/ 아래 부분 스크립트를 상속으로 이어 붙인다.
## 사슬: core(한계) → upgrades(업그레이드 나무) → night(밭·작물·구름·번짐·까마귀) → balance.gd(밤 길이). 앞 스크립트는 뒤 스크립트의 것을 못 본다

const NIGHT_BASE_SECONDS: float = 60.0   # 밤 한 판의 길이 (GDD 4절)
const NIGHT_SECONDS_PER_LEVEL: float = 5.0  # 긴 밤 레벨당


## 이번 밤의 길이: 기본 + 긴 밤 레벨 × 5초
func night_seconds(long_night_level: int) -> float:
	return NIGHT_BASE_SECONDS + NIGHT_SECONDS_PER_LEVEL * long_night_level

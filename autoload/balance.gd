extends "res://autoload/balance/story.gd"
## Balance (오토로드): 모든 수치와 공식. 바깥에서는 Balance.만 쓴다. 200줄 규칙 때문에 balance/ 아래 부분 스크립트를 상속으로 이어 붙인다.
## 사슬: core(한계) → upgrades(어둠의 나무) → night(밭·작물·구름·번짐·까마귀·다시 자라기) → farmer(지키는 이·수확일) → skills(밤 스킬) → workers(아지트 일꾼) → winter(겨울잠·꿈의 상점) → story(이야기 조각, 윤슬) → balance.gd(밤 길이, 약속된 휴식). 앞 스크립트는 뒤 스크립트의 것을 못 본다

const NIGHT_BASE_SECONDS: float = 20.0      # 밤 한 판의 길이. 짧게 시작한다 (방장 2026-10-14)
const NIGHT_SECONDS_PER_LEVEL: float = 3.0  # 긴 밤 레벨당
## 약속된 휴식 (이야기, 방장 2026-10-14): 어둠은 바친 생기가 많을수록 더 오래 쉬게 해 주겠다고 약속한다.
## 초 = 60 × 바친 생기^0.135. 생기 1천이면 2.5분, 첫 겨울잠(1e16) 2시간, 둘째(1e22) 17시간, 1e57이면 백 년 (이야기의 끝, 봇은 여섯째 철·4시간쯤).
## 처음엔 세제곱근이었다: 생기가 철마다 1만 배 넘게 불어나서 둘째 철(1시간)에 백 년을 넘었다 (docs/BALANCE_SIM.md)
const PROMISE_SECONDS_BASE: float = 60.0
const PROMISE_EXPONENT: float = 0.135
const HUNDRED_YEARS_SECONDS: float = 100.0 * 365.25 * 86400.0


## 이번 밤의 길이: 기본 + 긴 밤 레벨 × 3초
func night_seconds(long_night_level: int) -> float:
	return NIGHT_BASE_SECONDS + NIGHT_SECONDS_PER_LEVEL * long_night_level


## 바친 생기 합으로 약속된 휴식 (초)
func promised_rest_seconds(offered: float) -> float:
	return cap(PROMISE_SECONDS_BASE * pow(maxf(offered, 0.0), PROMISE_EXPONENT))

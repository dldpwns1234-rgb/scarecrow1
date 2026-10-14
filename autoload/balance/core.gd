extends Node
## Balance 0부: 숫자 한계와 시간 상한. 모든 수치와 공식은 Balance에만 둔다 (CLAUDE.md 아키텍처 원칙 1).
## 사슬: core → upgrades → (밤 공식 등 별빛이 더할 부분) → balance.gd. 앞 스크립트는 뒤 스크립트의 것을 못 본다

const MAX_NUMBER: float = 1e300  # 휴식·비용·피해의 상한. float은 1.8e308에서 무한대가 되어 비용·구매가 망가진다 (회귀 용사에서 데인 것)
const MAX_DELTA: float = 0.25    # _process의 delta 상한 (초)


## 상한에서 자르고 NaN은 0으로 (∞ × 0 같은 계산이 NaN을 낸다)
func cap(value: float) -> float:
	if is_nan(value):
		return 0.0
	return clampf(value, -MAX_NUMBER, MAX_NUMBER)

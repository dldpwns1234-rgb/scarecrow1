extends Node
## 테스트 스위트의 공통 도우미. 스위트는 이 스크립트를 상속하고 run()을 채운다.

var passed: int = 0
var failed: int = 0


func run() -> void:
	pass


func _equal(actual: Variant, expected: Variant, what: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


func _close(actual: float, expected: float, what: String) -> void:
	if is_equal_approx(actual, expected):
		passed += 1
	else:
		failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


## 아무것도 없는 상태에서 시작한다 (낮, 휴식 0, 업그레이드 0)
func _fresh() -> void:
	Upgrades.reset()
	Game.reset()

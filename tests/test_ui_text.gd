extends "res://tests/test_case.gd"
## 화면용 한글 다듬기 (scenes/ui/korean_text.gd): 띄어쓰기 자리에서만 줄 바꾸기, 받침에 맞는 조사. 나무 '최대' 단추의 ×N

const KoreanText := preload("res://scenes/ui/korean_text.gd")
const UpgradeTree := preload("res://scenes/day/upgrade_tree.gd")


func run() -> void:
	_equal(KoreanText.wrap("밤마다 황금 이삭이 하나씩 더 심긴다", 14), "밤마다 황금 이삭이 하나씩\n더 심긴다", "띄어쓰기 자리에서만 줄을 바꾼다")
	_equal(KoreanText.wrap("짧은 글", 14), "짧은 글", "짧으면 그대로")
	_equal(KoreanText.wrap("첫 줄\n둘째 줄", 2), "첫\n줄\n둘째\n줄", "있던 줄바꿈은 지키고 더 나눈다")
	_equal(KoreanText.wrap("아주긴낱말하나", 3), "아주긴낱말하나", "한 낱말이 길면 그 낱말만 한 줄")
	_equal(KoreanText.particle("검둥이", "을", "를"), "를", "받침 없음 → 를")
	_equal(KoreanText.particle("볏짚", "을", "를"), "을", "받침 있음 → 을")
	_equal(KoreanText.particle("crow", "을", "를"), "를", "한글이 아니면 받침 없는 쪽")
	_buy_max()


## 나무 '최대' 단추가 보이는 ×N은 Upgrades.buy_max가 실제로 사는 수와 같다 (상한 있는 칸·없는 칸)
func _buy_max() -> void:
	_fresh()
	for index in [Balance.Upgrade.RADIUS, Balance.Upgrade.TOXIN]:  # 넓은 구름(상한 10)을 사야 독한 포자(상한 없음)가 열린다
		Game.vitality = 5e4
		var shown := UpgradeTree.affordable_levels(index)
		_equal(shown > 1, true, "생기 5만이면 여러 레벨 (%s)" % Balance.upgrade_name(index))
		_equal(Upgrades.buy_max(index), shown, "최대 ×N = 실제로 산 레벨 수 (%s)" % Balance.upgrade_name(index))
		_equal(UpgradeTree.affordable_levels(index), 0, "산 뒤에는 지금 생기로 더 살 레벨이 없다")
	_fresh()

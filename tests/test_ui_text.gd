extends "res://tests/test_case.gd"
## 화면용 한글 다듬기 (scenes/ui/korean_text.gd): 띄어쓰기 자리에서만 줄 바꾸기, 받침에 맞는 조사

const KoreanText := preload("res://scenes/ui/korean_text.gd")


func run() -> void:
	_equal(KoreanText.wrap("밤마다 황금 이삭이 하나씩 더 심긴다", 14), "밤마다 황금 이삭이 하나씩\n더 심긴다", "띄어쓰기 자리에서만 줄을 바꾼다")
	_equal(KoreanText.wrap("짧은 글", 14), "짧은 글", "짧으면 그대로")
	_equal(KoreanText.wrap("첫 줄\n둘째 줄", 2), "첫\n줄\n둘째\n줄", "있던 줄바꿈은 지키고 더 나눈다")
	_equal(KoreanText.wrap("아주긴낱말하나", 3), "아주긴낱말하나", "한 낱말이 길면 그 낱말만 한 줄")
	_equal(KoreanText.particle("검둥이", "을", "를"), "를", "받침 없음 → 를")
	_equal(KoreanText.particle("볏짚", "을", "를"), "을", "받침 있음 → 을")
	_equal(KoreanText.particle("crow", "을", "를"), "를", "한글이 아니면 받침 없는 쪽")

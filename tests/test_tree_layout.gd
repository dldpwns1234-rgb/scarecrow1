extends "res://tests/test_case.gd"
## 스킬트리 배치 (scenes/day/tree_layout.gd): 사방으로 뻗기, 겹치지 않기, 선이 카드를 지나가지 않기, branch 키, 가운데 비우기

const TreeLayout := preload("res://scenes/day/tree_layout.gd")


func run() -> void:
	var cells := TreeLayout.cells(Balance.UPGRADES)
	_equal(cells.size(), Balance.UPGRADES.size(), "업그레이드마다 칸 하나")
	var seen := {}
	for cell in cells:
		_equal(seen.has(cell), false, "칸이 겹치지 않는다 %s" % cell)
		_equal(cell == Vector2i.ZERO, false, "가운데는 어둠의 계약 자리")
		seen[cell] = true
	_equal(TreeLayout.card_crossings(Balance.UPGRADES, cells), 0, "가지 선이 남의 카드를 지나가지 않는다 (방장 #529: 칸이 64개가 되자 가로질렀다)")

	var grown: Array[Dictionary] = Balance.UPGRADES.duplicate()
	var base := grown.size()
	for k in 10:  # 뒤에 열 칸을 더 붙여도 (깊은 칸들 아래에 하나씩)
		grown.append({"requires": base - 1 - k * 4})
	var grown_cells := TreeLayout.cells(grown)
	_equal(TreeLayout.card_crossings(grown, grown_cells), 0, "열 칸을 더 붙여도 선이 카드를 지나가지 않는다")
	_equal(grown_cells.slice(0, base) == cells, true, "뒤에 칸을 붙여도 앞 칸은 움직이지 않는다")

	var sample: Array[Dictionary] = [
		{"requires": -1}, {"requires": -1}, {"requires": -1}, {"requires": -1},
		{"requires": 0}, {"requires": 0}, {"requires": -1, "branch": "left"},
	]
	var placed := TreeLayout.cells(sample)
	_equal(placed[0], Vector2i(0, -1), "첫 뿌리는 위")
	_equal(placed[1], Vector2i(1, 0), "둘째는 오른쪽")
	_equal(placed[2], Vector2i(0, 1), "셋째는 아래")
	_equal(placed[3], Vector2i(-1, 0), "넷째는 왼쪽")
	_equal(placed[4], Vector2i(0, -2), "자식은 갈래 방향으로 한 칸 더")
	_equal(placed[5].y, -2, "둘째 자식은 같은 줄에서 옆으로 비켜 선다")
	_equal(placed[6].x, -1, "branch 키(왼쪽)를 따른다")
	_equal(placed[6].y != 0, true, "왼쪽 칸이 차 있으면 옆으로 비켜 선다")

	var with_center: Array[Dictionary] = [
		{"requires": -1, "branch": "center"},
		{"requires": 0, "branch": "right"}, {"requires": 0, "branch": "down"}, {"requires": 1},
	]
	var around := TreeLayout.cells(with_center)
	_equal(around[0], Vector2i.ZERO, "branch center는 가운데")
	_equal(around[1], Vector2i(1, 0), "가운데의 자식은 자기 branch 방향으로")
	_equal(around[2], Vector2i(0, 1), "다른 자식은 다른 방향")
	_equal(around[3], Vector2i(2, 0), "그 다음은 부모 방향을 따라간다")

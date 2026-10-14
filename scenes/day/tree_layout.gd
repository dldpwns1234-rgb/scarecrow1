extends RefCounted
## 스킬트리 배치 (방장 2026-10-14: 사방으로 뻗는 나무). 가운데(0, 0)는 '어둠의 계약'이고, 뿌리 업그레이드(requires -1)는 갈래 방향으로 한 칸 나간다.
## 갈래 방향은 데이터의 "branch"(up·right·down·left)를 따르고, 없으면 뿌리 순서대로 위·오른쪽·아래·왼쪽에 둔다.
## 자식은 부모에서 갈래 방향으로 한 칸 더 나가고, 그 칸이 차 있으면 옆(갈래에 수직)으로 비켜 선다. 화면과 떨어진 순수 계산이라 테스트한다

const DIRECTIONS := {"up": Vector2i(0, -1), "right": Vector2i(1, 0), "down": Vector2i(0, 1), "left": Vector2i(-1, 0)}
const ORDER: PackedStringArray = ["up", "right", "down", "left"]
const MAX_SIDE_STEP: int = 6  # 옆으로 비켜 설 칸 수의 한계. 넘으면 갈래 방향으로 더 나간다


## 업그레이드마다 격자 칸. 가운데 (0, 0)은 비워 둔다. requires는 늘 앞 번호다 (Balance가 지킨다)
static func cells(upgrades: Array[Dictionary]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = []
	var taken := {Vector2i.ZERO: true}
	var roots := 0
	for i in upgrades.size():
		var need: int = upgrades[i]["requires"]
		var dir: Vector2i
		var from := Vector2i.ZERO
		if need < 0:
			var key: String = upgrades[i].get("branch", ORDER[roots % ORDER.size()])
			dir = DIRECTIONS.get(key, Vector2i(0, -1))
			roots += 1
		else:
			dir = dirs[need]
			from = result[need]
		var cell := _free_cell(from, dir, taken)
		taken[cell] = true
		result.append(cell)
		dirs.append(dir)
	return result


## 부모 다음 칸, 차 있으면 다음 칸의 옆(+1, -1, +2, -2 …), 그래도 없으면 한 칸 더 나가서 다시
static func _free_cell(from: Vector2i, dir: Vector2i, taken: Dictionary) -> Vector2i:
	var side := Vector2i(-dir.y, dir.x)
	var ahead := from + dir
	while true:
		if not taken.has(ahead):
			return ahead
		for step in range(1, MAX_SIDE_STEP + 1):
			for sign_value: int in [1, -1]:
				var cell := ahead + side * step * sign_value
				if not taken.has(cell):
					return cell
		ahead += dir
	return ahead

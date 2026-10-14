extends RefCounted
## 스킬트리 배치 (방장 2026-10-14: 사방으로 뻗는 나무). 가운데(0, 0)는 '어둠의 계약'이고, 뿌리 업그레이드(requires -1)는 갈래 방향으로 한 칸 나간다.
## 갈래 방향은 데이터의 "branch"(up·right·down·left)를 따르고, 없으면 뿌리 순서대로 위·오른쪽·아래·왼쪽에 둔다.
## "branch": "center"인 줄(데이터에 넣은 어둠의 계약)은 가운데 자리이고, 그 자식들이 갈래의 첫 칸이 된다.
## 자식은 부모 둘레 몇 칸 안의 빈 칸 가운데 점수가 가장 낮은 칸에 선다: 갈래 방향 바로 앞이 가장 좋고, 옆으로 비키거나 멀어질수록,
## 제 갈래 쪽(가운데에서 본 방향)을 벗어날수록, 가지 선이 다른 카드를 지나가거나 다른 선과 엇갈릴수록 나쁘다 (방장 #529: 칸이 64개가 되자
## 옆으로 비켜 선 칸의 선이 남의 카드를 가로질렀다). 앞 번호부터 차례로 놓아서 뒤에 칸을 붙여도 앞 칸은 움직이지 않는다. 화면과 떨어진 순수 계산이라 테스트한다

const DIRECTIONS := {"up": Vector2i(0, -1), "right": Vector2i(1, 0), "down": Vector2i(0, 1), "left": Vector2i(-1, 0)}
const ORDER: PackedStringArray = ["up", "right", "down", "left"]
const STEP := Vector2(196, 136)   # 격자 한 칸의 간격 (화면 tree_board도 쓴다)
const CARD := Vector2(150, 96)    # 카드 크기
const CARD_MARGIN: float = 6.0    # 선이 카드 모서리를 이만큼 스치는 건 봐준다
const REACH: int = 3              # 부모에서 이 칸 수 안쪽부터 자리를 찾는다
const MAX_REACH: int = 8          # 선이 카드를 피할 자리가 없으면 여기까지 넓힌다
const SIDE_COST: float = 0.6      # 갈래 방향에서 옆으로 비킨 칸 수의 제곱마다
const FAR_COST: float = 1.0       # 바로 앞보다 더 나가거나 덜 나간 칸 수의 제곱마다
const LEVEL_COST: float = 0.5     # 부모와 같은 줄(앞으로 안 나감)
const OFF_SECTOR_COST: float = 3.0  # 제 갈래 쪽을 벗어나면 (갈래끼리 섞이지 않게)
const CROSS_CARD_COST: float = 100.0  # 가지 선이 다른 카드를 지나가면, 새 카드가 남의 선을 덮으면
const CROSS_LINE_COST: float = 4.0    # 가지 선끼리 엇갈리면


## 업그레이드마다 격자 칸. 가운데 (0, 0)은 어둠의 계약 자리라 다른 칸은 쓰지 않는다. requires는 늘 앞 번호다 (Balance가 지킨다)
static func cells(upgrades: Array[Dictionary]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = []
	var sectors: Array[Vector2i] = []
	var taken := {Vector2i.ZERO: true}
	var lines: Array[PackedVector2Array] = []
	var roots := 0
	for i in upgrades.size():
		var need: int = upgrades[i]["requires"]
		var key: String = upgrades[i].get("branch", "")
		if key == "center":  # 가운데 '어둠의 계약'이 데이터에 있으면 가운데 원 자리
			result.append(Vector2i.ZERO)
			dirs.append(Vector2i.ZERO)
			sectors.append(Vector2i.ZERO)
			continue
		var dir: Vector2i
		var from := Vector2i.ZERO
		var sector: Vector2i
		if need < 0 or dirs[need] == Vector2i.ZERO:  # 갈래의 첫 칸: 자기 branch, 없으면 순서대로
			dir = DIRECTIONS.get(key if not key.is_empty() else ORDER[roots % ORDER.size()], Vector2i(0, -1))
			sector = dir
			roots += 1
		else:
			dir = DIRECTIONS.get(key, dirs[need])  # branch가 있으면 거기서 꺾는다
			from = result[need]
			sector = sectors[need]
		var cell := _best_cell(from, dir, sector, taken, lines)
		taken[cell] = true
		lines.append(PackedVector2Array([center_of(from), center_of(cell)]))
		result.append(cell)
		dirs.append(dir)
		sectors.append(sector)
	return result


## 칸 가운데의 판 위 자리 (가운데 원이 0, 0)
static func center_of(cell: Vector2i) -> Vector2:
	return Vector2(cell) * STEP


## 카드 자리 (선이 모서리를 살짝 스치는 건 봐주게 조금 줄인다)
static func card_rect(cell: Vector2i) -> Rect2:
	return Rect2(center_of(cell) - CARD * 0.5, CARD).grow(-CARD_MARGIN)


## 가지 선이 남의 카드를 지나가는 수 (테스트·확인용)
static func card_crossings(upgrades: Array[Dictionary], placed: Array[Vector2i]) -> int:
	var count := 0
	for i in placed.size():
		var need: int = upgrades[i]["requires"]
		var from := placed[need] if need >= 0 else Vector2i.ZERO
		for j in placed.size():
			if j != i and placed[j] != from and placed[j] != placed[i] and _hits_rect(center_of(from), center_of(placed[i]), card_rect(placed[j])):
				count += 1
	return count


## 부모 둘레 REACH칸 안의 빈 칸 가운데 점수가 가장 낮은 칸. 값싼 점수(거리·갈래)로 먼저 줄 세우고, 그보다 나쁠 수 없는 칸만 선을 따진다.
## 둘레가 다 막혀 선이 카드를 지나갈 수밖에 없으면 MAX_REACH까지 넓혀 본다
static func _best_cell(from: Vector2i, dir: Vector2i, sector: Vector2i, taken: Dictionary, lines: Array[PackedVector2Array]) -> Vector2i:
	var best := from + dir * (MAX_REACH + 1)
	var best_cost := INF
	for reach in range(REACH, MAX_REACH + 1):
		var options: Array = []
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var cell := from + Vector2i(dx, dy)
				var ahead := (cell - from).x * dir.x + (cell - from).y * dir.y
				if taken.has(cell) or ahead < 0:
					continue
				options.append([_base_cost(from, cell, dir, sector), cell])
		options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for option: Array in options:
			if option[0] >= best_cost:
				break
			var cost: float = option[0] + _cross_cost(from, option[1], taken, lines)
			if cost < best_cost:
				best_cost = cost
				best = option[1]
		if best_cost < CROSS_CARD_COST:
			break
	return best


## 거리와 갈래: 갈래 방향 바로 앞이 0
static func _base_cost(from: Vector2i, cell: Vector2i, dir: Vector2i, sector: Vector2i) -> float:
	var offset := cell - from
	var ahead := offset.x * dir.x + offset.y * dir.y
	var side := absi(offset.x * dir.y - offset.y * dir.x)
	var cost := (ahead - 1) * (ahead - 1) * FAR_COST + side * side * SIDE_COST  # 제곱: 멀리 비스듬히 뻗는 긴 가지가 싫다
	if ahead == 0:
		cost += LEVEL_COST
	if not _in_sector(cell, sector):
		cost += OFF_SECTOR_COST
	return cost


## 가운데에서 본 방향이 그 갈래 쪽인가 (판 위 거리로 비스듬한 45도 선을 가른다. 선 위는 양쪽 다)
static func _in_sector(cell: Vector2i, sector: Vector2i) -> bool:
	var point := center_of(cell)
	var along := point.x * sector.x + point.y * sector.y
	var across := absf(point.x * sector.y - point.y * sector.x)
	return along > 0.0 and along >= across


## 새 가지 선이 남의 카드를 지나가거나, 새 카드가 남의 선을 덮거나, 선끼리 엇갈리는 값
static func _cross_cost(from: Vector2i, cell: Vector2i, taken: Dictionary, lines: Array[PackedVector2Array]) -> float:
	var a := center_of(from)
	var b := center_of(cell)
	var cost := 0.0
	for other: Vector2i in taken:
		if other != from and _hits_rect(a, b, card_rect(other)):
			cost += CROSS_CARD_COST
	var own := card_rect(cell)
	for line in lines:
		if _hits_rect(line[0], line[1], own):
			cost += CROSS_CARD_COST
		elif line[0] != a and line[1] != a and Geometry2D.segment_intersects_segment(a, b, line[0], line[1]) != null:
			cost += CROSS_LINE_COST
	return cost


## 선분이 사각형을 지나가는가 (끝점이 안에 있거나 변과 만난다)
static func _hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[k], corners[(k + 1) % 4]) != null:
			return true
	return false

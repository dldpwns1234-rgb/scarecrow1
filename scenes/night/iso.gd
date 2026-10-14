extends RefCounted
## 밤 밭의 아이소메트릭 투영 (배치용): 격자 좌표(칸 단위, Night와 같다) ↔ 화면 좌표. 칸 하나가 폭 TILE_W·높이 TILE_H의 마름모다.
## origin은 격자 (0, 0) 꼭짓점(밭 맨 위 꼭짓점)의 화면 자리

const TILE_W: float = 76.0
const TILE_H: float = 38.0


static func to_screen(origin: Vector2, grid: Vector2) -> Vector2:
	return origin + Vector2((grid.x - grid.y) * TILE_W * 0.5, (grid.x + grid.y) * TILE_H * 0.5)


static func to_grid(origin: Vector2, screen: Vector2) -> Vector2:
	var p := screen - origin
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## 격자 위 반지름 r의 원이 화면에서 그리는 타원의 반지름 (가로, 세로): 45° 돌린 정사각 격자라 √2배
static func ellipse_radii(r: float) -> Vector2:
	return Vector2(r * sqrt(2.0) * TILE_W * 0.5, r * sqrt(2.0) * TILE_H * 0.5)


## 칸 하나의 마름모 꼭짓점 (위, 오른쪽, 아래, 왼쪽)
static func tile_polygon(origin: Vector2, x: int, y: int) -> PackedVector2Array:
	return PackedVector2Array([
		to_screen(origin, Vector2(x, y)),
		to_screen(origin, Vector2(x + 1, y)),
		to_screen(origin, Vector2(x + 1, y + 1)),
		to_screen(origin, Vector2(x, y + 1)),
	])


## 밭 전체가 차지하는 화면 크기 (마름모의 폭과 높이)
static func field_size(cells: int) -> Vector2:
	return Vector2(cells * TILE_W, cells * TILE_H)

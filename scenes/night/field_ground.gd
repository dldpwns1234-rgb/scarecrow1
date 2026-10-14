extends Node2D
## 밤 밭의 땅 (field_view.gd의 아래층): 마름모 칸(풀 체크무늬, 시든 칸·번진 칸은 그 색)과 흙 옆면. 칸 수는 Night.field_size를 따른다.
## field_view가 그림이 바뀔 때 queue_redraw()를 부른다. 판(night_screen.gd) 안 좌표로 그린다. 상수는 연출용이다

const Iso := preload("res://scenes/night/iso.gd")
const GRASS := [Color("3f6b3a"), Color("44733e")]  # 달빛 아래 풀 (체크무늬)
const BLIGHT := Color("4a4232")         # 시든 칸
const ROT_GROUND := Color("4d3f5c")     # 번짐에 걸린 칸
const SIDE_LEFT := Color("4b3524")      # 흙 옆면
const SIDE_RIGHT := Color("3a291c")
const SIDE_DEPTH: float = 16.0
const EDGE := Color(0.0, 0.0, 0.0, 0.18)


func _draw() -> void:
	var n := Night.field_size
	if Night.kinds.size() != n * n:
		return
	# 흙 옆면: 왼쪽 아래 모서리와 오른쪽 아래 모서리
	var left := Iso.to_screen(Vector2.ZERO, Vector2(0, n))
	var bottom := Iso.to_screen(Vector2.ZERO, Vector2(n, n))
	var right := Iso.to_screen(Vector2.ZERO, Vector2(n, 0))
	var down := Vector2(0.0, SIDE_DEPTH)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + down, left + down]), SIDE_LEFT)
	draw_colored_polygon(PackedVector2Array([bottom, right, right + down, bottom + down]), SIDE_RIGHT)
	for y in n:
		for x in n:
			var index := y * n + x
			var color: Color = GRASS[(x + y) % 2]
			if Night.kinds[index] != Night.EMPTY and not Night.is_alive(index):
				color = BLIGHT
			elif Night.infected[index] == 1:
				color = ROT_GROUND
			var polygon := Iso.tile_polygon(Vector2.ZERO, x, y)
			draw_colored_polygon(polygon, color)
			polygon.append(polygon[0])
			draw_polyline(polygon, EDGE, 1.0)

extends Node2D
## 밤 밭의 땅 (field_view.gd의 아래층): 마름모 칸(풀 체크무늬, 시든 칸·번진 칸은 그 색)과 흙 옆면, 칸 사이 격자선. 칸 수는 Night.field_size를 따른다.
## field_view가 그림이 바뀔 때 queue_redraw()를 부른다. 판(night_screen.gd) 안 좌표로 그린다. 상수는 연출용이다
## 칸마다 다각형·테두리를 따로 그리면 18×18 밭에서 시들 때마다 648번 그려 프레임이 반으로 떨어졌다 (2026-10-15 측정).
## 그래서 칸은 삼각형 묶음 한 번(칸 자리는 밭 크기가 바뀔 때만 다시 잰다), 격자선은 줄 몇 개로 그린다

const Iso := preload("res://scenes/night/iso.gd")
const GRASS := [Color("3f6b3a"), Color("44733e")]  # 달빛 아래 풀 (체크무늬)
const BLIGHT := Color("4a4232")         # 시든 칸
const ROT_GROUND := Color("4d3f5c")     # 번짐에 걸린 칸
const SIDE_LEFT := Color("4b3524")      # 흙 옆면
const SIDE_RIGHT := Color("3a291c")
const SIDE_DEPTH: float = 16.0
const EDGE := Color(0.0, 0.0, 0.0, 0.18)

var _size: int = -1
var _points := PackedVector2Array()   # 칸마다 꼭짓점 넷 (위·오른쪽·아래·왼쪽)
var _indices := PackedInt32Array()    # 칸마다 삼각형 둘
var _colors := PackedColorArray()
var _lines := PackedVector2Array()    # 격자선 (선분 양 끝)


func _draw() -> void:
	var n := Night.field_size
	if Night.kinds.size() != n * n:
		return
	if n != _size:
		_build(n)
	# 흙 옆면: 왼쪽 아래 모서리와 오른쪽 아래 모서리
	var left := Iso.to_screen(Vector2.ZERO, Vector2(0, n))
	var bottom := Iso.to_screen(Vector2.ZERO, Vector2(n, n))
	var right := Iso.to_screen(Vector2.ZERO, Vector2(n, 0))
	var down := Vector2(0.0, SIDE_DEPTH)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + down, left + down]), SIDE_LEFT)
	draw_colored_polygon(PackedVector2Array([bottom, right, right + down, bottom + down]), SIDE_RIGHT)
	for index in n * n:
		var color: Color
		if Night.kinds[index] != Night.EMPTY and not Night.is_alive(index):
			color = BLIGHT
		elif Night.infected[index] == 1:
			color = ROT_GROUND
		else:
			@warning_ignore("integer_division")
			color = GRASS[(index % n + index / n) % 2]
		var at := index * 4
		_colors[at] = color
		_colors[at + 1] = color
		_colors[at + 2] = color
		_colors[at + 3] = color
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)
	draw_multiline(_lines, EDGE, 1.0)


## 밭 크기가 바뀌면 칸 꼭짓점·삼각형·격자선을 다시 잰다
func _build(n: int) -> void:
	_size = n
	_points.resize(n * n * 4)
	_colors.resize(n * n * 4)
	_indices.resize(n * n * 6)
	for y in n:
		for x in n:
			var index := y * n + x
			var polygon := Iso.tile_polygon(Vector2.ZERO, x, y)
			for k in 4:
				_points[index * 4 + k] = polygon[k]
			var base := index * 4
			var tri := index * 6
			_indices[tri] = base
			_indices[tri + 1] = base + 1
			_indices[tri + 2] = base + 2
			_indices[tri + 3] = base
			_indices[tri + 4] = base + 2
			_indices[tri + 5] = base + 3
	_lines.clear()
	for k in n + 1:
		_lines.append(Iso.to_screen(Vector2.ZERO, Vector2(k, 0)))
		_lines.append(Iso.to_screen(Vector2.ZERO, Vector2(k, n)))
		_lines.append(Iso.to_screen(Vector2.ZERO, Vector2(0, k)))
		_lines.append(Iso.to_screen(Vector2.ZERO, Vector2(n, k)))

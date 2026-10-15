extends Control
## 어둠의 나무를 멀리 볼 때(줌 FAR_ZOOM 아래)의 모습 (장르 조사의 공통 불만 '나무 화면이 복잡하고 아이콘을 구분하기 어렵다', 방장 #587 뒤).
## 글이 뭉개지는 카드 위에 갈래 색 판을 덮는다: 위 역병 구름은 보라, 왼쪽 밤의 시간은 파랑, 오른쪽 밭 살찌우기는 초록, 아래 까마귀는 주황.
## 산 칸은 짙게, 아직 0레벨이면 옅게, 다 산 칸은 흰 테, 살 수 있는 칸은 금빛 테. 왼쪽 위에 갈래 이름표.
## 가까이 볼 때는 카드 윗변 가운데에 같은 갈래 색 짧은 띠만 얹는다 (어느 갈래 칸인지). 판(tree_board)이 자리를 바꿀 때 다시 그린다. 상수는 연출용이다

const TreeLayout := preload("res://scenes/day/tree_layout.gd")
const FAR_ZOOM: float = 0.5
const BRANCHES: Array = [  # [뿌리가 선 방향, 이름, 색]
	[Vector2i(0, -1), "역병 구름", Color("9d7bd8")],
	[Vector2i(-1, 0), "밤의 시간", Color("6fa8dc")],
	[Vector2i(1, 0), "밭 살찌우기", Color("9ad14f")],
	[Vector2i(0, 1), "까마귀", Color("e07a5f")],
]
const IDLE_ALPHA: float = 0.38       # 아직 0레벨인 칸
const CORNER: int = 5
const EDGE_WIDTH: float = 2.0
const AFFORD := Color("f2d27a")
const MAXED := Color(1.0, 1.0, 1.0, 0.85)
const LEGEND_FONT_SIZE: int = 16
const LEGEND_AT := Vector2(14, 14)   # 판 왼쪽 위에서
const LEGEND_SWATCH: float = 12.0
const LEGEND_LINE: float = 22.0
const LEGEND_BACK := Color(0.05, 0.04, 0.09, 0.7)
const BAND_WIDTH: float = 0.42     # 가까이 볼 때 띠 폭 (카드 폭 비율)
const BAND_HEIGHT: float = 6.0    # 줌 1일 때 띠 두께
const BAND_TOP: float = 3.0       # 카드 윗변에서 띠까지 (줌 1)

var _board: Control                  # tree_board.gd (card_rect·zoom)
var _cards: Array[Button] = []
var _branch: Array[int] = []         # 카드마다 BRANCHES 번호
var _box := StyleBoxFlat.new()


func _init(board: Control, cards: Array[Button], cells: Array[Vector2i]) -> void:
	_board = board
	_cards = cards
	for i in cards.size():
		_branch.append(_branch_of(i, cells))
	_box.set_corner_radius_all(CORNER)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 뿌리까지 거슬러 올라가 뿌리 칸이 가운데에서 어느 쪽에 섰는지 (판 위 거리로 큰 쪽)
static func _branch_of(index: int, cells: Array[Vector2i]) -> int:
	var root := index
	while Balance.upgrade_requires(root) >= 0 and Balance.UPGRADES[Balance.upgrade_requires(root)].get("branch", "") != "center":
		root = Balance.upgrade_requires(root)
	var at := Vector2(cells[root]) * TreeLayout.STEP
	var dir := Vector2i(signi(roundi(at.x)), 0) if absf(at.x) >= absf(at.y) else Vector2i(0, signi(roundi(at.y)))
	for b in BRANCHES.size():
		if BRANCHES[b][0] == dir:
			return b
	return 0


func _draw() -> void:
	var zoom := float(_board.get("zoom"))
	if zoom >= FAR_ZOOM:
		_draw_bands(zoom)
		return
	for i in _cards.size():
		if not _cards[i].visible:
			continue
		var rect: Rect2 = _board.call("card_rect", i)
		var color: Color = BRANCHES[_branch[i]][2]
		_box.bg_color = color if Upgrades.level(i) > 0 else Color(color, IDLE_ALPHA)
		_box.border_color = AFFORD if _cards[i].theme_type_variation == "AccentButton" else MAXED
		_box.set_border_width_all(int(EDGE_WIDTH) if _cards[i].theme_type_variation == "AccentButton" or Upgrades.is_maxed(i) else 0)
		draw_style_box(_box, rect)
	_draw_legend()


## 가까이 볼 때: 카드 윗변 가운데의 갈래 색 짧은 띠
func _draw_bands(zoom: float) -> void:
	for i in _cards.size():
		if not _cards[i].visible:
			continue
		var rect: Rect2 = _board.call("card_rect", i)
		var width := rect.size.x * BAND_WIDTH
		_box.bg_color = BRANCHES[_branch[i]][2]
		_box.set_border_width_all(0)
		draw_style_box(_box, Rect2(rect.position + Vector2((rect.size.x - width) * 0.5, BAND_TOP * zoom), Vector2(width, BAND_HEIGHT * zoom)))


func _draw_legend() -> void:
	var font := get_theme_default_font()
	var width := 0.0
	for branch: Array in BRANCHES:
		width = maxf(width, font.get_string_size(branch[1], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x)
	var back := Rect2(LEGEND_AT - Vector2(8, 6), Vector2(LEGEND_SWATCH + 8.0 + width + 16.0, LEGEND_LINE * BRANCHES.size() + 8.0))
	draw_rect(back, LEGEND_BACK)
	for b in BRANCHES.size():
		var top := LEGEND_AT + Vector2(0, LEGEND_LINE * b)
		draw_rect(Rect2(top + Vector2(0, 3), Vector2.ONE * LEGEND_SWATCH), BRANCHES[b][2])
		draw_string(font, top + Vector2(LEGEND_SWATCH + 8.0, LEGEND_SWATCH + 2.0), BRANCHES[b][1], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, Color.WHITE)

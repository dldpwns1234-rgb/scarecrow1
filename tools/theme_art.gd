extends SceneTree
## 테마 생성기 1부: 그림 틀 (방장 2026-10-15 '진짜 게임처럼', 아트 방향 '달빛 동화 그림책풍'). tools/make_theme.gd가 상속해 마지막에 _dress()를 부른다.
## 납작한 단색 상자 대신 SVG 9칸 늘림 그림을 입힌다: 단추는 볏짚 끈 나무판(눌리면 내려앉음), 주요 단추는 금칠 판, 패널은 바느질한 삼베.
## 타입 변형 WoodPanel(볏짚 끈 나무판: 결과 알림·확인 창·설정), Parchment(낡은 종이: 이야기 카드·다시 읽기, 글은 짙은 갈색은 화면이 정한다),
## DarkBoard(나무 틀 안 보랏빛 밤하늘: 어둠의 나무 칸을 헛간 벽과 갈라 보이게, 방장 2026-10-15).
## 글꼴은 주아체 Jua(둥글고 굵음, OFL, 방장 2026-10-15 고름). 주아체에 없는 드문 글자는 Noto Sans KR이 대신 그린다.
## 그림은 assets/ui/*.svg (손으로 그린 SVG가 원본). 9칸 늘림이라 가장자리 폭(margin)만큼은 그대로, 가운데는 늘어난다

const WOOD := "res://assets/ui/button_wood.svg"
const WOOD_PRESSED := "res://assets/ui/button_wood_pressed.svg"
const GOLD := "res://assets/ui/button_gold.svg"
const BURLAP := "res://assets/ui/frame_burlap.svg"
const WOOD_FRAME := "res://assets/ui/frame_wood.svg"
const PARCHMENT := "res://assets/ui/frame_parchment.svg"
const DARK_BOARD := "res://assets/ui/frame_dark.svg"
const BOARD_EDGE: int = 24          # 어둠의 판 나무 틀 폭
const JUA := "res://assets/fonts/Jua-Regular.ttf"
const NOTO := "res://assets/fonts/NotoSansKR-Regular.ttf"
const BUTTON_EDGE: int = 16          # 단추 그림의 가장자리 폭
const BUTTON_SHADOW: int = 10        # 단추 아래 그늘 두께 (글을 그만큼 위로)
const PANEL_EDGE: int = 20
const FRAME_EDGE: int = 28          # 나무판 틀·종이의 가장자리 폭
const FRAME_TEXT := Vector2(26, 22)
const BUTTON_TEXT := Vector2(14, 8)  # 단추 글 여백
const PANEL_TEXT := Vector2(16, 12)
const WOOD_TEXT := Color("f3e6c8")   # 나무판 위 글 (밝은 짚 색)
const WOOD_TEXT_HOVER := Color("fff4d8")
const WOOD_TEXT_DIM := Color("a39887")
const HOVER_TINT := Color(1.15, 1.1, 1.05)
const DISABLED_TINT := Color(0.55, 0.55, 0.6)
const GOLD_PRESSED_TINT := Color(0.85, 0.82, 0.78)

var _art_count: int = 0  # 저장할 때 서브 리소스 id를 고정한다 (다시 만들어도 파일 차이가 없게)


## Button·AccentButton·PanelContainer·Panel의 상자를 그림 틀로 바꾼다 (다른 타입 변형은 그대로)
func _dress(theme: Theme) -> void:
	var font := FontVariation.new()
	_art_count += 1
	font.resource_scene_unique_id = "art_%d" % _art_count
	font.base_font = load(JUA)
	font.fallbacks = [load(NOTO)]
	theme.default_font = font
	var wood := _box(WOOD, BUTTON_EDGE, BUTTON_TEXT, BUTTON_SHADOW)
	for state: String in ["normal"]:
		theme.set_stylebox(state, "Button", wood)
	theme.set_stylebox("hover", "Button", _tinted(wood, HOVER_TINT))
	theme.set_stylebox("pressed", "Button", _box(WOOD_PRESSED, BUTTON_EDGE, BUTTON_TEXT, 4, 6))
	theme.set_stylebox("disabled", "Button", _tinted(wood, DISABLED_TINT))
	for color: String in ["font_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color, "Button", WOOD_TEXT)
	theme.set_color("font_hover_color", "Button", WOOD_TEXT_HOVER)
	theme.set_color("font_disabled_color", "Button", WOOD_TEXT_DIM)
	var gold := _box(GOLD, BUTTON_EDGE, BUTTON_TEXT, BUTTON_SHADOW)
	theme.set_stylebox("normal", "AccentButton", gold)
	theme.set_stylebox("hover", "AccentButton", _tinted(gold, HOVER_TINT))
	theme.set_stylebox("pressed", "AccentButton", _tinted(gold, GOLD_PRESSED_TINT))
	var burlap := _box(BURLAP, PANEL_EDGE, PANEL_TEXT)
	burlap.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT  # 바느질 점선·올이 늘어나지 않고 되풀이되게
	burlap.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	theme.set_stylebox("panel", "PanelContainer", burlap)
	theme.set_stylebox("panel", "Panel", burlap)
	theme.add_type("WoodPanel")
	theme.set_type_variation("WoodPanel", "PanelContainer")
	var wood_frame := _box(WOOD_FRAME, FRAME_EDGE, FRAME_TEXT)
	wood_frame.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT  # 큰 창에서 판자 결이 뭉개지지 않고 되풀이되게
	wood_frame.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	theme.set_stylebox("panel", "WoodPanel", wood_frame)
	theme.add_type("Parchment")
	theme.set_type_variation("Parchment", "PanelContainer")
	theme.set_stylebox("panel", "Parchment", _box(PARCHMENT, FRAME_EDGE, FRAME_TEXT))
	theme.add_type("DarkBoard")
	theme.set_type_variation("DarkBoard", "PanelContainer")
	var board := _box(DARK_BOARD, BOARD_EDGE, Vector2(BOARD_EDGE - 6, BOARD_EDGE - 6))
	board.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	board.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	theme.set_stylebox("panel", "DarkBoard", board)


## 9칸 늘림 상자: edge는 그림의 가장자리 폭, text는 글 여백, shadow는 아래 그늘만큼 글을 위로, sink는 눌렸을 때 글을 아래로
func _box(path: String, edge: int, text: Vector2, shadow: int = 0, sink: int = 0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	_art_count += 1
	box.resource_scene_unique_id = "art_%d" % _art_count
	box.texture = load(path)
	box.texture_margin_left = edge
	box.texture_margin_right = edge
	box.texture_margin_top = edge
	box.texture_margin_bottom = edge
	box.content_margin_left = text.x
	box.content_margin_right = text.x
	box.content_margin_top = text.y + sink
	box.content_margin_bottom = text.y + shadow
	return box


func _tinted(source: StyleBoxTexture, tint: Color) -> StyleBoxTexture:
	var box := source.duplicate() as StyleBoxTexture
	_art_count += 1
	box.resource_scene_unique_id = "art_%d" % _art_count
	box.modulate_color = tint
	return box

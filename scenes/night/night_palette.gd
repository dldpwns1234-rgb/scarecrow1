extends RefCounted
## 밤 겉모습 팔레트 (방장 #587, 장르 조사 제안 2: "레벨마다 겉모습이 같다"는 장르 공통 불만을 피해, 밭이 깊어질수록 더 깊은 밤으로 간다).
## 그 밤의 밭 단계가 from 이상인 마지막 줄을 쓴다. 배경(night_backdrop.gd: 하늘·달·별·언덕·들판)과 땅(field_ground.gd: 풀)이 읽고,
## 새 밤 이름은 처음 들어설 때 밤 연출 층(fx/night_fx.gd)이 띄운다. 색만 바꾸므로 그리는 비용은 같다. 상수는 연출용이다
## moon_cut: 달을 가리는 하늘색 원의 (x, y 비켜 섬, 반지름 배율). 반지름 배율 0이면 보름달. eclipse면 달은 어둡고 달무리만 밝다(검은 달)

const THEMES: Array[Dictionary] = [
	{"from": 1, "name": "초승달 밤", "sky_top": Color("0b1222"), "sky_horizon": Color("2a3c5c"), "far_hills": Color("1c2b40"), "near_hills": Color("16232f"),
		"field_top": Color("172a2c"), "field_bottom": Color("0c1517"), "moon": Color("f3ecd2"), "halo": Color(0.95, 0.92, 0.75, 0.34),
		"moon_cut": Vector3(12, -8, 0.85), "stars": 90, "grass": [Color("3f6b3a"), Color("44733e")]},
	{"from": 10, "name": "반달 밤", "sky_top": Color("101530"), "sky_horizon": Color("3a3c66"), "far_hills": Color("26304a"), "near_hills": Color("1b2433"),
		"field_top": Color("1a2b2a"), "field_bottom": Color("0d1616"), "moon": Color("f6eed6"), "halo": Color(0.92, 0.9, 0.85, 0.34),
		"moon_cut": Vector3(30, 0, 1.0), "stars": 110, "grass": [Color("3d6a3e"), Color("437242")]},
	{"from": 20, "name": "안개 낀 밤", "sky_top": Color("0d1a1f"), "sky_horizon": Color("3b5a5c"), "far_hills": Color("2b4446"), "near_hills": Color("1d3032"),
		"field_top": Color("1b2e2a"), "field_bottom": Color("0e1815"), "moon": Color("e8f0ea"), "halo": Color(0.85, 0.95, 0.92, 0.42),
		"moon_cut": Vector3(44, -6, 0.9), "stars": 60, "grass": [Color("3a6646"), Color("3f6d4b")]},
	{"from": 30, "name": "수확 달", "sky_top": Color("1a1020"), "sky_horizon": Color("5a3a3a"), "far_hills": Color("3a2630"), "near_hills": Color("2a1c24"),
		"field_top": Color("2a2a1e"), "field_bottom": Color("141410"), "moon": Color("f2c27a"), "halo": Color(1.0, 0.75, 0.4, 0.4),
		"moon_cut": Vector3.ZERO, "stars": 90, "grass": [Color("5e6a35"), Color("66703a")]},
	{"from": 45, "name": "보랏빛 어둠", "sky_top": Color("140b24"), "sky_horizon": Color("46306a"), "far_hills": Color("2e2148"), "near_hills": Color("211836"),
		"field_top": Color("211a2c"), "field_bottom": Color("100c18"), "moon": Color("e2d4f7"), "halo": Color(0.8, 0.65, 1.0, 0.4),
		"moon_cut": Vector3(10, -6, 0.82), "stars": 120, "grass": [Color("44594f"), Color("4a6155")]},
	{"from": 70, "name": "별비 내리는 밤", "sky_top": Color("060a1a"), "sky_horizon": Color("1f2d55"), "far_hills": Color("151f3a"), "near_hills": Color("0f172b"),
		"field_top": Color("101c24"), "field_bottom": Color("080e12"), "moon": Color("fbfbf0"), "halo": Color(0.9, 0.92, 1.0, 0.3),
		"moon_cut": Vector3(18, -10, 0.9), "stars": 200, "grass": [Color("3b6248"), Color("40694d")]},
	{"from": 100, "name": "검은 달", "sky_top": Color("050308"), "sky_horizon": Color("2b1426"), "far_hills": Color("1e0f1c"), "near_hills": Color("160b15"),
		"field_top": Color("1a1218"), "field_bottom": Color("0a070a"), "moon": Color("1a0f1a"), "halo": Color(1.0, 0.55, 0.4, 0.5),
		"moon_cut": Vector3.ZERO, "eclipse": true, "stars": 140, "grass": [Color("3f5340"), Color("445a44")]},
	{"from": 150, "name": "새벽 전 빛", "sky_top": Color("0a1420"), "sky_horizon": Color("3d6b5a"), "far_hills": Color("22403a"), "near_hills": Color("172e2a"),
		"field_top": Color("16281f"), "field_bottom": Color("0b140f"), "moon": Color("f0f6e0"), "halo": Color(0.85, 1.0, 0.85, 0.36),
		"moon_cut": Vector3(16, -10, 0.88), "stars": 70, "grass": [Color("457345"), Color("4b7a4a")]},
]
const MAX_STARS: int = 200


## 그 밭 단계의 밤 (THEMES 번호)
static func index_for(level: int) -> int:
	var found := 0
	for i in THEMES.size():
		if level >= int(THEMES[i]["from"]):
			found = i
	return found


static func theme_for(level: int) -> Dictionary:
	return THEMES[index_for(level)]

extends "res://autoload/balance/feats.gd"
## Balance 2.68부: 철마다 날씨 (방장 2026-10-15 #587, 장르 조사 제안 7: Max Manos는 회차마다 공격 방식이, To The Core는 행성마다 규칙이 바뀐다).
## 겨울잠을 잘 때마다 다음 철에 밤 규칙 하나가 붙는다: 둘째 철 서리, 셋째 철 장마, 넷째 철 보름달, 그 뒤로는 차례로 돈다.
## 엔딩(약속된 휴식 백 년) 뒤의 철은 '도전 겨울': 그 철의 날씨에 다음 날씨가 겹친다 (장르 조사 제안 10, 엔딩 뒤 할 것).
## 날씨는 묶음(비트)으로 넘긴다: 1 << Weather
## 손해만 주는 규칙은 두지 않는다. 노는 방식이 바뀌게 한다: 서리는 얼어붙은 작물을 골라 치게, 장마는 번짐을 노리게, 보름달은 달빛을 따라가게

enum Weather { FROST, MONSOON, MOON }
const WEATHERS: Array[Dictionary] = [
	{"name": "서리", "note": "얼어붙은 작물은 단단하지만 생기 ×4. 시들면 깨지며 옆 작물을 친다"},
	{"name": "장마", "note": "비가 오락가락한다. 오는 동안 구름이 커지고 시든 작물이 옆으로 잘 번진다"},
	{"name": "보름달", "note": "달빛이 밭 위를 떠돈다. 달빛 안에서 시든 작물의 생기 ×3"},
]
const FROST_SHARE: float = 0.12            # 서리: 심긴 작물 가운데 얼어붙는 몫
const FROST_HP: float = 2.5
const FROST_VITALITY: float = 4.0
const FROST_SHATTER_SECONDS: float = 1.0   # 깨지면 옆 칸(상하좌우) 작물에 구름 피해 1초 몫 (최대 체력의 %로 치면 벽이 사라진다)
const RAIN_EVERY: float = 12.0             # 장마: 이 초마다 한 번
const RAIN_SECONDS: float = 5.0            # 이만큼 비가 온다
const RAIN_RADIUS: float = 1.3             # 비 오는 동안 구름 반경 배율
const RAIN_SPREAD: float = 0.25            # 비 오는 동안 시든 작물이 옆 칸마다 더 번질 확률 (번지는 곰팡이와 따로)
const MOON_RADIUS_SHARE: float = 0.14      # 보름달: 달빛 원 반지름 = 밭 한 변 × 이 값 (적어도 1.5칸)
const MOON_MIN_RADIUS: float = 1.5
const MOON_SPEED: float = 0.4              # 칸/초
const MOON_TURN: float = 1.2               # 라디안/초
const MOON_VITALITY: float = 3.0


## 겨울잠을 sleeps번 잔 뒤 철의 날씨 묶음 (1 << Weather). 첫 철은 0. beyond(엔딩 뒤)면 다음 날씨가 겹친다
func season_weathers(sleeps: int, beyond: bool = false) -> int:
	if sleeps <= 0:
		return 0
	var main := (sleeps - 1) % WEATHERS.size()
	var mask := 1 << main
	if beyond:
		mask |= 1 << ((main + 1) % WEATHERS.size())
	return mask


## 묶음 안의 날씨 이름 ("서리·장마"). 없으면 빈 글
func weathers_name(mask: int) -> String:
	var names: Array[String] = []
	for weather in WEATHERS.size():
		if mask & (1 << weather):
			names.append(weather_name(weather))
	return "·".join(names)


## 밤이 시작할 때 보이는 한 줄: 날씨 하나면 설명, 둘 넘으면 '도전 겨울'
func weathers_banner(mask: int) -> String:
	var name := weathers_name(mask)
	if name.is_empty():
		return ""
	for weather in WEATHERS.size():
		if mask == 1 << weather:
			return "%s: %s" % [name, weather_note(weather)]
	return "도전 겨울: %s가 한꺼번에 온다" % name


func weather_name(weather: int) -> String:
	return WEATHERS[weather]["name"] if weather >= 0 else ""


func weather_note(weather: int) -> String:
	return WEATHERS[weather]["note"] if weather >= 0 else ""


## 달빛 원 반지름 (칸): 밭이 넓어지면 함께 넓어진다
func moon_radius(field_cells: int) -> float:
	return maxf(field_cells * MOON_RADIUS_SHARE, MOON_MIN_RADIUS)

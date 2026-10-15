extends "res://autoload/balance/wisp.gd"
## Balance 2.65부: 작물 숙련과 업적 (방장 2026-10-15 #587, 장르 조사 제안 8·9: To The Core의 숙련, 쿠키 클리커의 우유). 둘 다 겨울잠을 넘어 남는다.
## 숙련: 작물 종류마다 시든 수가 50 × 4^(n − 1)에 닿을 때마다 숙련 n. 그 작물의 생기 +5%씩 (더하기).
## 업적: 기록(밤 수·연 밭·바친 생기·시든 수·도깨비불·약속된 휴식 등)이 목표에 닿으면 열린다. 하나 열 때마다 모든 생기 +2% (더하기, 다 열면 ×1.86).
## 천 년·만 년의 잠과 300단계 밭은 엔딩(백 년) 뒤의 목표다 (장르 조사 제안 10: 엔딩 뒤 할 것)
## 업적은 id로 저장한다 (표 순서를 바꾸거나 사이에 넣어도 옛 저장이 맞는다). 화면(도감·업적 탭)은 윤슬

const MASTERY_FIRST: float = 50.0
const MASTERY_GROWTH: float = 4.0     # 밀은 3시간에 숙련 7~8, 황금 이삭은 4쯤 (어림)
const MASTERY_PER_LEVEL: float = 0.05
const MASTERY_MAX: int = 12
const FEAT_PER_ACHIEVEMENT: float = 0.02

enum Stat { NIGHTS, BEST_LEVEL, OFFERED, WITHERED, BEST_HAUL, WAVES, SLEEPS, WISPS, SKILLS, MASTERY, REST }
const YEAR_SECONDS: float = 365.25 * 86400.0
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "night_1", "name": "첫 흉년", "note": "밤을 한 번 보낸다", "stat": Stat.NIGHTS, "goal": 1.0},
	{"id": "night_10", "name": "밤일에 익숙해짐", "note": "밤 10번", "stat": Stat.NIGHTS, "goal": 10.0},
	{"id": "night_50", "name": "잠 못 드는 허수아비", "note": "밤 50번", "stat": Stat.NIGHTS, "goal": 50.0},
	{"id": "night_150", "name": "밤의 일꾼", "note": "밤 150번", "stat": Stat.NIGHTS, "goal": 150.0},
	{"id": "night_400", "name": "밤의 주인", "note": "밤 400번", "stat": Stat.NIGHTS, "goal": 400.0},
	{"id": "level_5", "name": "다섯째 밭", "note": "밭 5단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 5.0},
	{"id": "level_12", "name": "겨울이 부른다", "note": "밭 12단계를 연다 (겨울잠에 들 수 있다)", "stat": Stat.BEST_LEVEL, "goal": 12.0},
	{"id": "level_25", "name": "지키는 이와 마주침", "note": "밭 25단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 25.0},
	{"id": "level_50", "name": "반백의 밭", "note": "밭 50단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 50.0},
	{"id": "level_100", "name": "백 번째 밭", "note": "밭 100단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 100.0},
	{"id": "level_150", "name": "끝없는 들판", "note": "밭 150단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 150.0},
	{"id": "level_200", "name": "지평선 너머", "note": "밭 200단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 200.0},
	{"id": "level_300", "name": "끝 모를 밭", "note": "밭 300단계를 연다", "stat": Stat.BEST_LEVEL, "goal": 300.0},
	{"id": "offered_4", "name": "생기 한 줌", "note": "바친 생기 1만", "stat": Stat.OFFERED, "goal": 1e4},
	{"id": "offered_8", "name": "억 소리 나는 흉년", "note": "바친 생기 1억", "stat": Stat.OFFERED, "goal": 1e8},
	{"id": "offered_12", "name": "조 단위 흉년", "note": "바친 생기 1조", "stat": Stat.OFFERED, "goal": 1e12},
	{"id": "offered_16", "name": "경을 칠 흉년", "note": "바친 생기 1경", "stat": Stat.OFFERED, "goal": 1e16},
	{"id": "withered_3", "name": "천 포기", "note": "작물 1천 포기를 시들게 한다", "stat": Stat.WITHERED, "goal": 1e3},
	{"id": "withered_4", "name": "만 포기", "note": "작물 1만 포기", "stat": Stat.WITHERED, "goal": 1e4},
	{"id": "withered_5", "name": "십만 포기", "note": "작물 10만 포기", "stat": Stat.WITHERED, "goal": 1e5},
	{"id": "withered_6", "name": "백만 포기", "note": "작물 100만 포기", "stat": Stat.WITHERED, "goal": 1e6},
	{"id": "haul_3", "name": "한 밤에 천", "note": "한 밤에 생기 1천", "stat": Stat.BEST_HAUL, "goal": 1e3},
	{"id": "haul_6", "name": "한 밤에 백만", "note": "한 밤에 생기 100만", "stat": Stat.BEST_HAUL, "goal": 1e6},
	{"id": "haul_9", "name": "한 밤에 십억", "note": "한 밤에 생기 10억", "stat": Stat.BEST_HAUL, "goal": 1e9},
	{"id": "haul_12", "name": "한 밤에 조", "note": "한 밤에 생기 1조", "stat": Stat.BEST_HAUL, "goal": 1e12},
	{"id": "waves_3", "name": "물결 셋", "note": "한 밤에 밭을 세 번 정복한다", "stat": Stat.WAVES, "goal": 3.0},
	{"id": "waves_10", "name": "물결 열", "note": "한 밤에 밭을 열 번 정복한다", "stat": Stat.WAVES, "goal": 10.0},
	{"id": "waves_30", "name": "밀려오는 물결", "note": "한 밤에 밭을 서른 번 정복한다", "stat": Stat.WAVES, "goal": 30.0},
	{"id": "sleep_1", "name": "첫 겨울잠", "note": "겨울잠에 한 번 든다", "stat": Stat.SLEEPS, "goal": 1.0},
	{"id": "sleep_2", "name": "두 번째 겨울", "note": "겨울잠 두 번", "stat": Stat.SLEEPS, "goal": 2.0},
	{"id": "sleep_4", "name": "네 번의 겨울", "note": "겨울잠 네 번", "stat": Stat.SLEEPS, "goal": 4.0},
	{"id": "wisp_1", "name": "도깨비와 눈 맞춤", "note": "도깨비불을 잡는다", "stat": Stat.WISPS, "goal": 1.0},
	{"id": "wisp_10", "name": "도깨비 단골", "note": "도깨비불 10번", "stat": Stat.WISPS, "goal": 10.0},
	{"id": "wisp_40", "name": "도깨비 친구", "note": "도깨비불 40번", "stat": Stat.WISPS, "goal": 40.0},
	{"id": "skill_10", "name": "저절로 터진다", "note": "스킬이 10번 터진다", "stat": Stat.SKILLS, "goal": 10.0},
	{"id": "skill_300", "name": "어둠의 손길", "note": "스킬 300번", "stat": Stat.SKILLS, "goal": 300.0},
	{"id": "skill_5000", "name": "그칠 줄 모르는 재앙", "note": "스킬 5천 번", "stat": Stat.SKILLS, "goal": 5000.0},
	{"id": "mastery_5", "name": "손에 익다", "note": "작물 숙련 합 5", "stat": Stat.MASTERY, "goal": 5.0},
	{"id": "mastery_15", "name": "밭의 장인", "note": "작물 숙련 합 15", "stat": Stat.MASTERY, "goal": 15.0},
	{"id": "mastery_30", "name": "모든 작물의 천적", "note": "작물 숙련 합 30", "stat": Stat.MASTERY, "goal": 30.0},
	{"id": "rest_100", "name": "백 년의 약속", "note": "약속된 휴식 백 년", "stat": Stat.REST, "goal": 100.0 * YEAR_SECONDS},
	{"id": "rest_1000", "name": "천 년의 잠", "note": "약속된 휴식 천 년", "stat": Stat.REST, "goal": 1000.0 * YEAR_SECONDS},
	{"id": "rest_10000", "name": "만 년의 꿈", "note": "약속된 휴식 만 년", "stat": Stat.REST, "goal": 10000.0 * YEAR_SECONDS},
]


## 시든 수로 숙련 레벨: 50이면 1, 200이면 2, 800이면 3 … (상한 12)
func mastery_level(count: float) -> int:
	if count < MASTERY_FIRST:
		return 0
	return mini(floori(log(count / MASTERY_FIRST) / log(MASTERY_GROWTH) + 1e-9) + 1, MASTERY_MAX)


## 숙련 level에 닿는 시든 수 (level ≥ 1)
func mastery_goal(level: int) -> float:
	return MASTERY_FIRST * pow(MASTERY_GROWTH, level - 1)


## 숙련이 그 작물의 생기에 곱하는 값
func mastery_multiplier(level: int) -> float:
	return 1.0 + MASTERY_PER_LEVEL * level


## 연 업적 수가 모든 생기에 곱하는 값
func feats_multiplier(count: int) -> float:
	return 1.0 + FEAT_PER_ACHIEVEMENT * count


func achievement_name(index: int) -> String:
	return ACHIEVEMENTS[index]["name"]


func achievement_note(index: int) -> String:
	return ACHIEVEMENTS[index]["note"]

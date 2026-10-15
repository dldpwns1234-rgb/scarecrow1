extends "res://autoload/balance/branches.gd"
## Balance 2.7부: 아지트 일꾼 (GDD 8절 M2, 대화방 #419). 까마귀와 지친 허수아비를 일자리 칸에 놓는다.
## 일꾼은 밭 기록(겨울잠을 넘어 가장 높이 연 단계)과 겨울잠 횟수로 늘고, 일자리 칸은 헛간 확장(생기, 영구)으로 는다. 수치는 시뮬레이션으로 맞춘다

enum Worker { CROW, SCARECROW }
enum Job { WATCH, DRY, CARRY }
const JOBS: Array[Dictionary] = [
	{"name": "밭 망보기", "note": "밤마다 황금 이삭이 하나씩 더 심긴다", "favored": Worker.CROW},
	{"name": "포자 말리기", "note": "구름 피해 +15%씩", "favored": Worker.SCARECROW},
	{"name": "생기 나르기", "note": "낮에 있는 동안 초당 지난 밤 생기의 1%씩", "favored": -1},
]
const CROW_NAMES: PackedStringArray = ["까악이", "검둥이", "부리", "깃털", "그믐", "밤톨"]
const SCARECROW_NAMES: PackedStringArray = ["볏짚이", "누더기", "외팔이", "밀짚모"]
const HIDEOUT_LEVEL: int = 10              # 아지트가 열리는 밭 기록 (첫 허수아비가 합류한다)
const SCARECROW_LEVELS: Array[int] = [10, 20, 40, 80]  # 이 밭 기록에서 지친 허수아비가 하나씩 합류
const CROW_WORKERS_BASE: int = 1           # 아지트가 열리면 까마귀 일꾼 하나, 겨울잠마다 하나씩 더 (상한 CROW_NAMES 수)
const FAVORED_SHARE: float = 2.0           # 일자리에 맞는 일꾼은 두 몫 (까마귀 → 망보기, 허수아비 → 포자 말리기)
const DRY_PER_SHARE: float = 0.15          # 포자 말리기: 한 몫당 구름 피해 +15% (더하기)
const CARRY_PER_SHARE: float = 0.01        # 생기 나르기: 한 몫당 초당 지난 밤 생기의 1%
const BASE_SLOTS: int = 1                  # 일자리마다 처음 칸 수
const MAX_EXTRA_SLOTS: int = 3             # 헛간 확장으로 늘릴 수 있는 칸
const EXPAND_BASE_COST: float = 954.0  # 확장 비용 = 기본 × 성장^(그 일자리의 확장 횟수) 생기 (옛 5천 × 40^n을 상한 칸처럼 눌렀다)
const EXPAND_GROWTH: float = 13.226


func job_name(job: int) -> String:
	return JOBS[job]["name"]


func job_note(job: int) -> String:
	return JOBS[job]["note"]


## 이 일꾼이 이 일자리에서 내는 몫 (맞는 일자리면 두 몫)
func worker_share(kind: int, job: int) -> float:
	return FAVORED_SHARE if int(JOBS[job]["favored"]) == kind else 1.0


## 밭 기록으로 합류한 허수아비 수
func scarecrow_count(best_ever: int) -> int:
	var count := 0
	for level in SCARECROW_LEVELS:
		if best_ever >= level:
			count += 1
	return mini(count, SCARECROW_NAMES.size())


## 까마귀 일꾼 수: 아지트가 열리면 하나, 겨울잠마다 하나씩
func crow_worker_count(best_ever: int, sleeps: int) -> int:
	if best_ever < HIDEOUT_LEVEL:
		return 0
	return mini(CROW_WORKERS_BASE + sleeps, CROW_NAMES.size())


func expand_cost(extra: int) -> float:
	return cap(EXPAND_BASE_COST * pow(EXPAND_GROWTH, extra))


## 포자 말리기 배율: 1 + 0.15 × 몫
func dry_multiplier(shares: float) -> float:
	return 1.0 + DRY_PER_SHARE * shares


## 생기 나르기: 초당 생기 = 지난 밤 생기 × 1% × 몫
func carry_per_second(last_haul: float, shares: float) -> float:
	return cap(last_haul * CARRY_PER_SHARE * shares)

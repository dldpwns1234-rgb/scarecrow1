extends Node
## 게임 흐름 (GDD 3절): 낮과 밤의 전환, 휴식(재화), 밤 기록. 상태 변경은 오토로드의 함수로만 하고 UI는 시그널을 받아 표시만 한다.
## 밤 한 판 안의 일(밭·구름·작물·번짐·남은 시간)은 밤 쪽이 맡고, 작물이 시들면 add_rest()를, 시간이 끝나면 finish_night()를 부른다

signal phase_changed(phase: int)
signal rest_changed(rest: float)
signal night_finished(haul: float)  # 이번 밤에 모은 휴식. 결과 창용

enum Phase { DAY, NIGHT }

var phase: int = Phase.DAY
var rest: float = 0.0        # 휴식: 시든 작물에서 나오는 재화. 업그레이드에 쓴다
var nights: int = 0          # 지난 밤 수
var night_haul: float = 0.0  # 지금 밤에 모은 휴식
var last_haul: float = 0.0   # 지난 밤에 모은 휴식
var best_haul: float = 0.0   # 가장 많이 모은 밤


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다
func reset() -> void:
	phase = Phase.DAY
	rest = 0.0
	nights = 0
	night_haul = 0.0
	last_haul = 0.0
	best_haul = 0.0
	phase_changed.emit(phase)
	rest_changed.emit(rest)


func to_dict() -> Dictionary:
	return {"rest": rest, "nights": nights, "last_haul": last_haul, "best_haul": best_haul}


## 없는 필드는 기본값으로. 불러오면 늘 낮이다 (밤 한 판은 저장하지 않는다)
func from_dict(data: Dictionary) -> void:
	reset()
	rest = Balance.cap(maxf(float(data.get("rest", 0.0)), 0.0))
	nights = maxi(int(data.get("nights", 0)), 0)
	last_haul = Balance.cap(maxf(float(data.get("last_haul", 0.0)), 0.0))
	best_haul = Balance.cap(maxf(float(data.get("best_haul", 0.0)), 0.0))
	rest_changed.emit(rest)


func is_night() -> bool:
	return phase == Phase.NIGHT


## 이번 밤의 길이 (초)
func night_seconds() -> float:
	return Balance.night_seconds(Upgrades.level(Balance.Upgrade.LONG_NIGHT))


## 낮 → 밤. 이미 밤이면 false
func start_night() -> bool:
	if is_night():
		return false
	phase = Phase.NIGHT
	night_haul = 0.0
	phase_changed.emit(phase)
	return true


## 밤 → 낮. 이번 밤 기록을 남기고 저장한다. 밤이 아니면 false
func finish_night() -> bool:
	if not is_night():
		return false
	phase = Phase.DAY
	nights += 1
	last_haul = night_haul
	best_haul = maxf(best_haul, night_haul)
	night_finished.emit(night_haul)
	phase_changed.emit(phase)
	Save.save_game()
	return true


## 시든 작물의 휴식. 밤에만 받는다
func add_rest(amount: float) -> void:
	if amount <= 0.0 or not is_night():
		return
	night_haul = Balance.cap(night_haul + amount)
	rest = Balance.cap(rest + amount)
	rest_changed.emit(rest)


## 휴식을 치른다. 모자라면 false
func spend(cost: float) -> bool:
	if cost < 0.0 or rest < cost:
		return false
	rest -= cost
	rest_changed.emit(rest)
	return true

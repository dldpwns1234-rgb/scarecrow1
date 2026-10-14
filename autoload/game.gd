extends Node
## 게임 흐름 (GDD 3절): 낮과 밤의 전환, 생기(재화), 어둠에게 바친 생기의 합과 약속된 휴식(이야기), 밤 기록. 상태 변경은 오토로드의 함수로만 하고 UI는 시그널을 받아 표시만 한다.
## 밤 한 판 안의 일(밭·구름·작물·번짐·남은 시간)은 Night가 맡고, 작물이 시들면 add_vitality()를, 시간이 끝나면 finish_night()를 부른다

signal phase_changed(phase: int)
signal vitality_changed(vitality: float)
signal night_finished(haul: float)    # 이번 밤에 거둔 생기. 결과 창용

enum Phase { DAY, NIGHT }

var phase: int = Phase.DAY
var vitality: float = 0.0    # 생기: 시든 작물에서 거둔다. 어둠의 나무에 쓴다
var offered: float = 0.0     # 지금까지 거둔 생기의 합 (쓴 것도 친다). 약속된 휴식을 정한다
var nights: int = 0          # 지난 밤 수
var night_haul: float = 0.0  # 지금 밤에 거둔 생기
var last_haul: float = 0.0   # 지난 밤에 거둔 생기
var best_haul: float = 0.0   # 가장 많이 거둔 밤
## 옛 이름 (tests/test_save.gd가 vitality로 옮기면 지운다)
var rest: float:
	get:
		return vitality
	set(value):
		vitality = value


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다
func reset() -> void:
	phase = Phase.DAY
	vitality = 0.0
	offered = 0.0
	nights = 0
	night_haul = 0.0
	last_haul = 0.0
	best_haul = 0.0
	phase_changed.emit(phase)
	_emit_vitality()


func to_dict() -> Dictionary:
	return {"vitality": vitality, "offered": offered, "nights": nights, "last_haul": last_haul, "best_haul": best_haul}


## 없는 필드는 기본값으로 (옛 저장의 "rest"는 생기로 읽는다). 불러오면 늘 낮이다 (밤 한 판은 저장하지 않는다)
func from_dict(data: Dictionary) -> void:
	reset()
	vitality = _read(data, "vitality", float(data.get("rest", 0.0)))
	offered = maxf(_read(data, "offered", vitality), vitality)
	nights = maxi(int(data.get("nights", 0)), 0)
	last_haul = _read(data, "last_haul", 0.0)
	best_haul = _read(data, "best_haul", 0.0)
	_emit_vitality()


func is_night() -> bool:
	return phase == Phase.NIGHT


## 이번 밤의 길이 (초)
func night_seconds() -> float:
	return Balance.night_seconds(Upgrades.level(Balance.Upgrade.LONG_NIGHT))


## 지금까지 바친 생기로 어둠이 약속한 휴식 (초)
func promised_rest_seconds() -> float:
	return Balance.promised_rest_seconds(offered)


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


## 시든 작물의 생기. 밤에만 받는다
func add_vitality(amount: float) -> void:
	if amount <= 0.0 or not is_night():
		return
	night_haul = Balance.cap(night_haul + amount)
	vitality = Balance.cap(vitality + amount)
	offered = Balance.cap(offered + amount)
	_emit_vitality()


## 생기를 치른다. 모자라면 false
func spend(cost: float) -> bool:
	if cost < 0.0 or vitality < cost:
		return false
	vitality -= cost
	_emit_vitality()
	return true


func _emit_vitality() -> void:
	vitality_changed.emit(vitality)


func _read(data: Dictionary, key: String, fallback: float) -> float:
	return Balance.cap(maxf(float(data.get(key, fallback)), 0.0))

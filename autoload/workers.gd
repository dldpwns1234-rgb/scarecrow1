extends Node
## 아지트 일꾼 (GDD 8절 M2, 대화방 #419): 까마귀와 지친 허수아비를 일자리(밭 망보기·포자 말리기·생기 나르기) 칸에 놓는다.
## 일꾼은 밭 기록(겨울잠을 넘어 가장 높이 연 단계)과 겨울잠 횟수로 합류하고, 배치·칸·밭 기록은 겨울잠을 넘어 남는다. 데이터 초기화에서만 지운다.
## 효과는 Night(황금 이삭·구름 피해)가 묻고, 생기 나르기는 낮 동안 여기서 Game에 더한다. 상태 변경은 이 오토로드의 함수로만 한다

signal workers_changed()

var best_ever: int = 1                 # 겨울잠을 넘어 가장 높이 연 밭 단계
var jobs: Array[int] = []              # 일꾼마다 일자리 (Balance.Job, 쉬면 -1). 일꾼 목록 순서는 늘 까마귀들 → 허수아비들
var extra_slots: Array[int] = []       # 일자리마다 헛간 확장 횟수
var _kinds: Array[int] = []            # 일꾼마다 종류 (Balance.Worker)
var _names: Array[String] = []


func _ready() -> void:
	reset()
	Night.field_level_changed.connect(_on_field_level.unbind(2))
	Winter.slept.connect(_sync.unbind(1))


func _process(delta: float) -> void:
	if Game.is_night() or not is_open():
		return
	var gain := Balance.carry_per_second(Game.last_haul, shares(Balance.Job.CARRY)) * minf(delta, Balance.MAX_DELTA)
	if gain > 0.0:
		Game.add_day_vitality(gain)


## 데이터 초기화에서만 부른다
func reset() -> void:
	best_ever = 1
	jobs.clear()
	_kinds.clear()
	_names.clear()
	extra_slots.clear()
	extra_slots.resize(Balance.JOBS.size())
	extra_slots.fill(0)
	_sync()


func to_dict() -> Dictionary:
	return {"best_ever": best_ever, "jobs": jobs.duplicate(), "extra_slots": extra_slots.duplicate()}


## 없거나 망가진 값은 기본값으로. 일자리 칸을 넘는 배치는 쉬게 한다
func from_dict(data: Dictionary) -> void:
	reset()
	best_ever = clampi(int(data.get("best_ever", 1)), 1, Balance.MAX_FIELD_LEVEL)
	var slots: Variant = data.get("extra_slots", [])
	if slots is Array:
		for j in mini((slots as Array).size(), extra_slots.size()):
			extra_slots[j] = clampi(int(slots[j]), 0, Balance.MAX_EXTRA_SLOTS)
	_sync()
	var saved: Variant = data.get("jobs", [])
	if saved is Array:
		for w in mini((saved as Array).size(), jobs.size()):
			var job := int(saved[w])
			if job >= 0 and job < Balance.JOBS.size() and used(job) < slots_of(job):
				jobs[w] = job
	workers_changed.emit()


## 아지트가 열렸는지 (밭 기록 10단계)
func is_open() -> bool:
	return best_ever >= Balance.HIDEOUT_LEVEL


func worker_count() -> int:
	return jobs.size()


func worker_kind(worker: int) -> int:
	return _kinds[worker]


func worker_name(worker: int) -> String:
	return _names[worker]


func worker_job(worker: int) -> int:
	return jobs[worker]


func slots_of(job: int) -> int:
	return Balance.BASE_SLOTS + extra_slots[job]


func used(job: int) -> int:
	return jobs.count(job)


## 일꾼을 일자리에 놓는다 (다른 데서 일하고 있었으면 옮긴다). 칸이 다 찼으면 false
func assign(worker: int, job: int) -> bool:
	if worker < 0 or worker >= jobs.size() or job < 0 or job >= Balance.JOBS.size():
		return false
	if jobs[worker] == job:
		return true
	if used(job) >= slots_of(job):
		return false
	jobs[worker] = job
	workers_changed.emit()
	return true


func unassign(worker: int) -> void:
	if worker >= 0 and worker < jobs.size() and jobs[worker] >= 0:
		jobs[worker] = -1
		workers_changed.emit()


func expand_cost(job: int) -> float:
	return Balance.expand_cost(extra_slots[job])


func can_expand(job: int) -> bool:
	return is_open() and extra_slots[job] < Balance.MAX_EXTRA_SLOTS and Game.vitality >= expand_cost(job)


func expand(job: int) -> bool:
	if not can_expand(job) or not Game.spend(expand_cost(job)):
		return false
	extra_slots[job] += 1
	workers_changed.emit()
	return true


## 이 일자리에서 일하는 일꾼들의 몫 합 (맞는 일꾼은 두 몫)
func shares(job: int) -> float:
	var total := 0.0
	for w in jobs.size():
		if jobs[w] == job:
			total += Balance.worker_share(_kinds[w], job)
	return total


# 효과 (Night가 묻는다)

## 밭 망보기: 밤마다 더 심는 황금 이삭 수
func watch_goldens() -> int:
	return floori(shares(Balance.Job.WATCH))


## 포자 말리기: 구름 피해 배율
func dry_multiplier() -> float:
	return Balance.dry_multiplier(shares(Balance.Job.DRY))


func _on_field_level() -> void:
	if Night.best_level > best_ever:
		best_ever = Night.best_level
		_sync()


## 밭 기록·겨울잠 횟수에 맞춰 일꾼 목록을 맞춘다 (까마귀들 → 허수아비들). 일꾼은 줄지 않고, 있던 배치는 그대로
func _sync() -> void:
	var crows := Balance.crow_worker_count(best_ever, Winter.sleeps)
	var scarecrows := Balance.scarecrow_count(best_ever)
	var old_jobs := jobs.duplicate()
	var old_crows := _kinds.count(Balance.Worker.CROW)
	jobs.clear()
	_kinds.clear()
	_names.clear()
	for i in maxi(crows, old_crows):
		_add(Balance.Worker.CROW, Balance.CROW_NAMES[i], old_jobs[i] if i < old_crows else -1)
	var old_scarecrows := old_jobs.size() - old_crows
	for i in maxi(scarecrows, old_scarecrows):
		_add(Balance.Worker.SCARECROW, Balance.SCARECROW_NAMES[i], old_jobs[old_crows + i] if i < old_scarecrows else -1)
	workers_changed.emit()


func _add(kind: int, name: String, job: int) -> void:
	_kinds.append(kind)
	_names.append(name)
	jobs.append(job)

extends Node
## 낮의 업그레이드 나무 (GDD 6절): 레벨, 열림(앞 업그레이드), 구매. 휴식은 Game.spend()로 치른다. 수치는 Balance.UPGRADES.

signal upgrade_changed(index: int, level: int)

var levels: Array[int] = []  # Balance.Upgrade 순서


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다
func reset() -> void:
	levels.clear()
	levels.resize(Balance.UPGRADES.size())
	levels.fill(0)
	for i in levels.size():
		upgrade_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate()}


## 없거나 짧은 배열은 0으로, 상한을 넘는 레벨은 상한으로 (옛 저장·망가진 저장)
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("levels", [])
	if not saved is Array:
		return
	for i in mini((saved as Array).size(), levels.size()):
		var cap := Balance.upgrade_max_level(i)
		levels[i] = clampi(int(saved[i]), 0, cap if cap > 0 else 1000000)
		upgrade_changed.emit(i, levels[i])


func level(index: int) -> int:
	return levels[index]


## 앞 업그레이드(requires)를 1레벨 이상 가졌으면 열린다
func is_unlocked(index: int) -> bool:
	var need := Balance.upgrade_requires(index)
	return need < 0 or levels[need] > 0


func is_maxed(index: int) -> bool:
	var cap := Balance.upgrade_max_level(index)
	return cap > 0 and levels[index] >= cap


func cost(index: int) -> float:
	return Balance.upgrade_cost(index, levels[index])


func can_buy(index: int) -> bool:
	return is_unlocked(index) and not is_maxed(index) and Game.rest >= cost(index)


func buy(index: int) -> bool:
	if not is_unlocked(index) or is_maxed(index) or not Game.spend(cost(index)):
		return false
	levels[index] += 1
	upgrade_changed.emit(index, levels[index])
	return true


## 살 수 있는 업그레이드가 하나라도 있는지 (낮 화면 표시용)
func any_affordable() -> bool:
	for i in levels.size():
		if can_buy(i):
			return true
	return false

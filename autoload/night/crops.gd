extends "res://autoload/night/skills.gd"
## Night 2.7부: 시든 뒤 일 (방장 2026-10-14: 가득 차는 맛). 작물 버릇(해바라기 씨앗·수박 터짐·포도 덩굴)과 연쇄 시듦 스킬.
## night/waves.gd의 시듦이 줄을 세워 _after_wither()를 차례로 부른다. 그 안에서 친 작물이 시들면 줄 끝에 서서 이어 풀린다 (연쇄)

signal seeds_flung(index: int, targets: PackedInt32Array)  # 해바라기 씨앗이 튀어 번짐을 옮겼다 (연출용)
signal crop_burst(index: int, radius: float)              # 수박이 터졌다
signal chain_struck(from: int, to: int)                   # 포도 덩굴·연쇄 시듦이 옆 작물을 쳤다


## 시든 작물 하나의 뒤 일: 작물 버릇, 그다음 연쇄 시듦 (켜져 있으면)
func _after_wither(index: int) -> void:
	match kinds[index]:
		Balance.Crop.SUNFLOWER:
			_fling_seeds(index)
		Balance.Crop.WATERMELON:
			_burst(index)
		Balance.Crop.GRAPE:
			_snap_vine(index)
	if is_skill_active(Balance.Skill.CHAIN):
		_chain_from(index)


## 해바라기: 둘레의 번지지 않은 작물 몇에 씨앗이 튀어 번짐에 걸린다
func _fling_seeds(index: int) -> void:
	var at := cell_position(index)
	var picks: Array[int] = []
	for i in kinds.size():
		if is_alive(i) and infected[i] == 0 and cell_position(i).distance_to(at) <= Balance.SEED_RADIUS:
			picks.append(i)
	var targets := PackedInt32Array()
	for _i in mini(Balance.SEED_COUNT, picks.size()):
		var pick := rng.randi_range(0, picks.size() - 1)
		targets.append(picks[pick])
		picks.remove_at(pick)
	if targets.is_empty():
		return
	seeds_flung.emit(index, targets)
	for target in targets:
		_infect(target)


## 수박: 터져서 둘레의 작물마다 수박 최대 체력의 몫만큼 친다 (지키는 이의 약은 듣는다)
func _burst(index: int) -> void:
	var at := cell_position(index)
	var amount := max_hp[index] * Balance.BURST_SHARE
	crop_burst.emit(index, Balance.BURST_RADIUS)
	for i in kinds.size():
		if i != index and is_alive(i) and cell_position(i).distance_to(at) <= Balance.BURST_RADIUS:
			_damage(i, amount * guard(i))


## 포도: 덩굴로 이어진 옆 포도가 제 최대 체력의 몫을 잃는다
func _snap_vine(index: int) -> void:
	for n in neighbors(index):
		if is_alive(n) and kinds[n] == Balance.Crop.GRAPE:
			chain_struck.emit(index, n)
			_damage(n, max_hp[n] * Balance.VINE_SHARE * guard(n))


## 연쇄 시듦: 옆 작물마다 제 최대 체력의 몫을 잃는다
func _chain_from(index: int) -> void:
	var share := Balance.chain_share(skill_level(Balance.Skill.CHAIN))
	for n in neighbors(index):
		if is_alive(n):
			chain_struck.emit(index, n)
			_damage(n, max_hp[n] * share * guard(n))

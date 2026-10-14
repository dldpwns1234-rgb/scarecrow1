extends "res://autoload/night/skills.gd"
## Night 2.7부: 시든 뒤 일 (방장 2026-10-14: 가득 차는 맛). 작물 버릇(해바라기 씨앗·수박 터짐·포도 덩굴), 연쇄 시듦 스킬, 확률형 스킬 굴리기.
## night/waves.gd의 시듦이 줄을 세워 _after_wither()를 차례로 부른다. 그 안에서 친 작물이 시들면 줄 끝에 서서 이어 풀린다 (연쇄)

signal seeds_flung(index: int, targets: PackedInt32Array)  # 해바라기 씨앗이 튀어 번짐을 옮겼다 (연출용)
signal crop_burst(index: int, radius: float)              # 수박이 터졌다
signal chain_struck(from: int, to: int)                   # 포도 덩굴·연쇄 시듦이 옆 작물을 쳤다


## 시든 작물 하나의 뒤 일: 작물 버릇, 연쇄 시듦 (켜져 있으면), 확률형 스킬
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
	_roll_wither_skills()


## 해바라기: 둘레의 번지지 않은 작물 몇에 씨앗이 튀어 번짐에 걸린다
func _fling_seeds(index: int) -> void:
	var at := cell_position(index)
	var picks: Array[int] = []
	for i in kinds.size():
		if is_alive(i) and infected[i] == 0 and cell_position(i).distance_to(at) <= Balance.SEED_RADIUS:
			picks.append(i)
	var targets := PackedInt32Array()
	for _i in mini(Balance.seed_count(Upgrades.level(Balance.Upgrade.SUNFLOWER)), picks.size()):
		var pick := rng.randi_range(0, picks.size() - 1)
		targets.append(picks[pick])
		picks.remove_at(pick)
	if targets.is_empty():
		return
	seeds_flung.emit(index, targets)
	for target in targets:
		_infect(target)


## 수박: 터져서 둘레의 작물마다 구름 피해 몇 초 몫을 친다 (지키는 이의 약은 듣는다)
func _burst(index: int) -> void:
	var at := cell_position(index)
	var amount := Balance.burst_damage(cloud_dps(), Upgrades.level(Balance.Upgrade.MELON))
	crop_burst.emit(index, Balance.BURST_RADIUS)
	for i in kinds.size():
		if i != index and is_alive(i) and cell_position(i).distance_to(at) <= Balance.BURST_RADIUS:
			_damage(i, amount * guard(i))


## 포도: 덩굴로 이어진 옆 포도가 구름 피해 몇 초 몫을 받는다
func _snap_vine(index: int) -> void:
	var amount := Balance.vine_damage(cloud_dps(), Upgrades.level(Balance.Upgrade.GRAPE))
	for n in neighbors(index):
		if is_alive(n) and kinds[n] == Balance.Crop.GRAPE:
			chain_struck.emit(index, n)
			_damage(n, amount * guard(n))


## 연쇄 시듦: 옆 작물마다 구름 피해 몇 초 몫
func _chain_from(index: int) -> void:
	var amount := Balance.chain_damage(cloud_dps(), skill_level(Balance.Skill.CHAIN), skill_power(Balance.Skill.CHAIN))
	for n in neighbors(index):
		if is_alive(n):
			chain_struck.emit(index, n)
			_damage(n, amount * guard(n))

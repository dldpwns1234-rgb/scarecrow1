extends "res://autoload/night/field.gd"
## Night 2부: 밭 위를 오가는 것들 (GDD 4절·8절 M3). 까마귀(사역마)는 간격마다 작물을 쪼고, 지키는 이(5단계부터 농부, 깊어지면 감독관·관리·여신)는
## 밭을 걸어 다니며 둘레의 작물에 약을 쳐서(구름·번짐 피해 줄이기, 번짐 씻기) 지키고 시든 칸에 다시 심는다. 흐름(박자·시듦·정복)은 night.gd가 상속해서 맡는다

signal crow_pecked(index: int)
signal farmer_sprayed(index: int)  # 농부가 번짐을 씻어 냈다

var active: bool = false           # 밤이 도는 중
var farmers: Array[Vector2] = []   # 지키는 이 자리 (격자 단위). 화면이 매 프레임 읽는다
var farmer_kinds: Array[int] = []  # 지키는 이 종류 (Balance.Guardian)
var _farmer_targets: Array[Vector2] = []
var _replant_left: Array[float] = []
var _stun_left: Array[float] = []  # 까마귀 소란으로 멈춘 남은 초
var _crow_left: Array[float] = []


## 밤 시작: 까마귀 시계를 고르게 흩고, 농부를 밭 가장자리에 세운다
func _setup_critters() -> void:
	_crow_left.clear()
	var crows := Balance.crow_count(Upgrades.level(Balance.Upgrade.CROW)) + Winter.extra_crows()
	for i in crows:
		_crow_left.append(Balance.CROW_INTERVAL * float(i + 1) / float(crows))  # 한꺼번에 쪼지 않게
	farmers.clear()
	_farmer_targets.clear()
	_replant_left.clear()
	_stun_left.clear()
	farmer_kinds = Balance.guardians(field_level)
	var size := float(Balance.FIELD_SIZE)
	for i in farmer_kinds.size():
		var edge := rng.randf() * size
		farmers.append(Vector2(edge, 0.0) if i % 2 == 0 else Vector2(size, edge))
		_farmer_targets.append(_next_target())
		_replant_left.append(Balance.guardian_replant(farmer_kinds[i]))
		_stun_left.append(0.0)


## 까마귀와 농부의 시간을 흘린다 (night.gd의 tick이 부른다)
func _tick_critters(dt: float) -> void:
	for i in _crow_left.size():
		_crow_left[i] -= dt * _crow_speed()
		if active and _crow_left[i] <= 0.0:
			_crow_left[i] += Balance.CROW_INTERVAL
			_peck()
	for f in farmers.size():
		if not active:
			return
		if _stun_left[f] > 0.0:
			_stun_left[f] -= dt
			continue
		_walk(f, dt)
		_spray(f)
		_replant_left[f] -= dt
		if _replant_left[f] <= 0.0:
			_replant_left[f] += Balance.guardian_replant(farmer_kinds[f])
			_replant(f)


## 지키는 이 둘레 안의 작물이 받는 피해 배율 (약을 쳤다, 스며드는 독). 여럿이면 가장 센 약. 멈춘 이는 약을 못 친다
func guard(index: int) -> float:
	var at := cell_position(index)
	var result := 1.0
	for f in farmers.size():
		if _stun_left[f] <= 0.0 and farmers[f].distance_to(at) <= Balance.guardian_radius(farmer_kinds[f]):
			result = minf(result, Balance.guardian_guard(farmer_kinds[f], Upgrades.level(Balance.Upgrade.SEEP)))
	return result


## 이 농부가 까마귀 소란으로 멈춰 있는지 (화면용)
func is_stunned(f: int) -> bool:
	return f < _stun_left.size() and _stun_left[f] > 0.0


## 까마귀 한 마리가 살아 있는 작물 하나를 쫀다 (아무 칸이나, 까마귀 왕이면 생기가 가장 많은 작물. 약은 안 듣는다). 검은 깃털이면 쪼인 작물이 번짐에 걸릴 수 있다
func _peck() -> void:
	var target := _crow_target()
	if target < 0:
		return
	crow_pecked.emit(target)
	_stun_farmer()
	_damage(target, Balance.crow_damage(cloud_dps(), Upgrades.level(Balance.Upgrade.BEAK)))
	if is_alive(target) and infected[target] == 0 and rng.randf() < Balance.feather_chance(Upgrades.level(Balance.Upgrade.FEATHER)):
		_infect(target)


func _crow_target() -> int:
	var count := alive_count()
	if count <= 0:
		return -1
	if Upgrades.level(Balance.Upgrade.CROW_KING) > 0:
		var best := -1
		for i in kinds.size():
			if is_alive(i) and (best < 0 or crop_vitality(i) > crop_vitality(best)):
				best = i
		return best
	var pick := rng.randi_range(0, count - 1)
	for i in kinds.size():
		if is_alive(i):
			if pick == 0:
				return i
			pick -= 1
	return -1


## 까마귀 소란: 농부 하나(무작위)를 멈춘다. 이미 멈춰 있으면 더 긴 쪽
func _stun_farmer() -> void:
	var stun := Balance.racket_stun(Upgrades.level(Balance.Upgrade.RACKET))
	if stun <= 0.0 or farmers.is_empty():
		return
	var f := rng.randi_range(0, farmers.size() - 1)
	_stun_left[f] = maxf(_stun_left[f], stun)


## 농부가 노리던 자리에 닿으면 다음 자리 (살아 있는 작물 하나, 없으면 밭 가운데)
func _walk(f: int, dt: float) -> void:
	var step := _farmer_targets[f] - farmers[f]
	var reach := Balance.guardian_speed(farmer_kinds[f]) * dt
	if step.length() <= reach:
		farmers[f] = _farmer_targets[f]
		_farmer_targets[f] = _next_target()
	else:
		farmers[f] += step.normalized() * reach


func _next_target() -> Vector2:
	var count := alive_count()
	if count <= 0:
		return Vector2.ONE * Balance.FIELD_SIZE * 0.5
	var pick := rng.randi_range(0, count - 1)
	for i in kinds.size():
		if is_alive(i):
			if pick == 0:
				return cell_position(i)
			pick -= 1
	return Vector2.ONE * Balance.FIELD_SIZE * 0.5


## 둘레 안의 번진 작물을 씻어 낸다
func _spray(f: int) -> void:
	for i in kinds.size():
		if infected[i] == 1 and is_alive(i) and cell_position(i).distance_to(farmers[f]) <= Balance.guardian_radius(farmer_kinds[f]):
			infected[i] = 0
			farmer_sprayed.emit(i)


## 둘레 안의 시든 칸 하나에 다시 심는다 (가장 가까운 칸)
func _replant(f: int) -> void:
	var pick := -1
	var nearest := Balance.guardian_radius(farmer_kinds[f])
	for i in kinds.size():
		if kinds[i] == EMPTY or is_alive(i):
			continue
		var distance := cell_position(i).distance_to(farmers[f])
		if distance <= nearest:
			nearest = distance
			pick = i
	if pick >= 0:
		_grow(pick)
		crop_regrown.emit(pick)


## night/skills.gd가 채운다 (까마귀 떼 동안 빨리)
func _crow_speed() -> float:
	return 1.0


## night/waves.gd가 채운다 (까마귀가 쪼고 번짐을 옮길 때 부른다)
func _damage(_index: int, _amount: float) -> void:
	pass


func _infect(_index: int) -> void:
	pass

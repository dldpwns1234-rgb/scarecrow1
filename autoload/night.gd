extends "res://autoload/night/field.gd"
## 밤 한 판의 흐름 (GDD 4절): 시작(밭 심기·시계), 역병 구름의 박자, 번짐, 까마귀, 시듦과 생기, 다시 자라기, 밭 정복, 끝. 밭 자체(칸·심기·밭 단계)는 night/field.gd.
## 화면(scenes/night/)은 시그널을 받아 그리고 set_cloud()로 구름 자리만 넘긴다. 화면 없이도 돈다: 시뮬레이션 봇이 set_cloud()와 tick()을 직접 부른다.
## 수치는 Balance, 생기는 Game.add_vitality(), 밤 끝은 Game.finish_night(). 상태 변경은 이 오토로드의 함수로만 한다

signal night_started()
signal crop_hit(index: int, hp: float, damage: float)  # 구름·번짐·까마귀가 친 순간 (연출용)
signal crop_withered(index: int, vitality: float)
signal crop_infected(index: int)
signal crow_pecked(index: int)
signal pulsed()                                        # 구름이 한 번 쳤다 (박자 연출)
signal time_changed(seconds_left: float)
signal field_cleared(level: int)                       # 밭 정복: 남은 작물이 쓰러지고 다음 단계가 열렸다. 정복한 단계를 넘긴다

var active: bool = false
var time_left: float = 0.0
var cleared: bool = false          # 이번 밤에 밭을 정복했다
var _pulse_left: float = 0.0
var _tick: float = Balance.CLOUD_TICK  # 이번 밤의 박자 간격 (어스름)
var _crow_left: Array[float] = []


func _ready() -> void:
	reset()
	Game.phase_changed.connect(_on_phase_changed.unbind(1))


func _process(delta: float) -> void:
	if active:
		tick(minf(delta, Balance.MAX_DELTA))


## 데이터 초기화에서만 부른다
func reset() -> void:
	active = false
	cleared = false
	time_left = 0.0
	super()


## 다음 밤의 밭 단계를 고른다. 밤 중에는 못 바꾼다
func choose_level(level: int) -> bool:
	return not active and super(level)


## 밤 시작: 밭을 새로 심고 시계를 건다 (Game이 밤으로 바뀌면 부른다). seed가 0 이상이면 그 시드로 심는다
func begin(seed: int = -1) -> void:
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	_plant()
	active = true
	cleared = false
	time_left = Game.night_seconds()
	_tick = Balance.cloud_tick(Upgrades.level(Balance.Upgrade.DUSK))
	_pulse_left = _tick
	_crow_left.clear()
	var crows := Balance.crow_count(Upgrades.level(Balance.Upgrade.CROW))
	for i in crows:
		_crow_left.append(Balance.CROW_INTERVAL * float(i + 1) / float(crows))  # 한꺼번에 쪼지 않게 고르게 흩는다
	set_cloud(Vector2.ONE * Balance.FIELD_SIZE * 0.5)
	night_started.emit()
	time_changed.emit(time_left)


## 시간을 흘린다 (화면이 있으면 _process가, 시뮬레이션은 직접 부른다)
func tick(dt: float) -> void:
	if not active:
		return
	time_left -= dt
	_pulse_left -= dt
	while active and _pulse_left <= 0.0:
		_pulse_left += _tick
		_pulse()
	_tick_regrow(dt)
	for i in _crow_left.size():
		_crow_left[i] -= dt
		if active and _crow_left[i] <= 0.0:
			_crow_left[i] += Balance.CROW_INTERVAL
			_peck()
	if not active:
		return
	time_changed.emit(maxf(time_left, 0.0))
	if time_left <= 0.0:
		_end()


## 구름 박자: 원 안의 작물은 구름 피해, 번짐에 걸린 작물은 번짐 피해 (한 박자 몫)
func _pulse() -> void:
	var dps := cloud_dps()
	var hit := dps * _tick
	var rot := Balance.rot_dps(dps, Upgrades.level(Balance.Upgrade.ROT)) * _tick
	var radius := cloud_radius()
	pulsed.emit()
	for i in kinds.size():
		if not active:
			return
		if not is_alive(i):
			continue
		var amount := 0.0
		if cell_position(i).distance_to(cloud) <= radius:
			amount += hit
		if infected[i] == 1:
			amount += rot
		if amount > 0.0:
			_damage(i, amount)


## 까마귀 한 마리가 살아 있는 작물 하나를 쫀다 (아무 칸이나). 검은 깃털이면 쪼인 작물이 번짐에 걸릴 수 있다
func _peck() -> void:
	var count := alive_count()
	if count <= 0:
		return
	var pick := rng.randi_range(0, count - 1)
	for i in kinds.size():
		if not is_alive(i):
			continue
		if pick == 0:
			crow_pecked.emit(i)
			_damage(i, Balance.crow_damage(cloud_dps(), Upgrades.level(Balance.Upgrade.BEAK)))
			if is_alive(i) and infected[i] == 0 and rng.randf() < Balance.feather_chance(Upgrades.level(Balance.Upgrade.FEATHER)):
				_infect(i)
			return
		pick -= 1


func _damage(index: int, amount: float) -> void:
	hp[index] = maxf(hp[index] - amount, 0.0)
	crop_hit.emit(index, hp[index], amount)
	if hp[index] <= 0.0:
		_wither(index, true)


## 시듦: 생기를 주고 옆 칸으로 번지고, 다시 자라는 뿌리가 있으면 시계를 건다. 남은 작물이 처음 심은 수의 10% 아래면 밭 정복
func _wither(index: int, spread: bool) -> void:
	hp[index] = 0.0
	infected[index] = 0
	withered += 1
	var gained := crop_vitality(index)
	Game.add_vitality(gained)
	crop_withered.emit(index, gained)
	if cleared:
		return
	regrow_left[index] = Balance.regrow_delay(Upgrades.level(Balance.Upgrade.REGROW))
	if spread:
		_spread_from(index)
	if alive_count() <= floori(first_planted * (1.0 - Balance.CLEAR_RATIO)):
		_clear()


func _spread_from(index: int) -> void:
	var chance := Balance.spread_chance(Upgrades.level(Balance.Upgrade.SPREAD))
	if chance <= 0.0:
		return
	for n in neighbors(index):
		if is_alive(n) and infected[n] == 0 and rng.randf() < chance:
			_infect(n)


func _infect(index: int) -> void:
	infected[index] = 1
	crop_infected.emit(index)


## 밭 정복: 남은 작물이 저절로 쓰러지고(생기는 준다) 다음 밭 단계가 열린다
func _clear() -> void:
	cleared = true
	var level := field_level
	for i in kinds.size():
		if is_alive(i):
			_wither(i, false)
	_unlock_next()
	field_cleared.emit(level)
	_end()


## 밤을 일찍 끝낸다 ('새벽까지 쉬기'). 그때까지 거둔 생기는 그대로다
func stop() -> void:
	_end()


func _end() -> void:
	if not active:
		return
	active = false
	time_left = maxf(time_left, 0.0)
	Game.finish_night()


func _on_phase_changed() -> void:
	if Game.is_night() and not active:
		begin()
	elif not Game.is_night():
		active = false

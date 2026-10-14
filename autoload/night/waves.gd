extends "res://autoload/night/critters.gd"
## Night 3부: 시듦·번짐·정복·물결 (GDD 4절). 작물이 맞으면 체력이 줄고, 다하면 시들어 생기를 주고 옆으로 번지고, 다시 자라는 뿌리면 시계를 건다.
## 이번 물결에서 심은 수의 90%가 시들면 정복: 남은 작물이 쓰러지고, 가장 높은 단계였으면 다음 단계가 열리고, 밤은 이어져 밭이 새로 심긴다 (방장 2026-10-14)

signal crop_hit(index: int, hp: float, damage: float)  # 구름·번짐·까마귀가 친 순간 (연출용)
signal crop_withered(index: int, vitality: float)
signal crop_infected(index: int)
signal field_cleared(level: int)                       # 밭 정복: 남은 작물이 쓰러지고(처음이면 다음 단계가 열리고) 다음 물결이 심긴다. 정복한 단계를 넘긴다
signal wave_started(wave: int)                         # 정복 뒤 새로 심긴 물결 (1부터)

var cleared: bool = false          # 이번 밤에 밭을 한 번이라도 정복했다
var waves: int = 0                 # 이번 밤에 정복한 수 (정복할 때마다 밭이 새로 심긴다)
var _clearing: bool = false        # 정복으로 남은 작물을 쓰러뜨리는 중
var _wave_withered: int = 0        # 이번 물결이 시작할 때의 시든 수
var _wave_haul: float = 0.0        # 이번 물결이 시작할 때의 이번 밤 생기


func _damage(index: int, amount: float) -> void:
	hp[index] = maxf(hp[index] - amount, 0.0)
	crop_hit.emit(index, hp[index], amount)
	if hp[index] <= 0.0:
		_wither(index, true)


## 시듦: 생기를 주고 옆 칸으로 번지고, 다시 자라는 뿌리가 있으면 시계를 건다. 이번 물결에서 시든 수가 심은 수의 90%에 닿으면 밭 정복
func _wither(index: int, spread: bool) -> void:
	hp[index] = 0.0
	infected[index] = 0
	withered += 1
	var gained := crop_vitality(index)
	Game.add_vitality(gained)
	crop_withered.emit(index, gained)
	if _clearing:
		return
	regrow_left[index] = Balance.regrow_delay(Upgrades.level(Balance.Upgrade.REGROW))
	if spread:
		_spread_from(index)
	if wave_withered() >= clear_target():
		_clear()


## 밭 정복에 필요한 시든 작물 수 (이번 물결)
func clear_target() -> int:
	return ceili(first_planted * Balance.CLEAR_RATIO)


## 이번 물결에서 시든 수
func wave_withered() -> int:
	return withered - _wave_withered


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


## 밭 정복: 남은 작물이 저절로 쓰러지고(생기는 준다), 가장 높은 단계였으면 다음 단계가 열리고, 밤은 이어져 밭이 새로 심긴다 (방장 2026-10-14).
## 수확일이면 이번 물결의 생기를 반만큼 더 얹는다
func _clear() -> void:
	cleared = true
	var level := field_level
	_clearing = true
	for i in kinds.size():
		if is_alive(i):
			_wither(i, false)
	_clearing = false
	if Balance.is_harvest(level):
		Game.add_vitality((Game.night_haul - _wave_haul) * Balance.HARVEST_CLEAR_BONUS)
	_unlock_next()
	waves += 1
	field_cleared.emit(level)
	_replant_wave()
	_wave_withered = withered
	_wave_haul = Game.night_haul
	wave_started.emit(waves)

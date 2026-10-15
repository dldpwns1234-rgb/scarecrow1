extends "res://autoload/night/weather.gd"
## Night 3.7부: 철마다 새 작물의 버릇 (방장 #626 '알아서 개선', 장르 조사 '겨울잠 뒤에 새로 열리는 것'). 작물 표와 섞여 드는 철은 balance/crops.gd.
## 얼음꽃(첫 겨울잠 뒤): 시들면 둘레의 작물이 얼어붙는다 (서리와 같은 얼음: 체력 ×2.5·생기 ×4, 시들면 깨지며 옆을 친다. night/weather.gd).
## 버섯(둘째): 번진 채 심겨 저절로 썩어 가고, 시들면 상하좌우의 작물을 다 번지게 한다. 달맞이꽃(셋째): 새벽이 가까울수록 생기가 커진다.
## 밤의 남은 시간(time_left)도 여기 둔다 (달맞이꽃이 밤이 지난 몫을 잰다. 흐름은 night.gd)

signal crops_frozen(index: int, targets: PackedInt32Array)  # 얼음꽃이 시들며 둘레를 얼렸다 (연출용)

var time_left: float = 0.0
var night_length: float = 1.0     # 이번 밤이 시작할 때의 길이 (새벽 미루기로 늘어난 몫은 안 친다)


## 밤이 지난 몫 (0 → 1). 새벽 미루기로 남은 시간이 늘면 0 쪽으로 돌아간다
func night_progress() -> float:
	return clampf(1.0 - time_left / maxf(night_length, 1e-9), 0.0, 1.0)


## 버섯은 번진 채 심긴다
func _grow(index: int) -> void:
	super(index)
	if kinds[index] == Balance.Crop.MUSHROOM:
		infected[index] = 1


## 달맞이꽃: 칸 몫에 × (1 + 2 × 밤이 지난 몫)
func _cell_factor(index: int, rotten: bool) -> float:
	var factor := super(index, rotten)
	if kinds[index] == Balance.Crop.MOONFLOWER:
		factor *= 1.0 + Balance.MOONFLOWER_BLOOM * night_progress()
	return factor


func _after_wither(index: int) -> void:
	match kinds[index]:
		Balance.Crop.ICEFLOWER:
			_freeze_around(index)
		Balance.Crop.MUSHROOM:
			for n in neighbors(index):
				if is_alive(n) and infected[n] == 0:
					_infect(n)
	super(index)


## 얼음꽃: 둘레의 얼지 않은 작물을 얼린다 (남은 체력의 몫은 그대로)
func _freeze_around(index: int) -> void:
	var at := cell_position(index)
	var reach := ceili(Balance.ICE_RADIUS)
	var cx := index % field_size
	@warning_ignore("integer_division")
	var cy := index / field_size
	var targets := PackedInt32Array()
	for y in range(maxi(cy - reach, 0), mini(cy + reach, field_size - 1) + 1):  # 둘레를 감싼 네모 칸만 본다
		for x in range(maxi(cx - reach, 0), mini(cx + reach, field_size - 1) + 1):
			var i := y * field_size + x
			if i != index and is_alive(i) and not is_frosted(i) and cell_position(i).distance_to(at) <= Balance.ICE_RADIUS:
				frost[i] = 1
				max_hp[i] *= Balance.FROST_HP
				hp[i] *= Balance.FROST_HP
				targets.append(i)
	if not targets.is_empty():
		crops_frozen.emit(index, targets)

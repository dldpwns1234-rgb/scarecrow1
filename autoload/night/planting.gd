extends "res://autoload/night/field.gd"
## Night 1.5부: 심기 (GDD 4절). 밤 시작과 물결의 밭 심기(심는 비율·작물 비율·밭 망보기의 황금 이삭), 무더기·덩굴 작물 따라 심기, 다시 자라기.
## 밭 크기·칸 배열은 night/field.gd, 수치는 Balance(balance/crops.gd·night.gd)

signal crop_regrown(index: int)  # 다시 자라는 뿌리: 시든 칸에 새 작물

## 밭을 새로 심는다: 칸마다 심는 비율(빽빽한 밭)만큼 작물, 종류는 밭 단계의 비율(탐스러운 호박)대로
func _plant() -> void:
	_clear_field()
	var fill := Balance.field_fill(Upgrades.level(Balance.Upgrade.DENSE))
	for i in cell_count():
		if rng.randf() < fill:
			_grow(i)
	_add_goldens(Workers.watch_goldens())
	first_planted = crops_total


## 밭 망보기(아지트): 심긴 작물 중 n개를 황금 이삭으로 바꾼다
func _add_goldens(n: int) -> void:
	for _i in n:
		var picks: Array[int] = []
		for i in cell_count():
			if is_alive(i) and kinds[i] != Balance.Crop.GOLDEN:
				picks.append(i)
		if picks.is_empty():
			return
		var cell := picks[rng.randi_range(0, picks.size() - 1)]
		kinds[cell] = Balance.Crop.GOLDEN
		max_hp[cell] = Balance.crop_hp(Balance.Crop.GOLDEN, field_level, Upgrades.level(Balance.Upgrade.FERTILE)) * Balance.harvest_hp(field_level)
		hp[cell] = max_hp[cell]


## 다음 물결: 밭을 새로 심는다 (밤 중에 정복하면). 시든 수와 심은 수는 밤 전체로 이어 센다
func _replant_wave() -> void:
	var fill := Balance.field_fill(Upgrades.level(Balance.Upgrade.DENSE))
	var before := crops_total
	for i in cell_count():
		kinds[i] = EMPTY
		hp[i] = 0.0
		infected[i] = 0
		regrow_left[i] = 0.0
		if rng.randf() < fill:
			_grow(i)
	_add_goldens(Workers.watch_goldens())
	first_planted = crops_total - before


## 칸 하나에 작물을 심는다 (밤 시작과 다시 자라기). 체력은 밭 단계와 비옥한 어둠대로
func _grow(index: int) -> void:
	var crop := _pick_crop(index)
	kinds[index] = crop
	max_hp[index] = Balance.crop_hp(crop, field_level, Upgrades.level(Balance.Upgrade.FERTILE)) * Balance.harvest_hp(field_level)
	hp[index] = max_hp[index]
	infected[index] = 0
	regrow_left[index] = 0.0
	regrown[index] = 0
	crops_total += 1


## 심을 작물: 황금 이삭(확률), 옆의 무더기·덩굴 작물을 따라 심기, 아니면 밭 단계의 비율대로
func _pick_crop(index: int) -> int:
	var roll := rng.randf()
	if rng.randf() < Balance.golden_chance(Upgrades.level(Balance.Upgrade.GOLDEN)):
		return Balance.Crop.GOLDEN
	var follow := _cluster_neighbor(index)
	if follow >= 0 and rng.randf() < Balance.cluster_chance(follow, Upgrades.level(Balance.Upgrade.TURNIP)):
		return follow
	var weights := Balance.crop_weights(field_level, Upgrades.level(Balance.Upgrade.PUMPKIN), Winter.sleeps)
	for crop in weights.size():
		roll -= weights[crop]
		if roll < 0.0:
			return crop
	return Balance.Crop.WHEAT


## 따라 심을 이웃 작물: 왼쪽 칸이 무더기·덩굴 작물이거나, 위 칸이 무더기 작물이면 그 작물 (없으면 -1)
func _cluster_neighbor(index: int) -> int:
	var x := index % field_size
	if x > 0 and is_alive(index - 1) and not Balance.crop_cluster(kinds[index - 1]).is_empty():
		return kinds[index - 1]
	if index >= field_size and is_alive(index - field_size) and Balance.crop_cluster(kinds[index - field_size]) == "blob":
		return kinds[index - field_size]
	return -1


## 시든 칸의 다시 자라기 시계를 흘린다. 다 된 칸에는 새 작물 (night.gd의 tick이 부른다)
func _tick_regrow(dt: float) -> void:
	for i in regrow_left.size():
		if regrow_left[i] <= 0.0:
			continue
		regrow_left[i] -= dt
		if regrow_left[i] <= 0.0:
			_grow(i)
			regrown[i] = 1
			crop_regrown.emit(i)

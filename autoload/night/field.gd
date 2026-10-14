extends Node
## Night 1부: 밭 (GDD 4절). 격자의 칸마다 작물 종류·체력·번짐, 심기와 다시 자라기, 조회, 역병 구름의 자리·반경·피해, 밭 단계(고른 단계와 열린 단계)와 그 저장.
## 좌표는 격자 단위다: 칸 (x, y)의 가운데가 (x + 0.5, y + 0.5), 칸 번호 = y × FIELD_SIZE + x. 흐름(시작·박자·시듦·끝)은 night.gd가 상속해서 맡는다

signal field_level_changed(level: int, best: int)
signal crop_regrown(index: int)  # 다시 자라는 뿌리: 시든 칸에 새 작물

const EMPTY: int = -1
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var field_level: int = 1          # 이번 밤(또는 다음 밤)의 밭 단계
var best_level: int = 1           # 열린 가장 높은 밭 단계
var kinds: PackedInt32Array       # 칸마다 작물 종류 (Balance.Crop), 맨땅은 EMPTY
var hp: PackedFloat64Array        # 남은 체력. 0이면 시들었다
var max_hp: PackedFloat64Array
var infected: PackedByteArray     # 번짐에 걸린 작물이면 1
var crops_total: int = 0          # 이번 밤에 심긴 작물 수 (다시 자란 것 포함)
var first_planted: int = 0        # 밤이 시작할 때 심긴 수. 밭 정복의 기준
var regrow_left: PackedFloat64Array  # 시든 칸이 다시 자라기까지 남은 초 (0이면 안 자란다)
var withered: int = 0             # 이번 밤에 시든 작물 수
var cloud: Vector2 = Vector2.ZERO  # 역병 구름 가운데 (격자 단위)
var rng := RandomNumberGenerator.new()  # 밭 배치·번짐·까마귀. 시뮬레이션과 테스트는 시드를 고정한다


func to_dict() -> Dictionary:
	return {"field_level": field_level, "best_level": best_level}


## 없는 필드는 1로. 고른 단계는 열린 단계를 넘지 않는다. 불러오면 늘 낮이라 밭은 비어 있다
func from_dict(data: Dictionary) -> void:
	reset()
	best_level = clampi(int(data.get("best_level", 1)), 1, Balance.MAX_FIELD_LEVEL)
	field_level = clampi(int(data.get("field_level", best_level)), 1, best_level)
	field_level_changed.emit(field_level, best_level)


## 데이터 초기화에서만 부른다 (night.gd가 밤 상태도 함께 비운다)
func reset() -> void:
	field_level = 1
	best_level = 1
	_clear_field()
	field_level_changed.emit(field_level, best_level)


func cell_count() -> int:
	return Balance.FIELD_SIZE * Balance.FIELD_SIZE


func cell_position(index: int) -> Vector2:
	@warning_ignore("integer_division")
	return Vector2(index % Balance.FIELD_SIZE + 0.5, index / Balance.FIELD_SIZE + 0.5)


func is_alive(index: int) -> bool:
	return kinds[index] != EMPTY and hp[index] > 0.0


func alive_count() -> int:
	return crops_total - withered


## 구름을 옮긴다 (화면은 커서·손가락 자리를, 봇은 노리는 자리를 넘긴다). 밭 밖으로는 나가지 않는다
func set_cloud(position: Vector2) -> void:
	var size := float(Balance.FIELD_SIZE)
	cloud = Vector2(clampf(position.x, 0.0, size), clampf(position.y, 0.0, size))


func cloud_radius() -> float:
	return Balance.cloud_radius(Upgrades.level(Balance.Upgrade.RADIUS))


func cloud_dps() -> float:
	return Balance.cloud_dps(Upgrades.level(Balance.Upgrade.TOXIN))


## 이 칸이 지금 구름 안인지
func in_cloud(index: int) -> bool:
	return cell_position(index).distance_to(cloud) <= cloud_radius()


## 상하좌우 이웃 칸 번호 (밭 밖은 뺀다)
func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var x := index % Balance.FIELD_SIZE
	@warning_ignore("integer_division")
	var y := index / Balance.FIELD_SIZE
	for offset in NEIGHBORS:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx >= 0 and ny >= 0 and nx < Balance.FIELD_SIZE and ny < Balance.FIELD_SIZE:
			result.append(ny * Balance.FIELD_SIZE + nx)
	return result


## 다음 밤의 밭 단계를 고른다 (열린 단계까지)
func choose_level(level: int) -> bool:
	if level < 1 or level > best_level:
		return false
	field_level = level
	field_level_changed.emit(field_level, best_level)
	return true


## 지금 단계를 정복했으면 다음 단계를 열고 그리로 옮긴다 (가장 높은 단계를 깼을 때만)
func _unlock_next() -> void:
	if field_level == best_level and best_level < Balance.MAX_FIELD_LEVEL:
		best_level += 1
		field_level = best_level
		field_level_changed.emit(field_level, best_level)


## 이 칸의 작물을 시들게 하면 받는 생기 (썩은 냄새 배율 포함)
func crop_vitality(index: int) -> float:
	var value := Balance.crop_vitality(kinds[index], field_level, Upgrades.level(Balance.Upgrade.FERTILE), Upgrades.level(Balance.Upgrade.PUMPKIN))
	return Balance.cap(value * Balance.vitality_multiplier(Upgrades.level(Balance.Upgrade.ROT_VALUE)))


## 밭을 새로 심는다: 칸마다 심는 비율(빽빽한 밭)만큼 작물, 종류는 밭 단계의 비율(탐스러운 호박)대로
func _plant() -> void:
	_clear_field()
	var fill := Balance.field_fill(Upgrades.level(Balance.Upgrade.DENSE))
	for i in cell_count():
		if rng.randf() < fill:
			_grow(i)
	first_planted = crops_total


## 칸 하나에 작물을 심는다 (밤 시작과 다시 자라기). 체력은 밭 단계와 비옥한 어둠대로
func _grow(index: int) -> void:
	var weights := Balance.crop_weights(field_level, Upgrades.level(Balance.Upgrade.PUMPKIN))
	var roll := rng.randf()
	var crop: int = Balance.Crop.WHEAT
	if roll >= weights[0] + weights[1]:
		crop = Balance.Crop.PUMPKIN
	elif roll >= weights[0]:
		crop = Balance.Crop.CORN
	kinds[index] = crop
	max_hp[index] = Balance.crop_hp(crop, field_level, Upgrades.level(Balance.Upgrade.FERTILE))
	hp[index] = max_hp[index]
	infected[index] = 0
	regrow_left[index] = 0.0
	crops_total += 1


## 시든 칸의 다시 자라기 시계를 흘린다. 다 된 칸에는 새 작물 (night.gd의 tick이 부른다)
func _tick_regrow(dt: float) -> void:
	for i in regrow_left.size():
		if regrow_left[i] <= 0.0:
			continue
		regrow_left[i] -= dt
		if regrow_left[i] <= 0.0:
			_grow(i)
			crop_regrown.emit(i)


func _clear_field() -> void:
	kinds = PackedInt32Array()
	kinds.resize(cell_count())
	kinds.fill(EMPTY)
	hp = PackedFloat64Array()
	hp.resize(cell_count())
	max_hp = PackedFloat64Array()
	max_hp.resize(cell_count())
	infected = PackedByteArray()
	infected.resize(cell_count())
	regrow_left = PackedFloat64Array()
	regrow_left.resize(cell_count())
	crops_total = 0
	first_planted = 0
	withered = 0

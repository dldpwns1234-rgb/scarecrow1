extends Node
## Night 1부: 밭 (GDD 4절). 격자의 칸마다 작물 종류·체력·번짐, 심기, 조회, 밭 단계(고른 단계와 열린 단계)와 그 저장.
## 좌표는 격자 단위다: 칸 (x, y)의 가운데가 (x + 0.5, y + 0.5), 칸 번호 = y × FIELD_SIZE + x. 흐름(시작·박자·시듦·끝)은 night.gd가 상속해서 맡는다

signal field_level_changed(level: int, best: int)

const EMPTY: int = -1
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var field_level: int = 1          # 이번 밤(또는 다음 밤)의 밭 단계
var best_level: int = 1           # 열린 가장 높은 밭 단계
var kinds: PackedInt32Array       # 칸마다 작물 종류 (Balance.Crop), 맨땅은 EMPTY
var hp: PackedFloat64Array        # 남은 체력. 0이면 시들었다
var max_hp: PackedFloat64Array
var infected: PackedByteArray     # 번짐에 걸린 작물이면 1
var crops_total: int = 0          # 이번 밤에 심긴 작물 수
var withered: int = 0             # 이번 밤에 시든 작물 수
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


## 밭을 새로 심는다: 칸마다 FIELD_FILL 확률로 작물, 종류는 밭 단계의 비율대로
func _plant() -> void:
	_clear_field()
	var weights := Balance.crop_weights(field_level)
	for i in cell_count():
		if rng.randf() >= Balance.FIELD_FILL:
			continue
		var roll := rng.randf()
		var crop: int = Balance.Crop.WHEAT
		if roll >= weights[0] + weights[1]:
			crop = Balance.Crop.PUMPKIN
		elif roll >= weights[0]:
			crop = Balance.Crop.CORN
		kinds[i] = crop
		max_hp[i] = Balance.crop_hp(crop, field_level)
		hp[i] = max_hp[i]
		crops_total += 1


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
	crops_total = 0
	withered = 0

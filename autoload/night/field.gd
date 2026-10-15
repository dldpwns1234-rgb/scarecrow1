extends "res://autoload/night/levels.gd"
## Night 1부: 밭 (GDD 4절). 격자의 칸마다 작물 종류·체력·번짐, 조회, 역병 구름의 자리·반경·피해, 밭 단계의 저장 (단계 자체는 night/levels.gd, 심기는 night/planting.gd).
## 좌표는 격자 단위다: 칸 (x, y)의 가운데가 (x + 0.5, y + 0.5), 칸 번호 = y × field_size + x. 밭 크기는 밤이 시작할 때 밭 단계로 정해지고 그 밤 동안 그대로다. 흐름(시작·박자·시듦·끝)은 night.gd가 상속해서 맡는다

const EMPTY: int = -1
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var field_size: int = 1           # 밭 한 변의 칸 수 (Balance.field_size). 밤마다 _clear_field가 정한다
var kinds: PackedInt32Array       # 칸마다 작물 종류 (Balance.Crop), 맨땅은 EMPTY
var hp: PackedFloat64Array        # 남은 체력. 0이면 시들었다
var max_hp: PackedFloat64Array
var infected: PackedByteArray     # 번짐에 걸린 작물이면 1
var crops_total: int = 0          # 이번 밤에 심긴 작물 수 (다시 자란 것 포함)
var first_planted: int = 0        # 밤이 시작할 때 심긴 수. 밭 정복의 기준
var regrow_left: PackedFloat64Array  # 시든 칸이 다시 자라기까지 남은 초 (0이면 안 자란다)
var regrown: PackedByteArray      # 다시 자라는 뿌리로 다시 자란 작물이면 1 (무성한 뿌리)
var _kill_bonus: float = 1.0      # 지금 치는 쪽이 주는 생기 배율 (까마귀가 쪼는 동안 썩은 고기)
var withered: int = 0             # 이번 밤에 시든 작물 수
var cloud: Vector2 = Vector2.ZERO  # 역병 구름 가운데 (격자 단위)
var rng := RandomNumberGenerator.new()  # 밭 배치·번짐·까마귀. 시뮬레이션과 테스트는 시드를 고정한다


func to_dict() -> Dictionary:
	return {"field_level": field_level, "best_level": best_level, "auto_advance": auto_advance}


## 없는 필드는 1로. 고른 단계는 열린 단계를 넘지 않는다. 불러오면 늘 낮이라 밭은 비어 있다
func from_dict(data: Dictionary) -> void:
	reset()
	best_level = clampi(int(data.get("best_level", 1)), 1, Balance.MAX_FIELD_LEVEL)
	field_level = clampi(int(data.get("field_level", best_level)), 1, best_level)
	auto_advance = bool(data.get("auto_advance", false))
	field_level_changed.emit(field_level, best_level)


## 데이터 초기화에서만 부른다 (night.gd가 밤 상태도 함께 비운다)
func reset() -> void:
	field_level = 1
	best_level = 1
	auto_advance = false
	_clear_field()
	field_level_changed.emit(field_level, best_level)


func cell_count() -> int:
	return field_size * field_size


func cell_position(index: int) -> Vector2:
	@warning_ignore("integer_division")
	return Vector2(index % field_size + 0.5, index / field_size + 0.5)


func is_alive(index: int) -> bool:
	return kinds[index] != EMPTY and hp[index] > 0.0


func alive_count() -> int:
	return crops_total - withered


## 구름을 옮긴다 (화면은 커서·손가락 자리를, 봇은 노리는 자리를 넘긴다). 밭 밖으로는 나가지 않는다
func set_cloud(position: Vector2) -> void:
	var size := float(field_size)
	cloud = Vector2(clampf(position.x, 0.0, size), clampf(position.y, 0.0, size))


func cloud_radius() -> float:
	return Balance.cloud_radius(Upgrades.level(Balance.Upgrade.RADIUS))


## 독한 포자 × 깊은 잠(꿈의 상점) × 포자 말리기(아지트)
func cloud_dps() -> float:
	return Balance.cap(Balance.cloud_dps(Upgrades.level(Balance.Upgrade.TOXIN)) * Winter.damage_multiplier() * Workers.dry_multiplier())


## 이 칸이 지금 구름 안인지
func in_cloud(index: int) -> bool:
	return cell_position(index).distance_to(cloud) <= cloud_radius()


## 상하좌우 이웃 칸 번호 (밭 밖은 뺀다)
func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var x := index % field_size
	@warning_ignore("integer_division")
	var y := index / field_size
	for offset in NEIGHBORS:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx >= 0 and ny >= 0 and nx < field_size and ny < field_size:
			result.append(ny * field_size + nx)
	return result


## 이 칸의 작물을 시들게 하면 받는 생기 (그 작물의 칸·수확일·썩은 냄새·꿈속 수확 배율 포함).
## rotten이면 번진 채 시들었다 (끈적한 포자). 다시 자란 작물(무성한 뿌리), 까마귀가 쪼아 시든 작물(썩은 고기), 물결의 기세, 도깨비 잔치, 업적, 작물 숙련도 곱한다
func crop_vitality(index: int, rotten: bool = false) -> float:
	var bonus := Balance.crop_bonus_upgrade(kinds[index])
	var value := Balance.crop_vitality(kinds[index], field_level, Upgrades.level(Balance.Upgrade.FERTILE), Upgrades.level(bonus) if bonus >= 0 else 0)
	value *= Balance.harvest_vitality(field_level, Upgrades.level(Balance.Upgrade.BOUNTY)) * Winter.vitality_multiplier()
	value *= Balance.vitality_multiplier(Upgrades.level(Balance.Upgrade.ROT_VALUE)) * _kill_bonus * _wave_multiplier() * _boon_multiplier()
	value *= Feats.vitality_multiplier() * Feats.mastery_multiplier(kinds[index])  # 업적·작물 숙련 (겨울잠을 넘어 남는다)
	if rotten:
		value *= Balance.sticky_multiplier(Upgrades.level(Balance.Upgrade.STICKY))
	if index < regrown.size() and regrown[index] == 1:
		value *= Balance.roots_multiplier(Upgrades.level(Balance.Upgrade.ROOTS))
	return Balance.cap(value)


## night/waves.gd가 채운다 (물결의 기세)
func _wave_multiplier() -> float:
	return 1.0


## night/wisp.gd가 채운다 (도깨비 잔치)
func _boon_multiplier() -> float:
	return 1.0


func _clear_field() -> void:
	field_size = Balance.field_size(field_level)
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
	regrown = PackedByteArray()
	regrown.resize(cell_count())
	crops_total = 0
	first_planted = 0
	withered = 0

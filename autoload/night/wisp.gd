extends "res://autoload/night/waves.gd"
## Night 3.5부: 도깨비불 (방장 2026-10-15 #587, 장르 조사 제안 6). 밤이 시작할 때 이번 밤에 뜰지와 때를 정하고, 그때 밭 위에 나타나 떠돌다 사라진다.
## 구름 안에 WISP_CATCH_SECONDS 머물면 잡혀서 보상 하나를 고른다: 잔치(몇 초 동안 생기 배율), 주머니(밭 한 판 반 몫 생기), 장난(열린 스킬이 한꺼번에 터진다),
## 꿈 부스러기(꿈 조각, 겨울잠을 한 번 잔 뒤). 놓쳐도 손해는 없다. 뜰지·자리는 밭 rng와 따로 굴려서 밭 배치·번짐은 도깨비불이 없을 때와 같다.
## 화면은 wisp·wisp_left·feast_left·catch_progress()를 읽어 그린다

signal wisp_appeared()
signal wisp_caught(boon: int, amount: float)  # 잔치는 배율, 주머니는 생기, 장난은 터진 스킬 수, 꿈 부스러기는 조각 수
signal wisp_faded()                            # 못 잡고 사라졌다
signal feast_ended()

var wisp: Vector2 = Vector2.ZERO  # 도깨비불 자리 (격자 단위)
var wisp_left: float = 0.0        # 떠 있는 남은 초. 0이면 없다
var feast_left: float = 0.0       # 도깨비 잔치 남은 초
var _wisp_rng := RandomNumberGenerator.new()
var _wisp_wait: float = 0.0       # 나타나기까지 남은 초
var _wisp_pending: bool = false   # 이번 밤에 아직 나타나지 않았다
var _wisp_heading: float = 0.0    # 떠도는 방향 (라디안)
var _wisp_held: float = 0.0       # 구름 안에 머문 초
var _drought: int = 0             # 뜰 수 있었는데 안 뜬 밤 수 (저장하지 않는다)
var wisp_enabled: bool = true     # 봇이 도깨비불 없는 곡선을 잴 때만 끈다 (tools/sim_night.gd --wisp=off)


func is_wisp_up() -> bool:
	return wisp_left > 0.0


## 잡히기까지 찬 몫 (0~1)
func catch_progress() -> float:
	return clampf(_wisp_held / Balance.WISP_CATCH_SECONDS, 0.0, 1.0)


## 밤이 시작할 때 (night.gd의 begin이 밭을 심은 뒤 부른다)
func _reset_wisp() -> void:
	_wisp_rng.seed = rng.seed + 7919  # 밭 rng를 한 번도 굴리지 않는다
	wisp_left = 0.0
	feast_left = 0.0
	_wisp_held = 0.0
	_wisp_pending = false
	var chance := Balance.wisp_chance(Game.nights, _drought)
	if chance <= 0.0 or not wisp_enabled:
		return
	if _wisp_rng.randf() >= chance:
		_drought += 1
		return
	_drought = 0
	_wisp_pending = true
	var latest := maxf(Game.night_seconds() - Balance.WISP_LIFETIME, Balance.WISP_EARLIEST)
	_wisp_wait = _wisp_rng.randf_range(Balance.WISP_EARLIEST, latest)


## 도깨비 잔치: 그동안 시든 작물의 생기 배율 (night/field.gd의 crop_vitality가 곱한다)
func _boon_multiplier() -> float:
	return Balance.FEAST_MULTIPLIER if feast_left > 0.0 else 1.0


func _tick_wisp(dt: float) -> void:
	if feast_left > 0.0:
		feast_left -= dt
		if feast_left <= 0.0:
			feast_left = 0.0
			feast_ended.emit()
	if _wisp_pending:
		_wisp_wait -= dt
		if _wisp_wait <= 0.0:
			_appear()
		return
	if wisp_left <= 0.0:
		return
	wisp_left -= dt
	_drift(dt)
	if wisp.distance_to(cloud) <= cloud_radius():
		_wisp_held += dt
		if _wisp_held >= Balance.WISP_CATCH_SECONDS:
			_catch()
			return
	if wisp_left <= 0.0:
		wisp_left = 0.0
		wisp_faded.emit()


## 구름에서 떨어진 자리에 나타난다 (밭이 좁아 그런 자리가 없으면 구름 반대쪽 가장 먼 곳)
func _appear() -> void:
	_wisp_pending = false
	var size := float(field_size)
	var gap := cloud_radius() + Balance.WISP_SPAWN_GAP
	var best := Vector2.ONE * size * 0.5
	for attempt in 12:
		var spot := Vector2(_wisp_rng.randf_range(0.5, size - 0.5), _wisp_rng.randf_range(0.5, size - 0.5))
		if spot.distance_to(cloud) > best.distance_to(cloud):
			best = spot
		if spot.distance_to(cloud) >= gap:
			break
	wisp = best
	wisp_left = Balance.WISP_LIFETIME
	_wisp_held = 0.0
	_wisp_heading = _wisp_rng.randf() * TAU
	wisp_appeared.emit()


## 떠돈다: 방향을 조금씩 틀고, 밭 가장자리에 닿으면 밭 가운데 쪽으로 돌아선다
func _drift(dt: float) -> void:
	_wisp_heading += _wisp_rng.randf_range(-1.0, 1.0) * Balance.WISP_TURN * dt
	var next := wisp + Vector2.from_angle(_wisp_heading) * Balance.WISP_SPEED * dt
	var size := float(field_size)
	var inside := Vector2(clampf(next.x, 0.5, size - 0.5), clampf(next.y, 0.5, size - 0.5))
	if inside != next:
		_wisp_heading = (Vector2.ONE * size * 0.5 - inside).angle()
	wisp = inside


## 잡혔다: 받을 수 있는 보상 가운데 몫대로 하나
func _catch() -> void:
	wisp_left = 0.0
	_wisp_held = 0.0
	_grant(_pick_boon())


## 보상을 준다 (테스트는 보상마다 바로 부른다)
func _grant(boon: int) -> void:
	var amount := 0.0
	match boon:
		Balance.Boon.FEAST:
			feast_left = Balance.FEAST_SECONDS
			amount = Balance.FEAST_MULTIPLIER
		Balance.Boon.PURSE:
			amount = Balance.purse_vitality(_field_value())
			Game.add_vitality(amount)
		Balance.Boon.PRANK:
			for skill in Balance.SKILLS.size():
				if use_skill(skill):
					amount += 1.0
		Balance.Boon.DREAM:
			amount = Balance.dream_crumbs(Winter.shard_reward())
			Winter.add_shards(amount)
	wisp_caught.emit(boon, amount)


func _pick_boon() -> int:
	var skills_open := false
	for skill in Balance.SKILLS.size():
		skills_open = skills_open or is_skill_unlocked(skill)
	var slept := Winter.sleeps > 0 and Winter.shard_reward() > 0.0
	var weights: Array[float] = []
	var total := 0.0
	for boon in Balance.BOONS.size():
		weights.append(Balance.boon_weight(boon, skills_open, slept))
		total += weights[boon]
	var roll := _wisp_rng.randf() * total
	for boon in weights.size():
		roll -= weights[boon]
		if roll < 0.0:
			return boon
	return Balance.Boon.FEAST


## 밭 한 판 몫: 이번 밭에 심긴 작물을 모두 시들게 하면 받는 생기 (지금 배율로)
func _field_value() -> float:
	var total := 0.0
	for i in kinds.size():
		if kinds[i] != EMPTY:
			total += crop_vitality(i)
	return Balance.cap(total)

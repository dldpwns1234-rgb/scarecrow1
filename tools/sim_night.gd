extends "res://tools/sim_day.gd"
## 밤 시뮬레이션 (GDD 4절, 밸런스용). 실제 Balance·Upgrades·Game·Night 코드를 화면 없이 그대로 돌린다.
##
##   godot --headless --path . res://tools/sim_night.tscn [-- --nights=60 --speed=12 --day=15 --seed=1 --log=1 --retry=2 --winter=1 --stall=6]
##
## 사람 흉내: 밤에는 구름을 '값어치가 가장 몰린 자리'로 옮긴다 (원 안 작물의 생기 ÷ 남은 체력 합이 가장 큰 작물 자리, 0.25초마다 다시 고름).
## 커서는 초당 speed칸까지 움직인다. 낮에는 살 수 있는 업그레이드를 싼 것부터 다 사고, 열린 가장 높은 밭 단계로 나간다.
## 못 깨면 사람처럼 한 단계씩 내려가 모으고, 깨면 한 단계씩 올라가 다시 도전한다 (못 깨는 밭만 붙들면 수입이 바닥이라 벽이 실제보다 가팔라 보였고,
## 겨울 씨앗으로 높은 단계에서 맨손으로 시작한 철에는 영영 못 벗어났다). 가장 높은 단계에서 못 깨면 retry밤 동안 아래에서 모은 뒤 다시 간다.
## 겨울잠(winter=1): 열린 단계가 stall밤 동안 오르지 않고 겨울잠에 들 수 있으면 들고, 꿈 조각을 싼 것부터 다 쓴다. 철마다 한 줄씩 찍는다.
## 낮에 쓰는 시간(day초)을 밤 길이에 더해 실제 시간을 어림한다. 결과는 docs/BALANCE_SIM.md에 적는다

const DT: float = 0.05
const RETARGET: float = 0.25

var _speed: float = 12.0

var _log: bool = true
var _retry: int = 2
var _farm_left: int = 0  # 가장 높은 단계에서 진 뒤 아래에서 더 모을 밤 수
var _play_level: int = 1  # 다음 밤에 나갈 단계
var _winter: bool = false
var _stall: int = 6


func _ready() -> void:
	Save.blocked = true
	var args := _args()
	var nights := int(args.get("nights", "60"))
	_speed = float(args.get("speed", "12"))
	_day = float(args.get("day", "15"))
	_log = args.get("log", "1") == "1"
	_retry = int(args.get("retry", "2"))
	_winter = args.get("winter", "0") == "1"
	_stall = int(args.get("stall", "6"))
	var seed := int(args.get("seed", "1"))
	Upgrades.reset()
	Game.reset()
	Night.reset()
	Winter.reset()
	Workers.reset()
	var clock := 0.0
	var season_start := 0.0
	var since_new := 0
	var best_seen := Night.best_level
	print("밤 | 단계 | 생기 | 시든/전체 | 정복 | 누적 분 | 산 것")
	var firsts: Dictionary = {}
	for n in nights:
		_day_work()
		var bought := _shop()
		_pick_level()
		var level := Night.field_level
		Game.start_night()
		Night.begin(seed * 1000 + n)
		var seconds := _play()
		clock += seconds + _day
		var cleared := Night.cleared
		_after_night(level, cleared)
		if cleared and not firsts.has(level):
			firsts[level] = [n + 1, clock / 60.0]
		since_new = 0 if Night.best_level > best_seen else since_new + 1
		best_seen = Night.best_level
		if _log:
			print("%d | %d | %s | %d/%d | %s | %.1f | %s" % [n + 1, level, Num.format(Game.last_haul), Night.withered, Night.crops_total,
				"정복" if cleared else "-", clock / 60.0, bought])
		if _winter and since_new >= _stall and Winter.can_sleep():
			var reached := Night.best_level
			var reward := Winter.shard_reward()
			Winter.perform()
			print("== 겨울잠 %d: %.1f분 철 (누적 %.1f분), 밭 %d단계, 꿈 조각 +%s, 산 꿈: %s" % [Winter.sleeps, (clock - season_start) / 60.0, clock / 60.0,
				reached, Num.format(reward), _dream_shop()])
			print("   바친 생기 %s, 약속된 휴식 %.1f일" % [Num.format(Game.offered), Game.promised_rest_seconds() / 86400.0])
			season_start = clock
			_play_level = Night.best_level
			since_new = 0
			best_seen = Night.best_level
			firsts.clear()
	print("")
	print("단계 첫 정복: ", _firsts_text(firsts))
	print("업그레이드: ", _levels_text())
	get_tree().quit()


func _pick_level() -> void:
	Night.choose_level(clampi(_play_level, 1, Night.best_level))


## 깨면 올라가고(가장 높은 단계에서 진 뒤에는 retry밤 동안 그 아래에 머문다), 못 깨면 한 단계 내려간다
func _after_night(level: int, cleared: bool) -> void:
	if not cleared:
		if level == Night.best_level:
			_farm_left = _retry
		_play_level = maxi(level - 1, 1)
	elif _farm_left > 0 and level == Night.best_level - 1:
		_farm_left -= 1
		_play_level = level
	else:
		_play_level = Night.best_level


## 밤 한 판을 끝까지 돈다. 걸린 시간(초)을 돌려준다
func _play() -> float:
	var elapsed := 0.0
	var retarget := 0.0
	var target := Night.cloud
	while Night.active:
		retarget -= DT
		if retarget <= 0.0:
			retarget = RETARGET
			target = _best_spot()
		var step := target - Night.cloud
		var reach := _speed * DT
		Night.set_cloud(Night.cloud + (step if step.length() <= reach else step.normalized() * reach))
		Night.tick(DT)
		elapsed += DT
	return elapsed


## 원 안 작물의 (생기 ÷ 남은 체력) 합이 가장 큰 작물 자리. 작물마다 값을 한 번만 재고, 후보 둘레의 네모 칸만 본다
func _best_spot() -> Vector2:
	var radius := Night.cloud_radius()
	var size := Balance.FIELD_SIZE
	var reach := ceili(radius)
	var value := PackedFloat64Array()
	value.resize(Night.cell_count())
	for j in Night.cell_count():
		if Night.is_alive(j):
			value[j] = Night.crop_vitality(j) / maxf(Night.hp[j], 1e-9)
	var best := -1.0
	var spot := Night.cloud
	for i in Night.cell_count():
		if value[i] <= 0.0:
			continue
		var center := Night.cell_position(i)
		var cx := i % size
		@warning_ignore("integer_division")
		var cy := i / size
		var score := 0.0
		for y in range(maxi(cy - reach, 0), mini(cy + reach, size - 1) + 1):
			for x in range(maxi(cx - reach, 0), mini(cx + reach, size - 1) + 1):
				var j := y * size + x
				if value[j] > 0.0 and Night.cell_position(j).distance_to(center) <= radius:
					score += value[j]
		if score > best:
			best = score
			spot = center
	return spot


func _firsts_text(firsts: Dictionary) -> String:
	var parts: Array[String] = []
	for level: int in firsts:
		parts.append("%d단계 %d번째 밤(%.1f분)" % [level, firsts[level][0], firsts[level][1]])
	return "  ".join(parts)


func _levels_text() -> String:
	var parts: Array[String] = []
	for i in Balance.UPGRADES.size():
		parts.append("%s %d" % [Balance.upgrade_name(i), Upgrades.level(i)])
	return ", ".join(parts)


func _args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() == 2:
			result[pair[0]] = pair[1]
	return result
